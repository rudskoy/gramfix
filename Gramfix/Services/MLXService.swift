//
//  MLXService.swift
//  Gramfix
//
//  MLX on-device LLM service for text generation
//

import CoreImage
import Foundation
import Hub
import MLX
import MLXLLM
import MLXLMCommon
import MLXVLM
import os.log

private let logger = Logger(subsystem: "com.gramfix.app", category: "MLX")

/// Protocol defining the interface for MLX text generation services.
/// Used for dependency injection and testing.
/// Note: Methods are NOT MainActor-isolated to allow background execution.
protocol MLXServiceProtocol: AnyObject, Sendable {
    /// Generates text based on the provided prompt using the specified model.
    /// Runs on a background thread to avoid blocking the UI.
    /// - Parameters:
    ///   - prompt: The user prompt to generate a response for
    ///   - systemPrompt: Optional system prompt to set context
    ///   - model: The language model to use for generation
    ///   - parameters: Optional generation parameters (temperature, top_p, top_k)
    /// - Returns: The generated text response
    /// - Throws: Errors that might occur during generation
    func generate(prompt: String, systemPrompt: String?, model: LMModel, parameters: GenerationParameters?) async throws -> String
    
    /// Generates text based on the provided prompt and images using a vision model.
    /// Runs on a background thread to avoid blocking the UI.
    /// - Parameters:
    ///   - prompt: The user prompt to generate a response for
    ///   - systemPrompt: Optional system prompt to set context
    ///   - images: Array of image data (PNG/JPEG) for vision understanding
    ///   - model: The vision-language model to use for generation
    ///   - parameters: Optional generation parameters (temperature, top_p, top_k)
    /// - Returns: The generated text response
    /// - Throws: Errors that might occur during generation
    func generate(prompt: String, systemPrompt: String?, images: [Data], model: LMModel, parameters: GenerationParameters?) async throws -> String
}

/// A service class that manages machine learning models for text generation using MLX.
/// This class handles model loading, caching, and text generation using various LLM models.
/// 
/// Threading model:
/// - UI state properties (isLoading, isDownloading, progress) are MainActor-isolated
/// - Heavy computation (model loading, inference) runs on background threads
/// - The `generate` methods hop off MainActor for inference work
@Observable
final class MLXService: MLXServiceProtocol, @unchecked Sendable {
    /// Shared instance for singleton access (used by SettingsView)
    @MainActor static let shared = MLXService()
    
    /// List of available models that can be used for generation.
    /// Includes language models (LLM) and vision-language models (VLM) optimized for Apple Silicon.
    nonisolated static let availableModels: [LMModel] = [
        // Text-only LLMs
        LMModel(name: "llama3.2:1b", configuration: LLMRegistry.llama3_2_1B_4bit, type: .llm),
        LMModel(name: "qwen2.5:1.5b", configuration: LLMRegistry.qwen2_5_1_5b, type: .llm),
        LMModel(name: "smolLM:135m", configuration: LLMRegistry.smolLM_135M_4bit, type: .llm),
        LMModel(name: "qwen3:0.6b", configuration: LLMRegistry.qwen3_0_6b_4bit, type: .llm),
        LMModel(name: "qwen3:1.7b", configuration: LLMRegistry.qwen3_1_7b_4bit, type: .llm),
        LMModel(name: "qwen3:4b", configuration: LLMRegistry.qwen3_4b_4bit, type: .llm),
        LMModel(name: "qwen3:8b", configuration: LLMRegistry.qwen3_8b_4bit, type: .llm),
        // Vision-Language Models (VLM) - can understand images
        LMModel(name: "qwen3-vl:4b", configuration: VLMRegistry.qwen3VL4BInstruct4Bit, type: .vlm),
        LMModel(name: "gemma3:4b-vision", configuration: VLMRegistry.gemma3_4B_qat_4bit, type: .vlm),
        LMModel(name: "gemma3:12b-vision", configuration: VLMRegistry.gemma3_12B_qat_4bit, type: .vlm),
    ]
    
