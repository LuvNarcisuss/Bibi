import Combine
import Foundation
import Supabase

@MainActor
final class BackendServices: ObservableObject {
    enum Phase: Equatable { case signedOut, restoring, verification, recovery, signedIn, deleting }
    @Published private(set) var phase: Phase = .signedOut
    @Published private(set) var accountID: UUID?
    private(set) var generation = UUID()
    let client: SupabaseClient
    private(set) var isAuthenticating = false
    private var authEvents: Task<Void, Never>?
    var onAccountExit: (() -> Void)?
    var onRecovery: (() -> Void)?

    init() throws {
        guard BackendConfiguration.isEnabled else { throw BackendError.unavailable }
        client = SupabaseClient(supabaseURL: BackendConfiguration.projectURL,
            supabaseKey: BackendConfiguration.publishableKey,
            options: .init(auth: .init(storage: BackendKeychain(),
                redirectToURL: BackendConfiguration.callbackURL, flowType: .pkce)))
        authEvents = Task { [weak self, client] in
            for await (event, session) in client.auth.authStateChanges {
                guard let self, !Task.isCancelled else { break }
                if event == .signedOut { self.exitAccount(); self.onAccountExit?() }
                if event == .passwordRecovery {
                    self.phase = .recovery
                    self.onRecovery?()
                }
                if let current = self.accountID, let next = session?.user.id, current != next {
                    self.exitAccount(); self.onAccountExit?()
                }
            }
        }
    }

    deinit { authEvents?.cancel() }

    func requireAccount() throws -> UUID {
        guard phase == .signedIn, let accountID else { throw BackendError.signedOut }
        return accountID
    }

    func check(_ captured: UUID) throws {
        guard generation == captured else { throw BackendError.accountChanged }
        try Task.checkCancellation()
    }

    func restore() async throws -> Bool {
        let captured = try beginAuthentication(); defer { isAuthenticating = false }
        phase = .restoring
        do {
            let session = try await client.auth.session
            try check(captured)
            let profiles: [RemoteProfile] = try await client.from("bibi_profiles")
                .select().eq("id", value: session.user.id).limit(1).execute().value
            try check(captured)
            guard profiles.first?.account_status == "active" else { phase = .signedOut; return false }
            generation = UUID(); accountID = session.user.id; phase = .signedIn
            return true
        } catch {
            if generation == captured { exitAccount() }
            throw error
        }
    }

    var isGuest: Bool { client.auth.currentSession?.user.isAnonymous == true }

    func signInAsGuest(adult: Bool, agreement: String) async throws {
        guard adult, agreement != "unavailable" else {
            throw BackendError.invalidInput("Confirm that you are 18 or older and accept the agreements.")
        }
        let captured = try beginAuthentication(); defer { isAuthenticating = false }
        try BackendKeychain().verifyAvailable()
        // A failed enrollment must reuse the existing identity on retry.
        let session: Session
        if client.auth.currentSession != nil {
            session = try await client.auth.session
        } else {
            session = try await client.auth.signInAnonymously()
        }
        try check(captured)
        guard client.auth.currentSession?.user.id == session.user.id else {
            throw BackendError.invalidInput("Secure sign-in storage is unavailable. Please restart Bibi and try again.")
        }
        try await enroll(user: session.user.id, agreement: agreement, adult: adult, captured: captured)
    }

    func resumeGuestDeletion() async throws {
        let captured = try beginAuthentication(); defer { isAuthenticating = false }
        let session = try await client.auth.session
        try check(captured)
        guard session.user.isAnonymous else { throw BackendError.signedOut }
        try await performDeletion(password: "", account: session.user.id, captured: captured)
    }

    func signIn(email: String, password: String, adult: Bool, agreement: String) async throws {
        guard adult else { throw BackendError.invalidInput("Confirm that you are at least 18 years old.") }
        let captured = try beginAuthentication(); defer { isAuthenticating = false }
        let session = try await client.auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        try check(captured)
        try await enroll(user: session.user.id, agreement: agreement, adult: adult, captured: captured)
    }

