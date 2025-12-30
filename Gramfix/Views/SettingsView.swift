import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @ObservedObject var settings = LLMSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Ollama model selection state
    @State private var availableModels: [OllamaModel] = []
    @State private var isLoadingModels: Bool = false
    @State private var modelError: String?
    @State private var customModelName: String = ""
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0
    @State private var isServerReachable: Bool = true
    
    // MLX state - use shared singleton (download status cached in MLXService)
    // Using @State ensures SwiftUI tracks @Observable changes
    @State private var mlxService = MLXService.shared
    @State private var isMLXModelLoading: Bool = false
    
    // History cleanup confirmation alerts
    @State private var showClearTodayAlert: Bool = false
    @State private var showClearAllAlert: Bool = false
    
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
                    
                    startupSection
                    
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
                    
                    infoSection
                    
                    Rectangle()
                        .fill(Color.clipBorder)
                        .frame(height: 1)
                    
                    historySection
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 640)
        .alert("Clear Today's History", isPresented: $showClearTodayAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clipboardManager.clearHistoryForToday()
            }
        } message: {
            Text("This will remove \(clipboardManager.todayItemsCount) item(s) from today. This action cannot be undone.")
        }
        .alert("Clear All History", isPresented: $showClearAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clipboardManager.clearHistory()
            }
        } message: {
            Text("This will permanently delete all \(clipboardManager.items.count) clipboard items and the history file. This action cannot be undone.")
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            fetchModels()
            // Model download status is cached in MLXService and refreshed at startup
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
    
    // MARK: - MLX Model Actions
    
    private func downloadMLXModel(_ modelName: String) {
        mlxService.downloadModel(modelName)
        // Status is automatically refreshed when download completes
    }
    
    private func cancelMLXDownload() {
        mlxService.cancelDownload()
        // Status is automatically refreshed in MLXService.cancelDownload()
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
                    Text("Toggle Gramfix")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Show/hide clipboard manager from anywhere")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                KeyboardShortcuts.Recorder(for: .toggleGramfix)
            }
            .padding(12)
        }
    }
    
    // MARK: - Startup Section
    
    private var startupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LinearGradient.accentGradient)
                
                Text("Startup")
                    .font(.clipTitle)
                    .foregroundStyle(.primary)
            }
            
            // Launch at login toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Launch at login")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Automatically start Gramfix when you log in")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { LoginItemManager.shared.isEnabled },
                    set: { newValue in
                        _ = LoginItemManager.shared.setEnabled(newValue)
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
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
                    
                    Text("Run all text transformations in parallel (Grammar, Formal, Casual, Polished)")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Toggle("", isOn: $settings.autoProcess)
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
        VStack(alignment: .leading, spacing: 16) {
            // Text Model Section
            mlxTextModelPicker
            
            // VLM Model Section
            mlxVLMModelPicker
            
            // MLX download progress (shown for any model download)
            if mlxService.isDownloading {
                mlxDownloadProgressView
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
    
    // MARK: - Text Model Picker
    
    private var mlxTextModelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Text Model")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            
            Text("Used for processing text clipboard items")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
            
            Picker("", selection: $settings.mlxSelectedTextModel) {
                ForEach(MLXService.textModels) { model in
                    mlxModelRow(model: model)
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
            .onChange(of: settings.mlxSelectedTextModel) { _, newValue in
                handleModelSelection(newValue)
            }
            
            // Show download prompt if selected text model is not downloaded
            if !mlxService.isModelReady(settings.mlxSelectedTextModel) {
                if mlxService.isDownloading && mlxService.downloadingModelName == settings.mlxSelectedTextModel {
                    // Already downloading this model - progress shown in global progress view
                } else {
                    modelNotDownloadedBanner(modelName: settings.mlxSelectedTextModel)
                }
            }
        }
    }
    
    // MARK: - VLM Model Picker
    
    private var mlxVLMModelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "eye")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Vision Model")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            
            Text("Used for analyzing image clipboard items")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
            
            Picker("", selection: $settings.mlxSelectedVLMModel) {
                ForEach(MLXService.visionModels) { model in
                    mlxModelRow(model: model)
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
            .onChange(of: settings.mlxSelectedVLMModel) { _, newValue in
                handleModelSelection(newValue)
            }
            
            // Show download prompt if selected VLM model is not downloaded
            if !mlxService.isModelReady(settings.mlxSelectedVLMModel) {
                if mlxService.isDownloading && mlxService.downloadingModelName == settings.mlxSelectedVLMModel {
                    // Already downloading this model - progress shown in global progress view
                } else {
                    modelNotDownloadedBanner(modelName: settings.mlxSelectedVLMModel)
                }
            }
        }
    }
    
    // MARK: - Model Row Helper
    
    @ViewBuilder
    private func mlxModelRow(model: LMModel) -> some View {
        HStack(spacing: 6) {
            Text(model.name)
            
            if mlxService.isRefreshingStatus {
                // Still checking at startup
            } else if mlxService.isModelReady(model.name) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Model Not Downloaded Banner
    
    private func modelNotDownloadedBanner(modelName: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 12))
                .foregroundStyle(Color.clipAccent)
            
            Text("Model not downloaded")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button {
                downloadMLXModel(modelName)
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
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Download Progress View
    
    private var mlxDownloadProgressView: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 12))
                .foregroundStyle(Color.clipAccent)
            
            if let modelName = mlxService.downloadingModelName {
                Text(modelName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            
            if mlxService.overallProgress > 0 {
                ProgressView(value: mlxService.overallProgress)
                    .frame(maxWidth: .infinity)
                
                Text("\(Int(mlxService.overallProgress * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                
                if let speed = mlxService.formattedDownloadSpeed {
                    Text(speed)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            } else {
                ProgressView()
                    .scaleEffect(0.7)
                
                Text("Starting...")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            
            // Cancel button
            Button {
                cancelMLXDownload()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Cancel download")
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Handle Model Selection
    
    private func handleModelSelection(_ modelName: String) {
        // Check if model is downloaded (from cached status)
        if !mlxService.isModelReady(modelName) {
            // Auto-download in background when selecting a non-downloaded model
            downloadMLXModel(modelName)
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
                
                // Text transformations
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text transformations:")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    ForEach(TextPromptType.allCases) { promptType in
                        HStack(spacing: 8) {
                            Text(promptType.displayName)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .frame(width: 60, alignment: .leading)
                            
                            Text(promptTypeDescription(promptType))
                                .font(.system(size: 11, design: .rounded))
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
        Text("When you copy text, Gramfix runs 4 transformations in parallel. Click the prompt tags to switch between results. Press 1-4 to quickly select a result.")
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
            .lineSpacing(4)
    }
    
    private func promptTypeDescription(_ type: TextPromptType) -> String {
        switch type {
        case .grammar: return "Fix grammar and spelling errors"
        case .formal: return "Make text more professional"
        case .casual: return "Remove jargon, simplify"
        case .polished: return "Polished business style"
        }
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.8))
                
                Text("History Management")
                    .font(.clipTitle)
                    .foregroundStyle(.primary)
            }
            
            Text("Clear clipboard history items")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
            
            // Clear today's history button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clear Today's History")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("\(clipboardManager.todayItemsCount) item(s) from today")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Button {
                    showClearTodayAlert = true
                } label: {
                    Text("Clear")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            clipboardManager.todayItemsCount > 0
                                ? Color.orange
                                : Color.gray.opacity(0.5),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .disabled(clipboardManager.todayItemsCount == 0)
            }
            .padding(12)
            
            // Clear all history button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clear All History")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("\(clipboardManager.items.count) total item(s) + storage file")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Button {
                    showClearAllAlert = true
                } label: {
                    Text("Clear All")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            clipboardManager.items.count > 0
                                ? Color.red
                                : Color.gray.opacity(0.5),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .disabled(clipboardManager.items.count == 0)
            }
            .padding(12)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ClipboardManager())
}
