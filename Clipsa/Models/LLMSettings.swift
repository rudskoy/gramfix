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

/// Global LLM settings stored in UserDefaults
class LLMSettings: ObservableObject {
    static let shared = LLMSettings()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let customPrompt = "llm_custom_prompt"
        static let autoProcess = "llm_auto_process"
        static let detectTags = "llm_detect_tags"
        static let selectedModel = "llm_selected_model"
        static let selectedProvider = "llm_selected_provider"
        static let mlxSelectedModel = "llm_mlx_model"
        static let appTheme = "app_theme"
    }
    
    /// Default Ollama model name
    static let defaultModel = "qwen2.5:1.5b"
    
    /// Default MLX model name
    static let defaultMLXModel = "qwen2.5:1.5b"
    
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
    
    /// Default prompt template - {text} will be replaced with clipboard content
    static let defaultPrompt = """
Fix grammar errors in this text. Output ONLY the corrected text, nothing else:

{text}
"""
    
    /// Custom processing prompt - use {text} as placeholder for clipboard content
    @Published var customPrompt: String {
        didSet {
            defaults.set(customPrompt, forKey: Keys.customPrompt)
        }
    }
    
    /// Whether auto-processing is enabled
    @Published var autoProcess: Bool {
        didSet {
            defaults.set(autoProcess, forKey: Keys.autoProcess)
        }
    }
    
    /// Whether to detect tags using a separate async LLM query
    @Published var detectTags: Bool {
        didSet {
            defaults.set(detectTags, forKey: Keys.detectTags)
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
    
    /// Selected MLX model name
    @Published var mlxSelectedModel: String {
        didSet {
            defaults.set(mlxSelectedModel, forKey: Keys.mlxSelectedModel)
        }
    }
    
    /// App appearance theme
    @Published var appTheme: AppTheme {
        didSet {
            defaults.set(appTheme.rawValue, forKey: Keys.appTheme)
        }
    }
    
    private init() {
        self.customPrompt = defaults.string(forKey: Keys.customPrompt) ?? Self.defaultPrompt
        self.autoProcess = defaults.bool(forKey: Keys.autoProcess)
        self.detectTags = defaults.bool(forKey: Keys.detectTags)
        self.selectedModel = defaults.string(forKey: Keys.selectedModel) ?? Self.defaultModel
        
        // Load provider selection
        if let providerRaw = defaults.string(forKey: Keys.selectedProvider),
           let provider = LLMProviderType(rawValue: providerRaw) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = Self.defaultProvider
        }
        
        // Load MLX model selection
        self.mlxSelectedModel = defaults.string(forKey: Keys.mlxSelectedModel) ?? Self.defaultMLXModel
        
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
        
        // Set default to true if never set
        if defaults.object(forKey: Keys.detectTags) == nil {
            self.detectTags = true
        }
    }
    
    /// Build the final prompt by replacing {text} with actual content
    func buildPrompt(for text: String) -> String {
        return customPrompt.replacingOccurrences(of: "{text}", with: text)
    }
    
    /// Reset to default prompt
    func resetToDefault() {
        customPrompt = Self.defaultPrompt
    }
}
