//
//  MLXService.swift
//  Clipsa
//
//  MLX on-device LLM service for text generation
//

import Foundation
import Hub
import MLX
import MLXLLM
import MLXLMCommon
// TODO: Fix conflicting types across packages (MLXVLM's Message conflicts with Ollama's Message)
// import MLXVLM
import os.log

private let logger = Logger(subsystem: "com.clipsa.app", category: "MLX")

/// Protocol defining the interface for MLX text generation services.
/// Used for dependency injection and testing.
@MainActor
protocol MLXServiceProtocol: AnyObject, Sendable {
    /// Generates text based on the provided prompt using the specified model.
    /// - Parameters:
    ///   - prompt: The user prompt to generate a response for
    ///   - systemPrompt: Optional system prompt to set context
    ///   - model: The language model to use for generation
    /// - Returns: The generated text response
    /// - Throws: Errors that might occur during generation
    func generate(prompt: String, systemPrompt: String?, model: LMModel) async throws -> String
}

/// A service class that manages machine learning models for text generation using MLX.
/// This class handles model loading, caching, and text generation using various LLM models.
@Observable
@MainActor
class MLXService: MLXServiceProtocol {
    /// Shared instance for singleton access (used by SettingsView)
    static let shared = MLXService()
    
    /// List of available models that can be used for generation.
    /// Includes language models (LLM) optimized for Apple Silicon.
    static let availableModels: [LMModel] = [
        LMModel(name: "llama3.2:1b", configuration: LLMRegistry.llama3_2_1B_4bit, type: .llm),
        LMModel(name: "qwen2.5:1.5b", configuration: LLMRegistry.qwen2_5_1_5b, type: .llm),
        LMModel(name: "smolLM:135m", configuration: LLMRegistry.smolLM_135M_4bit, type: .llm),
        LMModel(name: "qwen3:0.6b", configuration: LLMRegistry.qwen3_0_6b_4bit, type: .llm),
        LMModel(name: "qwen3:1.7b", configuration: LLMRegistry.qwen3_1_7b_4bit, type: .llm),
        LMModel(name: "qwen3:4b", configuration: LLMRegistry.qwen3_4b_4bit, type: .llm),
        LMModel(name: "qwen3:8b", configuration: LLMRegistry.qwen3_8b_4bit, type: .llm),
    ]
    
    /// Cache to store loaded model containers to avoid reloading.
    private let modelCache = NSCache<NSString, ModelContainer>()
    
    /// Tracks the current model download progress.
    /// Access this property to monitor model download status.
    private(set) var modelDownloadProgress: Progress?
    
    /// Number of files that have completed downloading
    private(set) var downloadedFileCount: Int = 0
    
    /// Total number of files being downloaded (discovered dynamically)
    private(set) var totalFileCount: Int = 0
    
    /// Whether a download is currently in progress
    private(set) var isDownloading: Bool = false
    
    /// Set of progress object identifiers we've seen (to count unique files)
    private var seenProgressObjects = Set<ObjectIdentifier>()
    
    /// Set of progress object identifiers that have completed
    private var completedProgressObjects = Set<ObjectIdentifier>()
    
    /// Whether the service is currently loading a model
    private(set) var isLoading: Bool = false
    
    /// Last error message if any operation failed
    private(set) var lastError: String?
    
    init() {
        logger.info("🤖 MLXService initialized")
    }
    
    /// Get a model by name from the available models list
    static func model(named name: String) -> LMModel? {
        availableModels.first { $0.name == name }
    }
    
