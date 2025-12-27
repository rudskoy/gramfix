//
//  LLMProviderImpl.swift
//  Gramfix
//
//  Unified LLM provider implementation using TextGenerationClient for DI.
//  Contains all shared prompt-building and response-parsing logic.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.gramfix.app", category: "LLMProviderImpl")

/// Unified LLM provider implementation that uses a TextGenerationClient for actual text generation.
/// This class contains all shared logic for prompt building and response parsing.
final class LLMProviderImpl: LLMProvider, @unchecked Sendable {
    private let client: any TextGenerationClient
    
    /// Display name comes from the underlying client
    var name: String { client.name }
    
    /// System prompt used for all requests
    private let systemPrompt = "You are a helpful assistant. Respond concisely and accurately."
    
    init(client: any TextGenerationClient) {
        self.client = client
        logger.info("🤖 LLMProviderImpl initialized with client: \(client.name)")
    }
    
    /// Check if the underlying client is available
    func isAvailable() async -> Bool {
        await client.isAvailable()
    }
    
    /// Process text with the LLM
    func process(_ text: String, requestType: LLMRequestType) async throws -> LLMResult {
        let textPreview = String(text.prefix(50)).replacingOccurrences(of: "\n", with: " ")
        logger.info("🚀 Processing text (\(text.count) chars): \"\(textPreview)...\" with requestType: \(requestType.rawValue)")
        
        let prompt = buildPrompt(for: requestType, text: text)
        logger.debug("📝 Built prompt (\(prompt.count) chars)")
        
        do {
            let response = try await client.generate(prompt: prompt, systemPrompt: systemPrompt)
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
        return try await client.generate(prompt: fullPrompt, systemPrompt: systemPrompt)
    }
    
    // MARK: - Multi-Prompt Processing
    
    /// Process text with a specific prompt type from the predefined set
    /// - Parameters:
    ///   - text: The text content to process
    ///   - promptType: The type of text transformation to apply
    /// - Returns: The processed text response
    func processWithPromptType(_ text: String, promptType: TextPromptType) async throws -> String {
        let textPreview = String(text.prefix(50)).replacingOccurrences(of: "\n", with: " ")
        logger.info("Processing text (\(text.count) chars) with prompt: \(promptType.displayName)")
        
        let prompt = promptType.buildPrompt(for: text)
        
        do {
            let response = try await client.generate(prompt: prompt, systemPrompt: systemPrompt)
            let cleaned = cleanResponse(response)
            logger.info("Completed \(promptType.displayName): \(cleaned.prefix(50))...")
            return cleaned
        } catch {
            logger.error("Failed \(promptType.displayName): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Clean LLM response by removing prompt echoes and formatting artifacts
    private func cleanResponse(_ response: String) -> String {
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
            "corrected version",
            "revised text",
            "simplified text",
            "rephrased text"
        ]
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let lowerLine = trimmedLine.lowercased()
            
            // Skip lines that look like prompt echoes
            let isPromptEcho = skipPatterns.contains { lowerLine.hasPrefix($0) }
            if isPromptEcho {
                logger.debug("Skipping prompt echo: \(trimmedLine.prefix(30))...")
                continue
            }
            
            // Skip empty lines at the start
            if textLines.isEmpty && trimmedLine.isEmpty {
                continue
            }
            
            textLines.append(line)
        }
        
        var cleaned = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clean up any remaining format markers and markdown
        cleaned = cleaned
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    // MARK: - Prompt Building
    
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
            Extract up to 5 relevant tags/keywords from the following text. Output only comma-separated tags, nothing else.
            
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
            // Legacy: use grammar prompt as default
            return TextPromptType.grammar.buildPrompt(for: text)
        }
    }
    
    // MARK: - Response Parsing
    
    /// Parse the LLM response based on request type
    private func parseResponse(_ response: String, requestType: LLMRequestType) -> LLMResult {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch requestType {
        case .summarize:
            return LLMResult(response: cleaned, summary: cleaned, tags: [], contentType: nil, error: nil)
            
        case .extractTags:
            let allTags = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let tags = Array(allTags.prefix(5)) // Limit to 5 tags
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
            let limitedTags = Array((parsed.tags ?? []).prefix(5)) // Limit to 5 tags
            logger.info("✅ PARSED RESULT: summary=\"\(parsed.summary ?? "nil")\", tags=\(limitedTags), type=\"\(parsed.type ?? "nil")\"")
            return LLMResult(
                response: response,
                summary: parsed.summary,
                tags: limitedTags,
                contentType: parsed.type,
                error: nil
            )
        } catch {
            logger.error("❌ JSON parsing failed: \(error.localizedDescription)")
            logger.error("❌ Raw response was: \(response)")
            return LLMResult(response: response, summary: response, tags: [], contentType: nil, error: nil)
        }
    }
    
    /// Parse custom response - cleans up any prompt echoes
    /// Note: Tags are extracted via a separate async query, not from custom prompt response
    private func parseCustomResponse(_ response: String) -> LLMResult {
        var correctedText = response
        
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
        
        logger.info("✅ PARSED CUSTOM: text=\(correctedText.prefix(50))...")
        
        return LLMResult(response: correctedText, summary: nil, tags: [], contentType: nil, error: nil)
    }
}

