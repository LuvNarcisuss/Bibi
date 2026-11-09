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

    func testMediaGrantDoesNotWaitForNavigationCommit() {
        var policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        XCTAssertTrue(policy.permitsMedia(pageID: "page", sessionGeneration: generation, live: true, knownResource: true))
        let navigation = UUID()
        policy.beginNavigation(navigation)
        XCTAssertTrue(policy.permitsMedia(pageID: "page", sessionGeneration: generation, live: true, knownResource: true))
        policy.commitDocument(entry, navigation: navigation)
        XCTAssertTrue(policy.permitsMedia(pageID: "page", sessionGeneration: generation, live: true, knownResource: true))
        let next = UUID()
        policy.beginNavigation(next)
        policy.commitDocument(URL(string: "https://other.example.test")!, navigation: next)
        XCTAssertTrue(policy.permitsMedia(pageID: "page", sessionGeneration: generation, live: true, knownResource: true))
    }

    func testMediaDeniesStalePageSessionBackgroundAndUnknownResource() {
        let policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        XCTAssertFalse(policy.permitsMedia(pageID: "old", sessionGeneration: generation, live: true, knownResource: true))
        XCTAssertFalse(policy.permitsMedia(pageID: "page", sessionGeneration: UUID(), live: true, knownResource: true))
        XCTAssertFalse(policy.permitsMedia(pageID: "page", sessionGeneration: generation, live: false, knownResource: true))
        XCTAssertFalse(policy.permitsMedia(pageID: "page", sessionGeneration: generation, live: true, knownResource: false))
    }

    func testInvalidatedOrInvalidEntryNeverGrantsMedia() {
        var policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        policy.invalidate()
        let navigation = UUID()
        policy.beginNavigation(navigation)
        policy.commitDocument(entry, navigation: navigation)
        XCTAssertFalse(policy.permitsMedia(pageID: "page", sessionGeneration: generation, live: true, knownResource: true))
        for raw in ["about:blank", "file:///tmp/page.html", "https://user@entry.example.test"] {
            let invalid = BibiWebPagePolicy(url: URL(string: raw)!, pageID: "page", sessionGeneration: generation)
            XCTAssertFalse(invalid.permitsMedia(pageID: "page", sessionGeneration: generation, live: true, knownResource: true), raw)
        }
    }

    func testEmbeddedDocumentsUseApprovedPageScopeWithoutChangingTopLevelOrigin() {
        let policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        for raw in ["https://entry.example.test/frame", "https://media.example.test/capture",
                    "http://media.example.test/frame", "about:blank", "about:srcdoc"] {
            XCTAssertTrue(policy.permitsEmbeddedDocument(URL(string: raw)!, pageID: "page", sessionGeneration: generation, live: true), raw)
        }
        for raw in ["file:///tmp/frame.html", "data:text/html,frame", "javascript:void(0)",
                    "phonepe://pay", "about:config", "https://user@media.example.test/frame"] {
            XCTAssertFalse(policy.permitsEmbeddedDocument(URL(string: raw)!, pageID: "page", sessionGeneration: generation, live: true), raw)
        }
        XCTAssertFalse(policy.permitsDocument(URL(string: "https://media.example.test/capture")!))
        XCTAssertFalse(policy.permitsDocument(URL(string: "about:blank")!))
    }

    func testEmbeddedDocumentsDenyStaleNonLiveAndInvalidatedPages() {
        var policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        for raw in ["https://media.example.test/capture", "about:blank", "about:srcdoc"] {
            let url = URL(string: raw)!
            XCTAssertFalse(policy.permitsEmbeddedDocument(url, pageID: "old", sessionGeneration: generation, live: true), raw)
            XCTAssertFalse(policy.permitsEmbeddedDocument(url, pageID: "page", sessionGeneration: UUID(), live: true), raw)
            XCTAssertFalse(policy.permitsEmbeddedDocument(url, pageID: "page", sessionGeneration: generation, live: false), raw)
        }
        policy.invalidate()
        XCTAssertFalse(policy.permitsEmbeddedDocument(entry, pageID: "page", sessionGeneration: generation, live: true))
        XCTAssertFalse(policy.permitsEmbeddedDocument(URL(string: "about:blank")!, pageID: "page", sessionGeneration: generation, live: true))
    }

    func testPopupRequiresCommittedMainOriginAndCurrentScope() throws {
        var policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        let origin = try XCTUnwrap(BibiWebOrigin(url: entry))
        let foreign = try XCTUnwrap(BibiWebOrigin(url: URL(string: "https://media.example.test")!))
        let navigation = UUID()
        policy.beginNavigation(navigation)
        XCTAssertFalse(policy.permitsWindow(source: origin, pageID: "page", sessionGeneration: generation, navigation: navigation, live: true))
        policy.commitDocument(entry, navigation: navigation)
        XCTAssertTrue(policy.permitsWindow(source: origin, pageID: "page", sessionGeneration: generation, navigation: navigation, live: true))
        XCTAssertFalse(policy.permitsWindow(source: foreign, pageID: "page", sessionGeneration: generation, navigation: navigation, live: true))
        XCTAssertFalse(policy.permitsWindow(source: nil, pageID: "page", sessionGeneration: generation, navigation: navigation, live: true))
        XCTAssertFalse(policy.permitsWindow(source: origin, pageID: "old", sessionGeneration: generation, navigation: navigation, live: true))
        XCTAssertFalse(policy.permitsWindow(source: origin, pageID: "page", sessionGeneration: UUID(), navigation: navigation, live: true))
        XCTAssertFalse(policy.permitsWindow(source: origin, pageID: "page", sessionGeneration: generation, navigation: UUID(), live: true))
        XCTAssertFalse(policy.permitsWindow(source: origin, pageID: "page", sessionGeneration: generation, navigation: navigation, live: false))
    }

    func testNavigationAndInvalidationRemovePopupAuthority() throws {
        var policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        let origin = try XCTUnwrap(BibiWebOrigin(url: entry))
        let first = UUID(), next = UUID()
        policy.beginNavigation(first); policy.commitDocument(entry, navigation: first)
        policy.beginNavigation(next)
        policy.commitDocument(entry, navigation: first)
        XCTAssertFalse(policy.permitsWindow(source: origin, pageID: "page", sessionGeneration: generation, navigation: next, live: true))
        policy.commitDocument(URL(string: "https://foreign.example.test")!, navigation: next)
        XCTAssertFalse(policy.permitsWindow(source: origin, pageID: "page", sessionGeneration: generation, navigation: next, live: true))
        policy.commitDocument(entry, navigation: next)
        XCTAssertTrue(policy.permitsWindow(source: origin, pageID: "page", sessionGeneration: generation, navigation: next, live: true))
        policy.invalidate(); policy.commitDocument(entry, navigation: next)
        XCTAssertFalse(policy.permitsWindow(source: origin, pageID: "page", sessionGeneration: generation, navigation: next, live: true))
    }

    func testDocumentNavigationNeverLearnsAnOrigin() {
        let policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        XCTAssertTrue(policy.permitsDocument(URL(string: "https://entry.example.test/next")!))
        XCTAssertFalse(policy.permitsDocument(URL(string: "https://other.example.test")!))
        XCTAssertFalse(policy.permitsDocument(URL(string: "mailto:help@example.test")!))
    }

    func testHistoryAllowsExistingSameOriginBackAndForwardDestinations() {
        let policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        for raw in ["https://entry.example.test/previous", "https://entry.example.test/next",
                    "https://entry.example.test/start?view=call#details", "https://entry.example.test:443/start"] {
            XCTAssertTrue(policy.permitsHistory(URL(string: raw), canNavigate: true, live: true, checkoutActive: false), raw)
        }
    }

    func testHistoryAtRootOrWithoutDestinationDoesNothing() {
        let policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        XCTAssertFalse(policy.permitsHistory(nil, canNavigate: false, live: true, checkoutActive: false))
        XCTAssertFalse(policy.permitsHistory(nil, canNavigate: true, live: true, checkoutActive: false))
        XCTAssertFalse(policy.permitsHistory(entry, canNavigate: false, live: true, checkoutActive: false))
    }

    func testHistoryRejectsForeignOriginsAndRetiredPayments() {
        let policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        for raw in ["https://other.example.test/previous", "https://sub.entry.example.test/",
                    "https://entry.example.test.evil.test/", "http://entry.example.test/",
                    "https://entry.example.test:444/", "https://user@entry.example.test/",
                    "phonepe://pay", "PAYTMMP://upi/pay", "about:blank"] {
            XCTAssertFalse(policy.permitsHistory(URL(string: raw), canNavigate: true, live: true, checkoutActive: false), raw)
        }
    }

    func testHistoryRejectsNonLiveCheckoutAndInvalidatedPages() {
        var policy = BibiWebPagePolicy(url: entry, pageID: "page", sessionGeneration: generation)
        XCTAssertFalse(policy.permitsHistory(entry, canNavigate: true, live: false, checkoutActive: false))
        XCTAssertFalse(policy.permitsHistory(entry, canNavigate: true, live: true, checkoutActive: true))
        policy.invalidate()
        XCTAssertFalse(policy.permitsHistory(entry, canNavigate: true, live: true, checkoutActive: false))
    }

    func testUnsupportedPaymentSchemesMatchExactlyWithoutCaseSensitivity() {
        for raw in ["phonepe://pay?amount=1", "paytmmp://upi/pay", "PHONEPE://pay", "PayTmMp://pay"] {
            XCTAssertTrue(BibiWebInteractionPolicy.blocksPayment(URL(string: raw)!), raw)
        }
    }

    func testPaymentNamesInQueriesPathsHostsAndLookalikeSchemesDoNotMatch() {
        for raw in ["https://checkout.example.test/?provider=phonepe",
                    "https://checkout.example.test/?next=paytmmp%3A%2F%2Fpay",
                    "https://checkout.example.test/phonepe/paytmmp",
                    "https://phonepe.example.test/", "https://paytmmp.example.test/",
                    "phonepe-other://pay", "paytmmp2://pay", "upi://pay", "mailto:phonepe@example.test"] {
            XCTAssertFalse(BibiWebInteractionPolicy.blocksPayment(URL(string: raw)!), raw)
        }
    }
}

