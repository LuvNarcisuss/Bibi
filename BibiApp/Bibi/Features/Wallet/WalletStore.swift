import Combine
import Foundation

@MainActor
final class WalletStore: ObservableObject {
    @Published private(set) var snapshot = WalletSnapshot()
    @Published private(set) var isBusy = false
    @Published private(set) var prices: [String: String] = [:]
    @Published private(set) var catalog = StoreProductStatus()
    @Published private(set) var recoveryNotice: String?
    @Published private(set) var balanceError: String?
    @Published private(set) var balanceLoading = false
    private let purchasing = StoreKit1Purchasing.shared
    private var online: OnlineWallet?
    func configureOnline(_ wallet: OnlineWallet) {
        online = wallet
        balanceLoading = true
        purchasing.online = wallet
        wallet.onChange = { [weak self] snapshot, _ in
            self?.snapshot = snapshot; self?.balanceLoading = false; self?.balanceError = nil
        }
        wallet.onLoadError = { [weak self] message in self?.balanceError = message; self?.balanceLoading = false }
    }

    init() {
        purchasing.onChange = { [weak self] ledger, prices in
            if self?.online == nil { self?.snapshot = ledger.snapshot }
            self?.prices = prices
        }
        purchasing.onRecoveryChange = { [weak self] message in self?.recoveryNotice = message }
        purchasing.onCatalogChange = { [weak self] state in
            self?.catalog = state
        }
    }

    func priceText(for package: WalletPackage) -> String {
        prices[package.storeProductID] ?? catalog.placeholder
    }

    func isAvailable(_ package: WalletPackage) -> Bool {
        prices[package.storeProductID] != nil
    }

    func retryProducts() {
        purchasing.retryProducts()
        purchasing.resumeRecovery(userInitiated: true)
        if let online { Task { await online.reload() } }
    }
    var diagnostics: String { purchasing.diagnostics }
    func prepareRecovery() async { await purchasing.prepareRecovery() }
    func resumeRecovery() { purchasing.resumeRecovery() }
    func retryPurchaseConfirmations() { purchasing.resumeRecovery(userInitiated: true) }
    func invalidatePendingPurchases() { purchasing.invalidatePendingPurchaseAuthorization() }
    func retryBalance() {
        guard let online else { return }
        balanceLoading = true
        Task { await online.reload() }
    }

    func purchaseFromSocket(productID: String, reference: String?, messageID: String, context: BibiExternalPurchaseContext) async -> String? {
        guard !isBusy else { return "Please wait for the current request to finish." }
        isBusy = true
        defer { isBusy = false }
        return await purchasing.purchaseFromSocket(productID: productID, reference: reference, messageID: messageID, context: context)
    }

    func prepareProducts() {
        purchasing.reloadProductsIfNeeded()
        if let online { Task { await online.reload() } }
    }

    func adopt(_ ledger: WalletLedger) {
        purchasing.adopt(ledger)
    }

    func setPersist(_ persist: @escaping (WalletLedger) async -> Bool) {
        purchasing.setPersist(persist)
    }

    func startPayments() async {
        await purchasing.start()
        if let online { balanceLoading = true; Task { await online.start() } }
    }

    func stopPayments() async {
        online?.stop()
        await purchasing.stop()
    }

    func clearAccountMemory() {
        online?.stop()
        purchasing.clearMemory()
        snapshot = WalletSnapshot(); balanceError = nil; balanceLoading = online != nil
    }

    func purchase(_ package: WalletPackage) async -> String? {
        guard !isBusy else { return "Please wait for the current request to finish." }
        isBusy = true
        defer { isBusy = false }
        return await purchasing.purchase(package)
    }

    func send(_ gift: StarGift, quantity: Int, target: GiftTarget,
              isAvailable: @escaping @MainActor () -> Bool) async -> String? {
        "Post gifts are no longer available. No diamonds were spent."
    }

    func unlock(_ item: CosmeticItem) async -> String? {
        guard !isBusy else { return "Please wait for the current request to finish." }
        isBusy = true
        defer { isBusy = false }
        if let online { return await online.unlock(item) }
        return await purchasing.unlock(item)
    }

    func equip(_ kind: CosmeticKind, id: String?) async -> String? {
        guard !isBusy else { return "Please wait for the current request to finish." }
        isBusy = true
        defer { isBusy = false }
        if let online { return await online.equip(kind, id: id) }
        return await purchasing.equip(kind, id: id)
    }

    func payForChallenge(_ challengeID: String) async -> String? {
        guard online == nil else { return "Looks and challenge entries use the balance on this device. Online spending is not connected." }
        guard !isBusy else { return "Please wait for the current request to finish." }
        isBusy = true
        defer { isBusy = false }
        return await purchasing.payForChallenge(challengeID)
    }

    func refundChallenge(_ challengeID: String) async -> String? {
        guard online == nil else { return nil }
        guard !isBusy else { return "Please wait for the current request to finish." }
        isBusy = true
        defer { isBusy = false }
        return await purchasing.refundChallenge(challengeID)
    }

}

extension AppStore {
    // Keep these compatibility entry points inert for old screens and stored activity.
    func giftTarget(postID: UUID) -> GiftTarget? { nil }
    func canGift(_ target: GiftTarget) -> Bool { false }
}
