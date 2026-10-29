import Combine
import Foundation

@MainActor
final class WalletStore: ObservableObject {
    @Published private(set) var snapshot = WalletSnapshot()
    @Published private(set) var isBusy = false
    @Published private(set) var prices: [String: String] = [:]
    @Published private(set) var catalog = StoreProductStatus()
    private let purchasing = StoreKit1Purchasing()
    private var online: OnlineWallet?
    func configureOnline(_ wallet: OnlineWallet) {
        online = wallet
        wallet.onChange = { [weak self] snapshot, prices in self?.snapshot = snapshot; self?.prices = prices }
        wallet.onCatalog = { [weak self] state in self?.catalog = state }
    }

    init() {
        purchasing.onChange = { [weak self] ledger, prices in
            self?.snapshot = ledger.snapshot
            self?.prices = prices
        }
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

    func retryProducts() { if let online { Task { await online.reload() } } else { purchasing.retryProducts() } }
    var diagnostics: String { online == nil ? purchasing.diagnostics : "Server-verified purchases" }

    func prepareProducts() {
        if let online { Task { await online.reload() }; return }
        purchasing.reloadProductsIfNeeded()
    }

    func adopt(_ ledger: WalletLedger) {
        purchasing.adopt(ledger)
    }

    func setPersist(_ persist: @escaping (WalletLedger) async -> Bool) {
        purchasing.setPersist(persist)
    }

    func startPayments() async {
        if let online { await online.start(); return }
        await purchasing.start()
    }

    func stopPayments() async {
        if let online { online.stop(); return }
        await purchasing.stop()
    }

    func clearAccountMemory() {
        if let online { online.stop(); snapshot = WalletSnapshot(); prices = [:]; return }
        purchasing.clearMemory()
    }

    func purchase(_ package: WalletPackage) async -> String? {
        guard !isBusy else { return "Please wait for the current request to finish." }
        isBusy = true
        defer { isBusy = false }
        if let online { return await online.purchase(package) }
        return await purchasing.purchase(package)
    }

    func send(_ gift: StarGift, quantity: Int, target: GiftTarget,
              isAvailable: @escaping @MainActor () -> Bool) async -> String? {
        "Post gifts are no longer available. No diamonds were spent."
    }

    func unlock(_ item: CosmeticItem) async -> String? {
        guard online == nil else { return "Looks and challenge entries use the balance on this device. Online spending is not connected." }
        guard !isBusy else { return "Please wait for the current request to finish." }
        isBusy = true
        defer { isBusy = false }
        return await purchasing.unlock(item)
    }

    func equip(_ kind: CosmeticKind, id: String?) async -> String? {
        guard online == nil else { return "Looks and challenge entries use the balance on this device. Online spending is not connected." }
        guard !isBusy else { return "Please wait for the current request to finish." }
        isBusy = true
        defer { isBusy = false }
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
