import Foundation

struct StoreProductStatus {
    enum Phase: String {
        case idle, loading, ready, partial, unavailable, failed, timedOut
    }
    var phase: Phase = .idle
    var requestedIDs: [String] = []
    var returnedIDs: [String] = []
    var invalidIDs: [String] = []
    var errorCode: String?

    var notice: String? {
        switch phase {
        case .idle: return "Connect to the App Store to load prices."
        case .loading: return "Loading prices from the App Store…"
        case .ready: return nil
        case .partial: return "Some packages are currently unavailable in the App Store."
        case .unavailable: return "The App Store did not return these packages. Please try again later."
        case .failed: return "Could not connect to the App Store. Check your connection and retry."
        case .timedOut: return "The App Store took too long to respond. Please retry."
        }
    }

    var canRetry: Bool { phase != .loading && phase != .ready }
    var placeholder: String { phase == .loading ? "Loading…" : "Unavailable" }

    func purchaseFailure(for productID: String) -> String {
        if invalidIDs.contains(productID) {
            return "This package is not available from the App Store for this app. No payment was started."
        }
        return (notice ?? "This package is currently unavailable.") + " No payment was started."
    }
}

enum WalletCurrency: String, Codable, CaseIterable, Identifiable {
    case diamonds = "Diamonds"
    var id: String { rawValue }
    var symbol: String { "diamond.fill" }
}

struct WalletPackage: Identifiable {
    let currency: WalletCurrency
    let amount: Int
    let usdCents: Int
    // Catalog identifier; availability must be resolved through the purchase service.
    let storeProductID: String
    var id: String { "\(currency.id)-\(amount)" }
    /// Catalog reference only. The charge price comes from StoreKit.
    var price: String { String(format: "$%d.%02d", usdCents / 100, usdCents % 100) }
    var amountText: String { amount.formatted(.number.locale(Locale(identifier: "en_US"))) }
}

enum WalletCatalog {
    // Store product IDs from the purchase catalog. USD amounts are references, not the charge.
    private static let diamondTiers: [(amount: Int, usdCents: Int)] = [
        (400, 99),
        (800, 199),
        (2_450, 499),
        (5_150, 999),
        (10_800, 1_999),
        (29_400, 4_999),
        (63_700, 9_999)
    ]

    static func packages(for currency: WalletCurrency) -> [WalletPackage] {
        diamondTiers.map { tier in
            WalletPackage(currency: currency, amount: tier.amount,
                          usdCents: tier.usdCents, storeProductID: BibiConfiguration.productID(for: tier.amount))
        }
    }

    static var productIDs: Set<String> {
        Set(packages(for: .diamonds).map(\.storeProductID).filter { !$0.isEmpty })
    }

    static func package(forProductID productID: String) -> WalletPackage? {
        guard !productID.isEmpty else { return nil }
        return packages(for: .diamonds).first { $0.storeProductID == productID }
    }
}

struct StarGift: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let diamonds: Int
    let hue: Double

    static let catalog: [Self] = [
        .init(id: "rose", name: "Sakura", symbol: "camera.macro", diamonds: 10, hue: 0.96),
        .init(id: "balloons", name: "Balloons", symbol: "balloon.2.fill", diamonds: 50, hue: 0.54),
        .init(id: "heart", name: "Heart", symbol: "heart.fill", diamonds: 100, hue: 0.94),
        .init(id: "beat", name: "Magic Wand", symbol: "music.note", diamonds: 200, hue: 0.72),
        .init(id: "spotlight", name: "Starlight", symbol: "sparkles", diamonds: 500, hue: 0.12),
        .init(id: "bouquet", name: "Sakura Bloom", symbol: "camera.macro", diamonds: 1_000, hue: 0.88),
        .init(id: "crown", name: "Moon Crown", symbol: "crown.fill", diamonds: 2_000, hue: 0.10),
        .init(id: "encore", name: "Star Comet", symbol: "party.popper.fill", diamonds: 5_000, hue: 0.04),
        .init(id: "galaxy", name: "Star Galaxy", symbol: "moon.stars.fill", diamonds: 10_000, hue: 0.67)
    ]
}

struct GiftTarget: Codable, Equatable {
    enum Kind: String, Codable { case circlePost }
    let kind: Kind
    let id: UUID
    let title: String
    let creatorID: String
}

struct WalletActivity: Codable, Identifiable {
    let id: String
    let title: String
    let currency: WalletCurrency
    let amount: Int
    let date: Date
    /// "gift" is a local spend. A missing value is a diamond purchase.
    var kind: String? = nil
    var giftTarget: GiftTarget? = nil
    var giftID: String? = nil
    var giftQuantity: Int? = nil
}

struct WalletSnapshot {
    var diamonds = 0
    var activity: [WalletActivity] = []
    func balance(_ currency: WalletCurrency) -> Int { diamonds }
}

/// Device ledger for consumable diamond purchases. Missing file means an empty ledger.
struct WalletLedger: Codable {
    var schemaVersion = 1
    var diamonds: Int
    var activity: [WalletActivity]
    var creditedTransactionIDs: [String]

    static let empty = WalletLedger(diamonds: 0, activity: [], creditedTransactionIDs: [])

    var snapshot: WalletSnapshot { WalletSnapshot(diamonds: diamonds, activity: activity) }

    var isValid: Bool {
        schemaVersion == 1
            && diamonds >= 0
            && creditedTransactionIDs.allSatisfy { !$0.isEmpty }
            && Set(creditedTransactionIDs).count == creditedTransactionIDs.count
            && Set(activity.map(\.id)).count == activity.count
            && activity.allSatisfy { item in
                guard item.amount > 0, !item.id.isEmpty, !item.title.isEmpty, item.currency == .diamonds else {
                    return false
                }
                if item.kind == "gift" { return true }
                return (item.kind == nil || item.kind == "credit") && creditedTransactionIDs.contains(item.id)
            }
    }
}
