//
//  LLMProviderImplTests.swift
//  ClipsaTests
//
//  Unit tests for LLMProviderImpl using MockTextGenerationClient.
//  Tests all prompt-building and response-parsing logic.
//

import XCTest
@testable import Clipsa

// MARK: - Mock TextGenerationClient

/// Mock implementation of TextGenerationClient for testing
final class MockTextGenerationClient: TextGenerationClient, @unchecked Sendable {
    let name: String = "MockClient"
    
    /// The result to return from generate()
    var generateResult: String = ""
    
    /// Error to throw from generate() (if set)
    var generateError: Error?
    
    /// Count of generate() calls
    var generateCallCount = 0
    
    /// Last prompt passed to generate()
    var lastPrompt: String?
    
    /// Last system prompt passed to generate()
    var lastSystemPrompt: String?
    
    /// Whether the client should report as available
    var isAvailableResult: Bool = true
    
    func isAvailable() async -> Bool {
        return isAvailableResult
    }
    
    func generate(prompt: String, systemPrompt: String?) async throws -> String {
        generateCallCount += 1
        lastPrompt = prompt
        lastSystemPrompt = systemPrompt
        
        if let error = generateError {
            throw error
        }
        return generateResult
    }
    
    /// Reset all recorded state
    func reset() {
        generateResult = ""
        generateError = nil
        generateCallCount = 0
        lastPrompt = nil
        lastSystemPrompt = nil
        isAvailableResult = true
    }
}

// MARK: - LLMProviderImpl Tests

/// Unit tests for LLMProviderImpl
/// Uses MockTextGenerationClient to test prompt building and response parsing
final class LLMProviderImplTests: XCTestCase {
    
    private var mockClient: MockTextGenerationClient!
    private var provider: LLMProviderImpl!
    
    override func setUp() async throws {
        try await super.setUp()
        mockClient = MockTextGenerationClient()
        provider = LLMProviderImpl(client: mockClient)
    }
    
