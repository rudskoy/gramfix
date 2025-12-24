import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var settings = LLMSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var promptText: String = ""
    @State private var hasChanges: Bool = false
    
    // Ollama model selection state
    @State private var availableModels: [OllamaModel] = []
    @State private var isLoadingModels: Bool = false
    @State private var modelError: String?
    @State private var customModelName: String = ""
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0
    @State private var isServerReachable: Bool = true
    
    // MLX state - use shared singleton
    private var mlxService: MLXService { MLXService.shared }
    @State private var isMLXModelLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            // Subtle separator
            Rectangle()
                .fill(Color.clipBorder)
                .frame(height: 1)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    shortcutSection
                    
                    Rectangle()
                        .fill(Color.clipBorder)
                        .frame(height: 1)
                    
                    aiToggleSection
                    
                    Rectangle()
                        .fill(Color.clipBorder)
                        .frame(height: 1)
                    
                    providerSection
                    
                    Rectangle()
                        .fill(Color.clipBorder)
                        .frame(height: 1)
                    
                    modelSection
                    
                    Rectangle()
                        .fill(Color.clipBorder)
                        .frame(height: 1)
                    
                    promptSection
                    
                    Rectangle()
                        .fill(Color.clipBorder)
                        .frame(height: 1)
                    
                    infoSection
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            promptText = settings.customPrompt
            fetchModels()
        }
        .onChange(of: promptText) { _, newValue in
            hasChanges = newValue != settings.customPrompt
        }
    }
    
    // MARK: - Model Fetching
    
    private func fetchModels() {
        isLoadingModels = true
        modelError = nil
        
        Task {
            do {
                let models = try await OllamaClient.listAvailableModels()
                await MainActor.run {
                    availableModels = models
                    isLoadingModels = false
                    isServerReachable = true
                }
            } catch {
                await MainActor.run {
                    modelError = error.localizedDescription
                    isLoadingModels = false
                    isServerReachable = false
                }
            }
        }
    }
    
    private func downloadModel(_ modelName: String) {
        isDownloading = true
        downloadProgress = 0
        
        Task {
            do {
                try await OllamaClient.pullModel(modelName) { progress in
                    Task { @MainActor in
                        downloadProgress = progress
                    }
                }
                await MainActor.run {
                    isDownloading = false
                    settings.selectedModel = modelName
                    customModelName = ""
                    fetchModels() // Refresh the list
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    modelError = "Download failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private var isCurrentModelAvailable: Bool {
        availableModels.contains { $0.name == settings.selectedModel || $0.name.hasPrefix(settings.selectedModel.split(separator: ":").first.map(String.init) ?? settings.selectedModel) }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.clipHeader)
                    .foregroundStyle(.primary)
                
                Text("Configure AI processing")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.clipAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
    }
    
    // MARK: - Shortcut Section
    
    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LinearGradient.accentGradient)
                
                Text("Global Shortcut")
                    .font(.clipTitle)
                    .foregroundStyle(.primary)
            }
            
            Text("Press the shortcut keys to change")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
            
            // Shortcut recorder
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Toggle Clipsa")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Show/hide clipboard manager from anywhere")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                KeyboardShortcuts.Recorder(for: .toggleClipsa)
            }
            .padding(12)
        }
    }
    
    // MARK: - AI Toggle Section
    
    private var aiToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LinearGradient.accentGradient)
                
                Text("AI Processing")
                    .font(.clipTitle)
                    .foregroundStyle(.primary)
            }
            
            // Auto-process toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-process clipboard")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Automatically analyze copied text with AI")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Toggle("", isOn: $settings.autoProcess)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(12)
            
            // Detect tags toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Detect tags")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Extract keywords using a separate AI query")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Toggle("", isOn: $settings.detectTags)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(12)
        }
    }
    
    // MARK: - Provider Section
    
    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LinearGradient.accentGradient)
                
                Text("LLM Provider")
                    .font(.clipTitle)
                    .foregroundStyle(.primary)
            }
            
            Text("Choose between local Ollama server or on-device MLX inference")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
            
            // Provider picker
            HStack(spacing: 8) {
                ForEach(LLMProviderType.allCases) { provider in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            settings.selectedProvider = provider
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: provider.icon)
                                .font(.system(size: 14, weight: .medium))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                
                                Text(provider.description)
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(.tertiary)
                            }
                            
                            Spacer()
                            
                            if settings.selectedProvider == provider {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.clipAccent)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(
                            settings.selectedProvider == provider
                                ? Color.clipAccent.opacity(0.15)
                                : Color.primary.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    settings.selectedProvider == provider
                                        ? Color.clipAccent.opacity(0.5)
                                        : Color.primary.opacity(0.1),
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
            }
        }
    }
    
    // MARK: - Model Section
    
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LinearGradient.accentGradient)
                
                Text(settings.selectedProvider == .ollama ? "Ollama Model" : "MLX Model")
                    .font(.clipTitle)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Status indicator
                if settings.selectedProvider == .ollama {
                    if isLoadingModels {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Circle()
                            .fill(isServerReachable ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(isServerReachable ? "Ollama running" : "Ollama offline")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    // MLX status
                    if isMLXModelLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Loading...")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    } else {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("Apple Silicon ready")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            if settings.selectedProvider == .mlx {
                mlxModelSection
            } else if !isServerReachable {
                // Offline message
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    
                    Text("Start Ollama to manage models")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        fetchModels()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.clipAccent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            } else {
                // Model picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select from installed models")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                    
                    Picker("", selection: $settings.selectedModel) {
                        ForEach(availableModels) { model in
                            HStack {
                                Text(model.name)
                                Text("(\(model.formattedSize))")
                                    .foregroundStyle(.tertiary)
                            }
                            .tag(model.name)
                        }
                        
                        // Show current selection even if not in list
                        if !availableModels.contains(where: { $0.name == settings.selectedModel }) {
                            HStack {
                                Text(settings.selectedModel)
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                            .tag(settings.selectedModel)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    }
                }
                
                // Model status
                if !isCurrentModelAvailable && !availableModels.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        
                        Text("Model '\(settings.selectedModel)' is not installed")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if isDownloading {
                            ProgressView(value: downloadProgress)
                                .frame(width: 60)
                            Text("\(Int(downloadProgress * 100))%")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        } else {
                            Button {
                                downloadModel(settings.selectedModel)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 11))
                                    Text("Download")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(LinearGradient.accentGradient, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                }
                
                // Download new model
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or download a new model")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                    
                    HStack(spacing: 8) {
                        TextField("Model name (e.g., llama3.2:1b)", text: $customModelName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(10)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            }
                        
                        if isDownloading && !customModelName.isEmpty {
                            VStack(spacing: 2) {
                                ProgressView(value: downloadProgress)
                                    .frame(width: 50)
                                Text("\(Int(downloadProgress * 100))%")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        } else {
                            Button {
                                guard !customModelName.isEmpty else { return }
                                downloadModel(customModelName)
                            } label: {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(customModelName.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.clipAccent))
                            }
                            .buttonStyle(.plain)
                            .disabled(customModelName.isEmpty || isDownloading)
                        }
                    }
                }
            }
            
            // Error display
            if let error = modelError {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                    
                    Text(error)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.red.opacity(0.8))
                        .lineLimit(2)
                }
            }
        }
    }
    
    // MARK: - MLX Model Section
    
    private var mlxModelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select from available MLX models")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
            
            // MLX model picker
            Picker("", selection: $settings.mlxSelectedModel) {
                ForEach(MLXService.availableModels) { model in
                    HStack {
                        Text(model.displayName)
                        if model.isVisionModel {
                            Image(systemName: "eye")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(model.name)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            }
            
            // MLX download progress
            if mlxService.isDownloading {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.clipAccent)
                    
                    if mlxService.totalFileCount > 0 {
                        // Show progress based on file count
                        ProgressView(value: Double(mlxService.downloadedFileCount), total: Double(mlxService.totalFileCount))
                            .frame(maxWidth: .infinity)
                        
                        Text("Downloading \(mlxService.downloadedFileCount)/\(mlxService.totalFileCount) files")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    } else {
                        // Show indeterminate progress while discovering files
                        ProgressView()
                            .scaleEffect(0.7)
                        
                        Text("Starting download...")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
            
            // MLX info
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Text("MLX models run entirely on-device using Apple Silicon. First use downloads the model (~1-4 GB).")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // MARK: - Prompt Section
    
    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LinearGradient.accentGradient)
                
                Text("Custom Prompt")
                    .font(.clipTitle)
                    .foregroundStyle(.primary)
            }
            
            Text("Use {text} as a placeholder for clipboard content")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
            
            // Text editor with glass styling
            TextEditor(text: $promptText)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 180)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                }
            
            // Action buttons
            HStack {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        settings.resetToDefault()
                        promptText = settings.customPrompt
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .medium))
                        Text("Reset to Default")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        settings.customPrompt = promptText
                        hasChanges = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Save")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(hasChanges ? .white : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        if hasChanges {
                            Capsule().fill(LinearGradient.accentGradient)
                        } else {
                            Capsule().fill(.clear)
                        }
                    }
                    .background {
                        if !hasChanges {
                            Capsule().fill(Color.primary.opacity(0.1))
                        }
                    }
                    .shadow(color: hasChanges ? Color.clipAccent.opacity(0.4) : .clear, radius: 8)
                }
                .buttonStyle(.plain)
                .disabled(!hasChanges)
            }
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.clipAccent)
                
                Text("How it works")
                    .font(.clipTitle)
                    .foregroundStyle(.primary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                infoText
                
                // Example prompts in glass cards
                VStack(alignment: .leading, spacing: 8) {
                    Text("Example prompts:")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    ForEach(examplePrompts, id: \.self) { prompt in
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.tertiary)
                            
                            Text(prompt)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }
    
    private var infoText: some View {
        Text("When you copy text, Clipsa sends it to your selected LLM provider (Ollama or MLX) with your custom prompt. The AI response appears in the preview pane.")
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
            .lineSpacing(4)
    }
    
    private let examplePrompts = [
        "Explain this code: {text}",
        "Translate to English: {text}",
        "Summarize in 3 bullet points: {text}",
        "Find bugs in this code: {text}"
    ]
}

#Preview {
    SettingsView()
}
