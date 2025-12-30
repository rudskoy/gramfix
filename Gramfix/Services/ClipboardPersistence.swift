import Foundation
import CryptoKit
import os.log

private let logger = Logger(subsystem: "com.gramfix.app", category: "ClipboardPersistence")

/// Wrapper for persisted clipboard history with version for future migrations
struct PersistedClipboardHistory: Codable {
    /// Schema version for migration support
    let version: Int
    /// The clipboard items
    let items: [ClipboardItem]
    /// Paste history: maps content key to array of paste timestamps
    let pasteHistory: [String: [Date]]?
    
    static let currentVersion = 3
    
    init(items: [ClipboardItem], pasteHistory: [String: [Date]]? = nil) {
        self.version = Self.currentVersion
        self.items = items
        self.pasteHistory = pasteHistory
    }
}

/// Service for persisting clipboard history to Application Support
actor ClipboardPersistence {
    static let shared = ClipboardPersistence()
    
    /// Storage directory: ~/Library/Application Support/Gramfix/
    private var storageDirectory: URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to home directory if Application Support is unavailable (should never happen on macOS)
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            return homeDir.appendingPathComponent("Library/Application Support/Gramfix", isDirectory: true)
        }
        return appSupport.appendingPathComponent("Gramfix", isDirectory: true)
    }
    
    /// Full path to the encrypted history file
    private var encryptedHistoryFileURL: URL {
        storageDirectory.appendingPathComponent("clipboard_history.encrypted")
    }
    
    private init() {}
    
    // MARK: - Public API
    
    /// Save clipboard items and paste history to disk atomically (encrypted)
    func save(_ items: [ClipboardItem], pasteHistory: [String: [Date]]) async throws {
        // Ensure directory exists
        try ensureStorageDirectoryExists()
        
        let history = PersistedClipboardHistory(items: items, pasteHistory: pasteHistory)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData = try encoder.encode(history)
        
        // Encrypt the data
        let encryptedData = try await ClipboardEncryption.shared.encrypt(jsonData)
        
        // Write encrypted data atomically
        try encryptedData.write(to: encryptedHistoryFileURL, options: Data.WritingOptions.atomic)
        
        // Set restrictive file permissions (owner read/write only)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: encryptedHistoryFileURL.path
        )
        
        logger.info("💾 Saved \(items.count) clipboard items and \(pasteHistory.count) paste history entries to disk (encrypted)")
    }
    
    /// Load clipboard items and paste history from disk
    func load() async throws -> (items: [ClipboardItem], pasteHistory: [String: [Date]]) {
        guard FileManager.default.fileExists(atPath: encryptedHistoryFileURL.path) else {
            logger.info("📂 No existing clipboard history found")
            return ([], [:])
        }
        
        guard FileManager.default.isReadableFile(atPath: self.encryptedHistoryFileURL.path) else {
            logger.warning("⚠️ Encrypted history file exists but is not readable at \(self.encryptedHistoryFileURL.path)")
            return ([], [:])
        }
        
        let encryptedData = try Data(contentsOf: self.encryptedHistoryFileURL)
        
        // Validate encrypted data format before attempting decryption
        // AES-GCM sealed box requires at least 12 bytes (nonce) + 16 bytes (tag) = 28 bytes minimum
        guard encryptedData.count >= 28 else {
            logger.error("❌ Encrypted history file is too small (\(encryptedData.count) bytes). File may be corrupted. Starting with empty history.")
            // Backup corrupted file
            try? backupCorruptedFile(encryptedData)
            return ([], [:])
        }
        
        let jsonData: Data
        do {
            jsonData = try await ClipboardEncryption.shared.decrypt(encryptedData)
        } catch {
            // Handle decryption errors (CryptoKitError or other errors)
            // CryptoKitError error 3 = authenticationFailure (wrong key or corrupted data)
            // This typically happens when:
            // 1. The keychain key was deleted/reset (new key created)
            // 2. The file is corrupted
            // 3. The file was encrypted with a different key
            
            let errorMsg = error.localizedDescription
            let detailedMsg: String
            if errorMsg.contains("error 3") || errorMsg.contains("authentication") {
                detailedMsg = "Authentication failed - the encryption key may have changed (keychain reset) or the file is corrupted"
            } else {
                detailedMsg = errorMsg
            }
            
            logger.error("❌ Failed to decrypt clipboard history: \(detailedMsg). Starting with empty history.")
            // Backup corrupted file for potential recovery
            try? backupCorruptedFile(encryptedData)
            return ([], [:])
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let history = try decoder.decode(PersistedClipboardHistory.self, from: jsonData)
        let items = migrateIfNeeded(history)
        let pasteHistory = history.pasteHistory ?? [:]
        
        logger.info("📂 Loaded \(items.count) clipboard items and \(pasteHistory.count) paste history entries from encrypted storage (version \(history.version))")
        return (items, pasteHistory)
    }
    
    /// Check if history file exists
    func historyExists() -> Bool {
        FileManager.default.fileExists(atPath: encryptedHistoryFileURL.path)
    }
    
    /// Delete all persisted history
    func clearHistory() throws {
        guard FileManager.default.fileExists(atPath: encryptedHistoryFileURL.path) else { return }
        try FileManager.default.removeItem(at: encryptedHistoryFileURL)
        logger.info("🗑️ Cleared persisted clipboard history")
    }
    
    // MARK: - Private Helpers
    
    private func ensureStorageDirectoryExists() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: storageDirectory.path) {
            try fm.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            logger.info("📁 Created storage directory at \(self.storageDirectory.path)")
        }
    }
    
    /// Migrate data from older versions if needed
    private func migrateIfNeeded(_ history: PersistedClipboardHistory) -> [ClipboardItem] {
        // Version 1 -> 2: Added paste history (no item migration needed)
        // Version 2 -> 3: Added encryption (no item migration needed)
        if history.version < PersistedClipboardHistory.currentVersion {
            logger.info("📦 Migrating clipboard history from version \(history.version) to \(PersistedClipboardHistory.currentVersion)")
        }
        return history.items
    }
    
    /// Backup corrupted file with timestamp for potential recovery
    private func backupCorruptedFile(_ data: Data) throws {
        let backupURL = storageDirectory.appendingPathComponent("clipboard_history.encrypted.backup.\(Date().timeIntervalSince1970)")
        try data.write(to: backupURL, options: .atomic)
        logger.info("💾 Backed up corrupted file to \(backupURL.lastPathComponent)")
        
        // Keep only the 5 most recent backups to avoid disk space issues
        let fm = FileManager.default
        let backupFiles = try? fm.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: [.creationDateKey])
            .filter { $0.lastPathComponent.hasPrefix("clipboard_history.encrypted.backup.") }
            .sorted { ($0.path < $1.path) }
        
        if let backups = backupFiles, backups.count > 5 {
            for oldBackup in backups.dropLast(5) {
                try? fm.removeItem(at: oldBackup)
                logger.info("🗑️ Removed old backup: \(oldBackup.lastPathComponent)")
            }
        }
    }
}

