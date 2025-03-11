import Foundation
import Security

struct KeychainManager {
    
    static let serviceName = "com.tickscope.api" // Unique identifier for your app
    static let apiKeyKey = "PolygonAPIKey" // Key under which the API key is stored

    // Save API Key to Keychain
    static func saveAPIKey(_ apiKey: String) {
        let data = apiKey.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: apiKeyKey,
            kSecValueData as String: data
        ]
        
        // Delete existing key (if any) to avoid duplicates
        SecItemDelete(query as CFDictionary)
        
        // Add new key to Keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            print("✅ API Key saved successfully.")
        } else {
            print("❌ Failed to save API Key: \(status)")
        }
    }

    // Retrieve API Key from Keychain
    static func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: apiKeyKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        } else {
            print("⚠️ No API Key found in Keychain.")
            return nil
        }
    }

    // Delete API Key from Keychain (if needed)
    static func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: apiKeyKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            print("✅ API Key deleted successfully.")
        } else {
            print("⚠️ Failed to delete API Key: \(status)")
        }
    }
}
