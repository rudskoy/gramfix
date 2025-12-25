import Foundation
import SwiftUI

/// Available app appearance themes
enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    /// Cycle to next theme
    var next: AppTheme {
        switch self {
        case .system: return .light
        case .light: return .dark
        case .dark: return .system
        }
    }
}

/// Available LLM providers
enum LLMProviderType: String, CaseIterable, Identifiable {
    case ollama = "Ollama"
    case mlx = "MLX"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var icon: String {
        switch self {
        case .ollama: return "server.rack"
        case .mlx: return "cpu"
        }
    }
    
    var description: String {
        switch self {
        case .ollama: return "Local Ollama server"
        case .mlx: return "On-device Apple Silicon"
        }
    }
}

/// Predefined text transformation prompts for parallel processing
enum TextPromptType: String, CaseIterable, Codable, Identifiable {
    case grammar = "grammar"
    case formal = "formal"
    case casual = "casual"
    case polished = "polished"
    
    var id: String { rawValue }
    
    /// Short label for tag display
    var displayName: String {
        switch self {
        case .grammar: return "Grammar"
        case .formal: return "+Formal"
        case .casual: return "Casual"
        case .polished: return "Polished"
        }
    }
    
    /// Full prompt template ({text} is replaced with content)
    var prompt: String {
        switch self {
        case .grammar:
            return "Fix grammar errors in this text. Output ONLY the corrected text, nothing else:\n\n{text}"
        case .formal:
            return "Make this text slightly more formal and professional. Keep the meaning intact. Output ONLY the revised text:\n\n{text}"
        case .casual:
            return "Simplify this text by removing jargon and buzzwords. Make it direct and clear. Output ONLY the simplified text:\n\n{text}"
        case .polished:
            return "Rephrase this text in a polished, professional style. Output ONLY the rephrased text:\n\n{text}"
        }
    }
    
    /// Build the final prompt by replacing {text} with actual content
    func buildPrompt(for text: String) -> String {
        prompt.replacingOccurrences(of: "{text}", with: text)
    }
}

/// Global LLM settings stored in UserDefaults
class LLMSettings: ObservableObject {
    static let shared = LLMSettings()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let autoProcess = "llm_auto_process"
        static let selectedModel = "llm_selected_model"
        static let selectedProvider = "llm_selected_provider"
        static let mlxSelectedModel = "llm_mlx_model" // Legacy key for migration
        static let mlxSelectedTextModel = "llm_mlx_text_model"
        static let mlxSelectedVLMModel = "llm_mlx_vlm_model"
        static let appTheme = "app_theme"
        static let imageAnalysisEnabled = "llm_image_analysis_enabled"
    }
    
    /// Default Ollama model name
    static let defaultModel = "qwen2.5:1.5b"
    
    /// Default MLX text model name
    static let defaultMLXTextModel = "qwen2.5:1.5b"
    
    /// Default MLX VLM model name for image analysis
    static let defaultMLXVLMModel = "qwen3-vl:4b"
    
    /// Default provider - auto-detect Apple Silicon and prefer MLX
    static var defaultProvider: LLMProviderType {
        #if arch(arm64)
        // Apple Silicon (M1/M2/M3/M4) - use MLX for on-device inference
        return .mlx
        #else
        // Intel Mac - use Ollama
        return .ollama
        #endif
    }
    
    /// Whether running on Apple Silicon
    static var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    /// Whether auto-processing is enabled
    @Published var autoProcess: Bool {
        didSet {
            defaults.set(autoProcess, forKey: Keys.autoProcess)
        }
    }
    
    /// Selected Ollama model name
    @Published var selectedModel: String {
        didSet {
            defaults.set(selectedModel, forKey: Keys.selectedModel)
        }
    }
    
    /// Selected LLM provider
    @Published var selectedProvider: LLMProviderType {
        didSet {
            defaults.set(selectedProvider.rawValue, forKey: Keys.selectedProvider)
        }
    }
    
    /// Selected MLX text model name (for text processing)
    @Published var mlxSelectedTextModel: String {
        didSet {
            defaults.set(mlxSelectedTextModel, forKey: Keys.mlxSelectedTextModel)
        }
    }
    
    /// Selected MLX VLM model name (for image analysis)
    @Published var mlxSelectedVLMModel: String {
        didSet {
            defaults.set(mlxSelectedVLMModel, forKey: Keys.mlxSelectedVLMModel)
        }
    }
    
    /// App appearance theme
    @Published var appTheme: AppTheme {
        didSet {
            defaults.set(appTheme.rawValue, forKey: Keys.appTheme)
        }
    }
    
    /// Whether on-demand image analysis is enabled
    @Published var imageAnalysisEnabled: Bool {
        didSet {
            defaults.set(imageAnalysisEnabled, forKey: Keys.imageAnalysisEnabled)
        }
    }
    
    private init() {
        self.autoProcess = defaults.bool(forKey: Keys.autoProcess)
        self.selectedModel = defaults.string(forKey: Keys.selectedModel) ?? Self.defaultModel
        
        // Load provider selection
        if let providerRaw = defaults.string(forKey: Keys.selectedProvider),
           let provider = LLMProviderType(rawValue: providerRaw) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = Self.defaultProvider
        }
        
        // Load MLX model selections with migration from legacy single model
        let legacyModel = defaults.string(forKey: Keys.mlxSelectedModel)
        
        // Load text model (migrate from legacy if new key doesn't exist)
        if let textModel = defaults.string(forKey: Keys.mlxSelectedTextModel) {
            self.mlxSelectedTextModel = textModel
        } else if let legacy = legacyModel {
            // Migrate: if legacy was a text model, use it; otherwise use default
            self.mlxSelectedTextModel = legacy.contains("vision") || legacy.contains("-vl:") ? Self.defaultMLXTextModel : legacy
        } else {
            self.mlxSelectedTextModel = Self.defaultMLXTextModel
        }
        
        // Load VLM model (always use default if not set, don't migrate from legacy text model)
        self.mlxSelectedVLMModel = defaults.string(forKey: Keys.mlxSelectedVLMModel) ?? Self.defaultMLXVLMModel
        
        // Load app theme
        if let themeRaw = defaults.string(forKey: Keys.appTheme),
           let theme = AppTheme(rawValue: themeRaw) {
            self.appTheme = theme
        } else {
            self.appTheme = .system
        }
        
        // Set default to true if never set
        if defaults.object(forKey: Keys.autoProcess) == nil {
            self.autoProcess = true
        }
        
        // Load image analysis setting (default: false)
        self.imageAnalysisEnabled = defaults.bool(forKey: Keys.imageAnalysisEnabled)
    }
}