    func signUp(email: String, password: String, adult: Bool) async throws {
        guard adult, password.count >= 8 else {
            throw BackendError.invalidInput("Confirm that you are 18 or older and use a password of at least eight characters.")
        }
        let captured = try beginAuthentication(); defer { isAuthenticating = false }
        _ = try await client.auth.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password, redirectTo: BackendConfiguration.callbackURL)
        try check(captured)
        phase = .verification
    }

    func completeCallback(_ url: URL) async throws {
        guard BackendConfiguration.acceptsCallback(url) else { throw BackendError.invalidInput("This account link is invalid.") }
        // Pinned SDK PKCE exchange emits signedIn for both flows; route by the exact redirect path.
        let captured = try beginAuthentication(); defer { isAuthenticating = false }
        accountID = nil; phase = .restoring
        _ = try await client.auth.session(from: url)
        try check(captured)
        phase = url.path == BackendConfiguration.recoveryURL.path ? .recovery : .verification
    }

    func finishVerification(adult: Bool, agreement: String) async throws {
        guard phase == .verification else { throw BackendError.invalidInput("Verify your email first, or sign in with your password.") }
        let captured = try beginAuthentication(); defer { isAuthenticating = false }
        let session = try await client.auth.session
        try check(captured)
        try await enroll(user: session.user.id, agreement: agreement, adult: adult, captured: captured)
    }

    func resumeDeletion(email: String, password: String) async throws {
        let captured = try beginAuthentication(); defer { isAuthenticating = false }
        let session = try await client.auth.signIn(email: email, password: password)
        try check(captured)
        try await performDeletion(password: password, account: session.user.id, captured: captured)
    }

    func deleteAccount(password: String) async throws {
        let account = try requireAccount()
        let captured = try beginAuthentication(); defer { isAuthenticating = false }
        try await performDeletion(password: password, account: account, captured: captured)
    }
    private func performDeletion(password: String, account: UUID, captured: UUID) async throws {
        let user = try await client.auth.session.user.id
        try check(captured)
        if account != user { throw BackendError.accountChanged }
        // Keep a failed deletion resumable; the server locks business access before cleanup.
        phase = .deleting; onAccountExit?()
        let receipt: RemoteDeletionReceipt = try await client.functions.invoke("delete-account",
            options: .init(body: ["password": AnyJSON.string(password), "confirm_delete": .bool(true)]))
        try check(captured)
        guard receipt.status == "deleted" else { throw BackendError.unavailable }
        try? await AccountCache.shared(account: user).delete()
        try? await client.auth.signOut(scope: .local)
        exitAccount(); onAccountExit?()
    }

    private func enroll(user: UUID, agreement: String, adult: Bool, captured: UUID) async throws {
        guard adult, agreement != "unavailable" else { throw BackendError.invalidInput("Read and accept the agreements and confirm that you are 18 or older.") }
        struct Parameters: Encodable { let p_version: String; let p_adult: Bool; let p_name: String }
        _ = try await client.rpc("bibi_enroll", params: Parameters(p_version: agreement, p_adult: adult, p_name: isGuest ? "Bibi guest" : "Stargazer")).execute()
        try check(captured)
        accountID = user; phase = .signedIn
    }

    func resend(email: String) async throws {
        _ = try beginAuthentication(); defer { isAuthenticating = false }
        try await client.auth.resend(email: email, type: .signup, emailRedirectTo: BackendConfiguration.callbackURL)
    }

    func resetPassword(email: String) async throws {
        _ = try beginAuthentication(); defer { isAuthenticating = false }
        try await client.auth.resetPasswordForEmail(email, redirectTo: BackendConfiguration.recoveryURL)
    }

    func updatePassword(_ password: String) async throws {
        guard password.count >= 8 else { throw BackendError.invalidInput("Use at least eight characters.") }
        let captured = try beginAuthentication(); defer { isAuthenticating = false }
        _ = try await client.auth.update(user: UserAttributes(password: password))
        try check(captured)
        try await client.auth.signOut()
        exitAccount()
    }

    func signOut() async throws {
        _ = try beginAuthentication(); defer { isAuthenticating = false }
        // Clear the visible account first, even if remote revocation needs a retry.
        exitAccount(); onAccountExit?()
        do { try await client.auth.signOut() }
        catch { try? await client.auth.signOut(scope: .local); throw error }
    }

    private func beginAuthentication() throws -> UUID {
        guard !isAuthenticating else { throw BackendError.invalidInput("An account request is in progress. Please try again when it finishes.") }
        isAuthenticating = true; generation = UUID(); return generation
    }

    private func exitAccount() {
        generation = UUID(); accountID = nil; phase = .signedOut
    }

    func rows<T: Decodable>(_ table: String, filters: [String: String] = [:],
                            order: String = "created_at", ascending: Bool = false,
                            offset: Int = 0, limit: Int = 50) async throws -> [T] {
        _ = try requireAccount()
        let captured = generation
        var query = client.from(table).select()
        for (column, value) in filters { query = query.eq(column, value: value) }
        let result: [T] = try await query.order(order, ascending: ascending)
            .range(from: offset, to: offset + min(max(1, limit), 100) - 1).execute().value
        try check(captured)
        return result
    }

    func allRows<T: Decodable>(_ table: String, keys: [String] = ["id"]) async throws -> [T] {
        _ = try requireAccount(); let captured = generation
        var rows: [T] = [], cursor: [String]?
        while true {
            var filtered = client.from(table).select()
            if let cursor {
                // All current primary keys are UUIDs or catalog slugs. Never interpolate free text.
                let predicates = keys.indices.map { index -> String in
                    let prefix = (0..<index).map { "\(keys[$0]).eq.\(cursor[$0])" }
                    let parts = prefix + ["\(keys[index]).gt.\(cursor[index])"]
                    return parts.count == 1 ? parts[0] : "and(" + parts.joined(separator: ",") + ")"
                }
                filtered = filtered.or(predicates.joined(separator: ","))
            }
            var query = filtered.order(keys[0], ascending: true)
            for key in keys.dropFirst() { query = query.order(key, ascending: true) }
            let response = try await query.limit(100).execute()
            let page = try servicesDecoder.decode([T].self, from: response.data)
            try check(captured); rows.append(contentsOf: page)
            guard page.count == 100 else { return rows }
            guard let raw = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]], let last = raw.last else { throw BackendError.unavailable }
            cursor = try keys.map { key in
                guard let value = last[key] as? String, !value.isEmpty,
                      value.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { throw BackendError.unavailable }
                return value
            }
        }
    }

    private var servicesDecoder: JSONDecoder {
        // Match Supabase's fractional and whole-second timestamp decoding.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let format = ISO8601DateFormatter(); format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = format.date(from: value) { return date }
            format.formatOptions = [.withInternetDateTime]
            if let date = format.date(from: value) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid server date."))
        }
        return decoder
    }

    func command(_ action: String, operation: UUID, payload: [String: AnyJSON]) async throws -> [String: AnyJSON] {
        _ = try requireAccount()
        let captured = generation
        struct Parameters: Encodable { let p_operation: UUID; let p_action: String; let p_payload: [String: AnyJSON] }
        let result: [String: AnyJSON] = try await client.rpc("bibi_command",
            params: Parameters(p_operation: operation, p_action: action, p_payload: payload)).execute().value
        try check(captured)
        return result
    }
}
