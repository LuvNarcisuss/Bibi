import Combine
import Foundation

@MainActor
final class WalletStore: ObservableObject {
    @Published private(set) var snapshot = WalletSnapshot()
    @Published private(set) var isBusy = false
    @Published private(set) var prices: [String: String] = [:]
    @Published private(set) var catalog = StoreProductStatus()
    private let purchasing = StoreKit1Purchasing()

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

    func retryProducts() { purchasing.retryProducts() }
    var diagnostics: String { purchasing.diagnostics }

    func prepareProducts() {
        purchasing.reloadProductsIfNeeded()
    }

    func adopt(_ ledger: WalletLedger) {
        purchasing.adopt(ledger)
    }

    func setPersist(_ persist: @escaping (WalletLedger) async -> Bool) {
        purchasing.setPersist(persist)
    }

    func startPayments() async {
        await purchasing.start()
    }

    func stopPayments() async {
        await purchasing.stop()
    }

    func clearAccountMemory() {
        purchasing.clearMemory()
    }

    func purchase(_ package: WalletPackage) async -> String? {
        guard !isBusy else { return "Please wait for the current request to finish." }
        isBusy = true
        defer { isBusy = false }
        return await purchasing.purchase(package)
    }

    func send(_ gift: StarGift, quantity: Int, target: GiftTarget,
              isAvailable: @escaping @MainActor () -> Bool) async -> String? {
        guard !isBusy else { return "Please wait for the current request to finish." }
        isBusy = true
        defer { isBusy = false }
        return await purchasing.spend(gift, quantity: quantity, target: target, isAvailable: isAvailable)
    }
}

extension AppStore {
    func giftTarget(postID: UUID) -> GiftTarget? {
        guard let post = circlePosts().first(where: { $0.id == postID }),
              !post.author.isLocalOwner else { return nil }
        return GiftTarget(kind: .circlePost, id: postID,
                          title: String(post.body.prefix(60)), creatorID: post.author.id)
    }

    func canGift(_ target: GiftTarget) -> Bool {
        guard canUseGifts else { return false }
        let current = giftTarget(postID: target.id)
        return current?.creatorID == target.creatorID
    }
}
