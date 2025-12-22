//
//  OllamaClient.swift
//  Clipsa
//
//  Thin wrapper around ollama-swift Client implementing TextGenerationClient.
//  Also contains static model management methods for SettingsView.
//

import Foundation
import os.log
import Ollama

private let logger = Logger(subsystem: "com.clipsa.app", category: "OllamaClient")

/// Represents an Ollama model with metadata
struct OllamaModel: Identifiable, Hashable {
    let id: String
    let name: String
    let size: Int64
    let modifiedAt: String
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

/// Ollama text generation client implementing TextGenerationClient protocol.
/// Thin wrapper around the ollama-swift library.
actor OllamaClient: TextGenerationClient {
    nonisolated let name: String = "Ollama"
    
    private let hostURL: URL
    private var _client: Client?
    
    /// Model name - reads from LLMSettings
    private var modelName: String {
        LLMSettings.shared.selectedModel
    }
    
    /// Lazily initialized client to avoid async init issues
    private var client: Client {
        get async {
            if let existing = _client {
                return existing
            }
            // Use default client for localhost, or create custom client for other hosts
            let newClient: Client
            if hostURL.absoluteString == "http://localhost:11434" {
                newClient = await Client.default
            } else {
                newClient = await Client(host: hostURL)
            }
            _client = newClient
            return newClient
        }
    }
    
    /// Shared client for static methods
    private static var sharedClient: Client?
    
    private static func getSharedClient() async -> Client {
        if let existing = sharedClient {
            return existing
        }
        let newClient = await Client.default
        sharedClient = newClient
        return newClient
    }
    
    init(baseURL: String = "http://localhost:11434") {
        self.hostURL = URL(string: baseURL)!
        logger.info("🤖 OllamaClient initialized: baseURL=\(baseURL)")
    }
    
    // MARK: - TextGenerationClient Protocol
    
    /// Check if Ollama is running and the model is available
    func isAvailable() async -> Bool {
        logger.debug("🔍 Checking Ollama availability")
        
        do {
            let ollamaClient = await client
            let response = try await ollamaClient.listModels()
            let availableModels = response.models.map { $0.name }
            logger.debug("📦 Available models: \(availableModels.joined(separator: ", "))")
            
            let modelPrefix = modelName.split(separator: ":").first.map(String.init) ?? modelName
            let isModelAvailable = response.models.contains { $0.name.hasPrefix(modelPrefix) }
            logger.info("✅ Ollama available: \(isModelAvailable), looking for model: \(self.modelName)")
            return isModelAvailable
        } catch {
            logger.error("❌ Ollama availability check failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Generate text from a prompt using Ollama
    func generate(prompt: String, systemPrompt: String?) async throws -> String {
        logger.debug("📤 Sending request to Ollama with model: \(self.modelName)")
        let startTime = Date()
        
        do {
            let ollamaClient = await client
            let response = try await ollamaClient.generate(
                model: Model.ID(stringLiteral: modelName),
                prompt: prompt,
                think: false  // Disable reasoning/thinking mode for faster responses
            )
            
            let elapsed = Date().timeIntervalSince(startTime)
            logger.info("📥 Response received in \(String(format: "%.2f", elapsed))s")
            logger.info("📥 Ollama LLM output:\n\(response.response)")
            
            return response.response
        } catch {
            logger.error("❌ Ollama request failed: \(error.localizedDescription)")
            throw LLMError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Static Model Management (for SettingsView)
    
    /// List all available models from Ollama
    static func listAvailableModels() async throws -> [OllamaModel] {
        logger.info("📦 Fetching available models from Ollama")
        
        let ollamaClient = await getSharedClient()
        let response = try await ollamaClient.listModels()
        
        let models = response.models.map { model in
            OllamaModel(
                id: model.name,
                name: model.name,
                size: model.size,
                modifiedAt: model.modifiedAt
            )
        }
        
        logger.info("📦 Found \(models.count) models: \(models.map { $0.name }.joined(separator: ", "))")
        return models
    }
    
    /// Check if a specific model is available locally
    static func isModelAvailable(_ modelName: String) async -> Bool {
        do {
            let models = try await listAvailableModels()
            let modelPrefix = modelName.split(separator: ":").first.map(String.init) ?? modelName
            return models.contains { $0.name.hasPrefix(modelPrefix) || $0.name == modelName }
        } catch {
            logger.error("❌ Failed to check model availability: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Pull (download) a model from Ollama registry
    /// - Parameters:
    ///   - modelName: Name of the model to pull (e.g., "llama3.2:1b")
    ///   - onProgress: Callback with download progress (0.0 to 1.0)
    static func pullModel(_ modelName: String, onProgress: @escaping @Sendable (Double) -> Void) async throws {
        logger.info("⬇️ Starting download of model: \(modelName)")
        
        // Use direct HTTP API for streaming progress
        let url = URL(string: "http://localhost:11434/api/pull")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["name": modelName]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LLMError.networkError("Failed to pull model: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        // Parse streaming JSON lines for progress
        for try await line in bytes.lines {
            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // Check for error
                if let error = json["error"] as? String {
                    throw LLMError.networkError(error)
                }
                
                // Parse progress
                if let total = json["total"] as? Int64, total > 0,
                   let completed = json["completed"] as? Int64 {
                    let progressValue = Double(completed) / Double(total)
                    logger.debug("⬇️ Download progress: \(String(format: "%.1f", progressValue * 100))%")
                    onProgress(progressValue)
                }
                
                // Check if done
                if let status = json["status"] as? String, status == "success" {
                    logger.info("✅ Model \(modelName) downloaded successfully")
                    onProgress(1.0)
                    return
                }
            }
        }
        
        logger.info("✅ Model \(modelName) download completed")
        onProgress(1.0)
    }
    
    /// Check if Ollama server is reachable
    static func isServerReachable() async -> Bool {
        do {
            _ = try await listAvailableModels()
            return true
        } catch {
            logger.error("❌ Ollama server not reachable: \(error.localizedDescription)")
            return false
        }
    }
}

