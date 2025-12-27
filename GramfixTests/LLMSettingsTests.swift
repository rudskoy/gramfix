import XCTest
@testable import Gramfix

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
    
    // MARK: - SupportedLanguage Tests
    
    func testSupportedLanguageAllCases() {
        let allCases = SupportedLanguage.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.english))
        XCTAssertTrue(allCases.contains(.russian))
        XCTAssertTrue(allCases.contains(.japanese))
        XCTAssertTrue(allCases.contains(.dutch))
        XCTAssertTrue(allCases.contains(.korean))
    }
    
    func testSupportedLanguageFlags() {
        XCTAssertEqual(SupportedLanguage.english.flag, "\u{1F1EC}\u{1F1E7}")
        XCTAssertEqual(SupportedLanguage.russian.flag, "\u{1F1F7}\u{1F1FA}")
        XCTAssertEqual(SupportedLanguage.japanese.flag, "\u{1F1EF}\u{1F1F5}")
        XCTAssertEqual(SupportedLanguage.dutch.flag, "\u{1F1F3}\u{1F1F1}")
        XCTAssertEqual(SupportedLanguage.korean.flag, "\u{1F1F0}\u{1F1F7}")
    }
    
    func testSupportedLanguageDisplayNames() {
        XCTAssertEqual(SupportedLanguage.english.displayName, "English")
        XCTAssertEqual(SupportedLanguage.russian.displayName, "Russian")
        XCTAssertEqual(SupportedLanguage.japanese.displayName, "Japanese")
        XCTAssertEqual(SupportedLanguage.dutch.displayName, "Dutch")
        XCTAssertEqual(SupportedLanguage.korean.displayName, "Korean")
    }
    
    func testSupportedLanguageRawValues() {
        XCTAssertEqual(SupportedLanguage.english.rawValue, "en")
        XCTAssertEqual(SupportedLanguage.russian.rawValue, "ru")
        XCTAssertEqual(SupportedLanguage.japanese.rawValue, "ja")
        XCTAssertEqual(SupportedLanguage.dutch.rawValue, "nl")
        XCTAssertEqual(SupportedLanguage.korean.rawValue, "ko")
    }
    
    func testSupportedLanguageFromCode() {
        XCTAssertEqual(SupportedLanguage.from(code: "en"), .english)
        XCTAssertEqual(SupportedLanguage.from(code: "ru"), .russian)
        XCTAssertEqual(SupportedLanguage.from(code: "ja"), .japanese)
        XCTAssertEqual(SupportedLanguage.from(code: "nl"), .dutch)
        XCTAssertEqual(SupportedLanguage.from(code: "ko"), .korean)
        XCTAssertEqual(SupportedLanguage.from(code: "EN"), .english) // Case insensitive
        XCTAssertEqual(SupportedLanguage.from(code: "  en  "), .english) // Trims whitespace
        XCTAssertNil(SupportedLanguage.from(code: "fr")) // Unsupported
        XCTAssertNil(SupportedLanguage.from(code: "")) // Empty
    }
    
    func testSupportedLanguageOrderedList() {
        // With detected language
        let orderedWithEnglish = SupportedLanguage.orderedList(detectedLanguage: .english)
        XCTAssertEqual(orderedWithEnglish.first, .english)
        XCTAssertEqual(orderedWithEnglish.count, 5)
        XCTAssertFalse(orderedWithEnglish.dropFirst().contains(.english)) // English only appears once
        
        let orderedWithRussian = SupportedLanguage.orderedList(detectedLanguage: .russian)
        XCTAssertEqual(orderedWithRussian.first, .russian)
        XCTAssertEqual(orderedWithRussian.count, 5)
        
        // Without detected language
        let orderedWithNil = SupportedLanguage.orderedList(detectedLanguage: nil)
        XCTAssertEqual(orderedWithNil, SupportedLanguage.allCases)
    }
    
    func testSupportedLanguageDetectionPrompt() {
        let prompt = SupportedLanguage.detectionPrompt
        XCTAssertTrue(prompt.contains("{text}"))
        XCTAssertTrue(prompt.contains("en"))
        XCTAssertTrue(prompt.contains("ru"))
        XCTAssertTrue(prompt.contains("ja"))
        XCTAssertTrue(prompt.contains("nl"))
        XCTAssertTrue(prompt.contains("ko"))
    }
    
    func testSupportedLanguageTranslationPrompt() {
        let prompt = SupportedLanguage.translationPrompt(to: .russian)
        XCTAssertTrue(prompt.contains("{text}"))
        XCTAssertTrue(prompt.contains("Russian"))
    }
    
    func testSupportedLanguageCodable() throws {
        // Test encoding
        let encoder = JSONEncoder()
        let englishData = try encoder.encode(SupportedLanguage.english)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SupportedLanguage.self, from: englishData)
        
        XCTAssertEqual(decoded, SupportedLanguage.english)
    }
}