    /// Text-only models (LLM) for text processing
    nonisolated static var textModels: [LMModel] {
        availableModels.filter { $0.type == .llm }
    }
    
    /// Vision-language models (VLM) for image analysis
    nonisolated static var visionModels: [LMModel] {
        availableModels.filter { $0.type == .vlm }
    }
    
    /// Cache to store loaded model containers to avoid reloading.
    /// NSCache is thread-safe.
    private let modelCache = NSCache<NSString, ModelContainer>()
    
    /// Lock for synchronizing state updates
    private let stateLock = NSLock()
    
    /// Tracks the current model download progress (MainActor for UI).
    @MainActor private(set) var modelDownloadProgress: Progress?
    
    /// Number of files that have completed downloading (MainActor for UI)
    @MainActor private(set) var downloadedFileCount: Int = 0
    
    /// Total number of files being downloaded (discovered dynamically) (MainActor for UI)
    @MainActor private(set) var totalFileCount: Int = 0
    
    /// Whether a download is currently in progress (MainActor for UI)
    @MainActor private(set) var isDownloading: Bool = false
    
    /// Name of the model currently being downloaded (MainActor for UI)
    @MainActor private(set) var downloadingModelName: String?
    
    /// Overall download progress (0.0 to 1.0) for granular percentage display
    @MainActor private(set) var overallProgress: Double = 0.0
    
    /// Current download speed in bytes per second
    @MainActor private(set) var downloadSpeedBytesPerSec: Double? = nil
    
    /// Reference to the current download task for cancellation
    @MainActor private var currentDownloadTask: Task<Void, Never>?
    
    /// Set of progress object identifiers we've seen (to count unique files)
    @MainActor private var seenProgressObjects = Set<ObjectIdentifier>()
    
    /// Set of progress object identifiers that have completed
    @MainActor private var completedProgressObjects = Set<ObjectIdentifier>()
    
    /// Whether the service is currently loading a model (MainActor for UI)
    @MainActor private(set) var isLoading: Bool = false
    
    /// Last error message if any operation failed (MainActor for UI)
    @MainActor private(set) var lastError: String?
    
    /// Cached download status for all models (checked at startup and after downloads)
    @MainActor private(set) var modelDownloadStatus: [String: Bool] = [:]
    
    /// Whether the download status is currently being refreshed
    @MainActor private(set) var isRefreshingStatus: Bool = false
    
    @MainActor
    init() {
        logger.info("🤖 MLXService initialized")
        // Check download status for all models at startup
        Task {
            await refreshDownloadStatus()
        }
    }
    
    /// Refresh the cached download status for all models
    /// Called at startup and after downloads complete/cancel
    @MainActor
    func refreshDownloadStatus() async {
        isRefreshingStatus = true
        logger.debug("🔄 Refreshing model download status...")
        
        var status: [String: Bool] = [:]
        for model in Self.availableModels {
            status[model.name] = await isModelDownloaded(name: model.name)
        }
        
        modelDownloadStatus = status
        isRefreshingStatus = false
        
        let downloadedCount = status.values.filter { $0 }.count
        logger.info("✅ Model status refreshed: \(downloadedCount)/\(status.count) downloaded")
    }
    
    /// Synchronous check if a model is ready (from cache)
    /// Returns false if status is unknown (not yet checked)
    @MainActor
    func isModelReady(_ name: String) -> Bool {
        modelDownloadStatus[name] ?? false
    }
    
    /// Formatted download speed for UI display (e.g., "2.3 MB/s")
    @MainActor
    var formattedDownloadSpeed: String? {
        guard let speed = downloadSpeedBytesPerSec else { return nil }
        if speed >= 1_000_000 {
            return String(format: "%.1f MB/s", speed / 1_000_000)
        } else if speed >= 1_000 {
            return String(format: "%.0f KB/s", speed / 1_000)
        } else {
            return String(format: "%.0f B/s", speed)
        }
    }
    
    /// Get a model by name from the available models list
    nonisolated static func model(named name: String) -> LMModel? {
        availableModels.first { $0.name == name }
    }
    
