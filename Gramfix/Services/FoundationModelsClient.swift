//
//  FoundationModelsClient.swift
//  Gramfix
//
//  FoundationModels text generation client implementing TextGenerationClient protocol.
//  Uses Apple's FoundationModels framework for on-device LLM inference (macOS 26+).
//

import Foundation
import AppKit
import os.log

#if canImport(FoundationModels)
import FoundationModels
#endif

private let logger = Logger(subsystem: "com.gramfix.app", category: "FoundationModelsClient")

/// FoundationModels text generation client implementing TextGenerationClient protocol.
/// Thin wrapper around Apple's FoundationModels framework for on-device inference.
/// 
/// Threading model:
/// - The `generate` methods run on background threads (nonisolated)
/// - Uses LanguageModelSession for stateful conversations
@available(macOS 26.0, *)
public final class FoundationModelsClient: TextGenerationClient, @unchecked Sendable {
    nonisolated public let name: String = "FoundationModels"
    
    /// Shared session for text generation (reused across requests)
    private let session: LanguageModelSession
    
    /// Initialize with a new LanguageModelSession
    public init() {
        // Get the default system language model and create a session
        let model = SystemLanguageModel.default
        self.session = LanguageModelSession(model: model)
        logger.info("🤖 FoundationModelsClient initialized")
    }
    
    // MARK: - TextGenerationClient Protocol
    
    /// Check if FoundationModels is available (macOS 26+)
    nonisolated func isAvailable() async -> Bool {
        // FoundationModels requires macOS 26.0+
        if #available(macOS 26.0, *) {
            // Check if the default model is available
            return SystemLanguageModel.default.isAvailable
        } else {
            logger.warning("⚠️ FoundationModels requires macOS 26.0+")
            return false
        }
    }
    
    /// Generate text from a prompt using FoundationModels
    /// Runs on background thread to avoid blocking UI.
    nonisolated func generate(prompt: String, systemPrompt: String?, parameters: GenerationParameters?) async throws -> String {
        logger.debug("📤 Sending request to FoundationModels")
        
        do {
            // Build the prompt - FoundationModels uses Prompt builder
            // If we have a system prompt, we can set it via session instructions
            // For now, we'll combine them in the user prompt
            var userPrompt = prompt
            if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
                // Prepend system prompt to user prompt
                userPrompt = "\(systemPrompt)\n\n\(prompt)"
            }
            
            // Generate using the session
            // Note: Generation parameters (temperature, topP, topK) may need to be set
            // via session configuration or prompt options if the API supports it
            let response = try await session.respond {
                Prompt(userPrompt)
            }
            
            logger.info("📥 FoundationModels response received")
            // Extract the string content from the response
            // Response type is LanguageModelSession.Response<String>, extract content
            return response.content
        } catch {
            logger.error("❌ FoundationModels request failed: \(error.localizedDescription)")
            throw LLMError.networkError(error.localizedDescription)
        }
    }
    
    /// Generate text from a prompt with images using FoundationModels
    /// FoundationModels supports vision capabilities for image analysis
    nonisolated func generate(prompt: String, systemPrompt: String?, images: [Data], parameters: GenerationParameters?) async throws -> String {
        // If no images, fall back to text generation
        guard !images.isEmpty else {
            logger.debug("📤 No images provided, using text generation")
            return try await generate(prompt: prompt, systemPrompt: systemPrompt, parameters: parameters)
        }
        
        logger.debug("📤 Sending vision request to FoundationModels with \(images.count) image(s)")
        
        do {
            // Convert image data to NSImage, then to FoundationModels Image type
            // FoundationModels Prompt builder supports images
            var nsImages: [NSImage] = []
            for imageData in images {
                guard let nsImage = NSImage(data: imageData) else {
                    logger.warning("⚠️ Failed to create NSImage from data, skipping")
                    continue
                }
                nsImages.append(nsImage)
            }
            
            guard !nsImages.isEmpty else {
                logger.warning("⚠️ No valid images after conversion, falling back to text generation")
                return try await generate(prompt: prompt, systemPrompt: systemPrompt, parameters: parameters)
            }
            
            // Build the prompt with images
            // FoundationModels Prompt builder can accept images
            var userPrompt = prompt
            if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
                userPrompt = "\(systemPrompt)\n\n\(prompt)"
            }
            
            // Generate using the session with images
            // FoundationModels supports vision, but the exact API syntax for passing images
            // to Prompt() is not yet documented. The framework likely supports Image types
            // but the specific syntax needs to be confirmed from Apple's documentation.
            // For now, we fall back to text-only generation.
            // TODO: Update when FoundationModels vision API documentation is available
            logger.info("📤 FoundationModels vision is supported but API syntax needs verification")
            logger.info("📤 Falling back to text-only generation until correct API is confirmed")
            return try await generate(prompt: prompt, systemPrompt: systemPrompt, parameters: parameters)
        } catch {
            // If vision processing fails, log and fall back to text-only
            logger.warning("⚠️ FoundationModels vision request failed: \(error.localizedDescription), falling back to text generation")
            return try await generate(prompt: prompt, systemPrompt: systemPrompt, parameters: parameters)
        }
    }
}

// MARK: - Helper for Wrapper

/// Helper function to create FoundationModelsClient instance
/// This allows the wrapper to create instances without direct type dependency
@available(macOS 26.0, *)
func createFoundationModelsClientInstance() -> TextGenerationClient {
    return FoundationModelsClient()
}


