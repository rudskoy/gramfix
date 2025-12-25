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
    
    // MARK: - LLM-generated fields
    
    /// Full LLM response text (the main processed output)
    var llmResponse: String?
    
    /// AI-generated summary of the content (legacy, kept for compatibility)
    var llmSummary: String?
    
    /// AI-extracted tags/keywords
    var llmTags: [String]
    
    /// AI-classified content type (code, email, url, note, etc.)
    var llmContentType: String?
    
    /// Whether LLM processing has been attempted
    var llmProcessed: Bool
    
    /// Whether LLM processing is currently in progress (transient, not persisted)
    var llmProcessing: Bool
    
    /// Whether tag extraction is currently in progress (transient, not persisted)
    var llmTagsProcessing: Bool
    
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
        case llmResponse, llmSummary, llmTags, llmContentType, llmProcessed
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
        llmResponse = try container.decodeIfPresent(String.self, forKey: .llmResponse)
        llmSummary = try container.decodeIfPresent(String.self, forKey: .llmSummary)
        llmTags = try container.decodeIfPresent([String].self, forKey: .llmTags) ?? []
        llmContentType = try container.decodeIfPresent(String.self, forKey: .llmContentType)
        llmProcessed = try container.decodeIfPresent(Bool.self, forKey: .llmProcessed) ?? false
        
        // Transient states - always start as false when loading
        llmProcessing = false
        llmTagsProcessing = false
        
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
        llmResponse: String? = nil,
        llmSummary: String? = nil,
        llmTags: [String] = [],
        llmContentType: String? = nil,
        llmProcessed: Bool = false,
        llmProcessing: Bool = false,
        llmTagsProcessing: Bool = false,
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
        self.llmResponse = llmResponse
        self.llmSummary = llmSummary
        self.llmTags = llmTags
        self.llmContentType = llmContentType
        self.llmProcessed = llmProcessed
        self.llmProcessing = llmProcessing
        self.llmTagsProcessing = llmTagsProcessing
        self.imageAnalysisResponse = imageAnalysisResponse
        self.imageAnalysisProcessing = imageAnalysisProcessing
        self.shouldAnalyzeImage = shouldAnalyzeImage
    }
    
    /// Create a copy with updated LLM result (main prompt only, tags come from separate query)
    func withLLMResult(_ result: LLMResult) -> ClipboardItem {
        var updated = self
        updated.llmResponse = result.response
        updated.llmSummary = result.summary
        // Note: Tags are NOT updated here - they come from a separate async query
        updated.llmContentType = result.contentType
        updated.llmProcessed = true
        updated.llmProcessing = false
        return updated
    }
    
    /// Create a copy with updated tags from the async tag extraction query
    func withTagsResult(_ tags: [String]) -> ClipboardItem {
        var updated = self
        updated.llmTags = tags
        updated.llmTagsProcessing = false
        return updated
    }
    
    /// Create a copy with processing state
    func withProcessingState(_ processing: Bool) -> ClipboardItem {
        var updated = self
        updated.llmProcessing = processing
        return updated
    }
    
    /// Create a copy with tag processing state
    func withTagsProcessingState(_ processing: Bool) -> ClipboardItem {
        var updated = self
        updated.llmTagsProcessing = processing
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
        
        // For text, prefer LLM response if available
        if let response = llmResponse, !response.isEmpty {
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
    
    /// Formatted tags for display
    var formattedTags: String {
        llmTags.joined(separator: ", ")
    }
    
    /// Check if content matches search query (includes LLM fields)
    func matchesSearch(_ query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        
        // Check original content
        if content.localizedCaseInsensitiveContains(query) {
            return true
        }
        
        // Check LLM summary
        if let summary = llmSummary, summary.localizedCaseInsensitiveContains(query) {
            return true
        }
        
        // Check LLM tags
        if llmTags.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
            return true
        }
        
        // Check LLM content type
        if let contentType = llmContentType, contentType.lowercased().contains(lowercasedQuery) {
            return true
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
    
    /// Content to paste - AI response if available, otherwise original
    var pasteContent: String {
        if let aiResponse = llmResponse, !aiResponse.isEmpty {
            return aiResponse
        }
        return content
    }
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.llmProcessing == rhs.llmProcessing &&
        lhs.llmTagsProcessing == rhs.llmTagsProcessing &&
        lhs.imageAnalysisProcessing == rhs.imageAnalysisProcessing
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(llmProcessing)
        hasher.combine(llmTagsProcessing)
        hasher.combine(imageAnalysisProcessing)
    }
}