    /// Loads a model from the hub or retrieves it from cache.
    /// - Parameter model: The model configuration to load
    /// - Returns: A ModelContainer instance containing the loaded model
    /// - Throws: Errors that might occur during model loading
    private func load(model: LMModel) async throws -> ModelContainer {
        // Set GPU memory limit to prevent out of memory issues
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
        
        // Return cached model if available to avoid reloading
        if let container = modelCache.object(forKey: model.name as NSString) {
            logger.debug("📦 Using cached model: \(model.name)")
            return container
        }
        
        isLoading = true
        lastError = nil
        
        defer {
            isLoading = false
        }
        
        logger.info("⬇️ Loading model: \(model.name)")
        
        // Reset download tracking state
        resetDownloadTracking()
        isDownloading = true
        
        // Select appropriate factory based on model type
        // TODO: Fix conflicting types across packages - re-enable VLM support when MLXVLM is fixed
        let factory: ModelFactory =
            switch model.type {
            case .llm:
                LLMModelFactory.shared
            case .vlm:
                // VLMModelFactory.shared - disabled due to Message type conflict with Ollama
                fatalError("VLM models are currently disabled due to package conflicts")
            }
        
        // Load model and track download progress
        let container = try await factory.loadContainer(
            hub: .default, configuration: model.configuration
        ) { progress in
            Task { @MainActor in
                self.modelDownloadProgress = progress
                
                // Track unique files by their Progress object identity
                let progressId = ObjectIdentifier(progress)
                if !self.seenProgressObjects.contains(progressId) {
                    self.seenProgressObjects.insert(progressId)
                    self.totalFileCount += 1
                    logger.debug("⬇️ Discovered file \(self.totalFileCount)")
                }
                
                // Track completed files
                if progress.fractionCompleted >= 1.0 && !self.completedProgressObjects.contains(progressId) {
                    self.completedProgressObjects.insert(progressId)
                    self.downloadedFileCount += 1
                    logger.debug("✅ File \(self.downloadedFileCount)/\(self.totalFileCount) completed")
                }
            }
        }
        
        // Download complete
        isDownloading = false
        
        // Cache the loaded model for future use
        modelCache.setObject(container, forKey: model.name as NSString)
        
        logger.info("✅ Model \(model.name) loaded successfully")
        
        return container
    }
    
    /// Generates text based on the provided prompt using the specified model.
    /// - Parameters:
    ///   - prompt: The user prompt to generate a response for
    ///   - systemPrompt: Optional system prompt to set context
    ///   - model: The language model to use for generation
    /// - Returns: The generated text response
    /// - Throws: Errors that might occur during generation
    func generate(prompt: String, systemPrompt: String? = nil, model: LMModel) async throws -> String {
        logger.info("🚀 Generating response with model: \(model.name)")
        let startTime = Date()
        
        // Load or retrieve model from cache
        let modelContainer = try await load(model: model)
        
        // Build chat messages
        var chatMessages: [Chat.Message] = []
        
        if let systemPrompt = systemPrompt {
            chatMessages.append(Chat.Message(role: .system, content: systemPrompt))
        }
        
        chatMessages.append(Chat.Message(role: .user, content: prompt))
        
        // Prepare input for model processing
        let userInput = UserInput(chat: chatMessages)
        
        // Generate response using the model
        var generatedText = ""
        
        let stream = try await modelContainer.perform { (context: ModelContext) in
            let lmInput = try await context.processor.prepare(input: userInput)
            // Set temperature for response randomness (0.7 provides good balance)
            let parameters = GenerateParameters(temperature: 0.7)
            
            return try MLXLMCommon.generate(
                input: lmInput, parameters: parameters, context: context)
        }
        
        // Collect generated tokens
        for await generation in stream {
            switch generation {
            case .chunk(let chunk):
                generatedText += chunk
            case .info(let info):
                logger.debug("📊 Generation stats: \(info.tokensPerSecond) tokens/sec")
            case .toolCall:
                break
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        logger.info("📥 Response generated in \(String(format: "%.2f", elapsed))s")
        
        return generatedText
    }
    
    /// Check if a specific model is loaded/cached
    func isModelCached(name: String) -> Bool {
        modelCache.object(forKey: name as NSString) != nil
    }
    
    /// Clear the model cache to free memory
    func clearCache() {
        modelCache.removeAllObjects()
        logger.info("🗑️ Model cache cleared")
    }
    
    /// Reset download tracking state for a new download
    private func resetDownloadTracking() {
        downloadedFileCount = 0
        totalFileCount = 0
        seenProgressObjects.removeAll()
        completedProgressObjects.removeAll()
        modelDownloadProgress = nil
    }
}
