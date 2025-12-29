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
    let rtfData: Data?
    let htmlData: Data?  // HTML formatted data (preferred by Telegram, Slack, etc.)
    /// All pasteboard data types captured from the original copy (preserves app-specific formats)
    let allPasteboardData: [String: Data]?
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
    
    // MARK: - Language Detection and Translation fields
    
    /// Language detected by LLM (for text clipboard items)
    var detectedLanguage: SupportedLanguage?
    
    /// User-selected target language for translation (nil = show original/detected)
    var selectedTargetLanguage: SupportedLanguage?
    
    /// Translations cached per language code (e.g., ["ru": "...", "ja": "..."])
    var translatedResults: [String: String]
    
    /// Whether language detection is currently in progress (transient, not persisted)
    var languageDetectionProcessing: Bool
    
    /// Set of language codes currently being translated (transient, not persisted)
    var translationProcessingLanguages: Set<String>
    
    /// Legacy: Whether translation is currently in progress (kept for compatibility)
    var translationProcessing: Bool
    
    // MARK: - Codable
    
    /// Coding keys - excludes transient processing states and computed formattedTime
    enum CodingKeys: String, CodingKey {
        case id, content, rawData, rtfData, htmlData, allPasteboardData, type, timestamp, appName
        case promptResults, selectedPromptId
        case imageAnalysisResponse, shouldAnalyzeImage
        case detectedLanguage, selectedTargetLanguage, translatedResults
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        rawData = try container.decodeIfPresent(Data.self, forKey: .rawData)
        rtfData = try container.decodeIfPresent(Data.self, forKey: .rtfData)
        htmlData = try container.decodeIfPresent(Data.self, forKey: .htmlData)
        allPasteboardData = try container.decodeIfPresent([String: Data].self, forKey: .allPasteboardData)
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
        
        // Language detection and translation fields
        detectedLanguage = try container.decodeIfPresent(SupportedLanguage.self, forKey: .detectedLanguage)
        selectedTargetLanguage = try container.decodeIfPresent(SupportedLanguage.self, forKey: .selectedTargetLanguage)
        translatedResults = try container.decodeIfPresent([String: String].self, forKey: .translatedResults) ?? [:]
        languageDetectionProcessing = false
        translationProcessingLanguages = []
        translationProcessing = false
        
        // Recompute formatted time from timestamp
        formattedTime = Self.timeFormatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    init(
        id: UUID = UUID(),
        content: String,
        rawData: Data? = nil,
        rtfData: Data? = nil,
        htmlData: Data? = nil,
        allPasteboardData: [String: Data]? = nil,
        type: ClipboardType = .text,
        timestamp: Date = Date(),
        appName: String? = nil,
        promptResults: [String: String] = [:],
        selectedPromptId: String = TextPromptType.grammar.rawValue,
        promptProcessingIds: Set<String> = [],
        imageAnalysisResponse: String? = nil,
        imageAnalysisProcessing: Bool = false,
        shouldAnalyzeImage: Bool = false,
        detectedLanguage: SupportedLanguage? = nil,
        selectedTargetLanguage: SupportedLanguage? = nil,
        translatedResults: [String: String] = [:],
        languageDetectionProcessing: Bool = false,
        translationProcessingLanguages: Set<String> = [],
        translationProcessing: Bool = false
    ) {
        self.id = id
        self.content = content
        self.rawData = rawData
        self.rtfData = rtfData
        self.htmlData = htmlData
        self.allPasteboardData = allPasteboardData
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
        self.detectedLanguage = detectedLanguage
        self.selectedTargetLanguage = selectedTargetLanguage
        self.translatedResults = translatedResults
        self.languageDetectionProcessing = languageDetectionProcessing
        self.translationProcessingLanguages = translationProcessingLanguages
        self.translationProcessing = translationProcessing
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
    
    // MARK: - Language Detection and Translation Helpers
    
    /// Create a copy with detected language
    func withDetectedLanguage(_ language: SupportedLanguage) -> ClipboardItem {
        var updated = self
        updated.detectedLanguage = language
        updated.languageDetectionProcessing = false
        return updated
    }
    
    /// Create a copy with language detection processing state
    func withLanguageDetectionProcessingState(_ processing: Bool) -> ClipboardItem {
        var updated = self
        updated.languageDetectionProcessing = processing
        return updated
    }
    
    /// Create a copy with selected target language
    func withSelectedTargetLanguage(_ language: SupportedLanguage?) -> ClipboardItem {
        var updated = self
        updated.selectedTargetLanguage = language
        return updated
    }
    
    /// Create a copy with translation processing state (legacy)
    func withTranslationProcessingState(_ processing: Bool) -> ClipboardItem {
        var updated = self
        updated.translationProcessing = processing
        return updated
    }
    
    /// Create a copy with a translation result for a specific language
    func withTranslationResult(languageCode: String, translation: String) -> ClipboardItem {
        var updated = self
        updated.translatedResults[languageCode] = translation
        updated.translationProcessingLanguages.remove(languageCode)
        return updated
    }
    
    /// Create a copy with translation processing state for a specific language
    func withTranslationProcessing(languageCode: String, processing: Bool) -> ClipboardItem {
        var updated = self
        if processing {
            updated.translationProcessingLanguages.insert(languageCode)
        } else {
            updated.translationProcessingLanguages.remove(languageCode)
        }
        return updated
    }
    
    /// Create a copy with all non-detected languages marked as processing
    func withAllTranslationsProcessing() -> ClipboardItem {
        var updated = self
        let languagesToTranslate = SupportedLanguage.allCases.filter { $0 != detectedLanguage }
        updated.translationProcessingLanguages = Set(languagesToTranslate.map(\.rawValue))
        return updated
    }
    
    /// Whether translation is needed (target language differs from detected)
    var needsTranslation: Bool {
        guard let target = selectedTargetLanguage, let detected = detectedLanguage else {
            return false
        }
        return target != detected
    }
    
    /// Current language to display (target if set, otherwise detected)
    var displayLanguage: SupportedLanguage? {
        selectedTargetLanguage ?? detectedLanguage
    }
    
    /// Get translated content for the selected target language, or nil if not available
    var translatedContent: String? {
        guard let target = selectedTargetLanguage else { return nil }
        return translatedResults[target.rawValue]
    }
    
    /// Whether any translation is currently processing
    var isTranslating: Bool {
        !translationProcessingLanguages.isEmpty
    }
    
    /// Whether the selected target translation is still processing
    var isSelectedTranslationProcessing: Bool {
        guard let target = selectedTargetLanguage else { return false }
        return translationProcessingLanguages.contains(target.rawValue)
    }
    
    /// AI response to display - translation if target differs from detected, otherwise prompt result
    var displayedAIResponse: String? {
        // If target language is set and different from detected, show translation
        if let target = selectedTargetLanguage,
           let detected = detectedLanguage,
           target != detected {
            // Return translation if available
            return translatedResults[target.rawValue]
        }
        // Otherwise, return the normal prompt result
        return selectedPromptResult
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
    
    /// Content to paste - translation if available, then AI response, then original
    var pasteContent: String {
        // Prefer translated content if a target language is selected
        if let translated = displayedAIResponse, !translated.isEmpty {
            return translated
        }
        // Fall back to selected prompt result
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
        lhs.imageAnalysisProcessing == rhs.imageAnalysisProcessing &&
        lhs.detectedLanguage == rhs.detectedLanguage &&
        lhs.selectedTargetLanguage == rhs.selectedTargetLanguage &&
        lhs.translatedResults == rhs.translatedResults &&
        lhs.languageDetectionProcessing == rhs.languageDetectionProcessing &&
        lhs.translationProcessingLanguages == rhs.translationProcessingLanguages
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(promptProcessingIds)
        hasher.combine(promptResults)
        hasher.combine(selectedPromptId)
        hasher.combine(imageAnalysisProcessing)
        hasher.combine(detectedLanguage)
        hasher.combine(selectedTargetLanguage)
        hasher.combine(translatedResults)
        hasher.combine(languageDetectionProcessing)
        hasher.combine(translationProcessingLanguages)
    }
}