    /// Loads a model from the hub or retrieves it from cache.
    /// Runs on background thread, updates UI state on MainActor.
    /// - Parameter model: The model configuration to load
    /// - Returns: A ModelContainer instance containing the loaded model
    /// - Throws: Errors that might occur during model loading
    private nonisolated func load(model: LMModel) async throws -> ModelContainer {
        // Set GPU memory limit to prevent out of memory issues
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
        
        // Return cached model if available to avoid reloading
        if let container = modelCache.object(forKey: model.name as NSString) {
            logger.debug("📦 Using cached model: \(model.name)")
            return container
        }
        
        // Check if model is already downloaded (on disk but not in memory cache)
        let alreadyDownloaded = await isModelDownloaded(name: model.name)
        
        // Update UI state on MainActor
        await MainActor.run {
            self.isLoading = true
            self.lastError = nil
            self.resetDownloadTracking()
            // Only show downloading UI if model is NOT already downloaded
            if !alreadyDownloaded {
                self.isDownloading = true
                self.downloadingModelName = model.name
            }
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        logger.info("⬇️ Loading model: \(model.name) (downloaded: \(alreadyDownloaded))")
        
        // Select appropriate factory based on model type
        let factory: ModelFactory =
            switch model.type {
            case .llm:
                LLMModelFactory.shared
            case .vlm:
                VLMModelFactory.shared
            }
        
        // Load model and track download progress
        // Note: Progress callbacks may fire even for cached files during verification
        // Only show download UI if the model was not already downloaded
        let container = try await factory.loadContainer(
            hub: HubApi.default, configuration: model.configuration
        ) { [alreadyDownloaded] progress in
            Task { @MainActor in
                // Skip download UI updates if model was already on disk
                // (progress callbacks may fire during file verification)
                guard !alreadyDownloaded else { return }
                
                // Enable downloading UI if not already showing
                if !self.isDownloading {
                    self.isDownloading = true
                    self.downloadingModelName = model.name
                }
                
                self.modelDownloadProgress = progress
                
                // Capture overall progress percentage (0.0 to 1.0)
                self.overallProgress = progress.fractionCompleted
                
                // Capture download speed if available (bytes per second)
                self.downloadSpeedBytesPerSec = progress.userInfo[.throughputKey] as? Double
                
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
        
        // Loading complete - update on MainActor
        await MainActor.run {
            self.isDownloading = false
            self.downloadingModelName = nil
            // Update the download status cache to reflect the model is now available
            self.modelDownloadStatus[model.name] = true
        }
        
        // Cache the loaded model for future use
        modelCache.setObject(container, forKey: model.name as NSString)
        
        logger.info("✅ Model \(model.name) loaded successfully")
        
        return container
    }
    
    /// Generates text based on the provided prompt using the specified model.
    /// Runs on a background thread to avoid blocking the UI.
    /// - Parameters:
    ///   - prompt: The user prompt to generate a response for
    ///   - systemPrompt: Optional system prompt to set context
    ///   - model: The language model to use for generation
    ///   - parameters: Optional generation parameters (temperature, top_p, top_k)
    /// - Returns: The generated text response
    /// - Throws: Errors that might occur during generation
    nonisolated func generate(prompt: String, systemPrompt: String? = nil, model: LMModel, parameters: GenerationParameters?) async throws -> String {
        logger.info("🚀 Generating response with model: \(model.name)")
        let startTime = Date()
        
        // Load or retrieve model from cache (runs on background)
        let modelContainer = try await load(model: model)
        
        // Build chat messages
        var chatMessages: [Chat.Message] = []
        
        if let systemPrompt = systemPrompt {
            chatMessages.append(Chat.Message(role: .system, content: systemPrompt))
        }
        
        chatMessages.append(Chat.Message(role: .user, content: prompt))
        
        // Prepare input for model processing
        let userInput = UserInput(chat: chatMessages)
        
        // Generate response using the model (runs on background)
        var generatedText = ""
        
        let stream = try await modelContainer.perform { (context: ModelContext) in
            let lmInput = try await context.processor.prepare(input: userInput)
            // Use provided parameters or default to grammar correction parameters
            let genParams: GenerationParameters = parameters ?? .grammarCorrection
            // MLX GenerateParameters supports temperature and top_p (but not top_k)
            var mlxParams = GenerateParameters(
                temperature: Float(genParams.temperature),
                topP: Float(genParams.topP ?? 0.95)
            )
            logger.debug("📊 Using MLX parameters: temp=\(genParams.temperature), top_p=\(genParams.topP ?? 0.95)")
            
            return try MLXLMCommon.generate(
                input: lmInput, parameters: mlxParams, context: context)
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
    
    /// Generates text based on the provided prompt and images using a vision model.
    /// Runs on a background thread to avoid blocking the UI.
    /// - Parameters:
    ///   - prompt: The user prompt to generate a response for
    ///   - systemPrompt: Optional system prompt to set context
    ///   - images: Array of image data (PNG/JPEG) for vision understanding
    ///   - model: The vision-language model to use for generation
    ///   - parameters: Optional generation parameters (temperature, top_p, top_k)
    /// - Returns: The generated text response
    /// - Throws: Errors that might occur during generation
    nonisolated func generate(prompt: String, systemPrompt: String? = nil, images: [Data], model: LMModel, parameters: GenerationParameters?) async throws -> String {
        guard model.isVisionModel else {
            // Fall back to text-only generation if not a vision model
            logger.warning("⚠️ Model \(model.name) is not a vision model, ignoring images")
            return try await generate(prompt: prompt, systemPrompt: systemPrompt, model: model, parameters: parameters)
        }
        
        logger.info("🚀 Generating vision response with model: \(model.name), images: \(images.count)")
        let startTime = Date()
        
        // Load or retrieve model from cache (runs on background)
        let modelContainer = try await load(model: model)
        
        // Convert image data to MLX UserInput.Image format (via CIImage)
        // This runs on background thread
        let mlxImages: [UserInput.Image] = images.compactMap { data in
            guard let ciImage = CIImage(data: data) else {
                logger.warning("⚠️ Failed to convert image data to CIImage")
                return nil
            }
            return .ciImage(ciImage)
        }
        
        if mlxImages.count != images.count {
            logger.warning("⚠️ Some images failed to convert: \(images.count) provided, \(mlxImages.count) converted")
        }
        
        // Build chat messages with images
        var chatMessages: [MLXLMCommon.Chat.Message] = []
        
        if let systemPrompt = systemPrompt {
            chatMessages.append(.system(systemPrompt))
        }
        
        chatMessages.append(.user(prompt, images: mlxImages))
        
        // Prepare input for model processing
        let userInput = UserInput(chat: chatMessages)
        
        // Generate response using the model (runs on background)
        var generatedText = ""
        
        let stream = try await modelContainer.perform { (context: ModelContext) in
            let lmInput = try await context.processor.prepare(input: userInput)
            // Use provided parameters or default to lower temperature for vision tasks
            let genParams: GenerationParameters = parameters ?? GenerationParameters(temperature: 0.5, topP: 0.9, topK: nil)
            // MLX GenerateParameters supports temperature and top_p (but not top_k)
            var mlxParams = GenerateParameters(
                temperature: Float(genParams.temperature),
                topP: Float(genParams.topP ?? 0.9)
            )
            logger.debug("📊 Using MLX vision parameters: temp=\(genParams.temperature), top_p=\(genParams.topP ?? 0.9)")
            
            return try MLXLMCommon.generate(
                input: lmInput, parameters: mlxParams, context: context)
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
        logger.info("📥 Vision response generated in \(String(format: "%.2f", elapsed))s")
        
        return generatedText
    }
    
    /// Check if a specific model is loaded/cached in memory
    nonisolated func isModelCached(name: String) -> Bool {
        modelCache.object(forKey: name as NSString) != nil
    }
    
    /// Check if a model is downloaded on disk (Application Support cache)
    /// - Parameter name: The model name to check
    /// - Returns: True if the model files exist in the local cache
    nonisolated func isModelDownloaded(name: String) async -> Bool {
        guard let model = Self.model(named: name) else {
            logger.warning("⚠️ Model not found: \(name)")
            return false
        }
        
        // Check if model is already cached in memory - if so, it's definitely downloaded
        if isModelCached(name: name) {
            return true
        }
        
        // Use the same modelDirectory() method that the Hub API uses internally
        // This ensures we check the exact same path where models are downloaded
        let modelDir = model.configuration.modelDirectory(hub: HubApi.default)
        
        // Check for config.json which is always present in downloaded models
        let configFile = modelDir.appendingPathComponent("config.json")
        let exists = FileManager.default.fileExists(atPath: configFile.path)
        
        if exists {
            logger.debug("✅ Model \(name) found in cache: \(modelDir.path)")
            return true
        }
        
        logger.debug("❌ Model \(name) not found in cache: \(modelDir.path)")
        return false
    }
    
    /// Clear the model cache to free memory
    nonisolated func clearCache() {
        modelCache.removeAllObjects()
        logger.info("🗑️ Model cache cleared")
    }
    
    /// Reset download tracking state for a new download (must be called on MainActor)
    @MainActor
    private func resetDownloadTracking() {
        downloadedFileCount = 0
        totalFileCount = 0
        seenProgressObjects.removeAll()
        completedProgressObjects.removeAll()
        modelDownloadProgress = nil
        overallProgress = 0.0
        downloadSpeedBytesPerSec = nil
    }
    
    /// Check download status for all available models
    /// - Returns: Dictionary mapping model names to their downloaded status
    nonisolated func checkDownloadedModels() async -> [String: Bool] {
        var result: [String: Bool] = [:]
        for model in Self.availableModels {
            result[model.name] = await isModelDownloaded(name: model.name)
        }
        return result
    }
    
    /// Explicitly download a model by name (for background downloading)
    /// This triggers the model loading process which downloads if needed.
    /// - Parameter modelName: Name of the model to download
    @MainActor
    func downloadModel(_ modelName: String) {
        guard let model = Self.model(named: modelName) else {
            logger.warning("⚠️ Cannot download unknown model: \(modelName)")
            return
        }
        
        // Cancel any existing download
        currentDownloadTask?.cancel()
        
        // Store the task for potential cancellation
        currentDownloadTask = Task {
            // Check if already downloaded
            if await isModelDownloaded(name: modelName) {
                logger.info("✅ Model \(modelName) is already downloaded")
                return
            }
            
            logger.info("⬇️ Starting background download for model: \(modelName)")
            
            do {
                // Check for cancellation before starting
                try Task.checkCancellation()
                
                // Load the model which will trigger download if needed
                _ = try await load(model: model)
                logger.info("✅ Background download complete for model: \(modelName)")
                // Refresh download status cache after successful download
                await self.refreshDownloadStatus()
            } catch is CancellationError {
                logger.info("🛑 Download cancelled for model: \(modelName)")
                await MainActor.run {
                    self.isDownloading = false
                    self.downloadingModelName = nil
                    self.resetDownloadTracking()
                }
            } catch {
                logger.error("❌ Failed to download model \(modelName): \(error.localizedDescription)")
                await MainActor.run {
                    self.lastError = "Failed to download \(modelName): \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Cancel the current model download
    @MainActor
    func cancelDownload() {
        guard isDownloading, let task = currentDownloadTask else {
            logger.debug("No download to cancel")
            return
        }
        
        logger.info("🛑 Cancelling download for model: \(self.downloadingModelName ?? "unknown")")
        task.cancel()
        
        // Immediately update UI state
        isDownloading = false
        downloadingModelName = nil
        resetDownloadTracking()
        currentDownloadTask = nil
        
        // Refresh download status cache (model may be partially downloaded)
        Task {
            await refreshDownloadStatus()
        }
    }
}
