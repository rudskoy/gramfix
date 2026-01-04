//
//  MLXProviderTests.swift
//  GramfixTests
//
//  Unit tests for MLXClient + LLMProviderImpl using mock MLXService.
//  Focuses on MLX-specific behavior; parsing tests are in LLMProviderImplTests.
//

import XCTest
@testable import Gramfix

// MARK: - Mock MLXService

/// Mock implementation of MLXServiceProtocol for testing
@MainActor
final class MockMLXService: MLXServiceProtocol {
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
    
    /// Last model passed to generate()
    var lastModel: LMModel?
    
    func generate(prompt: String, systemPrompt: String?, model: LMModel, parameters: GenerationParameters?) async throws -> String {
        generateCallCount += 1
        lastPrompt = prompt
        lastSystemPrompt = systemPrompt
        lastModel = model
        
        if let error = generateError {
            throw error
        }
        return generateResult
    }
    
    /// Last images passed to generate()
    var lastImages: [Data]?
    
    func generate(prompt: String, systemPrompt: String?, images: [Data], model: LMModel, parameters: GenerationParameters?) async throws -> String {
        generateCallCount += 1
        lastPrompt = prompt
        lastSystemPrompt = systemPrompt
        lastImages = images
        lastModel = model
        
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
        lastImages = nil
        lastModel = nil
    }
}

// MARK: - MLXClient Tests

/// Unit tests for MLXClient + LLMProviderImpl
/// Uses MockMLXService to avoid actual model inference
final class MLXProviderTests: XCTestCase {
    
    private var mockService: MockMLXService!
    private var client: MLXClient!
    private var provider: LLMProviderImpl!
    private var originalModelName: String!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        
        // Save original model name and set a valid one for tests
        originalModelName = LLMSettings.shared.mlxSelectedTextModel
        LLMSettings.shared.mlxSelectedTextModel = "llama3.2:1b"
        
        mockService = MockMLXService()
        client = MLXClient(mlxService: mockService)
        provider = LLMProviderImpl(client: client)
    }
    
    @MainActor
    override func tearDown() async throws {
        // Restore original model name
        LLMSettings.shared.mlxSelectedTextModel = originalModelName
        
        provider = nil
        client = nil
        mockService = nil
        originalModelName = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Client Tests
    
    func testClientName() async throws {
        XCTAssertEqual(client.name, "MLX")
    }
    
    func testProviderNameFromClient() async throws {
        XCTAssertEqual(provider.name, "MLX")
    }
    
    func testIsAvailableOnAppleSilicon() async throws {
        let isAvailable = await client.isAvailable()
        
        #if arch(arm64)
        XCTAssertTrue(isAvailable, "MLX should be available on Apple Silicon")
        #else
        XCTAssertFalse(isAvailable, "MLX should not be available on Intel")
        #endif
    }
    
    // MARK: - MLXClient Generation Tests
    
    @MainActor
    func testClientGenerateDelegatesToService() async throws {
        // Given
        mockService.generateResult = "Test response"
        
        // When
        let result = try await client.generate(prompt: "Test prompt", systemPrompt: "System")
        
        // Then
        XCTAssertEqual(result, "Test response")
        XCTAssertEqual(mockService.generateCallCount, 1)
        XCTAssertEqual(mockService.lastPrompt, "Test prompt")
        XCTAssertEqual(mockService.lastSystemPrompt, "System")
        XCTAssertEqual(mockService.lastModel?.name, "llama3.2:1b")
    }
    
    @MainActor
    func testClientGenerateThrowsOnServiceError() async throws {
        // Given
        mockService.generateError = LLMError.networkError("Test error")
        
        // When/Then
        do {
            _ = try await client.generate(prompt: "test", systemPrompt: nil)
            XCTFail("Expected error to be thrown")
        } catch let error as LLMError {
            if case .networkError(let message) = error {
                XCTAssertTrue(message.contains("Test error"))
            } else {
                XCTFail("Expected networkError")
            }
        }
    }
    
    @MainActor
    func testClientGenerateThrowsOnInvalidModel() async throws {
        // Given - set an invalid model name
        LLMSettings.shared.mlxSelectedTextModel = "nonexistent-model"
        
        // When/Then
        do {
            _ = try await client.generate(prompt: "test", systemPrompt: nil)
            XCTFail("Expected error to be thrown")
        } catch let error as LLMError {
            if case .providerUnavailable = error {
                // Expected
            } else {
                XCTFail("Expected providerUnavailable")
            }
        }
    }
    
    // MARK: - Integration with LLMProviderImpl
    
    @MainActor
    func testProviderProcessDelegatesToClient() async throws {
        // Given
        mockService.generateResult = "Test summary"
        
        // When
        let result = try await provider.process("Test text", requestType: .summarize)
        
        // Then
        XCTAssertEqual(result.summary, "Test summary")
        XCTAssertEqual(mockService.generateCallCount, 1)
        XCTAssertTrue(mockService.lastPrompt?.contains("Test text") ?? false)
    }
    
    @MainActor
    func testProviderGenerateDelegatesToClient() async throws {
        // Given
        mockService.generateResult = "Generated response"
        
        // When
        let result = try await provider.generate(prompt: "Test", context: nil)
        
        // Then
        XCTAssertEqual(result, "Generated response")
        XCTAssertEqual(mockService.generateCallCount, 1)
    }
    
    // MARK: - Model Availability Tests (Static, no mock needed)
    
    @MainActor
    func testAvailableModelsExist() async throws {
        XCTAssertFalse(MLXService.availableModels.isEmpty, "Should have available models")
        
        for model in MLXService.availableModels {
            XCTAssertFalse(model.name.isEmpty, "Model name should not be empty")
        }
    }
    
    @MainActor
    func testModelLookupByName() async throws {
        // Test valid model
        let model = MLXService.model(named: "llama3.2:1b")
        XCTAssertNotNil(model, "Should find llama3.2:1b model")
        XCTAssertEqual(model?.name, "llama3.2:1b")
        
        // Test invalid model
        let invalidModel = MLXService.model(named: "nonexistent-model")
        XCTAssertNil(invalidModel, "Should not find nonexistent model")
    }
    
    @MainActor
    func testAllModelsHaveValidType() async throws {
        for model in MLXService.availableModels {
            // Each model should be exactly one type (LLM or VLM)
            XCTAssertTrue(model.isLanguageModel || model.isVisionModel, "Model \(model.name) should have a valid type")
            XCTAssertNotEqual(model.isLanguageModel, model.isVisionModel, "Model \(model.name) should be either LLM or VLM, not both")
        }
    }
    
    // MARK: - System Prompt Tests
    
    @MainActor
    func testSystemPromptPassedToService() async throws {
        mockService.generateResult = "result"
        _ = try await provider.process("test", requestType: .summarize)
        
        XCTAssertNotNil(mockService.lastSystemPrompt)
        XCTAssertTrue(mockService.lastSystemPrompt?.contains("grammar correction assistant") ?? false)
    }
    
    @MainActor
    func testModelPassedToService() async throws {
        mockService.generateResult = "result"
        _ = try await provider.process("test", requestType: .summarize)
        
        XCTAssertNotNil(mockService.lastModel)
        XCTAssertEqual(mockService.lastModel?.name, "llama3.2:1b")
    }
}
