import Foundation
import StoreKit
import XCTest
@testable import Bibi

@MainActor
final class PurchaseGate {
    private var continuation: CheckedContinuation<Void, Never>?
    var waiting: Bool { continuation != nil }
    func wait() async { await withCheckedContinuation { continuation = $0 } }
    func release() { continuation?.resume(); continuation = nil }
}

final class SimulatedPurchaseProduct: SKProduct, @unchecked Sendable {
    let sku: String
    init(_ sku: String) { self.sku = sku; super.init() }
    override var productIdentifier: String { sku }
}

final class SimulatedPurchaseTransaction: SKPaymentTransaction, @unchecked Sendable {
    let value: SKPayment
    let reference: String?
    let state: SKPaymentTransactionState
    let failure: Error?
    init(payment: SKPayment, id: String?, state: SKPaymentTransactionState, error: Error? = nil) {
        value = payment; reference = id; self.state = state; failure = error; super.init()
    }
    override var payment: SKPayment { value }
    override var transactionIdentifier: String? { reference }
    override var transactionState: SKPaymentTransactionState { state }
    override var error: Error? { failure }
}

/// Installed only on the fixture URLSession. Every request is intercepted; unknown routes fail closed.
final class PurchaseOfflineURLProtocol: URLProtocol {
    @MainActor static var routes: [String: (URLRequest) async throws -> (Int, Data)] = [:]
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Task { @MainActor in
            do {
                guard let key = request.value(forHTTPHeaderField: "Authorization"), let route = Self.routes[key] else { throw URLError(.unsupportedURL) }
                let (status, data) = try await route(request)
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
    }
    override func stopLoading() {}
}

@MainActor
final class PurchaseChainHarness: BibiPurchaseSettlement {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("bibi-chain-" + UUID().uuidString)
    var accountID: UUID? = UUID()
    let routeID = "Bearer offline-" + UUID().uuidString
    var active = true
    var allowed = true
    var environment = "Sandbox"
    var interactionTimeout: UInt64 = 90_000_000_000
    var resolver: ((String) async -> SKProduct?)?
    var journal: BibiPurchaseJournal!
    var service: StoreKit1Purchasing!
    var observer: SKPaymentTransactionObserver?
    var registrations = 0
    var payments: [SKPayment] = []
    var queue: [SKPaymentTransaction] = []
    var finishSnapshots: [BibiPurchaseRecord] = []
    var failedFinishes = 0
    var receiptCalls = 0
    var confirmCalls = 0
    var statusCalls = 0
    var serverCredits = 0
    var externalConfirmations = 0
    var balanceRefreshes = 0
    var balanceFailure = false
    var loseNextConfirmation = false
    var requests: [[String:Any]] = []
    var server: [String: (UUID, [String:Any])] = [:]
    var override: (([String:Any]) async throws -> (Int,[String:Any])?)?
    var receiptOperation: ((Int) async throws -> Data)?
    lazy var package = WalletCatalog.package(forProductID: "ldbsrbbhebevxdjf")!
    lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [PurchaseOfflineURLProtocol.self]
        return URLSession(configuration: config)
    }()
    lazy var client = BibiSettlementClient(currentAccount: { [unowned self] in accountID },
                                          authorization: { [unowned self] _ in String(routeID.dropFirst(7)) }, session: session)

