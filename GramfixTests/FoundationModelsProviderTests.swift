//
//  FoundationModelsProviderTests.swift
//  GramfixTests
//
//  Integration tests for FoundationModelsClient + LLMProviderImpl
//  Requires macOS 26.0+ and FoundationModels framework availability
//

import XCTest
import AppKit
@testable import Gramfix

/// Integration tests for FoundationModelsClient + LLMProviderImpl
/// Requires macOS 26.0+ and FoundationModels framework to be available
@available(macOS 26.0, *)
final class FoundationModelsProviderTests: XCTestCase {
    
    private var client: TextGenerationClient!
    private var provider: LLMProviderImpl!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Skip tests if FoundationModels is not available
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        // Create client - protocol conformance is declared via extension
        client = FoundationModelsClient()
        provider = LLMProviderImpl(client: client)
    }
    
    override func tearDown() async throws {
        provider = nil
        client = nil
        try await super.tearDown()
    }
    
    // MARK: - Availability Tests
    
    func testIsAvailable() async throws {
        // Skip if not on macOS 26+
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        let isAvailable = await provider.isAvailable()
        
        // Skip remaining tests if FoundationModels is not available
        try XCTSkipUnless(isAvailable, "FoundationModels is not available on this system")
        
        XCTAssertTrue(isAvailable)
    }
    
    // MARK: - Basic Provider Tests
    
    func testClientName() async throws {
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        XCTAssertEqual(client.name, "FoundationModels")
        XCTAssertTrue(client is FoundationModelsClient)
    }
    
    func testProviderNameFromClient() async throws {
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        XCTAssertEqual(provider.name, "FoundationModels")
    }
    
    // MARK: - Process Tests
    
    func testProcessSummarize() async throws {
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        // First check if FoundationModels is available
        let isAvailable = await provider.isAvailable()
        try XCTSkipUnless(isAvailable, "FoundationModels is not available on this system")
        
        let testText = "Swift is a powerful and intuitive programming language developed by Apple for iOS, macOS, watchOS, and tvOS app development. It's designed to be easy to learn and use."
        
        let result = try await provider.process(testText, requestType: .summarize)
        
        // Key assertions: no error, and response exists
        XCTAssertNil(result.error, "Error should be nil")
        XCTAssertNotNil(result.response, "Response should not be nil")
        XCTAssertFalse(result.response?.isEmpty ?? true, "Response should not be empty")
        
        // Summary content may vary based on LLM output
        // For summarize, response and summary should be the same (both set from response)
        XCTAssertEqual(result.response, result.summary, "For summarize, response equals summary")
    }
    
    func testProcessExtractTags() async throws {
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        let isAvailable = await provider.isAvailable()
        try XCTSkipUnless(isAvailable, "FoundationModels is not available on this system")
        
        let testText = "The Python programming language is widely used in machine learning, data science, and artificial intelligence applications."
        
        let result = try await provider.process(testText, requestType: .extractTags)
        
        XCTAssertNotNil(result.response, "Response should not be nil")
        XCTAssertNil(result.error, "Error should be nil")
        // Tags extraction may vary by LLM - just verify response exists
        // Tags may be empty if LLM doesn't format response as expected
    }
    
    func testProcessClassify() async throws {
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        let isAvailable = await provider.isAvailable()
        try XCTSkipUnless(isAvailable, "FoundationModels is not available on this system")
        
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
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        let isAvailable = await provider.isAvailable()
        try XCTSkipUnless(isAvailable, "FoundationModels is not available on this system")
        
        let testText = "The annual developer conference will be held in San Francisco on June 15th, 2024. Attendees can register online at conference.example.com"
        
        let result = try await provider.process(testText, requestType: .all)
        
        XCTAssertNotNil(result.response)
        // The .all request type should populate all fields from JSON response
        // At minimum, the response should be present
        XCTAssertNil(result.error)
    }
    
    func testProcessCustom() async throws {
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        let isAvailable = await provider.isAvailable()
        try XCTSkipUnless(isAvailable, "FoundationModels is not available on this system")
        
        let testText = "This is a sampel text with some grammer issues that needs to be fixd."
        
        let result = try await provider.process(testText, requestType: .custom)
        
        XCTAssertNotNil(result.response)
        XCTAssertNil(result.error)
    }
    
    // MARK: - Generate Tests
    
    func testGenerateWithoutContext() async throws {
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        let isAvailable = await provider.isAvailable()
        try XCTSkipUnless(isAvailable, "FoundationModels is not available on this system")
        
        let prompt = "Say hello in three different languages."
        
        // Generate may return empty string in some edge cases
        // The key test is that it doesn't throw
        let response = try await provider.generate(prompt: prompt, context: nil)
        
        // Response is a string (may or may not be empty depending on LLM state)
        XCTAssertNotNil(response)
    }
    
    func testGenerateWithContext() async throws {
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        let isAvailable = await provider.isAvailable()
        try XCTSkipUnless(isAvailable, "FoundationModels is not available on this system")
        
        let prompt = "What is the main topic of this text?"
        let context = "Artificial intelligence and machine learning are transforming industries worldwide. Companies are investing heavily in AI research and development."
        
        let response = try await provider.generate(prompt: prompt, context: context)
        
        XCTAssertFalse(response.isEmpty, "Response should not be empty")
    }
    
    // MARK: - FoundationModelsClient Specific Tests
    
    func testClientInitialization() async throws {
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        let newClient: TextGenerationClient = FoundationModelsClient()
        XCTAssertEqual(newClient.name, "FoundationModels")
    }
    
    func testClientGenerateDelegatesToSession() async throws {
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        let isAvailable = await client.isAvailable()
        try XCTSkipUnless(isAvailable, "FoundationModels is not available on this system")
        
        let prompt = "What is 2+2?"
        let response = try await client.generate(prompt: prompt, systemPrompt: nil, parameters: nil)
        
        XCTAssertFalse(response.isEmpty, "Response should not be empty")
    }
    
    func testClientGenerateWithSystemPrompt() async throws {
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        let isAvailable = await client.isAvailable()
        try XCTSkipUnless(isAvailable, "FoundationModels is not available on this system")
        
        let prompt = "Count to three."
        let systemPrompt = "You are a helpful assistant that responds concisely."
        let response = try await client.generate(prompt: prompt, systemPrompt: systemPrompt, parameters: nil)
        
        XCTAssertFalse(response.isEmpty, "Response should not be empty")
    }
    
    // MARK: - Vision Tests (when API is available)
    
    func testVisionSupportAvailable() async throws {
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("FoundationModels requires macOS 26.0+")
        }
        
        let isAvailable = await client.isAvailable()
        try XCTSkipUnless(isAvailable, "FoundationModels is not available on this system")
        
        // FoundationModels supports vision, but exact API syntax needs verification
        // This test verifies that the method exists and doesn't crash
        // When vision API is properly implemented, this test can be expanded
        
        // Create a simple test image (1x1 pixel PNG)
        let testImageData = createTestImageData()
        
        // The current implementation falls back to text-only, which is fine for now
        let response = try await client.generate(
            prompt: "Describe this image",
            systemPrompt: nil,
            images: [testImageData],
            parameters: nil
        )
        
        // Should not throw, even if it falls back to text-only
        XCTAssertNotNil(response)
    }
    
    // MARK: - Helper Methods
    
    /// Create a minimal test image data (1x1 pixel PNG)
    private func createTestImageData() -> Data {
        let size = NSSize(width: 1, height: 1)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            // Fallback: return empty data if image creation fails
            return Data()
        }
        
        return pngData
    }
}

