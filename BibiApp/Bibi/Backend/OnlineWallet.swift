import Foundation
import StoreKit
import Supabase

@MainActor
final class OnlineWallet {
    private let services: BackendServices
    private let content: ContentRepository
    private var updates: Task<Void, Never>?
    private var products: [String: Product] = [:]
    var onChange: ((WalletSnapshot, [String: String]) -> Void)?
    var onCatalog: ((StoreProductStatus) -> Void)?
    private var busy = false

    init(_ services: BackendServices) { self.services = services; content = ContentRepository(services) }
    deinit { updates?.cancel() }

    func start() async {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await verification in Transaction.updates {
                guard let self, !Task.isCancelled else { break }
                try? await self.credit(verification)
            }
        }
        // Unfinished transactions remain unfinished on network/configuration errors.
        for await verification in Transaction.unfinished { try? await credit(verification) }
        await reload()
    }

    func stop() { updates?.cancel(); updates = nil; products = [:] }

    func reload() async {
        do {
            _ = try services.requireAccount()
            let generation = services.generation
            struct Availability: Encodable { let action = "availability"; let environment: String }
            struct Available: Decodable { let available: Bool }
            let ready: Available = try await services.client.functions.invoke("verify-purchase",
                options: .init(body: Availability(environment: BackendConfiguration.environment)))
            guard ready.available else { throw BackendError.unavailable }
            let loaded = try await Product.products(for: WalletCatalog.productIDs)
            try services.check(generation)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            onCatalog?(StoreProductStatus(phase: loaded.isEmpty ? .unavailable : .ready))
            try await refreshBalance()
        } catch {
            products = [:]
            onCatalog?(StoreProductStatus(phase: .unavailable, errorCode: "Server verification unavailable"))
        }
    }

    func refreshBalance() async throws {
        let wallets: [RemoteWallet] = try await services.rows("bibi_wallets", filters: ["environment": BackendConfiguration.environment], order: "user_id")
        let activities: [RemoteWalletActivity] = try await services.rows("bibi_wallet_activity", filters: ["environment": BackendConfiguration.environment], limit: 100)
        let snapshot = WalletSnapshot(diamonds: Int(wallets.first?.balance ?? 0), activity: activities.map {
            WalletActivity(id: $0.id.uuidString, title: $0.kind == "gift" ? "Circle gift" : ($0.kind == "reversal" ? "Purchase adjustment" : "Diamond purchase"),
                currency: .diamonds, amount: Int($0.amount), date: $0.created_at, kind: $0.kind,
                giftTarget: nil, giftID: $0.gift_id, giftQuantity: $0.quantity)
        })
        onChange?(snapshot, products.mapValues(\.displayPrice))
    }

    func purchase(_ package: WalletPackage) async -> String? {
        guard !busy else { return "Please wait for the current purchase." }
        busy = true; defer { busy = false }
        do {
            let account = try services.requireAccount(), generation = services.generation
            guard let product = products[package.storeProductID] else { throw BackendError.unavailable }
            let result = try await product.purchase(options: [.appAccountToken(account)])
            try services.check(generation)
            switch result {
            case .success(let verification): try await credit(verification); return nil
            case .pending: return "Your purchase is pending approval. No diamonds have been added."
            case .userCancelled: return "Purchase cancelled."
            @unknown default: return "The purchase has not completed."
            }
        } catch { return "The purchase could not be confirmed. Any completed payment remains pending reconciliation." }
    }

    private func credit(_ verification: VerificationResult<Transaction>) async throws {
        let account = try services.requireAccount(), generation = services.generation
        guard case .verified(let transaction) = verification,
              transaction.appAccountToken == account,
              WalletCatalog.productIDs.contains(transaction.productID), transaction.revocationDate == nil else {
            throw BackendError.invalidInput("This purchase could not be verified for this account.")
        }
        struct Evidence: Encodable { let signed_transaction: String; let environment: String }
        let receipt: RemoteCredit = try await services.client.functions.invoke("verify-purchase",
            options: .init(body: Evidence(signed_transaction: verification.jwsRepresentation, environment: BackendConfiguration.environment)))
        try services.check(generation)
        guard receipt.transaction_id == String(transaction.id), receipt.environment == BackendConfiguration.environment else { throw BackendError.unavailable }
        await transaction.finish()
        try? await refreshBalance()
    }

    func gift(_ gift: StarGift, quantity: Int, target: GiftTarget) async -> String? {
        "Post gifts are no longer available. No diamonds were spent."
    }
}
