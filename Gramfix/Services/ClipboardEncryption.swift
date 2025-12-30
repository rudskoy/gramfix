import Foundation
import CryptoKit
import Security
import os.log

private let logger = Logger(subsystem: "com.gramfix.app", category: "ClipboardEncryption")

enum EncryptionError: LocalizedError {
    case keychainError(OSStatus)
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        }
    }
}

actor ClipboardEncryption {
    static let shared = ClipboardEncryption()
    
    private let keychainService = "com.gramfix.app.clipboard-encryption"
    private let keychainAccount = "encryption-key"
    
    private init() {}
    
    // MARK: - Key Management
    
    private func getOrCreateEncryptionKey() throws -> SymmetricKey {
        if let existingKey = try loadKeyFromKeychain() {
            return existingKey
        }
        
        let newKey = SymmetricKey(size: .bits256)
        try saveKeyToKeychain(newKey)
        return newKey
    }
    
    private func loadKeyFromKeychain() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data else {
            if status == errSecItemNotFound {
                return nil
            }
            throw EncryptionError.keychainError(status)
        }
        
        return SymmetricKey(data: keyData)
    }
    
    private func saveKeyToKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: keychainAccount
            ]
            
            let updateAttributes: [String: Any] = [
                kSecValueData as String: keyData
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw EncryptionError.keychainError(updateStatus)
            }
        } else if status != errSecSuccess {
            throw EncryptionError.keychainError(status)
        }
    }
    
    // MARK: - Encryption/Decryption
    
    func encrypt(_ data: Data) async throws -> Data {
        let key = try getOrCreateEncryptionKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        guard let encryptedData = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return encryptedData
    }
    
    func decrypt(_ encryptedData: Data) async throws -> Data {
        let key = try getOrCreateEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
}

