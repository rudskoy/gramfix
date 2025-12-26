import Foundation
import AppKit

enum ClipboardType: String, Codable {
    case text
    case link
    case image
    case file
    case other
}

struct ClipboardItem: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    let content: String
    let rawData: Data?
    let type: ClipboardType
    let timestamp: Date
    let appName: String?
    
    // Cached formatted time string for performance (not persisted, recomputed on load)
    let formattedTime: String
    
    // MARK: - Multi-Prompt Results
    
    /// Results from multiple prompts (keyed by TextPromptType.rawValue)
    var promptResults: [String: String]
    
    /// Currently selected prompt ID for display/paste (defaults to "grammar")
    var selectedPromptId: String
    
    /// Set of prompt IDs currently being processed (transient, not persisted)
    var promptProcessingIds: Set<String>
    
    // MARK: - Image Analysis fields
    
    /// VLM-generated image description (for image clipboard items)
    var imageAnalysisResponse: String?
    
    /// Whether image analysis is currently in progress (transient, not persisted)
    var imageAnalysisProcessing: Bool
    
    /// Whether image analysis should be performed (captured when item was created)
    /// Only images captured while the toggle was ON should be auto-analyzed
    let shouldAnalyzeImage: Bool
    
    // MARK: - Codable
    
    /// Coding keys - excludes transient processing states and computed formattedTime
    enum CodingKeys: String, CodingKey {
        case id, content, rawData, type, timestamp, appName
        case promptResults, selectedPromptId
        case imageAnalysisResponse, shouldAnalyzeImage
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        rawData = try container.decodeIfPresent(Data.self, forKey: .rawData)
        type = try container.decode(ClipboardType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        appName = try container.decodeIfPresent(String.self, forKey: .appName)
        
        // Multi-prompt fields (default to empty if not present - legacy items)
        promptResults = try container.decodeIfPresent([String: String].self, forKey: .promptResults) ?? [:]
        selectedPromptId = try container.decodeIfPresent(String.self, forKey: .selectedPromptId) ?? TextPromptType.grammar.rawValue
        
        // Transient state - always start empty when loading
        promptProcessingIds = []
        
        // Image analysis fields
        imageAnalysisResponse = try container.decodeIfPresent(String.self, forKey: .imageAnalysisResponse)
        imageAnalysisProcessing = false
        // Default to false for backward compatibility (old items won't be auto-analyzed)
        shouldAnalyzeImage = try container.decodeIfPresent(Bool.self, forKey: .shouldAnalyzeImage) ?? false
        
        // Recompute formatted time from timestamp
        formattedTime = Self.timeFormatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    init(
        id: UUID = UUID(),
        content: String,
        rawData: Data? = nil,
        type: ClipboardType = .text,
        timestamp: Date = Date(),
        appName: String? = nil,
        promptResults: [String: String] = [:],
        selectedPromptId: String = TextPromptType.grammar.rawValue,
        promptProcessingIds: Set<String> = [],
        imageAnalysisResponse: String? = nil,
        imageAnalysisProcessing: Bool = false,
        shouldAnalyzeImage: Bool = false
    ) {
        self.id = id
        self.content = content
        self.rawData = rawData
        self.type = type
        self.timestamp = timestamp
        self.appName = appName
        self.formattedTime = Self.timeFormatter.localizedString(for: timestamp, relativeTo: Date())
        self.promptResults = promptResults
        self.selectedPromptId = selectedPromptId
        self.promptProcessingIds = promptProcessingIds
        self.imageAnalysisResponse = imageAnalysisResponse
        self.imageAnalysisProcessing = imageAnalysisProcessing
        self.shouldAnalyzeImage = shouldAnalyzeImage
    }
    
    // MARK: - Prompt Result Helpers
    
    /// Whether any prompt has been processed
    var hasAnyPromptResult: Bool {
        !promptResults.isEmpty
    }
    
    /// Whether any prompt is currently processing
    var isProcessing: Bool {
        !promptProcessingIds.isEmpty
    }
    
    /// Number of completed prompt results
    var completedPromptCount: Int {
        promptResults.count
    }
    
    /// Total number of prompts
    var totalPromptCount: Int {
        TextPromptType.allCases.count
    }
    
    /// Get result for the currently selected prompt
    var selectedPromptResult: String? {
        promptResults[selectedPromptId]
    }
    
    /// Create a copy with a prompt result
    func withPromptResult(type: TextPromptType, response: String) -> ClipboardItem {
        var updated = self
        updated.promptResults[type.rawValue] = response
        updated.promptProcessingIds.remove(type.rawValue)
        return updated
    }
    
    /// Create a copy with prompt processing state
    func withPromptProcessing(type: TextPromptType, processing: Bool) -> ClipboardItem {
        var updated = self
        if processing {
            updated.promptProcessingIds.insert(type.rawValue)
        } else {
            updated.promptProcessingIds.remove(type.rawValue)
        }
        return updated
    }
    
    /// Create a copy with all prompts marked as processing
    func withAllPromptsProcessing() -> ClipboardItem {
        var updated = self
        updated.promptProcessingIds = Set(TextPromptType.allCases.map(\.rawValue))
        return updated
    }
    
    /// Create a copy with selected prompt ID
    func withSelectedPrompt(_ promptId: String) -> ClipboardItem {
        var updated = self
        updated.selectedPromptId = promptId
        return updated
    }
    
    /// Create a copy with image analysis result
    func withImageAnalysisResult(_ response: String) -> ClipboardItem {
        var updated = self
        updated.imageAnalysisResponse = response
        updated.imageAnalysisProcessing = false
        return updated
    }
    
    /// Create a copy with image analysis processing state
    func withImageAnalysisProcessingState(_ processing: Bool) -> ClipboardItem {
        var updated = self
        updated.imageAnalysisProcessing = processing
        return updated
    }
    
    /// Display text showing AI response preview if processed, otherwise original content
    var smartPreview: String {
        // For images, prefer VLM description if available
        if type == .image, let analysis = imageAnalysisResponse, !analysis.isEmpty {
            return analysis
        }
        
        // For text, prefer selected prompt result if available
        if let response = selectedPromptResult, !response.isEmpty {
            // Clean and truncate AI response same as compactPreview
            let cleaned = response
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\t", with: " ")
                .trimmingCharacters(in: .whitespaces)
            if cleaned.count > 60 {
                return String(cleaned.prefix(60)) + "…"
            }
            return cleaned
        }
        return compactPreview
    }
    
    /// Check if content matches search query (includes prompt results)
    func matchesSearch(_ query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        
        // Check original content
        if content.localizedCaseInsensitiveContains(query) {
            return true
        }
        
        // Check all prompt results
        for (_, result) in promptResults {
            if result.localizedCaseInsensitiveContains(query) {
                return true
            }
        }
        
        return false
    }
    
    // Shared formatter - expensive to create
    private static let timeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    // Compact single-line preview for list
    var compactPreview: String {
        let cleaned = content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.count > 60 {
            return String(cleaned.prefix(60)) + "…"
        }
        return cleaned
    }
    
    // Full preview (keeps formatting)
    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "…"
        }
        return trimmed
    }
    
    /// Content to paste - selected prompt result if available, otherwise original
    var pasteContent: String {
        if let aiResponse = selectedPromptResult, !aiResponse.isEmpty {
            return aiResponse
        }
        return content
    }
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.promptProcessingIds == rhs.promptProcessingIds &&
        lhs.promptResults == rhs.promptResults &&
        lhs.selectedPromptId == rhs.selectedPromptId &&
        lhs.imageAnalysisProcessing == rhs.imageAnalysisProcessing
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(promptProcessingIds)
        hasher.combine(promptResults)
        hasher.combine(selectedPromptId)
        hasher.combine(imageAnalysisProcessing)
    }
}
