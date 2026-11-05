import CryptoKit
import Foundation

struct BibiExternalPurchaseContext: Codable, Equatable {
    let supabaseAccountID: UUID
    let origin: URL
    let appID: String
    let authenticationAttemptID: UUID
    var isValid: Bool {
        guard let parts = URLComponents(url: origin, resolvingAgainstBaseURL: false) else { return false }
        return origin.absoluteString.count <= 2_048 && parts.scheme?.lowercased() == "https" && parts.host?.isEmpty == false
            && parts.user == nil && parts.password == nil && parts.query == nil && parts.fragment == nil
            && (parts.path.isEmpty || parts.path == "/")
            && !appID.isEmpty && appID.count <= 128
    }
}

enum BibiPurchasePhase: String, Codable {
    case prepared, awaitingTransaction, outcomeUnknown, deferred, awaitingEvidence
    case awaitingConfirmation, retryWait, needsReconciliation, blocked
    case serverConfirmed, deliveryCommitted, finishRequested, completed, failed

    var hasDelivery: Bool {
        [.serverConfirmed, .deliveryCommitted, .finishRequested, .completed].contains(self)
    }
    var deliveryRank: Int {
        switch self {
        case .serverConfirmed: return 1
        case .deliveryCommitted: return 2
        case .finishRequested: return 3
        case .completed: return 4
        default: return 0
        }
    }
    var awaitsApple: Bool { [.prepared, .awaitingTransaction, .outcomeUnknown, .deferred].contains(self) }
}

/// Association is immutable once a real transaction has been bound. Evidence may advance.
struct BibiPurchaseRecord: Codable, Identifiable {
    let id: UUID
    let source: ConfiguredPurchaseSource?
    let accountID: UUID?
    let productID: String
    let quantity: Int
    let environment: String
    let contractID: String
    let appVersion: String
    let deviceNo: String
    let messageID: String?
    let orderReference: String?
    let externalContext: BibiExternalPurchaseContext?
    let createdAt: Date
    var phase: BibiPurchasePhase
    var transactionID: String?
    var observedPaidAt: Date?
    var associationBasis: String?
    var receiptBase64: String?
    var receiptFingerprint: String?
    var evidenceVersion = 0
    var evidenceObtainedAt: Date?
    var rejectedFingerprint: String?
    var category: String?
    var nextRetryAt: Date?
    var confirmedAuthority: String?
    var confirmedBalance: Int64?
    var legacyDeviceDelivery = false

    var transactionKey: String? {
        transactionID.map { "com.bibi.quadratic|\(environment)|\($0)" }
    }
    var supportsSettlement: Bool { ["Sandbox", "Production"].contains(environment) }
}

/// Main-actor serialization keeps journal changes and observer callbacks in one order.
/// A checksummed primary and recoverable replica are atomically replaced with file protection.
@MainActor
final class BibiPurchaseJournal {
    struct State: Codable { var schemaVersion = 1; var generation = 0; var records: [BibiPurchaseRecord] = [] }
    private struct Envelope: Codable { let payload: Data; let sha256: String }
    private(set) var state = State()
    private(set) var isReady = false
    private(set) var failure: String?
    #if DEBUG
    var beforeCommit: ((State) throws -> Void)?
    #endif
    private let root: URL
    private let primary: URL
    private let replica: URL

    init(root: URL? = nil) {
        let base = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bibi/PurchaseRecovery", isDirectory: true)
        self.root = base
        primary = base.appendingPathComponent("purchases-v1.json")
        replica = base.appendingPathComponent("purchases-v1.replica.json")
    }

