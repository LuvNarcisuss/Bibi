import CoreFoundation
import Foundation
import Supabase

enum BibiSettlementTransportError: Error, Equatable { case sessionExpired, invalidResponse }

struct BibiSettlementReply {
    let confirmed: Bool
    let category: String
    let state: String
    let transactionID: String?
    let environment: String?
    let source: ConfiguredPurchaseSource?
    let productID: String?
    let quantity: Int?
    let authority: String?
    let balance: Int64?
    let recovery: [String: Any]

    static func integer(_ value: Any?) -> Int64? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              !["d", "f"].contains(String(cString: number.objCType)) else { return nil }
        return Int64(number.stringValue)
    }

    static func parse(_ data: Data, status: Int) throws -> Self {
        guard data.count <= 1_048_576, let fields = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let code = integer(fields["code"]), let state = fields["state"] as? String else {
            throw BibiSettlementTransportError.invalidResponse
        }
        let success = (200...299).contains(status) && code == 0 && state == "confirmed"
        return Self(confirmed: success, category: fields["category"] as? String ?? (success ? "confirmed" : "unknown"),
                    state: state, transactionID: fields["transaction_id"] as? String,
                    environment: fields["environment"] as? String,
                    source: (fields["source"] as? String).flatMap(ConfiguredPurchaseSource.init(rawValue:)),
                    productID: fields["product_id"] as? String,
                    quantity: integer(fields["quantity"]).flatMap(Int.init(exactly:)),
                    authority: fields["authority"] as? String, balance: integer(fields["balance"]),
                    recovery: fields["recovery"] as? [String: Any] ?? [:])
    }

    func matches(_ record: BibiPurchaseRecord) -> Bool {
        transactionID == record.transactionID && environment == record.environment && source == record.source
            && productID == record.productID && quantity == record.quantity
            && authority == (record.source == .socket ? "external" : "supabase")
    }
}

/// This is client-trusted settlement, not Apple server-side signature verification.
@MainActor
final class BibiSettlementClient {
    static let contractID = "bibi-48369038-v1"
    private let currentAccount: () -> UUID?
    private let authorization: (UUID) async throws -> String
    private let session: URLSession
    private let redirects = BibiRedirectPolicy()

    init(_ services: BackendServices) {
        currentAccount = { try? services.requireAccount() }
        authorization = { account in
            guard try services.requireAccount() == account else { throw BackendError.accountChanged }
            let authentication = try await services.client.auth.session
            guard authentication.user.id == account, try services.requireAccount() == account else { throw BackendError.accountChanged }
            return authentication.accessToken
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30; configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil; configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration, delegate: redirects, delegateQueue: nil)
    }

    #if DEBUG
    init(currentAccount: @escaping () -> UUID?, authorization: @escaping (UUID) async throws -> String,
         session: URLSession) {
        self.currentAccount = currentAccount; self.authorization = authorization; self.session = session
    }
    #endif

    func availability(source: ConfiguredPurchaseSource, productID: String, environment: String, account: UUID) async throws -> Bool {
        let body: [String: Any] = ["action":"availability", "environment":environment,
            SupabaseIntegrationContract.purchaseSourceField:source.rawValue,
            SupabaseIntegrationContract.purchaseProductIDField:productID,
            SupabaseIntegrationContract.purchaseQuantityField:1, "contract_id":Self.contractID]
        let (data, response) = try await send(body, account: account)
        guard let fields = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              (200...299).contains(response.statusCode), BibiSettlementReply.integer(fields["code"]) == 0,
              let available = fields["available"] as? NSNumber, CFGetTypeID(available) == CFBooleanGetTypeID(),
              fields["source"] as? String == source.rawValue,
              fields["environment"] as? String == environment else { return false }
        return available.boolValue
    }

    func status(transactionID: String, environment: String, account: UUID) async throws -> BibiSettlementReply {
        let (data, response) = try await send(["action":"status", "environment":environment,
            ConfiguredWireFields.diamond_reference:transactionID, "contract_id":Self.contractID], account: account)
        return try BibiSettlementReply.parse(data, status: response.statusCode)
    }

    func confirm(_ record: BibiPurchaseRecord) async throws -> BibiSettlementReply {
        guard let account = record.accountID, let source = record.source, let transaction = record.transactionID,
              let proof = record.receiptBase64, !proof.isEmpty, record.contractID == Self.contractID,
              !record.appVersion.isEmpty, !record.deviceNo.isEmpty else { throw BackendError.invalidInput("The original purchase association or evidence is unavailable.") }
        var body: [String: Any] = ["action":"confirm", "environment":record.environment,
            "contract_id":record.contractID, "request_id":record.id.uuidString,
            SupabaseIntegrationContract.purchaseSourceField:source.rawValue,
            SupabaseIntegrationContract.purchaseProductIDField:record.productID,
            SupabaseIntegrationContract.purchaseQuantityField:record.quantity,
            ConfiguredWireFields.diamond_reference:transaction, ConfiguredWireFields.diamond_proof:proof,
            ConfiguredWireFields.bibi_edition:record.appVersion, ConfiguredWireFields.starlight_installation:record.deviceNo]
        if let reference = record.orderReference { body[ConfiguredWireFields.orbit_order] = reference }
        if let message = record.messageID { body["message_id"] = message }
        if let context = record.externalContext {
            body["external_attempt_id"] = context.authenticationAttemptID.uuidString
            body["context_origin"] = context.origin.absoluteString
            body["app_id"] = context.appID
        }
        let (data, response) = try await send(body, account: account)
        return try BibiSettlementReply.parse(data, status: response.statusCode)
    }

    private func send(_ body: [String: Any], account: UUID) async throws -> (Data, HTTPURLResponse) {
        guard currentAccount() == account else { throw BackendError.accountChanged }
        let token = try await authorization(account)
        guard currentAccount() == account else { throw BackendError.accountChanged }
        let url = BackendConfiguration.projectURL.appendingPathComponent("functions/v1/" + SupabaseIntegrationContract.purchaseFunction)
        var request = URLRequest(url: url); request.httpMethod = "POST"
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue(BackendConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, data.count <= 1_048_576 else { throw BibiSettlementTransportError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw BibiSettlementTransportError.sessionExpired }
        // A valid original-account result can still commit its journal after a UI/session change.
        return (data, http)
    }
}