@MainActor
final class BibiWebCaptureLifecycleTests: XCTestCase {
    func testForegroundWaitsForPendingMuteBeforeResuming() {
        let resource = CaptureResource(state: .active)
        let reconciler = resource.makeReconciler()
        reconciler.suspend()
        reconciler.resume()
        XCTAssertEqual(resource.requests, [.muted])
        resource.completeNext()
        XCTAssertEqual(resource.requests, [.muted, .active])
        resource.completeNext()
        XCTAssertEqual(resource.state, .active)
        XCTAssertTrue(resource.pending.isEmpty)
    }

    func testActiveCompletionAfterNewBackgroundIsFollowedByMute() {
        let resource = CaptureResource(state: .active)
        let reconciler = resource.makeReconciler()
        reconciler.suspend(); resource.completeNext()
        reconciler.resume()
        reconciler.suspend()
        XCTAssertEqual(resource.requests, [.muted, .active])
        resource.completeNext()
        XCTAssertEqual(resource.requests, [.muted, .active, .muted])
        resource.completeNext()
        XCTAssertEqual(resource.state, .muted)
        XCTAssertTrue(resource.pending.isEmpty)
    }

    func testTeardownFinishesAfterPendingActivationAndCannotResume() {
        let resource = CaptureResource(state: .active)
        let reconciler = resource.makeReconciler()
        reconciler.suspend(); resource.completeNext()
        reconciler.resume()
        reconciler.stop(); reconciler.resume(); reconciler.suspend()
        XCTAssertEqual(resource.requests, [.muted, .active])
        resource.completeNext()
        XCTAssertEqual(resource.requests, [.muted, .active, .none])
        resource.completeNext()
        reconciler.resume(); reconciler.suspend(); reconciler.stop()
        XCTAssertEqual(resource.state, .none)
        XCTAssertEqual(resource.requests, [.muted, .active, .none])
    }

