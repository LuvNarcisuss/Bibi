import Foundation
import StoreKit
import OSLog

/// StoreKit 1 purchases for the diamond packages. A transaction is finished only after its diamonds are saved.
@MainActor
final class StoreKit1Purchasing: NSObject, SKPaymentTransactionObserver {
    var onChange: ((WalletLedger, [String: String]) -> Void)?
    var onCatalogChange: ((StoreProductStatus) -> Void)?

    private let productsFetcher = BibiStoreProductFetcher()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Bibi", category: "InAppPurchase")
    private var catalog = StoreProductStatus()
    private var productTimeout: Task<Void, Never>?
    private var ledger = WalletLedger.empty
    private var products: [String: SKProduct] = [:]
    private var prices: [String: String] = [:]
    private var productWaiters: [CheckedContinuation<Void, Never>] = []
    private var productRequestInFlight = false
    private var productRequestGeneration = 0
    private var persist: ((WalletLedger) async -> Bool)?
    private var observing = false
    private var acceptingPurchases = false
    private var queueDelivered = false
    private var expected: [String: Int] = [:]
    private var waiters: [String: [PurchaseWait]] = [:]
    private var preexistingObjects: Set<ObjectIdentifier> = []
    private var preexistingIDs: Set<String> = []
    private var finishedObjects: Set<ObjectIdentifier> = []
    private var tail: Task<Void, Never>?

    override init() {
        super.init()
        productsFetcher.onFinish = { [weak self] generation, loaded, invalid in
            Task { @MainActor in
                guard let self, self.productRequestInFlight,
                      self.productRequestGeneration == generation else { return }
                self.apply(loaded, invalid: invalid)
            }
        }
        productsFetcher.onFail = { [weak self] generation, error in
            Task { @MainActor in
                guard let self, self.productRequestInFlight,
                      self.productRequestGeneration == generation else { return }
                self.failProductRequest(error)
            }
        }
    }

    func adopt(_ ledger: WalletLedger) {
        self.ledger = ledger
        publish()
    }

    func setPersist(_ persist: @escaping (WalletLedger) async -> Bool) {
        self.persist = persist
    }

    func start() async {
        guard persist != nil else { return }
        guard !observing else {
            acceptingPurchases = true
            reloadProductsIfNeeded()
            return
        }
        queueDelivered = false
        for transaction in SKPaymentQueue.default().transactions {
            rememberPreexisting(transaction)
        }
        observing = true
        acceptingPurchases = false
        SKPaymentQueue.default().add(self)
        for _ in 0..<10 { await Task.yield() }
        await drain()
        acceptingPurchases = true
        beginProductRequest()
    }

    func reloadProductsIfNeeded() {
        guard acceptingPurchases, products.count < WalletCatalog.productIDs.count else { return }
        beginProductRequest()
    }

    func retryProducts() {
        guard acceptingPurchases else { return }
        beginProductRequest()
    }

    var diagnostics: String {
        let bundle = Bundle.main.bundleIdentifier ?? "unknown"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        return """
        Bibi StoreKit diagnostics
        Bundle ID: \(bundle)
        Version: \(version) (\(build))
        Payments allowed: \(SKPaymentQueue.canMakePayments())
        Catalog state: \(catalog.phase.rawValue)
        Requested IDs: \(catalog.requestedIDs.joined(separator: ", "))
        Returned IDs: \(catalog.returnedIDs.joined(separator: ", "))
        Invalid IDs: \(catalog.invalidIDs.joined(separator: ", "))
        Error: \(catalog.errorCode ?? "none")
        """
    }

    func stop() async {
        acceptingPurchases = false
        productRequestGeneration += 1
        productTimeout?.cancel()
        productsFetcher.cancel()
        productRequestInFlight = false
        catalog.phase = .idle
        publishCatalog()
        resumeProductWaiters()
        if observing {
            SKPaymentQueue.default().remove(self)
            observing = false
        }
        await drain()
    }

    func clearMemory() {
        ledger = .empty
        let pending = waiters
        waiters = [:]
        expected = [:]
        let message = "Purchase did not go through. You have not been charged."
        for list in pending.values {
            for wait in list { settle(wait, message: message) }
        }
        publish()
    }

