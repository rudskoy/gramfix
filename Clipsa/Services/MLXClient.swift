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
@MainActor
final class MLXClient: TextGenerationClient {
    nonisolated let name: String = "MLX"
    
    private let mlxService: any MLXServiceProtocol
    
    /// Model name - reads from LLMSettings
    private var modelName: String {
        LLMSettings.shared.mlxSelectedModel
    }
    
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
    func generate(prompt: String, systemPrompt: String?) async throws -> String {
        guard let model = MLXService.model(named: modelName) else {
            logger.error("❌ Model not found: \(self.modelName)")
            throw LLMError.providerUnavailable
        }
        
        logger.debug("📤 Sending request to MLX with model: \(self.modelName)")
        
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
}

