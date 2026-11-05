import Foundation
import StoreKit
import XCTest
@testable import Bibi

@MainActor
final class BibiPurchaseChainTests: XCTestCase {
    private func harness() async -> PurchaseChainHarness {
        let h = PurchaseChainHarness(); await h.open()
        addTeardownBlock { await h.close() }; return h
    }
    func testBothSourcesTraverseReceiptHTTPDeliveryAndFinish() async throws {
        let h = await harness()
        for socket in [false,true] {
            let id = socket ? "1002":"1001"
            let p = try await h.begin(socket:socket,order:socket ? "web-A":nil); h.emit(p.payment,id:id)
            try await h.until { h.record(id)?.phase == .completed }
            let result = await p.result.value
            XCTAssertTrue(result?.contains("Payment was received") == true); XCTAssertNil(h.record(id)?.receiptBase64)
        }
        XCTAssertEqual(h.serverCredits,1); XCTAssertEqual(h.externalConfirmations,1); XCTAssertEqual(h.balanceRefreshes,1)
        XCTAssertEqual(h.receiptCalls,2); XCTAssertEqual(h.registrations,1); XCTAssertEqual(h.payments.count,2)
        XCTAssertEqual(h.finishSnapshots.map(\.phase),[.finishRequested,.finishRequested])
        let requests = h.requests.filter { $0["action"] as? String == "confirm" }
        XCTAssertEqual(requests[1]["diamond_origin"] as? String,"constellation_order")
        XCTAssertEqual(requests[1]["diamond_product"] as? String,"external-only-sku")
        XCTAssertEqual(requests[1]["orbit_order"] as? String,"web-A"); XCTAssertNil(requests[0]["orbit_order"])
    }
    func testLostResponseConcurrentRecoveryNeverRepaysOrCreditsTwice() async throws {
        let h = await harness(); h.loseNextConfirmation = true
        let p = try await h.begin(); h.emit(p.payment,id:"1101")
        for _ in 0..<6 { h.service.resumeRecovery(userInitiated:true) }
        try await h.until { h.record("1101")?.phase == .completed }
        XCTAssertEqual(h.serverCredits,1); XCTAssertEqual(h.confirmCalls,1); XCTAssertGreaterThanOrEqual(h.statusCalls,1)
        XCTAssertEqual(h.payments.count,1); XCTAssertEqual(h.finishSnapshots.count,1)
    }
    func testSecondSameSKUPurchaseAndOldCallbackCannotStealOwnership() async throws {
        let h = await harness(); let gate = PurchaseGate(); defer { gate.release() }
        h.override = { body in
            if body["action"] as? String == "confirm", body["diamond_reference"] as? String == "1201" { await gate.wait() }
            return nil
        }
        let old = try await h.begin(); h.emit(old.payment,id:"1201"); try await h.until { gate.waiting }
        let next = try await h.begin(); h.emit(next.payment,id:"1201")
        let result = await next.result.value
        XCTAssertTrue(result?.contains("earlier transaction") == true)
        XCTAssertEqual(h.record("1201")?.id.uuidString.lowercased(),old.payment.applicationUsername)
        h.emit(next.payment,id:"1202"); try await h.until { h.record("1202")?.phase == .completed }
        gate.release(); try await h.until { h.record("1201")?.phase == .completed }
        XCTAssertEqual(h.serverCredits,2); XCTAssertEqual(h.payments.count,2)
    }
    func testLaterTransactionRequiresNewReceiptFlight() async throws {
        let h = await harness(); let gate = PurchaseGate(); defer { gate.release() }
        h.receiptOperation = { n in if n == 1 { await gate.wait() }; return Data("receipt-\(n)".utf8) }
        let first = try await h.begin(); h.emit(first.payment,id:"1301"); try await h.until { gate.waiting }
        let second = try await h.begin(); h.emit(second.payment,id:"1302"); try await h.until { h.record("1302") != nil }
        gate.release(); try await h.until { h.record("1301")?.phase == .completed && h.record("1302")?.phase == .completed }
        XCTAssertEqual(h.receiptCalls,2)
        let proof = h.requests.first { $0["action"] as? String == "confirm" && $0["diamond_reference"] as? String == "1302" }?["diamond_proof"] as? String
        XCTAssertEqual(proof,Data("receipt-2".utf8).base64EncodedString())
    }
    func testRejectedUnchangedReceiptStopsUntilFreshExplicitRetry() async throws {
        let h = await harness(); h.receiptOperation = { _ in Data("unchanged".utf8) }
        h.override = { body in body["action"] as? String == "confirm" ? (200,h.failure("awaiting_evidence")):nil }
        let p = try await h.begin(); h.emit(p.payment,id:"1401"); try await h.until { h.record("1401")?.phase == .blocked }
        XCTAssertEqual(h.receiptCalls,2); XCTAssertEqual(h.confirmCalls,1); XCTAssertTrue(h.finishSnapshots.isEmpty)
        h.override = nil; h.receiptOperation = { _ in Data("fresh".utf8) }; h.service.resumeRecovery(userInitiated:true)
        try await h.until { h.record("1401")?.phase == .completed }; XCTAssertEqual(h.payments.count,1)
    }
    func testMissingOrFailedReceiptAndDeferredCancelLateApproval() async throws {
        for bytes in [Data?.none,Data?.some(Data())] {
            let h = await harness()
            h.receiptOperation = { _ in guard let bytes else { throw URLError(.notConnectedToInternet) }; return bytes }
            let p = try await h.begin(); h.emit(p.payment,id:"1501"); try await h.until { h.record("1501")?.category == "awaiting_evidence" }
            XCTAssertEqual(h.confirmCalls,0); XCTAssertTrue(h.finishSnapshots.isEmpty)
            h.receiptOperation = nil; h.service.resumeRecovery(userInitiated:true)
            try await h.until { h.record("1501")?.phase == .completed }; XCTAssertEqual(h.payments.count,1)
        }
        let h = await harness(); let p = try await h.begin(); h.emit(p.payment,state:.deferred)
        let pending = await p.result.value; XCTAssertTrue(pending?.contains("waiting for approval") == true)
        XCTAssertEqual(h.confirmCalls,0); XCTAssertTrue(h.finishSnapshots.isEmpty)
        h.emit(p.payment,id:"1601"); try await h.until { h.record("1601")?.phase == .completed }
        let cancel = try await h.begin(); h.emit(cancel.payment,state:.failed,error:SKError(.paymentCancelled))
        let message = await cancel.result.value; XCTAssertTrue(message?.contains("cancelled") == true)
        try await h.until { h.failedFinishes == 1 }; XCTAssertEqual(h.serverCredits,1)
    }
    func testAccountSwitchPausesOriginalButAllowsOtherAccountPurchase() async throws {
        let h = await harness(); let original = h.accountID; let gate = PurchaseGate(); defer { gate.release() }
        h.receiptOperation = { n in if n == 1 { await gate.wait() }; return Data("receipt-\(n)".utf8) }
        let p = try await h.begin(); h.emit(p.payment,id:"1701"); try await h.until { gate.waiting }
        h.accountID = UUID(); h.service.clearMemory(); await h.service.start(); gate.release()
        try await h.until { h.record("1701")?.category == "session_expired" }
        let next = try await h.begin(); h.emit(next.payment,id:"1702"); try await h.until { h.record("1702")?.phase == .completed }
        XCTAssertEqual(h.record("1701")?.accountID,original)
        h.accountID = original; await h.service.start(); try await h.until { h.record("1701")?.phase == .completed }
        XCTAssertEqual(h.serverCredits,2)
    }
    func testPreparationAndPaidWriteFailureRetainTransactionWithoutEarlyFinish() async throws {
        let h = await harness(); h.journal.beforeCommit = { _ in throw URLError(.cannotWriteToFile) }
        let result = await h.service.purchase(h.package); XCTAssertNotNil(result); XCTAssertTrue(h.payments.isEmpty)
        h.journal.beforeCommit = nil; h.service.resumeRecovery(userInitiated:true)
        let p = try await h.begin()
        h.journal.beforeCommit = { state in if state.records.contains(where: { $0.phase == .awaitingEvidence }) { throw URLError(.cannotWriteToFile) } }
        h.emit(p.payment,id:"1801"); try await h.until { !h.journal.isReady }
        XCTAssertTrue(h.finishSnapshots.isEmpty); XCTAssertEqual(h.confirmCalls,0)
        h.journal.beforeCommit = nil; h.service.resumeRecovery(userInitiated:true)
        try await h.until { h.record("1801")?.phase == .completed }; XCTAssertEqual(h.payments.count,1)
    }
    func testRestartAtConfirmedDeliveryFinishAndRemovedWriteBoundaries() async throws {
        for phase in [BibiPurchasePhase.serverConfirmed,.deliveryCommitted,.finishRequested,.completed] {
            let h = await harness(); var failed = false
            h.journal.beforeCommit = { state in if !failed && state.records.contains(where: { $0.phase == phase }) { failed = true; throw URLError(.cannotWriteToFile) } }
            let p = try await h.begin(); h.emit(p.payment,id:"1901"); try await h.until { failed }; XCTAssertEqual(h.serverCredits,1)
            if phase != .completed { XCTAssertTrue(h.finishSnapshots.isEmpty) }
            h.journal.beforeCommit = nil; await h.restart(); h.service.resumeRecovery(userInitiated:true)
            try await h.until { h.record("1901")?.phase == .completed }
            XCTAssertEqual(h.confirmCalls,1); XCTAssertEqual(h.serverCredits,1); XCTAssertEqual(h.payments.count,1)
        }
    }
    func testRestartAfterSubmissionAndBeforeReceiptNeverRepays() async throws {
        let h = await harness(); h.active = false
        let p = try await h.begin(); h.emit(p.payment,id:"2001"); try await h.until { h.record("2001")?.phase == .awaitingEvidence }
        await h.restart(); h.active = true; h.service.resumeRecovery(userInitiated:true)
        try await h.until { h.record("2001")?.phase == .completed }
        let next = try await h.begin(); await h.restart(); XCTAssertEqual(h.payments.count,2)
        h.emit(next.payment,id:"2002"); h.service.resumeRecovery(userInitiated:true)
        try await h.until { h.record("2002")?.phase == .completed }
    }
    func testLostJournalUsesTrustedHistoryAndUnknownOrphanStaysUnresolved() async throws {
        let h = await harness(); let p = try await h.begin(); let tx = h.emit(p.payment,id:"2101")
        try await h.until { h.record("2101")?.phase == .completed }
        await h.restart(eraseJournal:true,replay:[tx]); try await h.until { h.record("2101")?.phase == .completed }
        XCTAssertEqual(h.serverCredits,1); XCTAssertEqual(h.confirmCalls,1)
        h.emit(SKMutablePayment(product:SimulatedPurchaseProduct("unknown-sku")),id:"2102")
        try await h.until { h.record("2102")?.phase == .needsReconciliation }
        XCTAssertNil(h.record("2102")?.accountID); XCTAssertNil(h.record("2102")?.source)
        XCTAssertFalse(h.finishSnapshots.contains { $0.transactionID == "2102" })
    }
    func testHTTPAndBusinessErrorCategoriesAndBalanceRefreshFailure() async throws {
        for (status,category,phase) in [(200,"configuration",BibiPurchasePhase.blocked),(200,"ownership_conflict",.blocked),
            (200,"unexpected_business",.blocked),(401,"session_expired",.blocked),(429,"transient",.retryWait),
            (503,"transient",.retryWait),(200,"needs_reconciliation",.needsReconciliation)] {
            let h = await harness(); h.override = { body in body["action"] as? String == "availability" ? nil:(status,h.failure(category)) }
            let p = try await h.begin(); h.emit(p.payment,id:"2201"); try await h.until { h.record("2201")?.phase == phase }
            XCTAssertTrue(h.finishSnapshots.isEmpty); XCTAssertEqual(h.record("2201")?.category,category); XCTAssertEqual(h.receiptCalls,1)
            h.override = nil; h.service.resumeRecovery(userInitiated:true); try await h.until { h.record("2201")?.phase == .completed }
            XCTAssertEqual(h.payments.count,1)
        }
        let h = await harness(); h.override = { body in body["action"] as? String == "confirm" ? (200,["code":false,"state":"confirmed"]):nil }
        let p = try await h.begin(); h.emit(p.payment,id:"2301"); try await h.until { h.record("2301")?.phase == .blocked }
        XCTAssertEqual(h.record("2301")?.category,"unknown_response")
        h.override = nil; h.balanceFailure = true; h.service.resumeRecovery(userInitiated:true)
        try await h.until { h.record("2301")?.phase == .completed }; await h.restart()
        XCTAssertEqual(h.serverCredits,1); XCTAssertEqual(h.confirmCalls,2)
    }