    func open() async {
        PurchaseOfflineURLProtocol.routes[routeID] = { [unowned self] in try await receive($0) }
        journal = BibiPurchaseJournal(root: root)
        var runtime = BibiPurchaseRuntime.disabled
        runtime.register = { [unowned self] in observer = $0; registrations += 1; return queue }
        runtime.snapshot = { [unowned self] in queue }
        runtime.canPay = { [unowned self] in allowed }; runtime.environment = { [unowned self] in environment }
        runtime.appleInteractionTimeoutNanoseconds = interactionTimeout
        runtime.deviceContext = { ("0.1.0", "00000000-0000-4000-8000-000000000009") }
        runtime.isActive = { [unowned self] in active }
        runtime.resolve = { [unowned self] sku in
            if let resolver { return await resolver(sku) }
            return SimulatedPurchaseProduct(sku)
        }
        runtime.submit = { [unowned self] in payments.append($0) }
        runtime.finish = { [unowned self] tx in
            if tx.transactionState == .failed { failedFinishes += 1; return }
            guard let id = tx.transactionIdentifier, let record = record(id) else { XCTFail("Finish without durable transaction"); return }
            finishSnapshots.append(record)
            queue.removeAll { $0 === tx }
            observer?.paymentQueue?(SKPaymentQueue.default(), removedTransactions: [tx])
        }
        runtime.sleep = { _ in try Task.checkCancellation(); await Task.yield() }
        let evidence = BibiReceiptEvidence(refresh: { [unowned self] in
            receiptCalls += 1
            if let receiptOperation { return try await receiptOperation(receiptCalls) }
            return Data("isolated-receipt-\(receiptCalls)".utf8)
        }, isActive: { [unowned self] in active })
        service = StoreKit1Purchasing.offline(journal: journal, runtime: runtime, evidence: evidence, settlement: self)
        await service.start()
    }
    func restart(eraseJournal: Bool = false, replay: [SKPaymentTransaction]? = nil) async {
        await service.endOfflineValidation()
        if eraseJournal { try? FileManager.default.removeItem(at: root) }
        if let replay { queue = replay }
        await open()
    }
    func close() async {
        await service.endOfflineValidation()
        PurchaseOfflineURLProtocol.routes[routeID] = nil
        session.invalidateAndCancel()
        try? FileManager.default.removeItem(at: root)
        override = nil; receiptOperation = nil; resolver = nil; observer = nil
    }
    func record(_ id: String) -> BibiPurchaseRecord? { journal.record(transactionID: id, environment: "Sandbox") }
    func until(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<400 { if predicate() { return }; try await Task.sleep(nanoseconds: 5_000_000) }
        XCTFail("Offline chain did not reach the expected state", file: file, line: line)
        throw URLError(.timedOut)
    }
    func begin(socket: Bool = false, product: String = "external-only-sku", order: String? = nil) async throws -> (payment: SKPayment, result: Task<String?,Never>) {
        let count = payments.count
        let result = Task { @MainActor in
            if socket {
                return await service.purchaseFromSocket(productID: product, reference: order,
                    messageID: UUID().uuidString, context: BibiExternalPurchaseContext(supabaseAccountID: accountID!,
                        origin: URL(string:"https://bibi.byig.top")!, appID:"48369038", authenticationAttemptID: UUID()))
            }
            return await service.purchase(package)
        }
        try await until { payments.count > count }
        return (payments[count], result)
    }
    @discardableResult
    func emit(_ payment: SKPayment, id: String? = nil, state: SKPaymentTransactionState = .purchased, error: Error? = nil) -> SKPaymentTransaction {
        let tx = SimulatedPurchaseTransaction(payment: payment, id: id, state: state, error: error)
        emitTransaction(tx); return tx
    }
    func emitTransaction(_ tx: SKPaymentTransaction) {
        if tx.transactionState == .purchased || tx.transactionState == .restored {
            if !queue.contains(where: { $0 === tx }) { queue.append(tx) }
        }
        observer?.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [tx])
    }
    func purchaseAvailable(source: ConfiguredPurchaseSource, productID: String, environment: String, account: UUID) async throws -> Bool {
        try await client.availability(source: source, productID: productID, environment: environment, account: account)
    }
    func purchaseStatus(transactionID: String, environment: String, account: UUID) async throws -> BibiSettlementReply {
        try await client.status(transactionID: transactionID, environment: environment, account: account)
    }
    func confirmPurchase(_ record: BibiPurchaseRecord) async throws -> BibiSettlementReply { try await client.confirm(record) }
    func refreshBalance() async throws { balanceRefreshes += 1; if balanceFailure { throw URLError(.notConnectedToInternet) } }
    func failure(_ category: String) -> [String:Any] { ["code":409,"category":category,"state":"needsReconciliation"] }
    func receive(_ request: URLRequest) async throws -> (Int,Data) {
        XCTAssertEqual(request.url?.host, "yepycfnkkfrfmuwdekka.supabase.co")
        XCTAssertEqual(request.url?.path, "/functions/v1/bibi-settlement")
        XCTAssertEqual(request.httpMethod, "POST")
        var data = request.httpBody
        if data == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }; var bytes = Data(); var buffer = [UInt8](repeating:0,count:4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer,maxLength:buffer.count); if n <= 0 { break }; bytes.append(buffer,count:n) }
            data = bytes
        }
        let body = try JSONSerialization.jsonObject(with: data ?? Data()) as! [String:Any]
        let owner = accountID!
        requests.append(body)
        let action = body["action"] as? String
        if action == "confirm" { confirmCalls += 1 }; if action == "status" { statusCalls += 1 }
        if let custom = try await override?(body) { return (custom.0,try JSONSerialization.data(withJSONObject:custom.1)) }
        var reply: [String:Any]
        if action == "availability" {
            reply = ["code":0,"available":true,"source":body["diamond_origin"]!,"environment":body["environment"]!]
        } else {
            let id = body["diamond_reference"] as! String
            if let saved = server[id], saved.0 == owner { reply = saved.1 }
            else if action == "status" { reply = failure("association_missing") }
            else {
                let source = body["diamond_origin"] as! String
                var recovery: [String:Any] = ["contract_id":body["contract_id"]!,"request_id":body["request_id"]!,"app_version":body["bibi_edition"]!,"device_no":body["starlight_installation"]!]
                for key in ["message_id","external_attempt_id","context_origin","app_id"] { recovery[key] = body[key] }
                recovery["order_reference"] = body["orbit_order"]
                reply = ["code":0,"state":"confirmed","transaction_id":id,"environment":body["environment"]!,"source":source,"product_id":body["diamond_product"]!,"quantity":body["diamond_count"]!,"authority":source == "bibi_wallet" ? "supabase":"external","recovery":recovery]
                if source == "bibi_wallet" { serverCredits += 1; reply["balance"] = 400 * serverCredits }
                else { externalConfirmations += 1 }
                server[id] = (owner, reply)
                if loseNextConfirmation { loseNextConfirmation = false; throw URLError(.networkConnectionLost) }
            }
        }
        return (200,try JSONSerialization.data(withJSONObject:reply))
    }
}
