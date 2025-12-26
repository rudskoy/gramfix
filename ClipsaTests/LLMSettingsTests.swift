import XCTest
@testable import Clipsa

/// Tests for LLMSettings
final class LLMSettingsTests: XCTestCase {
    
    private var originalAutoProcess: Bool!
    
    override func setUp() {
        super.setUp()
        // Save original values
        originalAutoProcess = LLMSettings.shared.autoProcess
    }
    
    override func tearDown() {
        // Restore original values
        LLMSettings.shared.autoProcess = originalAutoProcess
        super.tearDown()
    }
    
    // MARK: - Auto Process Tests
    
    func testAutoProcessCanBeToggled() {
        let settings = LLMSettings.shared
        
        settings.autoProcess = true
        XCTAssertTrue(settings.autoProcess)
        
        settings.autoProcess = false
        XCTAssertFalse(settings.autoProcess)
    }
    
    func testAutoProcessPersistence() {
        let settings = LLMSettings.shared
        
        settings.autoProcess = false
        XCTAssertFalse(settings.autoProcess)
        
        settings.autoProcess = true
        XCTAssertTrue(settings.autoProcess)
    }
    
    // MARK: - Singleton Tests
    
    func testSharedInstanceIsSingleton() {
        let instance1 = LLMSettings.shared
        let instance2 = LLMSettings.shared
        
        XCTAssertTrue(instance1 === instance2, "Should be the same instance")
    }
    
    // MARK: - TextPromptType Tests
    
    func testTextPromptTypeAllCases() {
        let allCases = TextPromptType.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.grammar))
        XCTAssertTrue(allCases.contains(.formal))
        XCTAssertTrue(allCases.contains(.casual))
        XCTAssertTrue(allCases.contains(.polished))
    }
    
    func testTextPromptTypeDisplayNames() {
        XCTAssertEqual(TextPromptType.grammar.displayName, "Grammar")
        XCTAssertEqual(TextPromptType.formal.displayName, "Corporate BS")
        XCTAssertEqual(TextPromptType.casual.displayName, "Reddit-like")
        XCTAssertEqual(TextPromptType.polished.displayName, "No Corporate BS")
    }
    
    func testTextPromptTypeRawValues() {
        XCTAssertEqual(TextPromptType.grammar.rawValue, "grammar")
        XCTAssertEqual(TextPromptType.formal.rawValue, "formal")
        XCTAssertEqual(TextPromptType.casual.rawValue, "casual")
        XCTAssertEqual(TextPromptType.polished.rawValue, "polished")
    }
    
    func testTextPromptTypeBuildPrompt() {
        let testText = "Hello world"
        
        let grammarPrompt = TextPromptType.grammar.buildPrompt(for: testText)
        XCTAssertTrue(grammarPrompt.contains(testText))
        XCTAssertTrue(grammarPrompt.contains("Fix grammar"))
        
        let formalPrompt = TextPromptType.formal.buildPrompt(for: testText)
        XCTAssertTrue(formalPrompt.contains(testText))
        XCTAssertTrue(formalPrompt.contains("corporate"))
        
        let casualPrompt = TextPromptType.casual.buildPrompt(for: testText)
        XCTAssertTrue(casualPrompt.contains(testText))
        XCTAssertTrue(casualPrompt.contains("Reddit"))
        
        let polishedPrompt = TextPromptType.polished.buildPrompt(for: testText)
        XCTAssertTrue(polishedPrompt.contains(testText))
        XCTAssertTrue(polishedPrompt.contains("corporate"))
    }
    
    func testTextPromptTypeId() {
        // Test Identifiable conformance
        XCTAssertEqual(TextPromptType.grammar.id, "grammar")
        XCTAssertEqual(TextPromptType.formal.id, "formal")
        XCTAssertEqual(TextPromptType.casual.id, "casual")
        XCTAssertEqual(TextPromptType.polished.id, "polished")
    }
    
    func testTextPromptTypeCodable() throws {
        // Test encoding
        let encoder = JSONEncoder()
        let grammarData = try encoder.encode(TextPromptType.grammar)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TextPromptType.self, from: grammarData)
        
        XCTAssertEqual(decoded, TextPromptType.grammar)
    }
}
