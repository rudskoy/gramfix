import XCTest
@testable import Gramfix

/// Tests for ClipboardPersistence to verify correct retrieval from Application Support directory
@MainActor
final class ClipboardPersistenceTests: XCTestCase {
    
    private var persistence: ClipboardPersistence!
    private var testDirectory: URL!
    private var originalStorageDirectory: URL?
    
    override func setUp() async throws {
        try await super.setUp()
        persistence = ClipboardPersistence.shared
        
        // Create a temporary test directory
        let tempDir = FileManager.default.temporaryDirectory
        testDirectory = tempDir.appendingPathComponent("GramfixTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        // Clean up test directory
        if let testDir = testDirectory, FileManager.default.fileExists(atPath: testDir.path) {
            try? FileManager.default.removeItem(at: testDir)
        }
        try await super.tearDown()
    }
    
    // MARK: - Storage Directory Tests
    
    func testStorageDirectoryPath() async {
        // Verify that the storage directory uses Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let expectedPath = appSupport.appendingPathComponent("Gramfix", isDirectory: true)
        
        // We can't directly access the private storageDirectory property,
        // but we can verify by checking if save/load works correctly
        let testItems = [
            ClipboardItem(content: "Test content", type: .text, appName: "TestApp")
        ]
        
        do {
            try await persistence.save(testItems, pasteHistory: [:])
            let result = try await persistence.load()
            
            XCTAssertEqual(result.items.count, 1, "Should load saved items")
            XCTAssertEqual(result.items.first?.content, "Test content", "Content should match")
            
            // Verify the encrypted file exists in the expected location
            let encryptedHistoryFile = expectedPath.appendingPathComponent("clipboard_history.encrypted")
            XCTAssertTrue(FileManager.default.fileExists(atPath: encryptedHistoryFile.path), 
                         "Encrypted history file should exist at expected path")
            
            // Clean up
            try? persistence.clearHistory()
        } catch {
            XCTFail("Save/load should not fail: \(error.localizedDescription)")
        }
    }
    
    func testLoadFromNonExistentFile() async {
        // Clear any existing history first
        try? persistence.clearHistory()
        
        // Loading from non-existent file should return empty arrays, not throw
        do {
            let result = try await persistence.load()
            XCTAssertEqual(result.items.count, 0, "Should return empty array when file doesn't exist")
            XCTAssertEqual(result.pasteHistory.count, 0, "Should return empty paste history when file doesn't exist")
        } catch {
            XCTFail("Loading from non-existent file should not throw: \(error.localizedDescription)")
        }
    }
    
    func testLoadFromNonExistentDirectory() async {
        // This test verifies that load() handles the case where
        // the Application Support directory might not exist yet
        // (though this is unlikely on macOS)
        
        // Clear history first
        try? persistence.clearHistory()
        
        // Load should work even if directory doesn't exist (it will just return empty)
        do {
            let result = try await persistence.load()
            XCTAssertEqual(result.items.count, 0, "Should return empty array when directory doesn't exist")
        } catch {
            XCTFail("Loading when directory doesn't exist should not throw: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save and Load Tests
    
    func testSaveAndLoadItems() async {
        let testItems = [
            ClipboardItem(content: "Item 1", type: .text, appName: "App1"),
            ClipboardItem(content: "Item 2", type: .link, appName: "App2"),
            ClipboardItem(content: "Item 3", type: .text, appName: "App3")
        ]
        
        do {
            // Save items
            try await persistence.save(testItems, pasteHistory: [:])
            
            // Load items
            let result = try await persistence.load()
            let loadedItems = result.items
            
            XCTAssertEqual(loadedItems.count, testItems.count, "Should load all saved items")
            XCTAssertEqual(loadedItems[0].content, "Item 1", "First item content should match")
            XCTAssertEqual(loadedItems[1].content, "Item 2", "Second item content should match")
            XCTAssertEqual(loadedItems[2].content, "Item 3", "Third item content should match")
            
            // Verify types
            XCTAssertEqual(loadedItems[0].type, .text, "First item type should match")
            XCTAssertEqual(loadedItems[1].type, .link, "Second item type should match")
            
            // Clean up
            try? persistence.clearHistory()
        } catch {
            XCTFail("Save/load should not fail: \(error.localizedDescription)")
        }
    }
    
    func testHistoryExists() {
        // Initially should not exist
        let initiallyExists = persistence.historyExists()
        
        // Save some items
        Task {
            let testItems = [ClipboardItem(content: "Test", type: .text, appName: "Test")]
            try? await persistence.save(testItems, pasteHistory: [:])
            
            // Now should exist
            let afterSave = persistence.historyExists()
            XCTAssertTrue(afterSave, "History should exist after save")
            
            // Clean up
            try? persistence.clearHistory()
        }
        
        // Give it a moment for async save
        let expectation = XCTestExpectation(description: "Save completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testClearHistory() async {
        // Save some items first
        let testItems = [ClipboardItem(content: "Test", type: .text, appName: "Test")]
        try? await persistence.save(testItems, pasteHistory: [:])
        
        // Verify it exists
        XCTAssertTrue(persistence.historyExists(), "History should exist before clear")
        
        // Clear history
        do {
            try persistence.clearHistory()
            XCTAssertFalse(persistence.historyExists(), "History should not exist after clear")
            
            // Loading should return empty
            let result = try await persistence.load()
            XCTAssertEqual(result.items.count, 0, "Should return empty array after clear")
        } catch {
            XCTFail("Clear history should not fail: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Version Migration Tests
    
    func testVersionHandling() async {
        // This test verifies that the version field is correctly saved and loaded
        let testItems = [
            ClipboardItem(content: "Test", type: .text, appName: "Test")
        ]
        
        do {
            try await persistence.save(testItems, pasteHistory: [:])
            
            // Read the encrypted file and decrypt to verify version
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let encryptedHistoryFile = appSupport.appendingPathComponent("Gramfix/clipboard_history.encrypted")
            
            let encryptedData = try Data(contentsOf: encryptedHistoryFile)
            let jsonData = try await ClipboardEncryption.shared.decrypt(encryptedData)
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            XCTAssertNotNil(json, "Should be valid JSON after decryption")
            XCTAssertEqual(json?["version"] as? Int, 3, "Version should be 3")
            XCTAssertNotNil(json?["items"], "Should have items array")
            
            // Clean up
            try? persistence.clearHistory()
        } catch {
            XCTFail("Version handling should not fail: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Encryption Tests
    
    func testEncryptionRoundTrip() async {
        // Test that encryption and decryption work correctly
        let testItems = [
            ClipboardItem(content: "Encrypted test", type: .text, appName: "TestApp")
        ]
        let testPasteHistory: [String: [Date]] = ["test-key": [Date()]]
        
        do {
            // Save encrypted
            try await persistence.save(testItems, pasteHistory: testPasteHistory)
            
            // Load and verify
            let result = try await persistence.load()
            XCTAssertEqual(result.items.count, 1, "Should load encrypted items")
            XCTAssertEqual(result.items.first?.content, "Encrypted test", "Content should match after encryption/decryption")
            XCTAssertEqual(result.pasteHistory.count, 1, "Should load encrypted paste history")
            XCTAssertNotNil(result.pasteHistory["test-key"], "Paste history should be preserved")
            
            // Clean up
            try? persistence.clearHistory()
        } catch {
            XCTFail("Encryption round-trip should not fail: \(error.localizedDescription)")
        }
    }
    
}

