import Foundation
import os.log
import Ollama

private let logger = Logger(subsystem: "com.clipsa.app", category: "Ollama")

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

/// Ollama LLM provider using ollama-swift library
actor OllamaProvider: LLMProvider {
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
        logger.info("🤖 OllamaProvider initialized: baseURL=\(baseURL), model will be read from settings")
    }
    
    // MARK: - Static Model Management
    
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
    
    /// Process text with Ollama
    func process(_ text: String, requestType: LLMRequestType) async throws -> LLMResult {
        let textPreview = String(text.prefix(50)).replacingOccurrences(of: "\n", with: " ")
        logger.info("🚀 Processing text (\(text.count) chars): \"\(textPreview)...\" with requestType: \(requestType.rawValue)")
        
        let prompt = buildPrompt(for: requestType, text: text)
        logger.debug("📝 Built prompt (\(prompt.count) chars)")
        
        do {
            let response = try await sendRequest(prompt: prompt)
            let result = parseResponse(response, requestType: requestType)
            logger.info("✅ Processing complete - summary: \(result.summary ?? "nil"), tags: \(result.tags), type: \(result.contentType ?? "nil")")
            return result
        } catch {
            logger.error("❌ Processing failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Generate custom response
    func generate(prompt: String, context: String?) async throws -> String {
        var fullPrompt = prompt
        if let context = context {
            fullPrompt = """
            Context:
            \(context)
            
            \(prompt)
            """
        }
        return try await sendRequest(prompt: fullPrompt)
    }
    
    /// Build the prompt based on request type
    private func buildPrompt(for requestType: LLMRequestType, text: String) -> String {
        switch requestType {
        case .summarize:
            return """
            Summarize the following text in one brief sentence (max 100 characters). Only output the summary, nothing else.
            
            Text:
            \(text)
            """
            
        case .extractTags:
            return """
            Extract 1-3 relevant tags/keywords from the following text. Output only comma-separated tags, nothing else.
            
            Text:
            \(text)
            """
            
        case .classify:
            return """
            Classify the following text into one category: code, email, url, note, address, phone, json, command, or other.
            Output only the category name, nothing else.
            
            Text:
            \(text)
            """
            
        case .all:
            return """
            Analyze the following text and provide a JSON response with these fields:
            - "summary": one brief sentence summary (max 100 chars)
            - "tags": array of 1-3 relevant keywords
            - "type": one of: code, email, url, note, address, phone, json, command, other
            
            Output only valid JSON, nothing else.
            
            Text:
            \(text)
            """
            
        case .custom:
            return LLMSettings.shared.buildPrompt(for: text)
        }
    }
    
    /// Parse the LLM response based on request type
    private func parseResponse(_ response: String, requestType: LLMRequestType) -> LLMResult {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch requestType {
        case .summarize:
            return LLMResult(response: cleaned, summary: cleaned, tags: [], contentType: nil, error: nil)
            
        case .extractTags:
            let tags = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            return LLMResult(response: cleaned, summary: nil, tags: tags, contentType: nil, error: nil)
            
        case .classify:
            return LLMResult(response: cleaned, summary: nil, tags: [], contentType: cleaned.lowercased(), error: nil)
            
        case .all:
            return parseJSONResponse(cleaned)
            
        case .custom:
            return parseCustomResponse(cleaned)
        }
    }
    
    /// Parse JSON response for combined request
    private func parseJSONResponse(_ response: String) -> LLMResult {
        logger.debug("🔍 Parsing JSON response: \(response)")
        
        var jsonString = response
        if let startIndex = response.firstIndex(of: "{"),
           let endIndex = response.lastIndex(of: "}") {
            jsonString = String(response[startIndex...endIndex])
            logger.debug("🔍 Extracted JSON: \(jsonString)")
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            logger.warning("⚠️ Could not convert to data, using raw response as summary")
            return LLMResult(response: response, summary: response, tags: [], contentType: nil, error: nil)
        }
        
        struct CombinedResponse: Codable {
            let summary: String?
            let tags: [String]?
            let type: String?
        }
        
        do {
            let parsed = try JSONDecoder().decode(CombinedResponse.self, from: data)
            logger.info("✅ PARSED RESULT: summary=\"\(parsed.summary ?? "nil")\", tags=\(parsed.tags ?? []), type=\"\(parsed.type ?? "nil")\"")
            return LLMResult(
                response: response,
                summary: parsed.summary,
                tags: parsed.tags ?? [],
                contentType: parsed.type,
                error: nil
            )
        } catch {
            logger.error("❌ JSON parsing failed: \(error.localizedDescription)")
            logger.error("❌ Raw response was: \(response)")
            return LLMResult(response: response, summary: response, tags: [], contentType: nil, error: nil)
        }
    }
    
    /// Parse custom response - cleans up any prompt echoes and extracts tags if present
    private func parseCustomResponse(_ response: String) -> LLMResult {
        var correctedText = response
        var tags: [String] = []
        
        let lines = response.components(separatedBy: "\n")
        var textLines: [String] = []
        
        // Patterns to skip (prompt echoes)
        let skipPatterns = [
            "fix grammar",
            "correct grammar",
            "output only",
            "nothing else",
            "corrected text",
            "**corrected text",
            "result:",
            "here is",
            "here's the",
            "the corrected",
            "corrected version"
        ]
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let lowerLine = trimmedLine.lowercased()
            
            // Extract tags
            if lowerLine.hasPrefix("tags:") {
                let tagsString = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                tags = tagsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                logger.debug("🏷️ Extracted tags: \(tags)")
                continue
            }
            
            // Skip lines that look like prompt echoes
            let isPromptEcho = skipPatterns.contains { lowerLine.hasPrefix($0) }
            if isPromptEcho {
                logger.debug("⏭️ Skipping prompt echo: \(trimmedLine.prefix(30))...")
                continue
            }
            
            // Skip empty lines at the start
            if textLines.isEmpty && trimmedLine.isEmpty {
                continue
            }
            
            textLines.append(line)
        }
        
        correctedText = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clean up any remaining format markers and markdown
        correctedText = correctedText
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        logger.info("✅ PARSED CUSTOM: text=\(correctedText.prefix(50))..., tags=\(tags)")
        
        return LLMResult(response: correctedText, summary: nil, tags: tags, contentType: nil, error: nil)
    }
    
    /// Send request to Ollama using ollama-swift library
    private func sendRequest(prompt: String) async throws -> String {
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
}
