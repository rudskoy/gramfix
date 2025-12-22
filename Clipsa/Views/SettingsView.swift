import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = LLMSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var promptText: String = ""
    @State private var hasChanges: Bool = false
    
    // Model selection state
    @State private var availableModels: [OllamaModel] = []
    @State private var isLoadingModels: Bool = false
    @State private var modelError: String?
    @State private var customModelName: String = ""
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0
    @State private var isServerReachable: Bool = true
    
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
        .glassEffect()
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
                let models = try await OllamaProvider.listAvailableModels()
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
                try await OllamaProvider.pullModel(modelName) { progress in
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
            // Otter mascot in settings
            OtterMascot(size: 36, animated: false)
            
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
                    .glassEffect(in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .glassEffect()
    }
    
    // MARK: - Model Section
    
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LinearGradient.accentGradient)
                
                Text("AI Model")
                    .font(.clipTitle)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Server status indicator
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
            }
            
            if !isServerReachable {
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
                .glassEffect(in: .rect(cornerRadius: 8))
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
                    .glassEffect(in: .rect(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
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
                    .glassEffect(in: .rect(cornerRadius: 8))
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
                            .glassEffect(in: .rect(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
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
                .glassEffect(in: .rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
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
                    .glassEffect(in: .capsule)
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
                            Capsule().glassEffect()
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
                        .glassEffect(in: .rect(cornerRadius: 6))
                    }
                }
            }
        }
    }
    
    private var infoText: some View {
        Text("When you copy text, Clipsa sends it to Ollama with your custom prompt. The AI response appears in the preview pane.")
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