    /// Retained for callers compiled against the previous wallet interface.
    func spend(_ gift: StarGift, quantity: Int, target: GiftTarget,
               isAvailable: @escaping @MainActor () -> Bool) async -> String? {
        "Post gifts are no longer available. No diamonds were spent."
    }

    func unlock(_ item: CosmeticItem) async -> String? {
        await editLedger(failure: "No diamonds were spent.") { ledger in
            var state = ledger.cosmetics ?? CosmeticState()
            if state.ownedIDs.contains(item.id) {
                state.equip(item.kind, id: item.id)
                ledger.cosmetics = state
                return .changed
            }
            let (balance, overflow) = ledger.diamonds.subtractingReportingOverflow(item.diamonds)
            guard item.diamonds > 0, !overflow, balance >= 0 else {
                return .failed("\(item.name) costs \(item.diamonds.formatted()) diamonds. No diamonds were spent.")
            }
            ledger.diamonds = balance
            state.ownedIDs.append(item.id)
            state.equip(item.kind, id: item.id)
            ledger.cosmetics = state
            ledger.recordSpend(id: "unlock-" + item.id + "-" + UUID().uuidString, title: item.name, amount: item.diamonds, kind: "unlock")
            return .changed
        }
    }

    func equip(_ kind: CosmeticKind, id: String?) async -> String? {
        await editLedger(failure: "The look was not changed.") { ledger in
            var state = ledger.cosmetics ?? CosmeticState()
            if let id, !state.ownedIDs.contains(id) { return .failed("Unlock this look before using it.") }
            state.equip(kind, id: id)
            ledger.cosmetics = state
            return .changed
        }
    }

    /// Charges once per challenge. A challenge already in the paid set is unchanged.
    func payForChallenge(_ challengeID: String) async -> String? {
        await editLedger(failure: "No diamonds were spent.") { ledger in
            var state = ledger.cosmetics ?? CosmeticState()
            if state.paidChallengeIDs.contains(challengeID) { return .unchanged }
            let cost = CosmeticCatalog.challengeEntryDiamonds
            let (balance, overflow) = ledger.diamonds.subtractingReportingOverflow(cost)
            guard !overflow, balance >= 0 else {
                return .failed("Joining a challenge costs \(cost.formatted()) diamonds. No diamonds were spent.")
            }
            ledger.diamonds = balance
            state.paidChallengeIDs.append(challengeID)
            ledger.cosmetics = state
            ledger.recordSpend(id: "challenge-" + challengeID + "-" + UUID().uuidString, title: "Challenge entry", amount: cost, kind: "challenge")
            return .changed
        }
    }

    func refundChallenge(_ challengeID: String) async -> String? {
        await editLedger(failure: "The diamond refund could not be saved.") { ledger in
            var state = ledger.cosmetics ?? CosmeticState()
            guard state.paidChallengeIDs.contains(challengeID) else { return .unchanged }
            let cost = CosmeticCatalog.challengeEntryDiamonds
            let (balance, overflow) = ledger.diamonds.addingReportingOverflow(cost)
            guard !overflow else { return .failed("The diamond refund could not be saved.") }
            ledger.diamonds = balance
            state.paidChallengeIDs.removeAll { $0 == challengeID }
            ledger.cosmetics = state
            ledger.recordSpend(id: "refund-" + challengeID + "-" + UUID().uuidString, title: "Challenge entry refund", amount: cost, kind: "refund")
            return .changed
        }
    }

    private final class LedgerEditBox { var message: String? }
    private enum LedgerEdit { case unchanged, changed, failed(String) }

    private func editLedger(failure: String, _ body: @escaping (inout WalletLedger) -> LedgerEdit) async -> String? {
        let box = LedgerEditBox()
        let previous = tail
        let next = Task { @MainActor in
            await previous?.value
            box.message = await self.commitLedgerEdit(failure: failure, body)
        }
        tail = next
        await next.value
        return box.message
    }

