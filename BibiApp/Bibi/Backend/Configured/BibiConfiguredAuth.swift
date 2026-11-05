import Foundation
import Supabase

struct BibiConfiguredIdentity: Codable, Equatable {
    let accountID: UUID
    let origin: URL
    let appID: String
}

struct BibiConfiguredAuthResult {
    let requiresPage: Bool
    let ticket: ConfiguredRealtimeTicket?
}

@MainActor
enum BibiConfiguredAuth {
    static func authenticate(_ identity: BibiConfiguredIdentity, services: BackendServices) async throws -> BibiConfiguredAuthResult {
        let generation = services.generation
        guard try services.requireAccount() == identity.accountID else { throw BackendError.accountChanged }
        var fields = try await BibiDeviceContext.shared.prepare(origin: identity.origin)
        try services.check(generation)
        var parts = URLComponents(url: identity.origin, resolvingAgainstBaseURL: false)!
        parts.path = IntegrationContract.entryPath
        if let field = IntegrationContract.authAppIDField {
            switch IntegrationContract.authAppIDLocation {
            case "body": fields[field] = .string(identity.appID)
            case "query": parts.queryItems = [URLQueryItem(name: field, value: identity.appID)]
            case "header": break
            default: throw BackendError.unavailable
            }
        }
        guard let url = parts.url else { throw BackendError.unavailable }
        var request = URLRequest(url: url)
        request.httpMethod = IntegrationContract.apiMethod
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if IntegrationContract.authAppIDLocation == "header", let field = IntegrationContract.authAppIDField {
            request.setValue(identity.appID, forHTTPHeaderField: field)
        }
        request.httpBody = try JSONEncoder().encode(fields)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 15
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        let session = URLSession(configuration: configuration, delegate: BibiRedirectPolicy(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (stream, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) || http.statusCode == 401 else {
            throw BackendError.invalidInput("Sign-in could not connect. Please try again.")
        }
        var bytes = Data()
        for try await byte in stream {
            guard bytes.count < 1_048_576 else { throw BackendError.unavailable }
            bytes.append(byte)
        }
        try services.check(generation)
        guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let code = ConfiguredRealtimeJSON.integer(root[ConfiguredWireFields.code]),
              let data = root[ConfiguredWireFields.data] as? [String: Any],
              let continuation = ConfiguredAuthContinuation.parse(data: data) else {
            throw BackendError.invalidInput("The sign-in response was invalid. Please try again.")
        }
        let plainSuccess = (200..<300).contains(http.statusCode) && code == 0
        let requiresPage = continuation == .realtimeRequired || !plainSuccess
        var raw: Any = root
        var present = true
        for key in IntegrationContract.realtimeConnectionValuePath {
            guard let object = raw as? [String: Any], let next = object[key] else { present = false; break }
            raw = next
        }
        let ticket: ConfiguredRealtimeTicket?
        if present {
            ticket = try ConfiguredRealtimeTicket.parseConnectionValue(raw,
                fields: .init(url: IntegrationContract.realtimeURLField, attach: IntegrationContract.realtimeAttachField,
                    action: IntegrationContract.realtimeAttachActionField, channel: IntegrationContract.realtimeAttachChannelField,
                    expiresAt: IntegrationContract.realtimeExpiryField), expectedClientID: IntegrationContract.realtimeClientID)
        } else { ticket = nil }
        guard !requiresPage || ticket != nil else { throw BackendError.invalidInput("Sign-in could not continue. Please try again.") }
        return BibiConfiguredAuthResult(requiresPage: requiresPage, ticket: ticket)
    }
}
