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
    func testEnabledBackendGateInitializesOnlineServices() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "BibiBackendEnabled") as? Bool, true)
        XCTAssertTrue(BackendConfiguration.isEnabled)
        let store = AppStore()
        XCTAssertTrue(store.isOnline)
        XCTAssertNotNil(store.online)
        _ = try BackendServices()
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

final class BibiWebMediaBoundaryTests: XCTestCase {
    private let entry = URL(string: "https://entry.example.test/start?ticket=opaque")!
    private let generation = UUID()

    func testOriginsNormalizeDefaultPortsAndIgnorePaths() throws {
        let expected = try XCTUnwrap(BibiWebOrigin(url: entry))
        XCTAssertEqual(expected, BibiWebOrigin(url: URL(string: "HTTPS://ENTRY.EXAMPLE.TEST:443/other?q=1#part")!))
        for raw in ["http://entry.example.test", "https://entry.example.test:444", "https://sub.entry.example.test", "https://entry.example.test.evil.test"] {
            XCTAssertNotEqual(expected, BibiWebOrigin(url: URL(string: raw)!))
        }
        for raw in ["https://user@entry.example.test", "file:///tmp/page.html", "about:blank", "https://entry.example.test:0"] {
            XCTAssertNil(BibiWebOrigin(url: URL(string: raw)!))
        }
    }

    func testMediaRequiresCommittedDocumentAndMatchingRequestAndFrame() throws {
        var policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        let origin = try XCTUnwrap(BibiWebOrigin(url: entry))
        let navigation = UUID()
        policy.beginNavigation(navigation)
        XCTAssertFalse(policy.permitsMedia(request: origin, frame: origin, pageID: "page", sessionGeneration: generation, navigation: navigation, live: true, knownResource: true))
        policy.commitDocument(entry, navigation: navigation)
        XCTAssertTrue(policy.permitsMedia(request: origin, frame: origin, pageID: "page", sessionGeneration: generation, navigation: navigation, live: true, knownResource: true))
        let foreign = try XCTUnwrap(BibiWebOrigin(url: URL(string: "https://other.example.test")!))
        for pair in [(foreign, origin), (origin, foreign), (foreign, foreign)] {
            XCTAssertFalse(policy.permitsMedia(request: pair.0, frame: pair.1, pageID: "page", sessionGeneration: generation, navigation: navigation, live: true, knownResource: true))
        }
        XCTAssertFalse(policy.permitsMedia(request: nil, frame: origin, pageID: "page", sessionGeneration: generation, navigation: navigation, live: true, knownResource: true))
    }

    func testStaleSessionPageNavigationAndUnknownResourcesDeny() throws {
        var policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        let origin = try XCTUnwrap(BibiWebOrigin(url: entry)), navigation = UUID()
        policy.beginNavigation(navigation); policy.commitDocument(entry, navigation: navigation)
        for scope in [("old", generation, navigation, true, true), ("page", UUID(), navigation, true, true), ("page", generation, UUID(), true, true), ("page", generation, navigation, false, true), ("page", generation, navigation, true, false)] {
            XCTAssertFalse(policy.permitsMedia(request: origin, frame: origin, pageID: scope.0, sessionGeneration: scope.1, navigation: scope.2, live: scope.3, knownResource: scope.4))
        }
    }

    func testNavigationAndInvalidationRemoveDocumentAuthority() throws {
        var policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        let origin = try XCTUnwrap(BibiWebOrigin(url: entry)), first = UUID(), next = UUID()
        policy.beginNavigation(first); policy.commitDocument(entry, navigation: first)
        policy.beginNavigation(next)
        policy.commitDocument(entry, navigation: first)
        XCTAssertFalse(policy.permitsMedia(request: origin, frame: origin, pageID: "page", sessionGeneration: generation, navigation: next, live: true, knownResource: true))
        policy.commitDocument(URL(string: "https://foreign.example.test")!, navigation: next)
        XCTAssertFalse(policy.permitsMedia(request: origin, frame: origin, pageID: "page", sessionGeneration: generation, navigation: next, live: true, knownResource: true))
        policy.commitDocument(entry, navigation: next)
        policy.invalidate(); policy.commitDocument(entry, navigation: next)
        XCTAssertFalse(policy.permitsMedia(request: origin, frame: origin, pageID: "page", sessionGeneration: generation, navigation: next, live: true, knownResource: true))
    }

    func testDocumentNavigationNeverLearnsAnOrigin() {
        let policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        XCTAssertTrue(policy.permitsDocument(URL(string: "https://entry.example.test/next")!))
        XCTAssertFalse(policy.permitsDocument(URL(string: "https://other.example.test")!))
        XCTAssertFalse(policy.permitsDocument(URL(string: "mailto:help@example.test")!))
    }
}