    func testPersistentOfflineThenReconnectAndSecondIndependentPayment() async throws {
        let h = await harness()
        h.override = { body in
            if body["action"] as? String != "availability" { throw URLError(.notConnectedToInternet) }
            return nil
        }
        let first = try await h.begin(); h.emit(first.payment,id:"2401")
        try await h.until { h.statusCalls >= 2 }
        await h.service.waitForOfflineRecovery()
        XCTAssertEqual(h.record("2401")?.phase,.retryWait)
        XCTAssertEqual(h.serverCredits,0); XCTAssertTrue(h.finishSnapshots.isEmpty)
        h.override = nil; h.service.resumeRecovery(userInitiated:true)
        let second = try await h.begin(); h.emit(second.payment,id:"2402")
        try await h.until { h.record("2401")?.phase == .completed && h.record("2402")?.phase == .completed }
        XCTAssertEqual(h.serverCredits,2); XCTAssertEqual(h.payments.count,2)
    }

    func testRejectedReceiptRefreshFailureAndNetworkResumeCannotReuseRejectedBytes() async throws {
        let h = await harness()
        h.receiptOperation = { n in if n == 2 { throw URLError(.notConnectedToInternet) }; return Data("receipt-\(n)".utf8) }
        h.override = { body in body["action"] as? String == "confirm" ? (200,h.failure("awaiting_evidence")):nil }
        let p = try await h.begin(); h.emit(p.payment,id:"2501")
        try await h.until { h.receiptCalls == 2 && h.record("2501")?.phase == .awaitingEvidence }
        await h.service.waitForOfflineRecovery()
        h.service.resumeRecovery(); await h.service.waitForOfflineRecovery()
        XCTAssertEqual(h.confirmCalls,1); XCTAssertEqual(h.receiptCalls,2)
        XCTAssertNil(h.record("2501")?.receiptBase64); XCTAssertTrue(h.finishSnapshots.isEmpty)
        h.override = nil; h.service.resumeRecovery(userInitiated:true)
        try await h.until { h.record("2501")?.phase == .completed }
        XCTAssertEqual(h.payments.count,1); XCTAssertEqual(h.serverCredits,1)
    }

