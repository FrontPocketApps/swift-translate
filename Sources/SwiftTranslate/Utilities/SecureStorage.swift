import Foundation
import Security

struct SecureStorage {

    // MARK: Properties

    private let keychainService = "SwiftTranslate.SecureStorage"

    // MARK: Actions

    func retrieveValue<T: Codable>(type: T.Type, for key: String) -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if
            status == errSecSuccess,
            let data = item as? Data,
            let result = try? JSONDecoder().decode(T.self, from: data) {
            return result
        }
        return nil
    }

    func storeValue(_ value: some Codable, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else {
            Log.error(newline: .after, "Unable to store value for \(key)")
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecSuccess {
            Log.success(newline: .after, "Value stored successfully for \(key)")
        } else {
            Log.error(newline: .after, "Error attempting to store value for \(key)")
        }
    }

    func deleteValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            Log.success(newline: .after, "Value deleted for \(key)")
        } else {
            Log.error(newline: .after, "Error attempting to delete value for \(key)")
        }
    }
}
