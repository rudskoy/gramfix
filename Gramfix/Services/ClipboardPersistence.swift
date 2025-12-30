import Foundation
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
        
        let jsonData: Data
        do {
            jsonData = try await ClipboardEncryption.shared.decrypt(encryptedData)
        } catch {
            // If decryption fails (wrong key, corrupted data, etc.), log and return empty
            logger.error("❌ Failed to decrypt clipboard history: \(error.localizedDescription). The file may be corrupted or encrypted with a different key. Starting with empty history.")
            // Don't automatically delete - user might want to recover it
            // The file will be overwritten on next save with the correct key
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
}

