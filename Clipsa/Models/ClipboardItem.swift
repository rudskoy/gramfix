import Foundation
import AppKit

enum ClipboardType: String, Codable {
    case text
    case image
    case file
    case other
}

struct ClipboardItem: Identifiable, Equatable, Hashable {
    let id: UUID
    let content: String
    let rawData: Data?
    let type: ClipboardType
    let timestamp: Date
    let appName: String?
    
    // Cached formatted time string for performance
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
    
    /// Whether LLM processing is currently in progress
    var llmProcessing: Bool
    
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
        llmProcessing: Bool = false
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
    }
    
    /// Create a copy with updated LLM result
    func withLLMResult(_ result: LLMResult) -> ClipboardItem {
        var updated = self
        updated.llmResponse = result.response
        updated.llmSummary = result.summary
        updated.llmTags = result.tags
        updated.llmContentType = result.contentType
        updated.llmProcessed = true
        updated.llmProcessing = false
        return updated
    }
    
    /// Create a copy with processing state
    func withProcessingState(_ processing: Bool) -> ClipboardItem {
        var updated = self
        updated.llmProcessing = processing
        return updated
    }
    
    /// Display text combining original preview with LLM summary
    var smartPreview: String {
        if let summary = llmSummary, !summary.isEmpty {
            return summary
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
        lhs.id == rhs.id && lhs.llmProcessing == rhs.llmProcessing
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(llmProcessing)
    }
}
