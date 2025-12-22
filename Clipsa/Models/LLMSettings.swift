import Foundation

/// Global LLM settings stored in UserDefaults
class LLMSettings: ObservableObject {
    static let shared = LLMSettings()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let customPrompt = "llm_custom_prompt"
        static let autoProcess = "llm_auto_process"
        static let selectedModel = "llm_selected_model"
    }
    
    /// Default model name
    static let defaultModel = "qwen2.5:1.5b"
    
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
    
    /// Selected Ollama model name
    @Published var selectedModel: String {
        didSet {
            defaults.set(selectedModel, forKey: Keys.selectedModel)
        }
    }
    
    private init() {
        self.customPrompt = defaults.string(forKey: Keys.customPrompt) ?? Self.defaultPrompt
        self.autoProcess = defaults.bool(forKey: Keys.autoProcess)
        self.selectedModel = defaults.string(forKey: Keys.selectedModel) ?? Self.defaultModel
        
        // Set default to true if never set
        if defaults.object(forKey: Keys.autoProcess) == nil {
            self.autoProcess = true
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
