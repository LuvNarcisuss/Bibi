import CryptoKit
import Foundation

/// Durable request identities and drafts are isolated from both other accounts and the legacy library.
actor AccountCache {
    @MainActor private static var instances: [UUID: AccountCache] = [:]
    @MainActor static func shared(account: UUID) -> AccountCache {
        if let value = instances[account] { return value }
        let value = AccountCache(account: account); instances[account] = value; return value
    }
    private let root: URL
    private struct Journal: Codable { var operations: [String: UUID] = [:]; var drafts: [String: String] = [:] }
    private init(account: UUID) {
        root = URL.applicationSupportDirectory.appendingPathComponent("BibiOnline", isDirectory: true)
            .appendingPathComponent(account.uuidString.lowercased(), isDirectory: true)
    }
    private var file: URL { root.appendingPathComponent("requests.json") }
    private func load() throws -> Journal {
        guard FileManager.default.fileExists(atPath: file.path) else { return Journal() }
        return try JSONDecoder().decode(Journal.self, from: Data(contentsOf: file))
    }
    private func save(_ journal: Journal) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(journal).write(to: file, options: [.atomic, .completeFileProtection])
    }
    func operation(key: String) throws -> UUID {
        var journal = try load()
        if let id = journal.operations[key] { return id }
        let id = UUID(); journal.operations[key] = id; try save(journal); return id
    }
    func acknowledge(key: String, operation: UUID) throws {
        var journal = try load()
        if journal.operations[key] == operation { journal.operations[key] = nil; try save(journal) }
    }
    func saveDraft(_ text: String, conversation: String) throws {
        guard text.count <= 2000 else { throw BackendError.invalidInput("Use up to 2,000 characters.") }
        var journal = try load(); journal.drafts[conversation] = text.isEmpty ? nil : text; try save(journal)
    }
    func drafts() throws -> [String: String] { try load().drafts }
    func delete() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }
    static func key(action: String, payload: Data) -> String {
        SHA256.hash(data: Data(action.utf8) + payload).map { String(format: "%02x", $0) }.joined()
    }
}
