// Generated B-stage runtime; use the paired ConfiguredEventDecoder template.
// Deployment mappings belong in Docs, never in App resources.
import Foundation

enum IntegrationContract {
    static let namespace: String = "bibi"
    static let realtimeTransport: String = "webSocket"
    static let realtimeConnectionValuePath: [String] = ["data", "constellation_pass"]
    static let realtimeClientID: String = "app"
    static let serverClientIDs: [String] = ["serve"]
    static let allowsMissingSender: Bool = true
    static let acceptsSerializedExpiry: Bool = true
    static let realtimeURLField: String = "orbit_address"
    static let realtimeAttachField: String = "orbit_join"
    static let realtimeAttachActionField: String = "join_step"
    static let realtimeAttachChannelField: String = "orbit_scope"
    static let realtimeExpiryField: String? = nil
    static let continuationMode: Int = 2
    static let apiMethod: String = "POST"
    static let entryPath: String = "/bibi/constellation/entry"
    static let authAppIDLocation: String = "none"
    static let authAppIDField: String? = nil
    static let pageSignal: String = "ConstellationReady"
    static let pageDiscriminator: [String] = ["signal"]
    static let purchaseSignal: String = "DiamondCheckout"
    static let purchaseDiscriminator: [String] = ["signal"]
    static let expirySignal: String = "ConstellationExpired"
    static let expiryDiscriminator: [String] = ["signal"]
    static let externalSignal: String = "OpenStoryLink"
    static let externalDiscriminator: [String] = ["signal"]
    static let pageAddressPath: [String] = ["page", "address"]
    static let purchaseItemPath: [String] = ["purchase", "product"]
    static let purchaseReferencePath: [String] = ["purchase", "reference"]
    static let externalAddressPath: [String] = ["navigation", "destination"]
}

enum ConfiguredWireFields {
    static let `bell_mark`: String = "bell_mark"
    static let `bibi_edition`: String = "bibi_edition"
    static let `code`: String = "code"
    static let `constellation_delivery`: String = "constellation_delivery"
    static let `constellation_gateway`: String = "constellation_gateway"
    static let `constellation_pass`: String = "constellation_pass"
    static let `data`: String = "data"
    static let `diamond_proof`: String = "diamond_proof"
    static let `diamond_reference`: String = "diamond_reference"
    static let `message`: String = "message"
    static let `orbit_order`: String = "orbit_order"
    static let `starlight_installation`: String = "starlight_installation"
}

enum ConfiguredAuthContinuation: Equatable {
    case plain, realtimeRequired

    // Validate the envelope first; plain requires HTTP/business success, while valid legacy continuation remains allowed.
    // nil is a malformed data object; key absence selects plain.
    static func parse(data: Any?) -> Self? {
        guard let fields = data as? [String: Any] else { return nil }
        return fields.keys.contains(ConfiguredWireFields.`constellation_gateway`) ? .realtimeRequired : .plain
    }
}

enum SupabaseIntegrationContract {
    static let projectURLString: String = "https://yepycfnkkfrfmuwdekka.supabase.co"
    static let bootstrapFunction: String = "bibi-begin"
    static let purchaseFunction: String = "bibi-settlement"
    static let backendOriginField: String = "constellation_origin"
    static let applicationIDField: String = "constellation_app"
    static let purchaseSourceField: String = "diamond_origin"
    static let purchaseProductIDField: String = "diamond_product"
    static let purchaseQuantityField: String = "diamond_count"
}

// Routing context is frozen before purchase; this enum is not proof of a genuine Apple payment.
enum ConfiguredPurchaseSource: String, Codable {
    case local = "bibi_wallet"
    case socket = "constellation_order"
}

enum ConfiguredBootstrapContinuation: Equatable {
    case standalone
    case nativeSupabase(appID: String)
    case external(origin: URL, appID: String)

    // Call only after Supabase session and bootstrap HTTP/business success.
    // Empty configuration is intentional; partial or malformed configuration is an error.
    static func parse(data: Any?) -> Self? {
        guard let fields = data as? [String: Any] else { return nil }
        if fields.isEmpty { return .standalone }
        guard let raw = fields[SupabaseIntegrationContract.backendOriginField] as? String,
              let appID = fields[SupabaseIntegrationContract.applicationIDField] as? String,
              !raw.isEmpty, raw == raw.trimmingCharacters(in: .whitespacesAndNewlines),
              !appID.isEmpty, appID == appID.trimmingCharacters(in: .whitespacesAndNewlines),
              raw.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              raw.rangeOfCharacter(from: .controlCharacters) == nil,
              raw.rangeOfCharacter(from: CharacterSet(charactersIn: "<>{}*\"\\")) == nil,
              appID.range(of: "^[A-Za-z0-9][A-Za-z0-9_-]*$", options: .regularExpression) != nil,
              var parts = URLComponents(string: raw),
              parts.scheme?.lowercased() == "https", let host = parts.host, !host.isEmpty,
              !host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.path.isEmpty || parts.path == "/",
              parts.port.map({ (1...65535).contains($0) }) ?? true,
              parts.url != nil else { return nil }
        parts.scheme = "https"
        parts.path = ""
        guard let origin = parts.url else { return nil }
        guard let native = URLComponents(string: SupabaseIntegrationContract.projectURLString) else { return nil }
        if parts.scheme?.lowercased() == native.scheme?.lowercased(),
           parts.host?.lowercased() == native.host?.lowercased(),
           (parts.port ?? 443) == (native.port ?? 443) {
            return .nativeSupabase(appID: appID)
        }
        return .external(origin: origin, appID: appID)
    }
}
