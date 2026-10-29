import Foundation
import Security
import Supabase

struct BackendKeychain: AuthLocalStorage {
    private let service = "im.seex.sao2-neiku-30.supabase.yepycfnkkfrfmuwdekka"

    private func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: key]
    }

    func verifyAvailable() throws {
        let key = "availability-" + UUID().uuidString
        let probe = Data(UUID().uuidString.utf8)
        defer { try? remove(key: key) }
        try store(key: key, value: probe)
        guard try retrieve(key: key) == probe else { throw KeychainFailure(status: errSecInternalError) }
    }

    func store(key: String, value: Data) throws {
        let attributes: [String: Any] = [kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let updated = SecItemUpdate(query(key) as CFDictionary, attributes as CFDictionary)
        if updated == errSecItemNotFound {
            let status = SecItemAdd(query(key).merging(attributes) { _, new in new } as CFDictionary, nil)
            guard status == errSecSuccess else { throw KeychainFailure(status: status) }
        } else if updated != errSecSuccess { throw KeychainFailure(status: updated) }
    }

    func retrieve(key: String) throws -> Data? {
        var request = query(key)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainFailure(status: status)
        }
        return data
    }

    func remove(key: String) throws {
        let status = SecItemDelete(query(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainFailure(status: status)
        }
    }

    private struct KeychainFailure: LocalizedError {
        let status: OSStatus
        var errorDescription: String? { "Secure account storage is unavailable. Please try again." }
    }
}
