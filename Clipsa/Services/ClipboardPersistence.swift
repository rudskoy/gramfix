import Foundation
import os.log

private let logger = Logger(subsystem: "com.clipsa.app", category: "ClipboardPersistence")

/// Wrapper for persisted clipboard history with version for future migrations
struct PersistedClipboardHistory: Codable {
    /// Schema version for migration support
    let version: Int
    /// The clipboard items
    let items: [ClipboardItem]
    
    static let currentVersion = 1
    
    init(items: [ClipboardItem]) {
        self.version = Self.currentVersion
        self.items = items
    }
}

/// Service for persisting clipboard history to Application Support
actor ClipboardPersistence {
    static let shared = ClipboardPersistence()
    
    /// Storage directory: ~/Library/Application Support/Clipsa/
    private var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Clipsa", isDirectory: true)
    }
    
    /// Full path to the history file
    private var historyFileURL: URL {
        storageDirectory.appendingPathComponent("clipboard_history.json")
    }
    
    private init() {}
    
    // MARK: - Public API
    
    /// Save clipboard items to disk atomically
    func save(_ items: [ClipboardItem]) async throws {
        // Ensure directory exists
        try ensureStorageDirectoryExists()
        
        let history = PersistedClipboardHistory(items: items)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(history)
        
        // Atomic write for crash safety
        try data.write(to: historyFileURL, options: .atomic)
        
        logger.info("💾 Saved \(items.count) clipboard items to disk")
    }
    
    /// Load clipboard items from disk
    func load() async throws -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            logger.info("📂 No existing clipboard history found")
            return []
        }
        
        let data = try Data(contentsOf: historyFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let history = try decoder.decode(PersistedClipboardHistory.self, from: data)
        
        // Handle version migrations if needed
        let items = migrateIfNeeded(history)
        
        logger.info("📂 Loaded \(items.count) clipboard items from disk (version \(history.version))")
        return items
    }
    
    /// Check if history file exists
    func historyExists() -> Bool {
        FileManager.default.fileExists(atPath: historyFileURL.path)
    }
    
    /// Delete all persisted history
    func clearHistory() throws {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else { return }
        try FileManager.default.removeItem(at: historyFileURL)
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
        // Currently at version 1, no migrations needed
        // Future migrations would go here:
        // if history.version < 2 { ... migrate to v2 ... }
        return history.items
    }
}

