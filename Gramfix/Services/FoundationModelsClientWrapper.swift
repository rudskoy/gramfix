//
//  FoundationModelsClientWrapper.swift
//  Gramfix
//
//  Wrapper for FoundationModelsClient that works on all macOS versions.
//  The actual FoundationModelsClient is only available on macOS 26+.
//
//  Note: This wrapper is not currently used - FoundationModelsClient is used directly
//  Keeping this file for potential future use if needed for compatibility
//

import Foundation
import os.log

// This wrapper is commented out as it's not currently used.
// FoundationModelsClient is used directly since the project targets macOS 26+.
// Uncomment if needed for pre-macOS 26 compatibility.

/*
private let logger = Logger(subsystem: "com.gramfix.app", category: "FoundationModelsClientWrapper")

/// Wrapper class that provides FoundationModelsClient when available, or a stub when not
/// This wrapper allows the client to be used on systems that may not have FoundationModels available
final class FoundationModelsClientWrapper: TextGenerationClient, @unchecked Sendable {
    nonisolated let name: String = "FoundationModels"
    
    /// The actual client (only available on macOS 26+)
    /// Using Any to avoid compile-time dependency on FoundationModelsClient type
    private var client: Any?
    
    init() {
        if #available(macOS 26.0, *) {
            // Use dynamic type creation to avoid compile-time dependency
            // This will only work if FoundationModelsClient is available
            self.client = createFoundationModelsClient()
        } else {
            self.client = nil
        }
    }
    
    @available(macOS 26.0, *)
    private func createFoundationModelsClient() -> Any? {
        // Use helper function from FoundationModelsClient.swift
        // This avoids direct type reference that causes compile errors
        return createFoundationModelsClientInstance()
    }
    
    nonisolated func isAvailable() async -> Bool {
        if #available(macOS 26.0, *) {
            guard let client = self.client as? TextGenerationClient else { return false }
            return await client.isAvailable()
        } else {
            return false
        }
    }
    
    nonisolated func generate(prompt: String, systemPrompt: String?, parameters: GenerationParameters?) async throws -> String {
        if #available(macOS 26.0, *) {
            guard let client = self.client as? TextGenerationClient else {
                throw LLMError.providerUnavailable
            }
            return try await client.generate(prompt: prompt, systemPrompt: systemPrompt, parameters: parameters)
        } else {
            throw LLMError.providerUnavailable
        }
    }
    
    nonisolated func generate(prompt: String, systemPrompt: String?, images: [Data], parameters: GenerationParameters?) async throws -> String {
        if #available(macOS 26.0, *) {
            guard let client = self.client as? TextGenerationClient else {
                throw LLMError.providerUnavailable
            }
            return try await client.generate(prompt: prompt, systemPrompt: systemPrompt, images: images, parameters: parameters)
        } else {
            throw LLMError.providerUnavailable
        }
    }
}
*/
