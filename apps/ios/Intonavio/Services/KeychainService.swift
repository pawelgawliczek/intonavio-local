import Foundation
import Security

enum KeychainService {
    private static let service = "com.intonaviolocal.apikeys"
    private static let stemSplitKey = "stemsplit_api_key"

    static func getStemSplitAPIKey() -> String? {
        getData(account: stemSplitKey)
    }

    static func setStemSplitAPIKey(_ key: String) {
        setData(key, account: stemSplitKey)
    }

    static func deleteStemSplitAPIKey() {
        deleteData(account: stemSplitKey)
    }

    static var hasStemSplitAPIKey: Bool {
        getStemSplitAPIKey() != nil
    }
}

// MARK: - Private

private extension KeychainService {
    static func getData(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    static func setData(_ value: String, account: String) {
        deleteData(account: account)
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func deleteData(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
