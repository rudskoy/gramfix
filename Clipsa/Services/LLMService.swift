import Foundation

/// Result of LLM processing for clipboard content
struct LLMResult: Equatable, Sendable {
    /// Full raw response from the LLM
    let response: String?
    /// Short summary of the content (1-2 sentences)
    let summary: String?
    /// Extracted tags/categories
    let tags: [String]
    /// Content type classification (code, email, url, note, etc.)
    let contentType: String?
    /// Error message if processing failed
    let error: String?
    
    static let empty = LLMResult(response: nil, summary: nil, tags: [], contentType: nil, error: nil)
    
    static func failure(_ error: String) -> LLMResult {
        LLMResult(response: nil, summary: nil, tags: [], contentType: nil, error: error)
    }
}

/// Request type for LLM processing
enum LLMRequestType: String, Sendable {
    case summarize = "summarize"
    case extractTags = "tags"
    case classify = "classify"
    case all = "all"
    case custom = "custom"  // Uses LLMSettings.customPrompt
}

/// Protocol defining the interface for LLM providers
protocol LLMProvider: Sendable {
    /// Display name of the provider
    var name: String { get }
    
    /// Whether the provider is currently available
    func isAvailable() async -> Bool
    
    /// Process text content with the LLM
    /// - Parameters:
    ///   - text: The text content to process
    ///   - requestType: Type of processing to perform
    /// - Returns: LLM processing result
    func process(_ text: String, requestType: LLMRequestType) async throws -> LLMResult
    
    /// Generate a custom response based on a prompt
    /// - Parameters:
    ///   - prompt: The prompt to send to the LLM
    ///   - context: Optional context (e.g., clipboard content)
    /// - Returns: Generated text response
    func generate(prompt: String, context: String?) async throws -> String
}

/// Main LLM service that manages providers and handles requests
@MainActor
class LLMService: ObservableObject {
    /// Available LLM providers
    @Published private(set) var providers: [any LLMProvider] = []
    
    /// Currently active provider
    @Published var activeProvider: (any LLMProvider)?
    
    /// Whether the service is currently processing
    @Published private(set) var isProcessing: Bool = false
    
    /// Last error message
    @Published private(set) var lastError: String?
    
    /// Cache for processed results (keyed by content hash)
    private var resultCache: [Int: LLMResult] = [:]
    private let maxCacheSize = 100
    
    init() {
        // Providers will be registered during app startup
    }
    
    /// Register an LLM provider
    func registerProvider(_ provider: any LLMProvider) {
        providers.append(provider)
        if activeProvider == nil {
            activeProvider = provider
        }
    }
    
    /// Set the active provider by name
    func setActiveProvider(name: String) {
        activeProvider = providers.first { $0.name == name }
    }
    
    /// Check if any provider is available
    func isAvailable() async -> Bool {
        guard let provider = activeProvider else { return false }
        return await provider.isAvailable()
    }
    
    /// Process clipboard text content
    func processContent(_ text: String, requestType: LLMRequestType = .custom) async -> LLMResult {
        guard let provider = activeProvider else {
            return .failure("No LLM provider configured")
        }
        
        // Check cache first
        let cacheKey = text.hashValue
        if let cached = resultCache[cacheKey] {
            return cached
        }
        
        // Skip very short or very long content
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else {
            return .empty
        }
        guard trimmed.count <= 10000 else {
            return .failure("Content too long for processing")
        }
        
        isProcessing = true
        lastError = nil
        
        defer {
            isProcessing = false
        }
        
        do {
            let result = try await provider.process(trimmed, requestType: requestType)
            
            // Cache the result
            if resultCache.count >= maxCacheSize {
                resultCache.removeAll()
            }
            resultCache[cacheKey] = result
            
            return result
        } catch {
            let errorMessage = error.localizedDescription
            lastError = errorMessage
            return .failure(errorMessage)
        }
    }
    
    /// Generate custom response
    func generate(prompt: String, context: String? = nil) async -> Result<String, Error> {
        guard let provider = activeProvider else {
            return .failure(LLMError.noProvider)
        }
        
        isProcessing = true
        lastError = nil
        
        defer {
            isProcessing = false
        }
        
        do {
            let response = try await provider.generate(prompt: prompt, context: context)
            return .success(response)
        } catch {
            lastError = error.localizedDescription
            return .failure(error)
        }
    }
    
    /// Clear the result cache
    func clearCache() {
        resultCache.removeAll()
    }
}

/// LLM-specific errors
enum LLMError: LocalizedError {
    case noProvider
    case providerUnavailable
    case invalidResponse
    case timeout
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .noProvider:
            return "No LLM provider is configured"
        case .providerUnavailable:
            return "LLM provider is not available"
        case .invalidResponse:
            return "Invalid response from LLM"
        case .timeout:
            return "LLM request timed out"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
