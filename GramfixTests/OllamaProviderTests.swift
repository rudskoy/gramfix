import XCTest
@testable import Gramfix

/// Integration tests for OllamaClient + LLMProviderImpl
/// Requires Ollama to be running locally at http://localhost:11434
final class OllamaProviderTests: XCTestCase {
    
    private var client: OllamaClient!
    private var provider: LLMProviderImpl!
    
    override func setUp() async throws {
        try await super.setUp()
        client = OllamaClient()
        provider = LLMProviderImpl(client: client)
    }
    
    override func tearDown() async throws {
        provider = nil
        client = nil
        try await super.tearDown()
    }
    
    // MARK: - Availability Tests
    
    func testIsAvailable() async throws {
        let isAvailable = await provider.isAvailable()
        
        // Skip remaining tests if Ollama is not available
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        XCTAssertTrue(isAvailable)
    }
    
    // MARK: - Process Tests
    
    func testProcessSummarize() async throws {
        // First check if Ollama is available
        let isAvailable = await provider.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        let testText = "Swift is a powerful and intuitive programming language developed by Apple for iOS, macOS, watchOS, and tvOS app development. It's designed to be easy to learn and use."
        
        let result = try await provider.process(testText, requestType: .summarize)
        
        // Key assertions: no error, and response exists
        XCTAssertNil(result.error, "Error should be nil")
        XCTAssertNotNil(result.response, "Response should not be nil")
        
        // Summary content may vary based on LLM output
        // For summarize, response and summary should be the same (both set from response)
        XCTAssertEqual(result.response, result.summary, "For summarize, response equals summary")
    }
    
    func testProcessExtractTags() async throws {
        let isAvailable = await provider.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        let testText = "The Python programming language is widely used in machine learning, data science, and artificial intelligence applications."
        
        let result = try await provider.process(testText, requestType: .extractTags)
        
        XCTAssertNotNil(result.response, "Response should not be nil")
        XCTAssertNil(result.error, "Error should be nil")
        // Tags extraction may vary by LLM - just verify response exists
        // Tags may be empty if LLM doesn't format response as expected
    }
    
    func testProcessClassify() async throws {
        let isAvailable = await provider.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        let codeText = """
        func greet(name: String) -> String {
            return "Hello, \\(name)!"
        }
        """
        
        let result = try await provider.process(codeText, requestType: .classify)
        
        XCTAssertNotNil(result.response)
        XCTAssertNotNil(result.contentType)
        XCTAssertFalse(result.contentType!.isEmpty, "Content type should not be empty")
        XCTAssertNil(result.error)
    }
    
    func testProcessAll() async throws {
        let isAvailable = await provider.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        let testText = "The annual developer conference will be held in San Francisco on June 15th, 2024. Attendees can register online at conference.example.com"
        
        let result = try await provider.process(testText, requestType: .all)
        
        XCTAssertNotNil(result.response)
        // The .all request type should populate all fields from JSON response
        // At minimum, the response should be present
        XCTAssertNil(result.error)
    }
    
    func testProcessCustom() async throws {
        let isAvailable = await provider.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        let testText = "This is a sampel text with some grammer issues that needs to be fixd."
        
        let result = try await provider.process(testText, requestType: .custom)
        
        XCTAssertNotNil(result.response)
        XCTAssertNil(result.error)
    }
    
    // MARK: - Generate Tests
    
    func testGenerateWithoutContext() async throws {
        let isAvailable = await provider.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        let prompt = "Say hello in three different languages."
        
        // Generate may return empty string in some edge cases
        // The key test is that it doesn't throw
        let response = try await provider.generate(prompt: prompt, context: nil)
        
        // Response is a string (may or may not be empty depending on LLM state)
        XCTAssertNotNil(response)
    }
    
    func testGenerateWithContext() async throws {
        let isAvailable = await provider.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        let prompt = "What is the main topic of this text?"
        let context = "Artificial intelligence and machine learning are transforming industries worldwide. Companies are investing heavily in AI research and development."
        
        let response = try await provider.generate(prompt: prompt, context: context)
        
        XCTAssertFalse(response.isEmpty, "Response should not be empty")
    }
    
    // MARK: - OllamaClient Specific Tests
    
    func testClientWithCustomURL() async throws {
        // Test that client can be initialized with custom URL
        let customClient = OllamaClient(baseURL: "http://localhost:11434")
        let customProvider = LLMProviderImpl(client: customClient)
        
        let isAvailable = await customProvider.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        XCTAssertEqual(customClient.name, "Ollama")
    }
    
    func testClientWithInvalidURL() async throws {
        // Test behavior with unreachable URL
        let invalidClient = OllamaClient(baseURL: "http://localhost:99999")
        
        let isAvailable = await invalidClient.isAvailable()
        
        XCTAssertFalse(isAvailable, "Client should not be available with invalid URL")
    }
    
    func testProviderNameFromClient() async throws {
        XCTAssertEqual(provider.name, "Ollama")
    }
}
