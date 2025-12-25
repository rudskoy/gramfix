//
//  MLXClient.swift
//  Clipsa
//
//  Thin wrapper around MLXService implementing TextGenerationClient.
//  Enables DI and mocking for MLX-based text generation.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.clipsa.app", category: "MLXClient")

/// MLX text generation client implementing TextGenerationClient protocol.
/// Thin wrapper that delegates to MLXService for actual model loading and generation.
/// 
/// Threading model:
/// - The `generate` methods run on background threads (nonisolated)
/// - Settings are read on MainActor when needed
final class MLXClient: TextGenerationClient, @unchecked Sendable {
    nonisolated let name: String = "MLX"
    
    private let mlxService: any MLXServiceProtocol
    
    /// Get text model name from settings (MainActor-isolated)
    @MainActor
    private var textModelName: String {
        LLMSettings.shared.mlxSelectedTextModel
    }
    
    /// Get VLM model name from settings (MainActor-isolated)
    @MainActor
    private var vlmModelName: String {
        LLMSettings.shared.mlxSelectedVLMModel
    }
    
    @MainActor
    init(mlxService: any MLXServiceProtocol) {
        self.mlxService = mlxService
        logger.info("🤖 MLXClient initialized")
    }
    
    // MARK: - TextGenerationClient Protocol
    
    /// Check if MLX is available (always true on Apple Silicon)
    nonisolated func isAvailable() async -> Bool {
        // MLX is available on Apple Silicon Macs
        #if arch(arm64)
        return true
        #else
        logger.warning("⚠️ MLX requires Apple Silicon (arm64)")
        return false
        #endif
    }
    
    /// Generate text from a prompt using MLX
    /// Runs on background thread to avoid blocking UI.
    nonisolated func generate(prompt: String, systemPrompt: String?) async throws -> String {
        // Read text model name on MainActor
        let currentModelName = await MainActor.run { self.textModelName }
        
        guard let model = MLXService.model(named: currentModelName) else {
            logger.error("❌ Model not found: \(currentModelName)")
            throw LLMError.providerUnavailable
        }
        
        logger.debug("📤 Sending request to MLX with model: \(currentModelName)")
        
        do {
            let response = try await mlxService.generate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                model: model
            )
            
            logger.info("📥 MLX response received")
            return response
        } catch {
            logger.error("❌ MLX request failed: \(error.localizedDescription)")
            throw LLMError.networkError(error.localizedDescription)
        }
    }
    
    /// Generate text from a prompt with images using MLX vision model
    /// Runs on background thread to avoid blocking UI.
    nonisolated func generate(prompt: String, systemPrompt: String?, images: [Data]) async throws -> String {
        // If no images, fall back to text generation
        guard !images.isEmpty else {
            logger.debug("📤 No images provided, using text generation")
            return try await generate(prompt: prompt, systemPrompt: systemPrompt)
        }
        
        // Read VLM model name on MainActor for image processing
        let currentModelName = await MainActor.run { self.vlmModelName }
        
        guard let model = MLXService.model(named: currentModelName) else {
            logger.error("❌ VLM model not found: \(currentModelName)")
            throw LLMError.providerUnavailable
        }
        
        // Verify it's actually a vision model
        guard model.isVisionModel else {
            logger.warning("⚠️ Selected VLM \(currentModelName) is not a vision model, falling back to text generation")
            return try await generate(prompt: prompt, systemPrompt: systemPrompt)
        }
        
        logger.debug("📤 Sending vision request to MLX with model: \(currentModelName), images: \(images.count)")
        
        do {
            let response = try await mlxService.generate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                images: images,
                model: model
            )
            
            logger.info("📥 MLX vision response received")
            return response
        } catch {
            logger.error("❌ MLX vision request failed: \(error.localizedDescription)")
            throw LLMError.networkError(error.localizedDescription)
        }
    }
}

