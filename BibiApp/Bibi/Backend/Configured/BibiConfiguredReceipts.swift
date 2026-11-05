import CryptoKit
import Foundation
import UIKit

/// Business acknowledgements survive disconnects; transport ACKs never remove them.
@MainActor
final class BibiConfiguredReceipts {
    private struct Receipt: Codable {
        let id: String
        let origin: String
        let signal: String
        let stage: String
        let sequence: Int
        var attempts = 0
        var nextAttempt = Date.distantPast
    }
    private let file: URL
    private let transport: BibiConfiguredTransport
    private var rows: [Receipt]
    private var inFlight: Set<String> = []
    private var timer: Task<Void, Never>?

    init(identity: BibiConfiguredIdentity, transport: BibiConfiguredTransport) throws {
        self.transport = transport
        let scope = identity.origin.absoluteString + "|" + identity.appID
        let hash = SHA256.hash(data: Data(scope.utf8)).map { String(format: "%02x", $0) }.joined()
        file = URL.applicationSupportDirectory.appendingPathComponent("BibiOnline", isDirectory: true)
            .appendingPathComponent(identity.accountID.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent("receipts-" + hash + ".json")
        if FileManager.default.fileExists(atPath: file.path) {
            rows = try JSONDecoder().decode([Receipt].self, from: Data(contentsOf: file))
        } else { rows = [] }
    }

    func record(messageID: String, signal: String, stage: String = "applied", sequence: Int = 2) throws {
        let seed = messageID + "|" + signal + "|" + String(sequence)
        let id = SHA256.hash(data: Data(seed.utf8)).map { String(format: "%02x", $0) }.joined()
        guard !rows.contains(where: { $0.id == id }) else { return }
        var next = rows
        next.append(Receipt(id: id, origin: messageID, signal: signal, stage: stage, sequence: sequence))
        try save(next); rows = next
        flush()
    }

    func acknowledge(_ id: String) throws {
        let next = rows.filter { $0.id != id }
        try save(next); rows = next; inFlight.remove(id)
    }

    func ready(reason: String) {
        flush()
        if let event = try? ConfiguredThemeEvent.makeOutbound(signal: .replayRequested, values: [
            "syncReference": UUID().uuidString, "reason": reason,
            "pendingReferences": Array(Set(rows.map(\.origin))).sorted()]) {
            transport.publish(event) { _ in }
        }
        if timer == nil {
            timer = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(nanoseconds: 60_000_000_000) } catch { return }
                    guard let self else { return }
                    if UIApplication.shared.applicationState == .active { self.ready(reason: "periodic") }
                }
            }
        }
    }

    func stop(clear: Bool) {
        timer?.cancel(); timer = nil; inFlight = []
        if clear { try? save([]); rows = [] }
    }

    private func flush() {
        guard transport.client?.state == .ready, UIApplication.shared.applicationState == .active else { return }
        for row in rows where row.nextAttempt <= Date() && !inFlight.contains(row.id) {
            guard let event = try? ConfiguredThemeEvent.makeOutbound(signal: .businessApplied, values: [
                "receiptReference": row.id, "originReference": row.origin, "originSignal": row.signal,
                "stage": row.stage, "sequence": row.sequence]) else { continue }
            inFlight.insert(row.id)
            transport.publish(event) { [weak self] result in
                guard let self else { return }
                self.inFlight.remove(row.id)
                guard let index = self.rows.firstIndex(where: { $0.id == row.id }) else { return }
                var next = self.rows
                next[index].attempts += 1
                let delay: Double
                switch result {
                case .success: delay = 60
                case .failure: delay = min(60, pow(2, Double(min(next[index].attempts, 6))))
                }
                next[index].nextAttempt = Date().addingTimeInterval(delay)
                do { try self.save(next); self.rows = next } catch { }
            }
        }
    }

    private func save(_ rows: [Receipt]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(rows).write(to: file, options: [.atomic, .completeFileProtection])
    }
}