    private func commitLedgerEdit(failure: String, _ body: (inout WalletLedger) -> LedgerEdit) async -> String? {
        var next = ledger
        switch body(&next) {
        case .failed(let message): return message
        case .unchanged: return nil
        case .changed:
            guard next.isValid, let persist, await persist(next) else { return failure }
            ledger = next
            publish()
            return nil
        }
    }

    func purchase(_ package: WalletPackage) async -> String? {
        guard !package.storeProductID.isEmpty else { return "Purchases are not available yet. No payment was started." }
        guard acceptingPurchases else { return "Please wait for the current request to finish." }
        guard SKPaymentQueue.canMakePayments() else {
            return "Purchases are turned off in Settings. You have not been charged."
        }
        guard let product = await resolveProduct(package.storeProductID) else {
            return catalog.purchaseFailure(for: package.storeProductID)
        }
        guard acceptingPurchases else { return "The store session ended. No payment was started." }
        let wait = PurchaseWait()
        expected[package.storeProductID, default: 0] += 1
        waiters[package.storeProductID, default: []].append(wait)
        logger.info("Presenting Apple payment sheet for \(product.productIdentifier, privacy: .public)")
        SKPaymentQueue.default().add(SKPayment(product: product))
        return await withCheckedContinuation { continuation in
            if wait.settled {
                continuation.resume(returning: wait.message)
            } else {
                wait.continuation = continuation
            }
        }
    }