    func testPreviouslyMutedOrAbsentResourcesNeverAutomaticallyActivate() {
        for initial in [BibiWebCaptureReconciler.State.muted, .none] {
            let resource = CaptureResource(state: initial)
            let reconciler = resource.makeReconciler()
            reconciler.suspend(); reconciler.resume()
            XCTAssertTrue(resource.requests.isEmpty)
            XCTAssertEqual(resource.state, initial)
        }
    }

    func testEndedResourceIsNotRecreatedAfterBackground() {
        let resource = CaptureResource(state: .active)
        let reconciler = resource.makeReconciler()
        reconciler.suspend(); resource.completeNext()
        resource.state = .none
        reconciler.resume()
        XCTAssertEqual(resource.requests, [.muted])
        XCTAssertEqual(resource.state, .none)
    }

    func testOldWebViewCompletionOnlyStopsItsOwnResource() {
        let oldResource = CaptureResource(state: .active)
        let oldReconciler = oldResource.makeReconciler()
        oldReconciler.suspend()
        oldReconciler.stop()
        let newResource = CaptureResource(state: .active)
        let newReconciler = newResource.makeReconciler()
        newReconciler.suspend()
        oldResource.completeNext()
        XCTAssertEqual(oldResource.requests, [.muted, .none])
        XCTAssertEqual(newResource.requests, [.muted])
        oldResource.completeNext()
        newResource.completeNext()
        newReconciler.resume(); newResource.completeNext()
        XCTAssertEqual(oldResource.state, .none)
        XCTAssertEqual(newResource.state, .active)
        XCTAssertEqual(oldResource.requests, [.muted, .none])
    }

