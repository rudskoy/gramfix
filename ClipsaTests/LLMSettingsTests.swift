import XCTest
@testable import Clipsa

/// Tests for LLMSettings
final class LLMSettingsTests: XCTestCase {
    
    private var originalPrompt: String!
    private var originalAutoProcess: Bool!
    
    override func setUp() {
        super.setUp()
        // Save original values
        originalPrompt = LLMSettings.shared.customPrompt
        originalAutoProcess = LLMSettings.shared.autoProcess
    }
    
    override func tearDown() {
        // Restore original values
        LLMSettings.shared.customPrompt = originalPrompt
        LLMSettings.shared.autoProcess = originalAutoProcess
        super.tearDown()
    }
    
    // MARK: - Build Prompt Tests
    
    func testBuildPromptReplacesPlaceholder() {
        let settings = LLMSettings.shared
        settings.customPrompt = "Process this: {text}"
        
        let result = settings.buildPrompt(for: "Hello World")
        
        XCTAssertEqual(result, "Process this: Hello World")
    }
    
    func testBuildPromptWithNoPlaceholder() {
        let settings = LLMSettings.shared
        settings.customPrompt = "Static prompt without placeholder"
        
        let result = settings.buildPrompt(for: "Any text")
        
        XCTAssertEqual(result, "Static prompt without placeholder")
    }
    
    func testBuildPromptWithMultiplePlaceholders() {
        let settings = LLMSettings.shared
        settings.customPrompt = "First: {text}, Second: {text}"
        
        let result = settings.buildPrompt(for: "Test")
        
        XCTAssertEqual(result, "First: Test, Second: Test")
    }
    
    func testBuildPromptWithEmptyText() {
        let settings = LLMSettings.shared
        settings.customPrompt = "Text: {text}"
        
        let result = settings.buildPrompt(for: "")
        
        XCTAssertEqual(result, "Text: ")
    }
    
    func testBuildPromptWithMultilineText() {
        let settings = LLMSettings.shared
        settings.customPrompt = "Content:\n{text}"
        
        let multilineText = """
        Line 1
        Line 2
        Line 3
        """
        
        let result = settings.buildPrompt(for: multilineText)
        
        XCTAssertTrue(result.contains("Line 1"))
        XCTAssertTrue(result.contains("Line 2"))
        XCTAssertTrue(result.contains("Line 3"))
    }
    
    func testBuildPromptWithSpecialCharacters() {
        let settings = LLMSettings.shared
        settings.customPrompt = "Process: {text}"
        
        let textWithSpecialChars = "Hello $100 & @user <tag> \"quotes\""
        
        let result = settings.buildPrompt(for: textWithSpecialChars)
        
        XCTAssertEqual(result, "Process: \(textWithSpecialChars)")
    }
    
    // MARK: - Reset Tests
    
    func testResetToDefault() {
        let settings = LLMSettings.shared
        
        // Change from default
        settings.customPrompt = "Custom prompt"
        XCTAssertNotEqual(settings.customPrompt, LLMSettings.defaultPrompt)
        
        // Reset
        settings.resetToDefault()
        
        XCTAssertEqual(settings.customPrompt, LLMSettings.defaultPrompt)
    }
    
    // MARK: - Default Prompt Tests
    
    func testDefaultPromptContainsPlaceholder() {
        XCTAssertTrue(LLMSettings.defaultPrompt.contains("{text}"))
    }
    
    func testDefaultPromptNotEmpty() {
        XCTAssertFalse(LLMSettings.defaultPrompt.isEmpty)
    }
    
    // MARK: - Auto Process Tests
    
    func testAutoProcessCanBeToggled() {
        let settings = LLMSettings.shared
        
        settings.autoProcess = true
        XCTAssertTrue(settings.autoProcess)
        
        settings.autoProcess = false
        XCTAssertFalse(settings.autoProcess)
    }
    
    // MARK: - Persistence Tests
    
    func testCustomPromptPersistence() {
        let settings = LLMSettings.shared
        let customPrompt = "Test prompt for persistence: {text}"
        
        settings.customPrompt = customPrompt
        
        // Value should be stored
        XCTAssertEqual(settings.customPrompt, customPrompt)
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
}
