import XCTest
@testable import Bibi

final class BackendBoundaryTests: XCTestCase {
    func testSecureSessionStorageSurvivesReinitialization() throws {
        let key = "guest-storage-test-" + UUID().uuidString
        let bytes = Data("Disposable secure storage probe".utf8)
        let storage = BackendKeychain()
        defer { try? storage.remove(key: key) }
        try storage.verifyAvailable()
        try storage.store(key: key, value: bytes)
        XCTAssertEqual(try BackendKeychain().retrieve(key: key), bytes)
        try storage.remove(key: key)
        XCTAssertNil(try storage.retrieve(key: key))
    }

    @MainActor
    func testDisabledBackendGateKeepsOnlineServicesUninitialized() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "BibiBackendEnabled") as? Bool, false)
        XCTAssertFalse(BackendConfiguration.isEnabled)
        let store = AppStore()
        XCTAssertFalse(store.isOnline)
        XCTAssertNil(store.online)
        XCTAssertThrowsError(try BackendServices()) { error in
            guard case BackendError.unavailable = error else {
                XCTFail("Unexpected backend initialization error: \(error)")
                return
            }
        }
    }

    func testCallbacksRejectForeignOriginsAndAmbiguousCredentials() {
        XCTAssertTrue(BackendConfiguration.acceptsCallback(URL(string: "bibi://auth/callback?code=one-time-code")!))
        XCTAssertTrue(BackendConfiguration.acceptsCallback(URL(string: "bibi://auth/recovery?code=one-time-code")!))
        for value in ["https://auth/callback?code=x", "bibi://evil/callback?code=x",
                      "bibi://auth/callback/extra?code=x", "bibi://user@auth/callback?code=x",
                      "bibi://auth:443/callback?code=x", "bibi://auth/callback#access_token=x"] {
            XCTAssertFalse(BackendConfiguration.acceptsCallback(URL(string: value)!), value)
        }
    }

    @MainActor
    func testConcurrentRetryIdentityAndAccountIsolation() async throws {
        let first = AccountCache.shared(account: UUID())
        let second = AccountCache.shared(account: UUID())
        do {
            async let one = first.operation(key: "interrupted-send")
            async let two = first.operation(key: "interrupted-send")
            let values = try await (one, two)
            XCTAssertEqual(values.0, values.1)
            let other = try await second.operation(key: "interrupted-send")
            XCTAssertNotEqual(values.0, other)
            try await first.saveDraft("Account A only", conversation: "room")
            let otherDrafts = try await second.drafts()
            XCTAssertNil(otherDrafts["room"])
            try await first.acknowledge(key: "interrupted-send", operation: UUID())
            let unchanged = try await first.operation(key: "interrupted-send")
            XCTAssertEqual(unchanged, values.0)
            try await first.acknowledge(key: "interrupted-send", operation: values.0)
            let next = try await first.operation(key: "interrupted-send")
            XCTAssertNotEqual(next, values.0)
            try await first.delete(); try await second.delete()
        } catch {
            try? await first.delete(); try? await second.delete(); throw error
        }
    }
}