    func testUnchangedRejectedMutationDoesNotRetryInCompletionLoop() {
        let resource = CaptureResource(state: .active)
        let reconciler = resource.makeReconciler()
        reconciler.suspend()
        resource.completeNext(apply: false)
        XCTAssertEqual(resource.requests, [.muted])
        XCTAssertTrue(resource.pending.isEmpty)
    }

    func testDetachedOwnerRemainsAliveUntilTerminalStopCompletes() {
        let resource = CaptureResource(state: .active)
        var reconciler: BibiWebCaptureReconciler? = resource.makeReconciler()
        reconciler?.suspend(); reconciler?.stop()
        weak var pendingOwner = reconciler
        reconciler = nil
        XCTAssertNotNil(pendingOwner)
        resource.completeNext()
        XCTAssertEqual(resource.requests, [.muted, .none])
        resource.completeNext()
        XCTAssertEqual(resource.state, .none)
        XCTAssertNil(pendingOwner)
    }

    @MainActor
    private final class CaptureResource {
        var state: BibiWebCaptureReconciler.State
        var requests: [BibiWebCaptureReconciler.State] = []
        var pending: [(state: BibiWebCaptureReconciler.State, completion: () -> Void)] = []

        init(state: BibiWebCaptureReconciler.State) { self.state = state }
        func makeReconciler() -> BibiWebCaptureReconciler {
            BibiWebCaptureReconciler(readState: { self.state }, setState: { state, completion in
                self.requests.append(state)
                self.pending.append((state, completion))
            })
        }
        func completeNext(apply: Bool = true, file: StaticString = #filePath, line: UInt = #line) {
            guard !pending.isEmpty else { XCTFail("No capture mutation is pending", file: file, line: line); return }
            let operation = pending.removeFirst()
            if apply { state = operation.state }
            operation.completion()
        }
    }
}