    private func resolveProduct(_ productID: String) async -> SKProduct? {
        if let product = products[productID] { return product }
        if !productRequestInFlight { beginProductRequest() }
        if productRequestInFlight {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                productWaiters.append(continuation)
            }
        }
        return products[productID]
    }

    /// Asks StoreKit 1 for the catalog IDs. A second call waits on the request already running.
    private func beginProductRequest() {
        guard !productRequestInFlight else { return }
        let identifiers = WalletCatalog.productIDs
        guard !identifiers.isEmpty else {
            catalog = StoreProductStatus(phase: .unavailable, errorCode: "No configured product IDs")
            publishCatalog()
            return
        }
        productRequestInFlight = true
        productRequestGeneration += 1
        let generation = productRequestGeneration
        catalog = StoreProductStatus(phase: .loading, requestedIDs: identifiers.sorted(), returnedIDs: products.keys.sorted())
        publishCatalog()
        logger.info("Requesting products for \(Bundle.main.bundleIdentifier ?? "unknown", privacy: .public): \(identifiers.sorted().joined(separator: ","), privacy: .public)")
        productsFetcher.start(identifiers, generation: generation)
        productTimeout?.cancel()
        productTimeout = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 20_000_000_000) } catch { return }
            guard let self else { return }
            guard self.productRequestGeneration == generation, self.productRequestInFlight else { return }
            self.productsFetcher.cancel()
            self.productRequestInFlight = false
            self.catalog.phase = .timedOut
            self.catalog.errorCode = "Product request timed out after 20 seconds"
            self.logger.error("Product request timed out")
            self.publishCatalog()
            self.resumeProductWaiters()
        }
    }

    private func apply(_ loaded: [SKProduct], invalid: [String]) {
        let rejected = Set(invalid)
        var nextProducts: [String: SKProduct] = [:]
        var nextPrices: [String: String] = [:]
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        for product in loaded {
            guard !rejected.contains(product.productIdentifier),
                  WalletCatalog.package(forProductID: product.productIdentifier) != nil else { continue }
            formatter.locale = product.priceLocale
            nextProducts[product.productIdentifier] = product
            nextPrices[product.productIdentifier] = formatter.string(from: product.price) ?? "See price"
        }
        products = nextProducts
        prices = nextPrices
        productTimeout?.cancel()
        productRequestInFlight = false
        catalog.returnedIDs = products.keys.sorted()
        catalog.invalidIDs = invalid.sorted()
        catalog.phase = products.isEmpty ? .unavailable : (products.count == WalletCatalog.productIDs.count ? .ready : .partial)
        logger.info("Products returned: \(self.catalog.returnedIDs.joined(separator: ","), privacy: .public); invalid: \(invalid.joined(separator: ","), privacy: .public)")
        publishCatalog()
        publish()
        resumeProductWaiters()
    }

    private func failProductRequest(_ error: Error) {
        productTimeout?.cancel()
        productRequestInFlight = false
        catalog.phase = .failed
        // Record domains and codes only; never log receipts, account details, or error userInfo.
        var current: NSError? = error as NSError
        var codes: [String] = []
        while let item = current, codes.count < 5 {
            codes.append("\(item.domain) (\(item.code))")
            current = item.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        catalog.errorCode = codes.joined(separator: " -> ")
        logger.error("Product request failed: \(self.catalog.errorCode ?? "unknown", privacy: .public)")
        publishCatalog()
        resumeProductWaiters()
    }

    private func publishCatalog() {
        onCatalogChange?(catalog)
    }

    private func resumeProductWaiters() {
        let waiters = productWaiters
        productWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }

    private func publish() {
        onChange?(ledger, prices)
    }

    private func enqueue(_ transactions: [SKPaymentTransaction]) {
        let previous = tail
        let next = Task { @MainActor in
            await previous?.value
            for transaction in transactions {
                await self.handle(transaction)
            }
        }
        tail = next
    }

    private func handle(_ transaction: SKPaymentTransaction) async {
        if finishedObjects.contains(ObjectIdentifier(transaction)) { return }
        let productID = transaction.payment.productIdentifier
        switch transaction.transactionState {
        case .purchasing:
            return
        case .deferred:
            rememberPreexisting(transaction)
            resumeWaiting(
                productID,
                message: "This purchase is waiting for approval. Diamonds are added when it is approved."
            )
        case .failed:
            finish(transaction)
            resumeWaiting(productID, message: failureMessage(transaction.error))
        case .purchased, .restored:
            guard WalletCatalog.package(forProductID: productID) != nil else {
                resumeWaiting(productID, message: "This purchase could not be matched to a diamond package. No diamonds were added. Please check your App Store purchase history.")
                return
            }
            switch await credit(transaction) {
            case .savedNew:
                finish(transaction)
                resumeWaiting(productID, message: nil)
            case .alreadySaved:
                finish(transaction)
                resumeWaiting(productID, message: nil)
            case .notSaved:
                rememberPreexisting(transaction)
                resumeWaiting(
                    productID,
                    message: "Diamonds could not be saved on this device. If you were charged, they will be added when you open the app again."
                )
            }
        default:
            return
        }
    }

    private func drain() async {
        var drained: Task<Void, Never>?
        while let next = tail, next != drained {
            drained = next
            await next.value
        }
    }

    /// Credits one catalog consumable at most once.
    private func credit(_ transaction: SKPaymentTransaction) async -> CreditOutcome {
        let productID = transaction.payment.productIdentifier
        guard let package = WalletCatalog.package(forProductID: productID) else { return .notSaved }
        let identifiers = transactionIdentifiers(transaction)
        guard !identifiers.isEmpty else { return .notSaved }
        if identifiers.contains(where: { ledger.creditedTransactionIDs.contains($0) }) {
            preexistingIDs.formUnion(identifiers)
            guard let persist, await persist(ledger) else { return .notSaved }
            return .alreadySaved
        }
        let quantity = transaction.payment.quantity
        let (total, overflow) = package.amount.multipliedReportingOverflow(by: quantity)
        let (balance, balanceOverflow) = ledger.diamonds.addingReportingOverflow(total)
        guard quantity > 0, package.amount > 0, !overflow, !balanceOverflow, balance >= ledger.diamonds else {
            return .notSaved
        }
        var next = ledger
        next.diamonds = balance
        let amountText = total.formatted(.number.locale(Locale(identifier: "en_US")))
        next.activity.insert(
            WalletActivity(
                id: identifiers[0], title: "Added \(amountText) diamonds",
                currency: .diamonds, amount: total, date: transaction.transactionDate ?? Date()
            ),
            at: 0
        )
        if next.activity.count > 40 { next.activity = Array(next.activity.prefix(40)) }
        for identifier in identifiers where !next.creditedTransactionIDs.contains(identifier) {
            next.creditedTransactionIDs.append(identifier)
        }
        guard next.isValid, let persist, await persist(next) else { return .notSaved }
        preexistingIDs.formUnion(identifiers)
        ledger = next
        publish()
        return .savedNew
    }

    private func finish(_ transaction: SKPaymentTransaction) {
        finishedObjects.insert(ObjectIdentifier(transaction))
        forgetPreexisting(transaction)
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    private func resumeWaiting(_ productID: String, message: String?) {
        guard let count = expected[productID], count > 0 else { return }
        expected[productID] = count == 1 ? nil : count - 1
        guard var queue = waiters[productID], !queue.isEmpty else { return }
        let wait = queue.removeFirst()
        waiters[productID] = queue
        settle(wait, message: message)
    }

    private func settle(_ wait: PurchaseWait, message: String?) {
        guard !wait.settled else { return }
        wait.settled = true
        wait.message = message
        if let continuation = wait.continuation {
            wait.continuation = nil
            continuation.resume(returning: message)
        }
    }

    private func failureMessage(_ error: Error?) -> String {
        guard let error = error as? SKError else {
            return "Purchase did not go through. You have not been charged."
        }
        switch error.code {
        case .paymentCancelled:
            return "Purchase canceled. You have not been charged."
        case .paymentNotAllowed:
            return "Purchases are turned off in Settings. You have not been charged."
        case .storeProductNotAvailable:
            return "This package is not available. You have not been charged."
        default:
            return "Purchase did not go through. You have not been charged."
        }
    }

    private func transactionIdentifiers(_ transaction: SKPaymentTransaction) -> [String] {
        [transaction.transactionIdentifier, transaction.original?.transactionIdentifier]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
    }

    private func rememberPreexisting(_ transaction: SKPaymentTransaction) {
        preexistingObjects.insert(ObjectIdentifier(transaction))
        preexistingIDs.formUnion(transactionIdentifiers(transaction))
    }

    private func forgetPreexisting(_ transaction: SKPaymentTransaction) {
        preexistingObjects.remove(ObjectIdentifier(transaction))
    }

    nonisolated func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        let batch = transactions
        Task { @MainActor in
            if !self.queueDelivered && self.expected.isEmpty {
                self.queueDelivered = true
                for transaction in batch { self.rememberPreexisting(transaction) }
            } else if !self.acceptingPurchases {
                for transaction in batch { self.rememberPreexisting(transaction) }
            }
            self.enqueue(batch)
        }
    }
}

