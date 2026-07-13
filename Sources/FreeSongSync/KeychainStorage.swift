import Foundation
import Security

// MARK: - Keychain Wrapper

/// Secure storage for sensitive values (Personal Access Tokens).
///
/// Uses the system Keychain via the Security framework.
/// Data is accessible after first device unlock so background sync works,
/// but not before the user has unlocked the device at least once.
public enum KeychainStorage {

    private static let service = "com.freesong.sync"
    private static let account = "codeberg-pat"

    // MARK: Public API

    /// Store a token string in the Keychain.
    /// - Parameter token: The Personal Access Token to store.
    /// - Throws: `KeychainError` if encoding or store fails.
    public static func store(token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Remove any existing item first (upsert semantics).
        deleteMatching()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    /// Retrieve the stored token from the Keychain.
    /// - Returns: The token string, or `nil` if no token has been stored.
    /// - Throws: `KeychainError` if retrieval or decoding fails.
    public static func retrieve() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.retrieveFailed(status)
        }

        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }

        return token
    }

    /// Delete the stored token from the Keychain.
    /// - Throws: `KeychainError` if deletion fails.
    public static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Whether a token is currently stored.
    public static var hasToken: Bool {
        (try? retrieve()) != nil
    }

    // MARK: Private Helpers

    private static func deleteMatching() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

/// Errors that can occur during Keychain operations.
public enum KeychainError: Error, LocalizedError {
    case encodingFailed
    case decodingFailed
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode token data"
        case .decodingFailed:
            return "Failed to decode token data"
        case .storeFailed(let status):
            return "Failed to store in keychain (OSStatus: \(status))"
        case .retrieveFailed(let status):
            return "Failed to retrieve from keychain (OSStatus: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from keychain (OSStatus: \(status))"
        }
    }
}