    func testCorruptedJournalBuffersRealObserverUntilVerifiedFilesAreRestored() async throws {
        let h = await harness(); h.active = false
        let p = try await h.begin(); h.emit(p.payment,id:"2601")
        try await h.until { h.record("2601") != nil }
        await h.service.endOfflineValidation()
        let primary = h.root.appendingPathComponent("purchases-v1.json")
        let replica = h.root.appendingPathComponent("purchases-v1.replica.json")
        let saved = try Data(contentsOf:primary)
        try Data("damaged".utf8).write(to:primary); try Data("damaged".utf8).write(to:replica)
        await h.open(); XCTAssertFalse(h.journal.isReady)
        XCTAssertEqual(h.confirmCalls,0); XCTAssertTrue(h.finishSnapshots.isEmpty)
        try saved.write(to:primary); try saved.write(to:replica)
        h.active = true; h.service.resumeRecovery(userInitiated:true)
        try await h.until { h.record("2601")?.phase == .completed }
        XCTAssertEqual(h.payments.count,1); XCTAssertEqual(h.serverCredits,1)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath:h.root.path).contains { $0.hasPrefix("unreadable-") })
    }

    func testUnavailableEnvironmentProductAndPermissionNeverEnqueuePayment() async throws {
        let h = await harness(); h.allowed = false
        let denied = await h.service.purchase(h.package); XCTAssertNotNil(denied)
        h.allowed = true; h.environment = "Xcode"
        let unsupported = await h.service.purchase(h.package); XCTAssertNotNil(unsupported)
        h.environment = "Sandbox"; h.resolver = { _ in nil }
        let missing = await h.service.purchase(h.package); XCTAssertNotNil(missing)
        XCTAssertTrue(h.payments.isEmpty); XCTAssertEqual(h.confirmCalls,0)
    }

    func testEntryExpiryDuringProductLookupInvalidatesUnsubmittedAuthorization() async throws {
        let h = await harness(); let gate = PurchaseGate(); defer { gate.release() }
        h.resolver = { sku in await gate.wait(); return SimulatedPurchaseProduct(sku) }
        let pending = Task { await h.service.purchase(h.package) }
        try await h.until { gate.waiting }
        h.service.invalidatePendingPurchaseAuthorization(); await h.service.start(); gate.release()
        let result = await pending.value
        XCTAssertTrue(result?.contains("changed") == true)
        XCTAssertTrue(h.payments.isEmpty); XCTAssertEqual(h.confirmCalls,0)
    }

    func testAppleInteractionTimeoutKeepsAssociationAndLatePaidCallbackCanRecover() async throws {
        let h = await harness(); h.interactionTimeout = 20_000_000; await h.restart()
        let p = try await h.begin(); h.emit(p.payment,state:.purchasing)
        let timeout = await p.result.value
        XCTAssertTrue(timeout?.contains("not returned a final result") == true)
        let blocked = await h.service.purchase(h.package); XCTAssertNotNil(blocked)
        XCTAssertEqual(h.payments.count,1); XCTAssertTrue(h.finishSnapshots.isEmpty)
        h.emit(p.payment,id:"2701"); try await h.until { h.record("2701")?.phase == .completed }
        XCTAssertEqual(h.serverCredits,1)
    }

    func testCompletedTransactionRedeliveryOnlyFinishesRealObjectAgain() async throws {
        let h = await harness(); let p = try await h.begin(); h.emit(p.payment,id:"2801")
        try await h.until { h.record("2801")?.phase == .completed }
        h.emit(p.payment,id:"2801")
        try await h.until { h.finishSnapshots.count == 2 }
        XCTAssertEqual(h.confirmCalls,1); XCTAssertEqual(h.serverCredits,1); XCTAssertEqual(h.payments.count,1)
    }

    func testEachNewActualQueueObjectCanFinishAfterEarlierObjectsAreReleased() async throws {
        let h = await harness(); let p = try await h.begin(); h.emit(p.payment,id:"2901")
        try await h.until { h.record("2901")?.phase == .completed }
        for count in 2...32 {
            h.emit(p.payment,id:"2901")
            try await h.until { h.finishSnapshots.count == count }
        }
        XCTAssertEqual(h.confirmCalls,1); XCTAssertEqual(h.serverCredits,1); XCTAssertEqual(h.payments.count,1)
    }

    func testSocketWithoutOrderAndRejectedConfirmationNeverBecomeNativeCredit() async throws {
        let h = await harness()
        h.override = { body in body["action"] as? String == "confirm" ? (200,h.failure("upstream_rejected")):nil }
        let p = try await h.begin(socket:true); h.emit(p.payment,id:"3001")
        try await h.until { h.record("3001")?.phase == .blocked }
        XCTAssertEqual(h.record("3001")?.source,.socket)
        XCTAssertEqual(h.serverCredits,0); XCTAssertEqual(h.externalConfirmations,0)
        XCTAssertTrue(h.finishSnapshots.isEmpty)
        let request = h.requests.first { $0["action"] as? String == "confirm" }
        XCTAssertNil(request?["orbit_order"]); XCTAssertEqual(request?["diamond_origin"] as? String,"constellation_order")
        h.override = nil; h.service.resumeRecovery(userInitiated:true)
        try await h.until { h.record("3001")?.phase == .completed }
        XCTAssertEqual(h.externalConfirmations,1); XCTAssertEqual(h.serverCredits,0)
        XCTAssertEqual(h.balanceRefreshes,0); XCTAssertEqual(h.payments.count,1)
    }

    func testUnavailableSettlementNeverSubmitsApplePayment() async throws {
        let h = await harness()
        h.override = { body in
            guard body["action"] as? String == "availability" else { return nil }
            return (200,["code":0,"available":false,"source":body["diamond_origin"]!,"environment":body["environment"]!])
        }
        let result = await h.service.purchase(h.package)
        XCTAssertTrue(result?.contains("not configured") == true)
        XCTAssertTrue(h.payments.isEmpty); XCTAssertEqual(h.confirmCalls,0)
    }
}