/// Kept off the main-actor class so StoreKit 1 can call this delegate.
@objc(BibiStoreProductFetcher)
final class BibiStoreProductFetcher: NSObject, SKProductsRequestDelegate {
    private var request: SKProductsRequest?
    private var generation = 0
    var onFinish: ((Int, [SKProduct], [String]) -> Void)?
    var onFail: ((Int, Error) -> Void)?

    func start(_ identifiers: Set<String>, generation: Int) {
        let begin = {
            self.request?.cancel()
            self.generation = generation
            let next = SKProductsRequest(productIdentifiers: identifiers)
            next.delegate = self
            self.request = next
            next.start()
        }
        if Thread.isMainThread {
            begin()
        } else {
            DispatchQueue.main.async(execute: begin)
        }
    }

    func cancel() {
        let cancelRequest = {
            self.request?.cancel()
            self.request = nil
        }
        if Thread.isMainThread { cancelRequest() }
        else { DispatchQueue.main.async(execute: cancelRequest) }
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let loaded = response.products
        let invalid = response.invalidProductIdentifiers
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard request === self.request else { return }
            let generation = self.generation
            self.request = nil
            self.onFinish?(generation, loaded, invalid)
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard request === self.request else { return }
            let generation = self.generation
            self.request = nil
            self.onFail?(generation, error)
        }
    }
}

private enum CreditOutcome {
    case savedNew
    case alreadySaved
    case notSaved
}

private final class PurchaseWait {
    var continuation: CheckedContinuation<String?, Never>?
    var settled = false
    var message: String?
}