    static func fingerprint(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    func load() throws {
        guard !isReady else { return }
        do {
            let existing = [primary, replica].filter { FileManager.default.fileExists(atPath: $0.path) }
            var states: [State] = []
            for url in existing {
                do {
                    let bytes = try Data(contentsOf: url)
                    guard bytes.count <= 32_000_000 else { throw BackendError.invalidInput("Purchase recovery storage is too large.") }
                    let envelope = try JSONDecoder().decode(Envelope.self, from: bytes)
                    guard envelope.sha256 == Self.fingerprint(envelope.payload) else { throw BackendError.unavailable }
                    let decoded = try JSONDecoder().decode(State.self, from: envelope.payload)
                    guard decoded.schemaVersion == 1, Set(decoded.records.map(\.id)).count == decoded.records.count else { throw BackendError.unavailable }
                    let keys = decoded.records.compactMap(\.transactionKey)
                    guard Set(keys).count == keys.count else { throw BackendError.unavailable }
                    states.append(decoded)
                } catch {
                    // Keep the unreadable original; a copy is evidence, never an empty reset.
                    let evidence = root.appendingPathComponent("unreadable-\(UUID().uuidString).json")
                    try? FileManager.default.copyItem(at: url, to: evidence)
                }
            }
            guard existing.isEmpty || !states.isEmpty else { throw BackendError.invalidInput("Purchase recovery storage cannot be read. Existing purchases have been kept.") }
            state = states.max(by: { $0.generation < $1.generation }) ?? State()
            isReady = true; failure = nil
            if !existing.isEmpty && states.count != existing.count { failure = "A purchase recovery replica was unreadable; the verified copy was retained." }
        } catch {
            failure = "Purchase recovery storage is unavailable. No new payment can start."
            throw error
        }
    }

    func record(_ id: UUID) -> BibiPurchaseRecord? { state.records.first { $0.id == id } }
    func record(transactionID: String, environment: String) -> BibiPurchaseRecord? {
        state.records.first { $0.transactionID == transactionID && $0.environment == environment }
    }

    func save(_ record: BibiPurchaseRecord) throws {
        guard isReady else { throw BackendError.invalidInput(failure ?? "Purchase recovery has not started.") }
        var next = state
        if let index = next.records.firstIndex(where: { $0.id == record.id }) {
            let old = next.records[index]
            guard old.source == record.source, old.accountID == record.accountID,
                  old.productID == record.productID, old.quantity == record.quantity,
                  old.environment == record.environment, old.contractID == record.contractID,
                  old.appVersion == record.appVersion, old.deviceNo == record.deviceNo, old.createdAt == record.createdAt,
                  old.observedPaidAt == nil || old.observedPaidAt == record.observedPaidAt,
                  old.orderReference == record.orderReference, old.messageID == record.messageID,
                  old.externalContext == record.externalContext,
                  old.transactionID == nil || old.transactionID == record.transactionID,
                  old.phase.deliveryRank <= record.phase.deliveryRank,
                  old.confirmedAuthority == nil || old.confirmedAuthority == record.confirmedAuthority,
                  !old.phase.hasDelivery || record.receiptBase64 == nil || record.receiptBase64 == old.receiptBase64,
                  record.evidenceVersion >= old.evidenceVersion else { throw BackendError.invalidInput("Purchase association cannot change.") }
            next.records[index] = record
        } else {
            guard next.records.count < 10_000 else { throw BackendError.invalidInput("Purchase recovery storage requires maintenance before a new payment.") }
            next.records.append(record)
        }
        let keys = next.records.compactMap(\.transactionKey)
        guard Set(keys).count == keys.count else { throw BackendError.invalidInput("This Apple transaction already has an original purchase association.") }
        try commit(next)
    }

    /// Only an owner-scoped service result can restore a missing historical association.
    func restoreTrusted(_ record: BibiPurchaseRecord, replacing orphanID: UUID) throws {
        guard let orphan = self.record(orphanID), orphan.source == nil, orphan.accountID == nil,
              !orphan.phase.hasDelivery, orphan.transactionKey == record.transactionKey,
              record.source != nil, record.accountID != nil,
              orphan.productID == record.productID, orphan.quantity == record.quantity,
              !state.records.contains(where: { $0.id == record.id && $0.id != orphanID }) else {
            throw BackendError.invalidInput("The original purchase association cannot be recovered safely.")
        }
        var next = state; next.records.removeAll { $0.id == orphanID }; next.records.append(record)
        try commit(next)
    }

    private func commit(_ state: State) throws {
        guard isReady else { throw BackendError.invalidInput(failure ?? "Purchase recovery is unavailable.") }
        var next = state
        next.generation += 1
        do {
            #if DEBUG
            try beforeCommit?(next)
            #endif
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            var directory = root; try directory.setResourceValues(values)
            let payload = try JSONEncoder().encode(next)
            let bytes = try JSONEncoder().encode(Envelope(payload: payload, sha256: Self.fingerprint(payload)))
            guard bytes.count <= 32_000_000 else { throw BackendError.invalidInput("Purchase evidence storage requires recovery before more evidence can be saved.") }
            try bytes.write(to: replica, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            try bytes.write(to: primary, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            self.state = next
        } catch {
            isReady = false
            failure = "Purchase recovery could not be saved. The actual Apple transaction remains unfinished."
            throw error
        }
    }
}

/// The actual observer uses these association rules before binding an unrecognized transaction.
enum BibiPurchaseAssociation {
    static func candidate(records: [BibiPurchaseRecord], paymentOwner: UUID?, applicationUsername: String?,
                          productID: String, quantity: Int, environment: String) -> BibiPurchaseRecord? {
        guard let id = paymentOwner ?? applicationUsername.flatMap(UUID.init(uuidString:)),
              let record = records.first(where: { $0.id == id }), record.source != nil, record.accountID != nil,
              record.productID == productID, record.quantity == quantity,
              record.environment == environment else { return nil }
        return record
    }
}