    override func tearDown() async throws {
        provider = nil
        mockClient = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Provider Tests
    
    func testProviderNameFromClient() async throws {
        XCTAssertEqual(provider.name, "MockClient")
    }
    
    func testIsAvailableDelegatesToClient() async throws {
        mockClient.isAvailableResult = true
        let available = await provider.isAvailable()
        XCTAssertTrue(available)
        
        mockClient.isAvailableResult = false
        let notAvailable = await provider.isAvailable()
        XCTAssertFalse(notAvailable)
    }
    
    // MARK: - Process Summarize Tests
    
    func testProcessSummarize() async throws {
        // Given
        mockClient.generateResult = "This is a test summary."
        let testText = "Swift is a powerful programming language."
        
        // When
        let result = try await provider.process(testText, requestType: .summarize)
        
        // Then
        XCTAssertEqual(result.response, "This is a test summary.")
        XCTAssertEqual(result.summary, "This is a test summary.")
        XCTAssertTrue(result.tags.isEmpty)
        XCTAssertNil(result.contentType)
        XCTAssertNil(result.error)
        XCTAssertEqual(mockClient.generateCallCount, 1)
        XCTAssertTrue(mockClient.lastPrompt?.contains("Summarize") ?? false)
        XCTAssertTrue(mockClient.lastPrompt?.contains(testText) ?? false)
    }
    
    // MARK: - Process Extract Tags Tests
    
    func testProcessExtractTags() async throws {
        // Given
        mockClient.generateResult = "Python, machine learning, data science"
        let testText = "Python is used for machine learning and data science."
        
        // When
        let result = try await provider.process(testText, requestType: .extractTags)
        
        // Then
        XCTAssertEqual(result.response, "Python, machine learning, data science")
        XCTAssertEqual(result.tags, ["Python", "machine learning", "data science"])
        XCTAssertNil(result.summary)
        XCTAssertNil(result.contentType)
        XCTAssertNil(result.error)
        XCTAssertTrue(mockClient.lastPrompt?.contains("Extract") ?? false)
    }
    
    func testProcessExtractTagsSingleTag() async throws {
        // Given
        mockClient.generateResult = "Swift"
        
        // When
        let result = try await provider.process("Swift code", requestType: .extractTags)
        
        // Then
        XCTAssertEqual(result.tags, ["Swift"])
    }
    
    func testProcessExtractTagsWithWhitespace() async throws {
        // Given
        mockClient.generateResult = "  tag1  ,  tag2  ,  tag3  "
        
        // When
        let result = try await provider.process("test", requestType: .extractTags)
        
        // Then
        XCTAssertEqual(result.tags, ["tag1", "tag2", "tag3"])
    }
    
    func testProcessExtractTagsLimitedToFive() async throws {
        // Given - model returns more than 5 tags
        mockClient.generateResult = "tag1, tag2, tag3, tag4, tag5, tag6, tag7, tag8"
        
        // When
        let result = try await provider.process("test", requestType: .extractTags)
        
        // Then - only first 5 tags are kept
        XCTAssertEqual(result.tags.count, 5)
        XCTAssertEqual(result.tags, ["tag1", "tag2", "tag3", "tag4", "tag5"])
    }
    
    // MARK: - Process Classify Tests
    
    func testProcessClassify() async throws {
        // Given
        mockClient.generateResult = "code"
        let codeText = "func hello() { print(\"Hello\") }"
        
        // When
        let result = try await provider.process(codeText, requestType: .classify)
        
        // Then
        XCTAssertEqual(result.response, "code")
        XCTAssertEqual(result.contentType, "code")
        XCTAssertNil(result.summary)
        XCTAssertTrue(result.tags.isEmpty)
        XCTAssertNil(result.error)
        XCTAssertTrue(mockClient.lastPrompt?.contains("Classify") ?? false)
    }
    
    func testProcessClassifyNormalizesCase() async throws {
        // Given
        mockClient.generateResult = "CODE"
        
        // When
        let result = try await provider.process("test", requestType: .classify)
        
        // Then
        XCTAssertEqual(result.contentType, "code")
    }
    
    // MARK: - Process All (JSON) Tests
    
    func testProcessAllValidJSON() async throws {
        // Given
        mockClient.generateResult = """
        {"summary": "Test summary", "tags": ["tag1", "tag2"], "type": "note"}
        """
        
        // When
        let result = try await provider.process("test text", requestType: .all)
        
        // Then
        XCTAssertEqual(result.summary, "Test summary")
        XCTAssertEqual(result.tags, ["tag1", "tag2"])
        XCTAssertEqual(result.contentType, "note")
        XCTAssertNil(result.error)
    }
    
    func testProcessAllJSONWithExtraText() async throws {
        // Given - LLM sometimes adds text around JSON
        mockClient.generateResult = """
        Here is the analysis:
        {"summary": "Brief summary", "tags": ["tag1"], "type": "code"}
        That's the result.
        """
        
        // When
        let result = try await provider.process("test", requestType: .all)
        
        // Then - Should extract JSON from surrounding text
        XCTAssertEqual(result.summary, "Brief summary")
        XCTAssertEqual(result.tags, ["tag1"])
        XCTAssertEqual(result.contentType, "code")
    }
    
    func testProcessAllInvalidJSONFallsBack() async throws {
        // Given - Invalid JSON
        mockClient.generateResult = "This is not valid JSON at all"
        
        // When
        let result = try await provider.process("test", requestType: .all)
        
        // Then - Falls back to using response as summary
        XCTAssertEqual(result.summary, "This is not valid JSON at all")
        XCTAssertTrue(result.tags.isEmpty)
        XCTAssertNil(result.contentType)
        XCTAssertNil(result.error)
    }
    
    func testProcessAllPartialJSON() async throws {
        // Given - Partial JSON fields
        mockClient.generateResult = """
        {"summary": "Only summary provided"}
        """
        
        // When
        let result = try await provider.process("test", requestType: .all)
        
        // Then
        XCTAssertEqual(result.summary, "Only summary provided")
        XCTAssertTrue(result.tags.isEmpty)
        XCTAssertNil(result.contentType)
    }
    
    // MARK: - Process Custom Tests
    
    func testProcessCustomCleansResponse() async throws {
        // Given
        mockClient.generateResult = "The quick brown fox jumps over the lazy dog."
        
        // When
        let result = try await provider.process("Text with isues", requestType: .custom)
        
        // Then
        XCTAssertEqual(result.response, "The quick brown fox jumps over the lazy dog.")
        XCTAssertNil(result.summary)
        XCTAssertTrue(result.tags.isEmpty)
    }
    
    func testProcessCustomSkipsPromptEchoes() async throws {
        // Given - LLM echoes parts of prompt
        mockClient.generateResult = """
        Here is the corrected text:
        This is the actual result.
        """
        
        // When
        let result = try await provider.process("test", requestType: .custom)
        
        // Then - Should skip the echo line
        XCTAssertEqual(result.response, "This is the actual result.")
    }
    
    func testProcessCustomRemovesMarkdown() async throws {
        // Given
        mockClient.generateResult = "**Bold text** and ```code block```"
        
        // When
        let result = try await provider.process("test", requestType: .custom)
        
        // Then
        XCTAssertEqual(result.response, "Bold text and code block")
    }
    
    // MARK: - Generate Tests
    
    func testGenerateWithoutContext() async throws {
        // Given
        mockClient.generateResult = "Hello in English, Bonjour in French, Hola in Spanish"
        
        // When
        let result = try await provider.generate(prompt: "Say hello in 3 languages", context: nil)
        
        // Then
        XCTAssertEqual(result, "Hello in English, Bonjour in French, Hola in Spanish")
        XCTAssertEqual(mockClient.lastPrompt, "Say hello in 3 languages")
        XCTAssertEqual(mockClient.generateCallCount, 1)
    }
    
    func testGenerateWithContext() async throws {
        // Given
        mockClient.generateResult = "The topic is AI"
        
        // When
        let result = try await provider.generate(
            prompt: "What is the topic?",
            context: "Artificial intelligence is transforming industries."
        )
        
        // Then
        XCTAssertEqual(result, "The topic is AI")
        XCTAssertTrue(mockClient.lastPrompt?.contains("Context:") ?? false)
        XCTAssertTrue(mockClient.lastPrompt?.contains("Artificial intelligence") ?? false)
        XCTAssertTrue(mockClient.lastPrompt?.contains("What is the topic?") ?? false)
    }
    
    // MARK: - Error Handling Tests
    
    func testProcessThrowsOnClientError() async throws {
        // Given
        mockClient.generateError = LLMError.networkError("Connection failed")
        
        // When/Then
        do {
            _ = try await provider.process("test", requestType: .summarize)
            XCTFail("Expected error to be thrown")
        } catch let error as LLMError {
            if case .networkError(let message) = error {
                XCTAssertEqual(message, "Connection failed")
            } else {
                XCTFail("Expected networkError")
            }
        }
    }
    
    func testGenerateThrowsOnClientError() async throws {
        // Given
        mockClient.generateError = LLMError.providerUnavailable
        
        // When/Then
        do {
            _ = try await provider.generate(prompt: "test", context: nil)
            XCTFail("Expected error to be thrown")
        } catch let error as LLMError {
            if case .providerUnavailable = error {
                // Expected
            } else {
                XCTFail("Expected providerUnavailable")
            }
        }
    }
    
    // MARK: - Prompt Building Tests (via mock inspection)
    
    func testSummarizePromptStructure() async throws {
        mockClient.generateResult = "summary"
        _ = try await provider.process("test text", requestType: .summarize)
        
        let prompt = mockClient.lastPrompt ?? ""
        XCTAssertTrue(prompt.contains("Summarize"))
        XCTAssertTrue(prompt.contains("one brief sentence"))
        XCTAssertTrue(prompt.contains("max 100 characters"))
        XCTAssertTrue(prompt.contains("test text"))
    }
    
    func testExtractTagsPromptStructure() async throws {
        mockClient.generateResult = "tags"
        _ = try await provider.process("test text", requestType: .extractTags)
        
        let prompt = mockClient.lastPrompt ?? ""
        XCTAssertTrue(prompt.contains("Extract"))
        XCTAssertTrue(prompt.contains("up to 5 relevant tags"))
        XCTAssertTrue(prompt.contains("comma-separated"))
    }
    
    func testClassifyPromptStructure() async throws {
        mockClient.generateResult = "code"
        _ = try await provider.process("test text", requestType: .classify)
        
        let prompt = mockClient.lastPrompt ?? ""
        XCTAssertTrue(prompt.contains("Classify"))
        XCTAssertTrue(prompt.contains("code, email, url, note"))
    }
    
    func testAllPromptStructure() async throws {
        mockClient.generateResult = "{}"
        _ = try await provider.process("test text", requestType: .all)
        
        let prompt = mockClient.lastPrompt ?? ""
        XCTAssertTrue(prompt.contains("JSON"))
        XCTAssertTrue(prompt.contains("summary"))
        XCTAssertTrue(prompt.contains("tags"))
        XCTAssertTrue(prompt.contains("type"))
    }
    
    func testSystemPromptIsSet() async throws {
        mockClient.generateResult = "result"
        _ = try await provider.process("test", requestType: .summarize)
        
        XCTAssertNotNil(mockClient.lastSystemPrompt)
        XCTAssertTrue(mockClient.lastSystemPrompt?.contains("helpful assistant") ?? false)
    }
    
    // MARK: - ProcessWithPromptType Tests (Multi-Prompt Feature)
    
    func testProcessWithPromptTypeGrammar() async throws {
        // Given
        mockClient.generateResult = "The quick brown fox jumps over the lazy dog."
        let testText = "The quik brown fox jump over lazy dog."
        
        // When
        let result = try await provider.processWithPromptType(testText, promptType: .grammar)
        
        // Then
        XCTAssertEqual(result, "The quick brown fox jumps over the lazy dog.")
        XCTAssertEqual(mockClient.generateCallCount, 1)
        XCTAssertTrue(mockClient.lastPrompt?.contains("Fix grammar") ?? false)
        XCTAssertTrue(mockClient.lastPrompt?.contains(testText) ?? false)
    }
    
    func testProcessWithPromptTypeFormal() async throws {
        // Given
        mockClient.generateResult = "We would like to schedule a meeting."
        let testText = "Let's have a meeting."
        
        // When
        let result = try await provider.processWithPromptType(testText, promptType: .formal)
        
        // Then
        XCTAssertEqual(result, "We would like to schedule a meeting.")
        XCTAssertTrue(mockClient.lastPrompt?.contains("formal") ?? false)
    }
    
    func testProcessWithPromptTypeCasual() async throws {
        // Given
        mockClient.generateResult = "Let's sync up tomorrow."
        let testText = "Let's leverage our synergies to facilitate a strategic alignment meeting."
        
        // When
        let result = try await provider.processWithPromptType(testText, promptType: .casual)
        
        // Then
        XCTAssertEqual(result, "Let's sync up tomorrow.")
        XCTAssertTrue(mockClient.lastPrompt?.contains("Simplify") ?? false)
    }
    
    func testProcessWithPromptTypePolished() async throws {
        // Given
        mockClient.generateResult = "We are pleased to announce the successful completion of the project."
        let testText = "We finished the project."
        
        // When
        let result = try await provider.processWithPromptType(testText, promptType: .polished)
        
        // Then
        XCTAssertEqual(result, "We are pleased to announce the successful completion of the project.")
        XCTAssertTrue(mockClient.lastPrompt?.contains("polished") ?? false)
    }
    
    func testProcessWithPromptTypeCleansResponse() async throws {
        // Given - LLM adds unwanted formatting
        mockClient.generateResult = """
        Here is the corrected text:
        **This is the actual result.**
        """
        
        // When
        let result = try await provider.processWithPromptType("test", promptType: .grammar)
        
        // Then - Should clean up the response
        XCTAssertEqual(result, "This is the actual result.")
    }
    
    func testProcessWithPromptTypeThrowsOnError() async throws {
        // Given
        mockClient.generateError = LLMError.networkError("Connection failed")
        
        // When/Then
        do {
            _ = try await provider.processWithPromptType("test", promptType: .grammar)
            XCTFail("Expected error to be thrown")
        } catch let error as LLMError {
            if case .networkError(let message) = error {
                XCTAssertEqual(message, "Connection failed")
            } else {
                XCTFail("Expected networkError")
            }
        }
    }
    
    func testProcessWithPromptTypeAllPromptTypes() async throws {
        // Test that all prompt types work and include the test text
        let testText = "Sample text for processing"
        mockClient.generateResult = "Processed result"
        
        for promptType in TextPromptType.allCases {
            mockClient.reset()
            mockClient.generateResult = "Processed result"
            
            let result = try await provider.processWithPromptType(testText, promptType: promptType)
            
            XCTAssertEqual(result, "Processed result")
            XCTAssertTrue(mockClient.lastPrompt?.contains(testText) ?? false, 
                "Prompt for \(promptType.displayName) should contain the input text")
        }
    }
}

