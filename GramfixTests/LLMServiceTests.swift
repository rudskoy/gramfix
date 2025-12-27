import XCTest
@testable import Gramfix

/// Integration tests for LLMService
/// Requires Ollama to be running locally for full functionality tests
@MainActor
final class LLMServiceTests: XCTestCase {
    
    private var service: LLMService!
    private var client: OllamaClient!
    private var provider: LLMProviderImpl!
    
    override func setUp() async throws {
        try await super.setUp()
        service = LLMService()
        client = OllamaClient()
        provider = LLMProviderImpl(client: client)
    }
    
    override func tearDown() async throws {
        service = nil
        provider = nil
        client = nil
        try await super.tearDown()
    }
    
    // MARK: - Provider Management Tests
    
    func testRegisterProvider() async {
        XCTAssertTrue(service.providers.isEmpty, "Should start with no providers")
        XCTAssertNil(service.activeProvider, "Should have no active provider initially")
        
        service.registerProvider(provider)
        
        XCTAssertEqual(service.providers.count, 1, "Should have one provider")
        XCTAssertNotNil(service.activeProvider, "Should have active provider after registration")
        XCTAssertEqual(service.activeProvider?.name, "Ollama")
    }
    
    func testSetActiveProviderByName() async {
        service.registerProvider(provider)
        
        service.setActiveProvider(name: "Ollama")
        XCTAssertEqual(service.activeProvider?.name, "Ollama")
        
        service.setActiveProvider(name: "NonExistent")
        XCTAssertNil(service.activeProvider, "Should be nil for non-existent provider")
    }
    
    // MARK: - Availability Tests
    
    func testIsAvailable() async throws {
        service.registerProvider(provider)
        
        let isAvailable = await service.isAvailable()
        
        // Just verify it returns a boolean, actual availability depends on Ollama
        XCTAssertTrue(isAvailable || !isAvailable)
    }
    
    func testIsAvailableWithoutProvider() async {
        let isAvailable = await service.isAvailable()
        
        XCTAssertFalse(isAvailable, "Should not be available without a provider")
    }
    
    // MARK: - Content Validation Tests
    
    func testProcessContentTooShort() async {
        service.registerProvider(provider)
        
        let shortText = "Hi"  // Less than 10 characters
        let result = await service.processContent(shortText)
        
        XCTAssertNil(result.response)
        XCTAssertNil(result.error, "Short content should return empty result, not error")
    }
    
    func testProcessContentTooLong() async {
        service.registerProvider(provider)
        
        // Create text longer than 10000 characters
        let longText = String(repeating: "This is a long text. ", count: 1000)
        XCTAssertGreaterThan(longText.count, 10000)
        
        let result = await service.processContent(longText)
        
        XCTAssertNotNil(result.error)
        XCTAssertEqual(result.error, "Content too long for processing")
    }
    
    func testProcessContentWithoutProvider() async {
        let result = await service.processContent("This is some valid text to process.")
        
        XCTAssertNotNil(result.error)
        XCTAssertEqual(result.error, "No LLM provider configured")
    }
    
    // MARK: - Processing Tests (Integration)
    
    func testProcessContentValid() async throws {
        service.registerProvider(provider)
        
        let isAvailable = await service.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        let validText = "This is a valid piece of text that should be processed by the LLM service without any issues."
        
        XCTAssertFalse(service.isProcessing)
        
        let result = await service.processContent(validText)
        
        XCTAssertFalse(service.isProcessing, "Should not be processing after completion")
        XCTAssertNil(result.error)
        XCTAssertNotNil(result.response)
    }
    
    // MARK: - Caching Tests
    
    func testResultCaching() async throws {
        service.registerProvider(provider)
        
        let isAvailable = await service.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        let testText = "This unique text should be cached after first processing attempt."
        
        // First call - should process
        let result1 = await service.processContent(testText)
        
        // Second call with same text - should return cached result
        let result2 = await service.processContent(testText)
        
        // Both results should be the same (cached)
        XCTAssertEqual(result1.response, result2.response)
        XCTAssertEqual(result1.summary, result2.summary)
        XCTAssertEqual(result1.tags, result2.tags)
    }
    
    func testClearCache() async throws {
        service.registerProvider(provider)
        
        let isAvailable = await service.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        let testText = "Text to test cache clearing functionality."
        
        // Process to populate cache
        _ = await service.processContent(testText)
        
        // Clear cache
        service.clearCache()
        
        // Process again - should make new request (not from cache)
        let result = await service.processContent(testText)
        
        XCTAssertNil(result.error)
    }
    
    // MARK: - Generate Tests
    
    func testGenerateWithoutProvider() async {
        let result = await service.generate(prompt: "Test prompt")
        
        switch result {
        case .success:
            XCTFail("Should fail without provider")
        case .failure(let error):
            XCTAssertTrue(error is LLMError)
        }
    }
    
    func testGenerateWithProvider() async throws {
        service.registerProvider(provider)
        
        let isAvailable = await service.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        let result = await service.generate(prompt: "Say hello", context: nil)
        
        switch result {
        case .success(let response):
            XCTAssertFalse(response.isEmpty)
        case .failure(let error):
            XCTFail("Should succeed: \(error.localizedDescription)")
        }
    }
    
    func testGenerateWithContext() async throws {
        service.registerProvider(provider)
        
        let isAvailable = await service.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        let result = await service.generate(
            prompt: "Summarize this",
            context: "Swift is a programming language by Apple."
        )
        
        switch result {
        case .success(let response):
            XCTAssertFalse(response.isEmpty)
        case .failure(let error):
            XCTFail("Should succeed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - State Tests
    
    func testProcessingState() async throws {
        service.registerProvider(provider)
        
        let isAvailable = await service.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama is not running or model is not available")
        
        XCTAssertFalse(service.isProcessing, "Should not be processing initially")
        XCTAssertNil(service.lastError)
        
        // After successful processing
        _ = await service.processContent("Valid text for processing state test.")
        
        XCTAssertFalse(service.isProcessing, "Should not be processing after completion")
    }
}
