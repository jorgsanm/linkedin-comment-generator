import Foundation
import Security

public final class KeychainService {
    private let service = "LinkedInCommentAssistant"
    private let account = "openai-api-key"

    public init() {}

    public func saveAPIKey(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        SecItemDelete(baseQuery as CFDictionary)

        let status = SecItemAdd(
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecValueData: data
            ] as CFDictionary,
            nil
        )

        guard status == errSecSuccess else {
            throw AppError.unsupportedEnvironment("The API key could not be saved to Keychain.")
        }
    }

    public func loadAPIKey() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    public func deleteAPIKey() {
        SecItemDelete(
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account
            ] as CFDictionary
        )
    }
}
