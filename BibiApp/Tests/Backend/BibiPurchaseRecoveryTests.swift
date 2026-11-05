import Foundation
import XCTest
@testable import Bibi

/// Authored recovery checks. They require the designated simulator and have not been run in this revision.
@MainActor
final class BibiPurchaseRecoveryTests: XCTestCase {
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("bibi-purchase-check-" + UUID().uuidString, isDirectory: true) }
    private func record(id: UUID = UUID(), source: ConfiguredPurchaseSource? = .local, account: UUID? = UUID(), transaction: String? = nil) -> BibiPurchaseRecord {
        var value = BibiPurchaseRecord(id: id, source: source, accountID: account,
            productID: "test-consumable", quantity: 1, environment: "Sandbox", contractID: BibiSettlementClient.contractID,
            appVersion: "1.0", deviceNo: UUID().uuidString, messageID: nil, orderReference: nil,
            externalContext: nil, createdAt: Date(), phase: .awaitingTransaction)
        value.transactionID = transaction
        return value
    }

    func testAssociationNeverUsesSKUOrCurrentUserAsOwnership() {
        let original = record()
        XCTAssertNil(BibiPurchaseAssociation.candidate(records: [original], paymentOwner: nil,
            applicationUsername: nil, productID: original.productID, quantity: 1, environment: "Sandbox"))
        XCTAssertNil(BibiPurchaseAssociation.candidate(records: [original], paymentOwner: UUID(),
            applicationUsername: original.id.uuidString, productID: original.productID, quantity: 1, environment: "Sandbox"))
        XCTAssertEqual(BibiPurchaseAssociation.candidate(records: [original], paymentOwner: nil,
            applicationUsername: original.id.uuidString, productID: original.productID, quantity: 1, environment: "Sandbox")?.id, original.id)
        XCTAssertNil(BibiPurchaseAssociation.candidate(records: [original], paymentOwner: original.id,
            applicationUsername: nil, productID: original.productID, quantity: 1, environment: "Production"))
    }

    func testEarlierTransactionLookupWinsOverNewPaymentOwner() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journal = BibiPurchaseJournal(root: root); try journal.load()
        var old = record(transaction: "apple-old"); old.phase = .awaitingConfirmation
        let current = record()
        try journal.save(old); try journal.save(current)
        let known = journal.record(transactionID: "apple-old", environment: "Sandbox")
        let attempted = BibiPurchaseAssociation.candidate(records: journal.state.records,
            paymentOwner: current.id, applicationUsername: current.id.uuidString,
            productID: current.productID, quantity: 1, environment: "Sandbox")
        XCTAssertEqual(known?.id, old.id)
        XCTAssertEqual(attempted?.id, current.id)
        XCTAssertNotEqual(known?.id, attempted?.id)
        XCTAssertNil(journal.record(current.id)?.transactionID)
    }

    func testDeliveryPhasesCannotRegressFromLateResponses() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journal = BibiPurchaseJournal(root: root); try journal.load()
        var paid = record(transaction: "apple-one"); paid.phase = .awaitingConfirmation
        paid.receiptBase64 = Data([1, 2, 3]).base64EncodedString(); paid.evidenceVersion = 1
        try journal.save(paid)
        paid.phase = .serverConfirmed; paid.confirmedAuthority = "supabase"; try journal.save(paid)
        paid.phase = .deliveryCommitted; paid.receiptBase64 = nil; try journal.save(paid)
        paid.phase = .finishRequested; try journal.save(paid)
        var stale = paid; stale.phase = .serverConfirmed
        XCTAssertThrowsError(try journal.save(stale))
        paid.phase = .completed; try journal.save(paid)
        stale.phase = .finishRequested
        XCTAssertThrowsError(try journal.save(stale))
        let reopened = BibiPurchaseJournal(root: root); try reopened.load()
        XCTAssertEqual(reopened.record(paid.id)?.phase, .completed)
        XCTAssertNil(reopened.record(paid.id)?.receiptBase64)
    }

    func testOneTransactionCannotBeClaimedByAnotherSourceOrAccount() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journal = BibiPurchaseJournal(root: root); try journal.load()
        let original = record(transaction: "apple-shared")
        try journal.save(original)
        let conflicting = record(source: .socket, transaction: "apple-shared")
        XCTAssertThrowsError(try journal.save(conflicting))
        XCTAssertEqual(journal.state.records.count, 1)
        XCTAssertEqual(journal.record(original.id)?.accountID, original.accountID)
    }

    func testVerifiedReplicaSurvivesPrimaryCorruptionWithoutResettingPurchases() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journal = BibiPurchaseJournal(root: root); try journal.load()
        let paid = record(transaction: "apple-kept"); try journal.save(paid)
        try Data("unreadable".utf8).write(to: root.appendingPathComponent("purchases-v1.json"))
        let reopened = BibiPurchaseJournal(root: root); try reopened.load()
        XCTAssertEqual(reopened.record(paid.id)?.transactionID, "apple-kept")
        XCTAssertNotNil(reopened.failure)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).contains(where: { $0.hasPrefix("unreadable-") }))
    }

    func testBothUnreadableCopiesBlockPaymentRatherThanCreateEmptyLedger() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for name in ["purchases-v1.json", "purchases-v1.replica.json"] { try Data("damaged".utf8).write(to: root.appendingPathComponent(name)) }
        let journal = BibiPurchaseJournal(root: root)
        XCTAssertThrowsError(try journal.load())
        XCTAssertFalse(journal.isReady)
        XCTAssertThrowsError(try journal.save(record()))
    }

    func testOnlyUnownedExactOrphanCanAcquireTrustedServerAssociation() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let journal = BibiPurchaseJournal(root: root); try journal.load()
        var orphan = record(source: nil, account: nil, transaction: "apple-orphan"); orphan.phase = .needsReconciliation
        try journal.save(orphan)
        var recovered = record(transaction: "apple-orphan"); recovered.phase = .deliveryCommitted
        recovered.confirmedAuthority = "supabase"
        try journal.restoreTrusted(recovered, replacing: orphan.id)
        XCTAssertNil(journal.record(orphan.id))
        XCTAssertEqual(journal.record(recovered.id)?.accountID, recovered.accountID)
        XCTAssertThrowsError(try journal.restoreTrusted(record(transaction: "apple-orphan"), replacing: recovered.id))
    }

    func testRefreshStartedBeforeLaterPaidCallbackCannotSupplyItsEvidence() {
        let first = Date(timeIntervalSince1970: 100), later = Date(timeIntervalSince1970: 101)
        XCTAssertTrue(BibiReceiptEvidence.covers(observedAt: first, refreshStartedAt: first))
        XCTAssertFalse(BibiReceiptEvidence.covers(observedAt: later, refreshStartedAt: first))
        XCTAssertTrue(BibiReceiptEvidence.covers(observedAt: later, refreshStartedAt: later))
    }

    func testOnlyHTTPAndExactIntegerBusinessSuccessCanConfirm() throws {
        let success = Data("{\"code\":0,\"state\":\"confirmed\"}".utf8)
        XCTAssertTrue(try BibiSettlementReply.parse(success, status: 200).confirmed)
        XCTAssertFalse(try BibiSettlementReply.parse(success, status: 400).confirmed)
        for code in ["false", "0.0", "\"0\""] {
            let data = Data(("{\"code\":" + code + ",\"state\":\"confirmed\"}").utf8)
            XCTAssertThrowsError(try BibiSettlementReply.parse(data, status: 200))
        }
        XCTAssertFalse(try BibiSettlementReply.parse(Data("{\"code\":0,\"state\":\"processing\"}".utf8), status: 202).confirmed)
    }
}
