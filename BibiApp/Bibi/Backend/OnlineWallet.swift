import Foundation
import Supabase

@MainActor
final class OnlineWallet: BibiPurchaseSettlement {
    private let services: BackendServices
    private let content: ContentRepository
    private lazy var settlement = BibiSettlementClient(services)
    var onChange: ((WalletSnapshot, [String: String]) -> Void)?
    var onLoadError: ((String?) -> Void)?
    private var busy = false
    var accountID: UUID? { try? services.requireAccount() }

    init(_ services: BackendServices) { self.services = services; content = ContentRepository(services) }
    func start() async { await reload() }
    func stop() {}
    func reload() async {
        let generation = services.generation
        do { try await refreshBalance() }
        catch {
            if services.generation == generation { onLoadError?(error.localizedDescription) }
        }
    }

    func purchaseAvailable(source: ConfiguredPurchaseSource, productID: String, environment: String, account: UUID) async throws -> Bool {
        try await settlement.availability(source: source, productID: productID, environment: environment, account: account)
    }
    func purchaseStatus(transactionID: String, environment: String, account: UUID) async throws -> BibiSettlementReply {
        try await settlement.status(transactionID: transactionID, environment: environment, account: account)
    }
    func confirmPurchase(_ record: BibiPurchaseRecord) async throws -> BibiSettlementReply {
        try await settlement.confirm(record)
    }

    func refreshBalance() async throws {
        let environment = try BackendConfiguration.requireSupportedEnvironment()
        let generation = services.generation
        let wallets: [RemoteWallet] = try await services.rows("bibi_wallets", filters: ["environment": environment], order: "user_id")
        let activities: [RemoteWalletActivity] = try await services.rows("bibi_wallet_activity", filters: ["environment": environment], limit: 100)
        let states: [RemoteCosmeticState] = try await services.rows("bibi_cosmetics", filters: ["environment": environment], order: "user_id")
        try services.check(generation)
        let snapshot = WalletSnapshot(diamonds: Int(wallets.first?.balance ?? 0), activity: activities.map {
            WalletActivity(id: $0.id.uuidString, title: activityTitle($0.kind),
                currency: .diamonds, amount: Int($0.amount), date: $0.created_at, kind: $0.kind,
                giftTarget: nil, giftID: $0.gift_id, giftQuantity: $0.quantity)
        }, cosmetics: states.first?.project() ?? CosmeticState())
        onChange?(snapshot, [:]); onLoadError?(nil)
    }

    private func activityTitle(_ kind: String) -> String {
        switch kind {
        case "gift": return "Circle gift"
        case "reversal": return "Purchase adjustment"
        case "unlock": return "Look unlocked"
        case "challenge": return "Challenge entry"
        case "refund": return "Challenge entry returned"
        default: return "Diamond purchase"
        }
    }

    func unlock(_ item: CosmeticItem) async -> String? {
        await changeLook("cosmetic_unlock", payload: ["item_id": .string(item.id)])
    }

    func equip(_ kind: CosmeticKind, id: String?) async -> String? {
        var payload: [String: AnyJSON] = ["kind": .string(kind.rawValue)]
        if let id { payload["item_id"] = .string(id) }
        return await changeLook("cosmetic_equip", payload: payload)
    }

    private func changeLook(_ action: String, payload: [String: AnyJSON]) async -> String? {
        guard !busy else { return "Please wait for the current wallet request." }
        busy = true; defer { busy = false }
        do {
            let generation = services.generation
            var input = payload
            input["environment"] = .string(try BackendConfiguration.requireSupportedEnvironment())
            _ = try await content.mutate(action, payload: input)
            try services.check(generation)
            try await refreshBalance()
            return nil
        } catch { return error.localizedDescription }
    }

    func gift(_ gift: StarGift, quantity: Int, target: GiftTarget) async -> String? {
        "Post gifts are no longer available. No diamonds were spent."
    }
}

private struct RemoteCosmeticState: Decodable {
    let owned_ids: [String]
    let equipped: [String: String]
    let paid_challenge_ids: [String]

    func project() -> CosmeticState {
        var state = CosmeticState()
        state.ownedIDs = owned_ids
        state.paidChallengeIDs = paid_challenge_ids
        for kind in [CosmeticKind.avatarFrame, .profileBackground, .chatBubble, .chatBackground, .coverTemplate] {
            state.equip(kind, id: equipped[kind.rawValue])
        }
        return state
    }
}
