import Foundation
import StoreKit
import OSLog
import UIKit

/// The application's sole SK1 observer owns both native and external purchases.
@MainActor
final class StoreKit1Purchasing: NSObject, SKPaymentTransactionObserver {
    static let shared: StoreKit1Purchasing = {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BIBI_OFFLINE_PURCHASE_VALIDATION"] == "1" {
            return StoreKit1Purchasing(journal: BibiPurchaseJournal(), runtime: .disabled,
                                       evidence: BibiReceiptEvidence(), settlement: nil)
        }
        #endif
        return StoreKit1Purchasing(journal: BibiPurchaseJournal(), runtime: .live,
                                   evidence: BibiReceiptEvidence(), settlement: nil)
    }()
    var onChange: ((WalletLedger, [String: String]) -> Void)?
    var onCatalogChange: ((StoreProductStatus) -> Void)?
    var onRecoveryChange: ((String?) -> Void)?
    var online: (any BibiPurchaseSettlement)?
    private let journal: BibiPurchaseJournal
    private let runtime: BibiPurchaseRuntime
    private let receiptEvidence: BibiReceiptEvidence
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
    private var purchaseUIGeneration = UUID()
    private var tail: Task<Void, Never>?
    private var appleOwner: UUID?
    private var paymentOwners: [ObjectIdentifier: UUID] = [:]
    private var waits: [UUID: BibiPurchaseWait] = [:]
    private var transactions: [String: SKPaymentTransaction] = [:]
    private var bufferedCallbacks: [ObjectIdentifier: SKPaymentTransaction] = [:]
    private var recoveryTasks: [String: Task<Void, Never>] = [:]
    private var receiptAllowed: Set<UUID> = []
    private var refreshTimer: Task<Void, Never>?
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?

    private init(journal: BibiPurchaseJournal, runtime: BibiPurchaseRuntime,
                 evidence: BibiReceiptEvidence, settlement: (any BibiPurchaseSettlement)?) {
        self.journal = journal; self.runtime = runtime; receiptEvidence = evidence; online = settlement
        super.init()
        productsFetcher.onFinish = { [weak self] generation, loaded, invalid in
            Task { @MainActor in
                guard let self, self.productRequestInFlight, self.productRequestGeneration == generation else { return }
                self.apply(loaded, invalid: invalid)
            }
        }
        productsFetcher.onFail = { [weak self] generation, error in
            Task { @MainActor in
                guard let self, self.productRequestInFlight, self.productRequestGeneration == generation else { return }
                self.failProductRequest(error)
            }
        }
    }

    #if DEBUG
    /// Creates an isolated instance that never registers another live Apple observer.
    static func offline(journal: BibiPurchaseJournal, runtime: BibiPurchaseRuntime,
                        evidence: BibiReceiptEvidence, settlement: (any BibiPurchaseSettlement)?) -> StoreKit1Purchasing {
        precondition(!runtime.catalogRequestsEnabled && !runtime.lifecycleObservationEnabled)
        return StoreKit1Purchasing(journal: journal, runtime: runtime, evidence: evidence, settlement: settlement)
    }

    func waitForOfflineRecovery() async {
        precondition(!runtime.catalogRequestsEnabled && !runtime.lifecycleObservationEnabled)
        for task in Array(recoveryTasks.values) { await task.value }
    }

    func endOfflineValidation() async {
        precondition(!runtime.catalogRequestsEnabled && !runtime.lifecycleObservationEnabled)
        await stop()
        online = nil
        let tasks = Array(recoveryTasks.values)
        for task in tasks { task.cancel() }
        for task in tasks { await task.value }
        refreshTimer?.cancel(); refreshTimer = nil
        online = nil
    }
    #endif

    func adopt(_ ledger: WalletLedger) {
        self.ledger = ledger; publish()
        // A trusted legacy delivery can be recognized after its private ledger loads.
        for transaction in transactions.values { handle(transaction) }
    }
    func setPersist(_ persist: @escaping (WalletLedger) async -> Bool) { self.persist = persist }

    func prepareRecovery() async {
        reloadJournal()
        guard !observing else { scheduleRecovery(); return }
        // Protected storage failures quarantine callbacks without removing Apple's unfinished transaction.
        observing = true
        for transaction in runtime.register(self) { handle(transaction) }
        reconcileFinishedQueue()
        guard runtime.lifecycleObservationEnabled else { reportRecovery(); scheduleRecovery(); return }
        let center = NotificationCenter.default
        foregroundObserver = center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.resumeRecovery() }
        }
        backgroundObserver = center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshTimer?.cancel(); self?.refreshTimer = nil }
        }
        reportRecovery(); scheduleRecovery()
    }

    private func reloadJournal() {
        do {
            try journal.load()
            for var record in journal.state.records where record.phase == .prepared {
                record.phase = .failed; record.category = "prepared_not_submitted"
                try journal.save(record)
            }
            let buffered = Array(bufferedCallbacks.values); bufferedCallbacks = [:]
            for transaction in buffered { handle(transaction) }
        } catch { onRecoveryChange?(journal.failure) }
    }

    func start() async {
        await prepareRecovery()
        purchaseUIGeneration = UUID(); acceptingPurchases = true
        reloadProductsIfNeeded()
        resumeRecovery()
    }

    func resumeRecovery(userInitiated: Bool = false) {
        if !journal.isReady { reloadJournal() }
        reconcileFinishedQueue()
        guard journal.isReady else { return }
        for var record in journal.state.records where record.accountID == online?.accountID
                && record.phase == .blocked && record.category == "session_expired" {
            record.phase = record.receiptBase64 == nil ? .awaitingEvidence : .awaitingConfirmation
            try? journal.save(record)
        }
        if userInitiated {
            for var record in journal.state.records where !record.phase.hasDelivery && record.transactionID != nil {
                if record.accountID == online?.accountID || record.accountID == nil {
                    receiptAllowed.insert(record.id)
                    record.nextRetryAt = nil
                    if record.phase == .blocked { record.phase = record.receiptBase64 == nil ? .awaitingEvidence : .awaitingConfirmation }
                    try? journal.save(record)
                }
            }
        }
        scheduleRecovery()
    }

    func reloadProductsIfNeeded() {
        guard runtime.catalogRequestsEnabled, acceptingPurchases, products.count < WalletCatalog.productIDs.count else { return }
        beginProductRequest()
    }
    func retryProducts() { guard runtime.catalogRequestsEnabled, acceptingPurchases else { return }; beginProductRequest() }
    var diagnostics: String {
        let unresolved = journal.state.records.filter { !$0.phase.hasDelivery && $0.phase != .failed }.count
        let unknown = journal.state.records.filter { $0.phase == .needsReconciliation }.count
        return "Bibi StoreKit 1\nBundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")\nCatalog: \(catalog.phase.rawValue)\nUnfinished purchase records: \(unresolved)\nAssociations requiring reconciliation: \(unknown)\n\(journal.failure ?? "")"
    }

    func stop() async {
        invalidatePurchaseUI()
        // Logout pauses original-account confirmations; the single observer remains registered.
        refreshTimer?.cancel(); refreshTimer = nil
        productRequestGeneration += 1; productTimeout?.cancel(); productsFetcher.cancel()
        productRequestInFlight = false; resumeProductWaiters()
        await drain()
    }
    func clearMemory() { invalidatePurchaseUI(); ledger = .empty; publish(); reportRecovery() }
    func invalidatePendingPurchaseAuthorization() { invalidatePurchaseUI() }

    private func invalidatePurchaseUI() {
        purchaseUIGeneration = UUID(); acceptingPurchases = false
        for id in Array(waits.keys) {
            if var record = journal.record(id), record.phase.awaitsApple {
                record.phase = .outcomeUnknown; record.category = "ui_session_ended"
                try? journal.save(record)
            }
            endWait(id, message: "The purchase remains associated with its original account. Reopen the account to continue confirmation.", releaseApple: false)
        }
        if let owner = appleOwner, journal.record(owner)?.phase.awaitsApple != true { appleOwner = nil }
    }

    func purchase(_ package: WalletPackage) async -> String? {
        guard WalletCatalog.productIDs.contains(package.storeProductID) else { return "This diamond package is unavailable." }
        return await beginPurchase(productID: package.storeProductID, source: .local, reference: nil, messageID: nil, context: nil)
    }

    func purchaseFromSocket(productID: String, reference: String?, messageID: String, context: BibiExternalPurchaseContext) async -> String? {
        guard !messageID.isEmpty, messageID.count <= 200, context.isValid, context.supabaseAccountID == online?.accountID,
              reference.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 1_024 }) ?? true else {
            return "The original purchase context is unavailable. No payment was started."
        }
        return await beginPurchase(productID: productID, source: .socket, reference: reference, messageID: messageID, context: context)
    }

    private func beginPurchase(productID: String, source: ConfiguredPurchaseSource, reference: String?, messageID: String?, context: BibiExternalPurchaseContext?) async -> String? {
        guard journal.isReady, observing else { return journal.failure ?? "Purchase recovery is not ready. No payment was started." }
        guard acceptingPurchases, let online, let account = online.accountID else { return "Sign in to your Bibi account before purchasing." }
        guard !productID.isEmpty, productID.count <= 255, runtime.canPay() else { return "Apple purchases are unavailable. No payment was started." }
        if source == .socket, let existing = journal.state.records.first(where: {
            $0.accountID == account && $0.source == .socket &&
                ($0.messageID == messageID || (reference != nil && $0.orderReference == reference))
        }) {
            guard existing.productID == productID, existing.orderReference == reference,
                  existing.externalContext?.origin == context?.origin, existing.externalContext?.appID == context?.appID else { return "This order conflicts with an existing purchase association." }
            resumeRecovery(userInitiated: true)
            return existing.phase == .completed ? nil : "This order is already recorded. Its original payment is being reconciled; no new payment was started."
        }
        if journal.state.records.contains(where: { $0.accountID == account && $0.productID == productID && $0.phase.awaitsApple }) {
            return "Apple has not resolved an earlier purchase request for this product. Its association has been kept; no duplicate payment was started."
        }
        guard appleOwner == nil else { return "Please finish the current Apple purchase interaction." }
        let requestID = UUID(), capturedUIGeneration = purchaseUIGeneration; appleOwner = requestID
        var submittedToApple = false
        defer { if appleOwner == requestID, !submittedToApple { appleOwner = nil } }
        let environment = runtime.environment()
        guard ["Sandbox", "Production"].contains(environment) else {
            return "This receipt environment is not enabled for online settlement. No payment was started."
        }
        do {
            guard try await online.purchaseAvailable(source: source, productID: productID, environment: environment, account: account) else {
                return "Purchase settlement is not configured for this product and source. No payment was started."
            }
            guard let product = await runtime.resolve(productID) else { return "This Apple product is unavailable. No payment was started." }
            guard appleOwner == requestID, acceptingPurchases, purchaseUIGeneration == capturedUIGeneration, online.accountID == account else { return "Your account changed before payment. No payment was started." }
            let (version, device) = try runtime.deviceContext()
            guard !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, version.count <= 64,
                  UUID(uuidString: device) != nil else {
                return "The original device context is unavailable. No payment was started."
            }
            var record = BibiPurchaseRecord(id: requestID, source: source, accountID: account,
                productID: productID, quantity: 1, environment: environment, contractID: BibiSettlementClient.contractID,
                appVersion: version, deviceNo: device, messageID: messageID, orderReference: reference,
                externalContext: context, createdAt: Date(), phase: .prepared)
            try journal.save(record)
            let payment = SKMutablePayment(product: product); payment.quantity = 1
            payment.applicationUsername = requestID.uuidString.lowercased()
            let wait = BibiPurchaseWait()
            // Keep a durable submitted state even when termination occurs around add(payment).
            record.phase = .awaitingTransaction; try journal.save(record)
            guard acceptingPurchases, purchaseUIGeneration == capturedUIGeneration,
                  online.accountID == account, appleOwner == requestID else {
                record.phase = .failed; record.category = "not_submitted_ui_session_ended"
                try journal.save(record)
                return "The account view changed before payment. No payment was started."
            }
            paymentOwners[ObjectIdentifier(payment)] = requestID; waits[requestID] = wait
            submittedToApple = true
            runtime.submit(payment)
            let interactionTimeout = runtime.appleInteractionTimeoutNanoseconds
            wait.timeout = Task { @MainActor [weak self] in
                do { try await Task.sleep(nanoseconds: interactionTimeout) } catch { return }
                guard let self else { return }
                if var pending = self.journal.record(requestID), pending.phase.awaitsApple {
                    pending.phase = .outcomeUnknown; pending.category = "apple_outcome_unknown"
                    try? self.journal.save(pending)
                }
                // UI waiting ends; an actually unresolved Apple interaction is not declared cancelled.
                self.endWait(requestID, message: "Apple has not returned a final result. This purchase request has been kept; do not pay again to recover it.", releaseApple: false)
            }
            return await withCheckedContinuation { continuation in
                if wait.settled { continuation.resume(returning: wait.message) } else { wait.continuation = continuation }
            }
        } catch { return journal.failure ?? "The purchase could not be prepared. No payment was started." }
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

    private func handle(_ transaction: SKPaymentTransaction) {
        guard journal.isReady else {
            bufferedCallbacks[ObjectIdentifier(transaction)] = transaction
            onRecoveryChange?(journal.failure); return
        }
        let environment = runtime.environment()
        let transactionID = transaction.transactionIdentifier.flatMap { $0.isEmpty ? nil : $0 }
        let processOwner = paymentOwners[ObjectIdentifier(transaction.payment)]
        let association = BibiPurchaseAssociation.candidate(records: journal.state.records,
            paymentOwner: processOwner, applicationUsername: transaction.payment.applicationUsername,
            productID: transaction.payment.productIdentifier, quantity: transaction.payment.quantity, environment: environment)
        switch transaction.transactionState {
        case .purchasing: return
        case .deferred:
            if var record = association, record.transactionID == nil {
                record.phase = .deferred; record.category = "approval_pending"
                do { try journal.save(record) } catch { bufferedCallbacks[ObjectIdentifier(transaction)] = transaction; reportRecovery(); return }
                endWait(record.id, message: "Apple is waiting for approval. No entitlement has been delivered.")
            }
        case .failed:
            if var record = association, !record.phase.hasDelivery, record.transactionID == nil {
                record.phase = .failed; record.category = "apple_failed"
                do { try journal.save(record) } catch { bufferedCallbacks[ObjectIdentifier(transaction)] = transaction; reportRecovery(); return }
                endWait(record.id, message: failureMessage(transaction.error))
            }
            // This object really is failed; a server rejection never reaches this branch.
            runtime.finish(transaction)
        case .purchased, .restored:
            guard let transactionID else { onRecoveryChange?("Apple has not provided the paid transaction identifier. The transaction remains unfinished."); return }
            let key = "com.bibi.quadratic|\(environment)|\(transactionID)"
            transactions[key] = transaction
            if var known = journal.record(transactionID: transactionID, environment: environment) {
                if known.productID != transaction.payment.productIdentifier || known.quantity != transaction.payment.quantity {
                    onRecoveryChange?("A purchase conflicts with its original product association. It remains unfinished."); return
                }
                // Transaction identity wins before a new request's payment/username clue.
                if let attempted = association, attempted.id != known.id, attempted.transactionID == nil {
                    var unresolved = attempted; unresolved.phase = .outcomeUnknown; unresolved.category = "earlier_transaction_returned"
                    do { try journal.save(unresolved) } catch { bufferedCallbacks[ObjectIdentifier(transaction)] = transaction; reportRecovery(); return }
                    endWait(attempted.id, message: "Apple returned an earlier transaction. Its original confirmation is being resumed; this request has no new transaction yet.")
                }
                if known.source == nil, ledger.creditedTransactionIDs.contains(transactionID) {
                    known.legacyDeviceDelivery = true; known.phase = .deliveryCommitted
                    known.category = "legacy_device_delivery"
                    do { try journal.save(known) } catch { bufferedCallbacks[ObjectIdentifier(transaction)] = transaction; reportRecovery(); return }
                }
                if known.phase.hasDelivery { finishDelivered(known); return }
                scheduleRecovery(); return
            }
            if transaction.transactionState == .purchased, var record = association, record.transactionID == nil {
                record.transactionID = transactionID; record.observedPaidAt = Date()
                record.associationBasis = processOwner != nil ? "payment_object" : "persisted_application_username"
                record.phase = .awaitingEvidence
                do { try journal.save(record) } catch { bufferedCallbacks[ObjectIdentifier(transaction)] = transaction; reportRecovery(); return }
                receiptAllowed.insert(record.id)
                // Apple interaction and UI loading end independently of server confirmation.
                endWait(record.id, message: "Payment was received. Entitlement confirmation is pending; do not pay again to recover this purchase.")
                scheduleRecovery(); return
            }
            var unknown = BibiPurchaseRecord(id: UUID(), source: nil, accountID: nil,
                productID: transaction.payment.productIdentifier, quantity: transaction.payment.quantity,
                environment: environment, contractID: BibiSettlementClient.contractID, appVersion: "", deviceNo: "",
                messageID: nil, orderReference: nil, externalContext: nil, createdAt: Date(), phase: .needsReconciliation)
            unknown.transactionID = transactionID; unknown.observedPaidAt = Date()
            unknown.category = transaction.transactionState == .restored ? "restored_requires_original_delivery" : "association_missing"
            if ledger.creditedTransactionIDs.contains(transactionID) {
                unknown.legacyDeviceDelivery = true; unknown.phase = .deliveryCommitted
                unknown.category = "legacy_device_delivery"
            }
            do { try journal.save(unknown) } catch { bufferedCallbacks[ObjectIdentifier(transaction)] = transaction; reportRecovery(); return }
            if unknown.phase.hasDelivery { finishDelivered(unknown) } else { scheduleRecovery() }
        @unknown default: break
        }
        reportRecovery()
    }

    private func scheduleRecovery() {
        guard journal.isReady, runtime.isActive() else { return }
        guard online?.accountID != nil else { reportRecovery(); return }
        for record in journal.state.records {
            if record.phase.hasDelivery { finishDelivered(record); continue }
            guard record.transactionID != nil, let key = record.transactionKey,
                  recoveryTasks[key] == nil, recoveryTasks.count < 2,
                  record.nextRetryAt.map({ $0 <= Date() }) ?? true,
                  record.accountID == nil || record.accountID == online?.accountID,
                  record.phase != .blocked, record.phase != .failed else { continue }
            if record.phase == .awaitingEvidence && !receiptAllowed.contains(record.id) { continue }
            recoveryTasks[key] = Task { @MainActor [weak self] in
                guard let self else { return }
                await self.recover(record.id)
                self.recoveryTasks[key] = nil
                self.reportRecovery()
                self.scheduleRecovery()
            }
        }
        refreshTimer?.cancel(); refreshTimer = nil
        let dates = journal.state.records.compactMap { $0.nextRetryAt }.filter { $0 > Date() }
        if let next = dates.min() {
            refreshTimer = Task { @MainActor [weak self] in
                do { try await Task.sleep(nanoseconds: UInt64(min(3600, max(1, next.timeIntervalSinceNow))) * 1_000_000_000) } catch { return }
                self?.scheduleRecovery()
            }
        }
    }

    private func recover(_ id: UUID) async {
        guard let initial = journal.record(id), let online, let account = online.accountID else { return }
        if initial.phase.hasDelivery { finishDelivered(initial); return }
        guard initial.supportsSettlement else { suspend(id, category: "configuration", phase: .blocked); return }
        if initial.accountID == nil {
            await recoverAssociation(initial, account: account, online: online)
            return
        }
        guard initial.accountID == account else { return }
        var correctionUsed = false
        for attempt in 0..<3 {
            guard var record = journal.record(id), !record.phase.hasDelivery, online.accountID == account else { return }
            do {
                if record.phase == .awaitingConfirmation || record.phase == .retryWait || record.phase == .needsReconciliation || (record.category != nil && record.category != "awaiting_evidence") {
                    let status = try await online.purchaseStatus(transactionID: record.transactionID!, environment: record.environment, account: account)
                    if status.confirmed { try accept(status, for: record); return }
                    if ["needs_reconciliation", "ownership_conflict", "configuration", "session_expired", "upstream_rejected", "invalid_input"].contains(status.category) {
                        applyFailure(status.category, id: id); return
                    }
                    if status.category == "processing" {
                        suspend(id, category: "processing", phase: .retryWait, delay: 60); return
                    }
                }
                if record.receiptBase64 == nil {
                    guard receiptAllowed.contains(id), let observed = record.observedPaidAt else {
                        suspend(id, category: "awaiting_evidence", phase: .awaitingEvidence); return
                    }
                    let originalVersion = record.evidenceVersion
                    let evidence: BibiReceiptSnapshot
                    do { evidence = try await receiptEvidence.refreshed(after: observed) }
                    catch {
                        receiptAllowed.remove(id)
                        suspend(id, category: "awaiting_evidence", phase: .awaitingEvidence)
                        return
                    }
                    guard var current = journal.record(id), !current.phase.hasDelivery,
                          current.evidenceVersion == originalVersion, BibiReceiptEvidence.covers(observedAt: observed, refreshStartedAt: evidence.startedAt) else { return }
                    let fingerprint = BibiPurchaseJournal.fingerprint(evidence.data)
                    guard fingerprint != current.rejectedFingerprint else {
                        suspend(id, category: "awaiting_evidence", phase: .blocked); return
                    }
                    current.receiptBase64 = evidence.data.base64EncodedString()
                    current.receiptFingerprint = fingerprint; current.evidenceVersion += 1
                    current.evidenceObtainedAt = evidence.obtainedAt; current.phase = .awaitingConfirmation
                    current.category = nil; current.nextRetryAt = nil
                    try journal.save(current); record = current
                }
                let response = try await online.confirmPurchase(record)
                if response.confirmed { try accept(response, for: record); return }
                if response.category == "awaiting_evidence", !correctionUsed {
                    correctionUsed = true
                    guard var current = journal.record(id), !current.phase.hasDelivery else { return }
                    current.rejectedFingerprint = current.receiptFingerprint; current.receiptBase64 = nil
                    current.phase = .awaitingEvidence; current.category = response.category
                    try journal.save(current)
                    receiptAllowed.insert(id)
                    continue
                }
                if response.category == "transient" {
                    suspend(id, category: response.category, phase: .retryWait, delay: 60)
                    if attempt < 2 {
                        try await self.runtime.sleep(UInt64(attempt == 0 ? 2 : 5) * 1_000_000_000 + UInt64.random(in: 0...400_000_000))
                        continue
                    }
                    return
                }
                applyFailure(response.category, id: id); return
            } catch {
                guard journal.isReady else { reportRecovery(); return }
                guard journal.record(id)?.phase.hasDelivery != true else { return }
                if error as? BibiSettlementTransportError == .sessionExpired || online.accountID != account {
                    suspend(id, category: "session_expired", phase: .blocked); return
                }
                if error as? BibiSettlementTransportError == .invalidResponse {
                    suspend(id, category: "unknown_response", phase: .blocked); return
                }
                // No new payment is added here. A subsequent attempt first queries server state.
                suspend(id, category: "transient", phase: .retryWait, delay: 60)
                if attempt < 2 {
                    do { try await self.runtime.sleep(UInt64(attempt == 0 ? 2 : 5) * 1_000_000_000 + UInt64.random(in: 0...400_000_000)) }
                    catch { return }
                }
            }
        }
        if journal.record(id)?.phase == .awaitingEvidence {
            receiptAllowed.remove(id)
        }
    }

    private func recoverAssociation(_ orphan: BibiPurchaseRecord, account: UUID, online: any BibiPurchaseSettlement) async {
        guard let transaction = orphan.transactionID else { return }
        do {
            let status = try await online.purchaseStatus(transactionID: transaction, environment: orphan.environment, account: account)
            guard journal.record(orphan.id)?.source == nil, journal.record(orphan.id)?.phase.hasDelivery != true else { return }
            guard status.transactionID == transaction, status.environment == orphan.environment,
                  status.productID == orphan.productID, status.quantity == orphan.quantity,
                  let source = status.source, status.recovery["contract_id"] as? String == BibiSettlementClient.contractID else {
                suspend(orphan.id, category: "association_missing", phase: .needsReconciliation, delay: 60); return
            }
            let metadata = status.recovery
            var context: BibiExternalPurchaseContext?
            if source == .socket {
                guard let origin = metadata["context_origin"] as? String, let originURL = URL(string: origin),
                      let appID = metadata["app_id"] as? String,
                      let attempt = (metadata["external_attempt_id"] as? String).flatMap(UUID.init(uuidString:)),
                      let message = metadata["message_id"] as? String, !message.isEmpty else {
                    suspend(orphan.id, category: "association_missing", phase: .needsReconciliation, delay: 60); return
                }
                context = BibiExternalPurchaseContext(supabaseAccountID: account, origin: originURL, appID: appID, authenticationAttemptID: attempt)
                guard context?.isValid == true else { suspend(orphan.id, category: "association_missing", phase: .needsReconciliation, delay: 60); return }
            }
            let request = (metadata["request_id"] as? String).flatMap(UUID.init(uuidString:))
            let version = metadata["app_version"] as? String ?? ""
            let device = metadata["device_no"] as? String ?? ""
            guard status.confirmed || (request != nil && !version.isEmpty && !device.isEmpty) else {
                suspend(orphan.id, category: "association_missing", phase: .needsReconciliation, delay: 60); return
            }
            var restored = BibiPurchaseRecord(id: request ?? orphan.id, source: source, accountID: account,
                productID: orphan.productID, quantity: orphan.quantity, environment: orphan.environment,
                contractID: BibiSettlementClient.contractID, appVersion: version, deviceNo: device,
                messageID: metadata["message_id"] as? String, orderReference: metadata["order_reference"] as? String,
                externalContext: context, createdAt: orphan.createdAt, phase: status.confirmed ? .deliveryCommitted : .awaitingEvidence)
            restored.transactionID = transaction; restored.observedPaidAt = orphan.observedPaidAt
            if !status.confirmed {
                restored.category = status.category
                switch status.category {
                case "needs_reconciliation", "association_missing": restored.phase = .needsReconciliation; restored.nextRetryAt = Date().addingTimeInterval(60)
                case "processing", "transient": restored.phase = .retryWait; restored.nextRetryAt = Date().addingTimeInterval(60)
                case "configuration", "ownership_conflict", "session_expired", "upstream_rejected", "invalid_input": restored.phase = .blocked
                default: restored.phase = .awaitingEvidence
                }
            }
            restored.associationBasis = "owner_scoped_server_record"
            if status.confirmed {
                guard status.matches(restored) else { suspend(orphan.id, category: "ownership_conflict", phase: .blocked); return }
                restored.confirmedAuthority = status.authority; restored.confirmedBalance = status.balance
            }
            try journal.restoreTrusted(restored, replacing: orphan.id)
            if receiptAllowed.remove(orphan.id) != nil { receiptAllowed.insert(restored.id) }
            if restored.phase.hasDelivery { finishDelivered(restored) }
        } catch { suspend(orphan.id, category: "association_missing", phase: .needsReconciliation, delay: 60) }
    }

    private func accept(_ response: BibiSettlementReply, for snapshot: BibiPurchaseRecord) throws {
        guard response.confirmed, response.matches(snapshot), var current = journal.record(snapshot.id) else {
            throw BackendError.invalidInput("The server confirmation does not match the original purchase.")
        }
        if current.phase.hasDelivery { finishDelivered(current); return }
        current.phase = .serverConfirmed; current.confirmedAuthority = response.authority
        current.confirmedBalance = response.balance; current.category = nil; current.nextRetryAt = nil
        try journal.save(current)
        // Both authorities have already delivered; this client performs no second credit.
        current.phase = .deliveryCommitted; current.receiptBase64 = nil
        try journal.save(current)
        finishDelivered(current)
        if response.authority == "supabase", online?.accountID == current.accountID {
            Task { @MainActor [weak self] in try? await self?.online?.refreshBalance() }
        }
    }

    private let finishObjects = NSHashTable<SKPaymentTransaction>(options: [.weakMemory, .objectPointerPersonality])
    private func finishDelivered(_ snapshot: BibiPurchaseRecord) {
        guard var record = journal.record(snapshot.id), record.phase.hasDelivery,
              let key = record.transactionKey,
              let transaction = transactions[key], [.purchased, .restored].contains(transaction.transactionState),
              !finishObjects.contains(transaction) else { return }
        do {
            // A crash after serverConfirmed only needs the local delivery marker, never re-settlement.
            if record.phase == .serverConfirmed {
                record.phase = .deliveryCommitted; record.receiptBase64 = nil; try journal.save(record)
            }
            if record.phase == .deliveryCommitted { record.phase = .finishRequested; try journal.save(record) }
            finishObjects.add(transaction)
            runtime.finish(transaction)
        } catch { onRecoveryChange?(journal.failure) }
    }

    /// Reconcile already-delivered finish requests against the actual current queue.
    /// If Apple later re-delivers an absent object, completed records still finish that
    /// real object without a second confirmation or entitlement increment.
    private func reconcileFinishedQueue() {
        guard observing, journal.isReady else { return }
        let environment = runtime.environment()
        guard ["Sandbox", "Production"].contains(environment) else { return }
        let queued = Set(runtime.snapshot().compactMap { $0.transactionIdentifier })
        for var record in journal.state.records where record.phase == .finishRequested
                && record.environment == environment && !queued.contains(record.transactionID ?? "") {
            record.phase = .completed
            do {
                try journal.save(record)
                if let key = record.transactionKey { transactions[key] = nil }
            } catch { reportRecovery(); return }
        }
    }

    private func applyFailure(_ category: String, id: UUID) {
        switch category {
        case "awaiting_evidence":
            if var record = journal.record(id), !record.phase.hasDelivery {
                record.rejectedFingerprint = record.receiptFingerprint; record.receiptBase64 = nil
                record.phase = .awaitingEvidence; record.category = category
                try? journal.save(record); receiptAllowed.remove(id)
            }
        case "processing", "transient": suspend(id, category: category, phase: .retryWait, delay: 60)
        case "needs_reconciliation", "association_missing": suspend(id, category: category, phase: .needsReconciliation, delay: 60)
        default: suspend(id, category: category, phase: .blocked)
        }
    }
    private func suspend(_ id: UUID, category: String, phase: BibiPurchasePhase, delay: TimeInterval? = nil) {
        guard var record = journal.record(id), !record.phase.hasDelivery else { return }
        record.phase = phase; record.category = category; record.nextRetryAt = delay.map { Date().addingTimeInterval($0) }
        do { try journal.save(record) } catch { onRecoveryChange?(journal.failure) }
    }
    private func reportRecovery() {
        if let failure = journal.failure { onRecoveryChange?(failure); return }
        if journal.state.records.contains(where: { $0.phase == .needsReconciliation }) {
            onRecoveryChange?("An earlier Apple transaction has no recoverable original association. It remains unfinished and may still affect that product. Contact support with your App Store purchase history.")
        } else if journal.state.records.contains(where: { !$0.phase.hasDelivery && $0.phase != .failed }) {
            onRecoveryChange?("A purchase is awaiting its original evidence, account or confirmation. Do not pay again to recover it.")
        } else { onRecoveryChange?(nil) }
    }
    private func endWait(_ id: UUID, message: String?, releaseApple: Bool = true) {
        if releaseApple, appleOwner == id { appleOwner = nil }
        guard let wait = waits.removeValue(forKey: id), !wait.settled else { return }
        wait.settled = true; wait.message = message; wait.timeout?.cancel()
        let continuation = wait.continuation; wait.continuation = nil
        continuation?.resume(returning: message)
    }
    private func failureMessage(_ error: Error?) -> String {
        if (error as? SKError)?.code == .paymentCancelled { return "Purchase cancelled. Apple reported no completed payment." }
        return "Apple reported that this payment did not complete."
    }
    private func drain() async {
        var drained: Task<Void, Never>?
        while let next = tail, next != drained { drained = next; await next.value }
    }

    nonisolated func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        Task { @MainActor in for transaction in transactions { self.handle(transaction) } }
    }
    nonisolated func paymentQueue(_ queue: SKPaymentQueue, removedTransactions removed: [SKPaymentTransaction]) {
        Task { @MainActor in
            for transaction in removed {
                guard let id = transaction.transactionIdentifier else { continue }
                let environment = self.runtime.environment()
                guard var record = self.journal.record(transactionID: id, environment: environment) else { continue }
                if record.phase == .completed {
                    self.transactions[record.transactionKey ?? ""] = nil
                    continue
                }
                guard record.phase == .finishRequested else { continue }
                record.phase = .completed
                do { try self.journal.save(record) } catch { self.onRecoveryChange?(self.journal.failure); continue }
                self.transactions[record.transactionKey ?? ""] = nil
            }
            self.reportRecovery()
        }
    }
}

