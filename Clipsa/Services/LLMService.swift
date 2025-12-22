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

/// Low-level text generation client protocol for DI and mocking.
/// Implementations handle the actual LLM communication (Ollama HTTP, MLX inference).
protocol TextGenerationClient: Sendable {
    /// Display name of the client (e.g., "Ollama", "MLX")
    var name: String { get }
    
    /// Whether the client is currently available
    func isAvailable() async -> Bool
    
    /// Generate text from a prompt
    /// - Parameters:
    ///   - prompt: The prompt to send to the LLM
    ///   - systemPrompt: Optional system prompt to set context
    /// - Returns: Generated text response
    func generate(prompt: String, systemPrompt: String?) async throws -> String
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
    /// Available LLM providers keyed by type
    @Published private(set) var providersByType: [LLMProviderType: any LLMProvider] = [:]
    
    /// Available LLM providers (for backwards compatibility)
    var providers: [any LLMProvider] {
        Array(providersByType.values)
    }
    
    /// Currently active provider
    @Published var activeProvider: (any LLMProvider)?
    
    /// Currently active provider type
    @Published private(set) var activeProviderType: LLMProviderType?
    
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
    
    /// Register an LLM provider with its type
    func registerProvider(_ provider: any LLMProvider, type: LLMProviderType) {
        providersByType[type] = provider
        
        // Set active provider based on settings
        if activeProvider == nil || LLMSettings.shared.selectedProvider == type {
            activeProvider = provider
            activeProviderType = type
        }
    }
    
    /// Register an LLM provider (legacy method for backwards compatibility)
    func registerProvider(_ provider: any LLMProvider) {
        // Determine type from provider name
        let type: LLMProviderType = provider.name == "MLX" ? .mlx : .ollama
        registerProvider(provider, type: type)
    }
    
    /// Set the active provider by type
    func setActiveProvider(type: LLMProviderType) {
        if let provider = providersByType[type] {
            activeProvider = provider
            activeProviderType = type
            LLMSettings.shared.selectedProvider = type
            clearCache() // Clear cache when switching providers
        }
    }
    
    /// Set the active provider by name
    func setActiveProvider(name: String) {
        if let type = LLMProviderType(rawValue: name) {
            setActiveProvider(type: type)
        } else {
            activeProvider = providers.first { $0.name == name }
        }
    }
    
    /// Sync with current settings (call when settings change)
    func syncWithSettings() {
        let preferredType = LLMSettings.shared.selectedProvider
        if let provider = providersByType[preferredType] {
            activeProvider = provider
            activeProviderType = preferredType
        }
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