private final class BibiPurchaseWait {
    var continuation: CheckedContinuation<String?, Never>?
    var settled = false
    var message: String?
    var timeout: Task<Void, Never>?
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

/// Exact one-SKU lookup is independent of the native nine-package catalog.
@MainActor
final class BibiSingleProductQuery: NSObject, SKProductsRequestDelegate {
    private var request: SKProductsRequest?
    private var waiter: CheckedContinuation<SKProduct?, Never>?
    private var timeout: Task<Void, Never>?
    private var productID = ""
    func resolve(_ productID: String) async -> SKProduct? {
        self.productID = productID
        return await withCheckedContinuation { continuation in
            waiter = continuation
            let next = SKProductsRequest(productIdentifiers: [productID]); request = next
            next.delegate = self; next.start()
            timeout = Task { @MainActor [weak self] in
                do { try await Task.sleep(nanoseconds: 20_000_000_000) } catch { return }
                self?.complete(nil)
            }
        }
    }
    private func complete(_ product: SKProduct?) {
        guard let waiter else { return }
        self.waiter = nil; timeout?.cancel(); timeout = nil
        request?.delegate = nil; request?.cancel(); request = nil
        waiter.resume(returning: product)
    }
    nonisolated func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        Task { @MainActor in
            guard request === self.request else { return }
            let exact = response.products.filter { $0.productIdentifier == self.productID }
            self.complete(exact.count == 1 && !response.invalidProductIdentifiers.contains(self.productID) ? exact[0] : nil)
        }
    }
    nonisolated func request(_ request: SKRequest, didFailWithError error: Error) {
        Task { @MainActor in guard request === self.request else { return }; self.complete(nil) }
    }
}
