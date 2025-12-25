import SwiftUI
import AppKit

struct PreviewPane: View {
    let item: ClipboardItem?
    @EnvironmentObject var clipboardManager: ClipboardManager
    @ObservedObject private var settings = LLMSettings.shared
    
    // Reference to shared MLX service for download status
    // Using @State to store the reference ensures SwiftUI tracks @Observable changes
    @State private var mlxService = MLXService.shared
    
    var body: some View {
        Group {
            if let item = item {
                VStack(alignment: .leading, spacing: 0) {
                    // Content
                    previewContent(item: item)
                }
                .id(item.id)  // Stabilize view identity to prevent recreation
                .transaction { $0.animation = nil }  // Prevent animation flash on item change
            } else {
                emptyPreview
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private func previewContent(item: ClipboardItem) -> some View {
        switch item.type {
        case .text:
            // Two sections: AI response on top, Original on bottom (equal split)
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // LLM processed content section
                    VStack(alignment: .leading, spacing: 0) {
                        textProcessingHeader(item: item)
                        
                        if item.llmProcessing {
                            processingPlaceholder
                        } else if let response = item.llmResponse, !response.isEmpty {
                            VStack(spacing: 0) {
                                ScrollView {
                                    Text(response)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(14)
                                }
                                
                                // Tags at the bottom
                                if !item.llmTags.isEmpty {
                                    tagsFooter(tags: item.llmTags)
                                }
                            }
                        } else if !item.llmProcessed {
                            notProcessedPlaceholder
                        } else {
                            VStack(spacing: 8) {
                                Text("¯\\_(ツ)_/¯")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundStyle(.tertiary)
                                
                                Text("Nothing to generate.")
                                    .font(.system(size: 12, weight: .medium, design: .default))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        }
                    }
                    .frame(height: geometry.size.height / 2)
                    
                    // Original content section
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader(title: "Original", icon: "doc.on.doc", isActive: true, timestamp: item.timestamp) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.content, forType: .string)
                        }
                        ScrollView {
                            Text(item.content)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                        }
                    }
                    .frame(height: geometry.size.height / 2)
                }
            }
        case .link:
            VStack(spacing: 16) {
                Image(systemName: "link")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(LinearGradient.accentGradient)
                    .shadow(color: .clipAccent.opacity(0.3), radius: 12)
                
                Text(item.content)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding(.horizontal)
                
                // Action buttons
                HStack(spacing: 16) {
                    LinkActionButton(
                        icon: "doc.on.doc",
                        label: "Copy",
                        showsCheckmark: true
                    ) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.content, forType: .string)
                    }
                    
                    LinkActionButton(
                        icon: "safari",
                        label: "Open"
                    ) {
                        if let url = URL(string: item.content) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .image:
            if let data = item.rawData, let nsImage = NSImage(data: data) {
                VStack(spacing: 0) {
                    // Image Analysis section (when enabled)
                    if settings.imageAnalysisEnabled {
                        imageAnalysisSection(item: item, imageData: data)
                    }
                    
                    // Image preview
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(14)
                            .padding(8)
                            .glassEffect(in: .rect(cornerRadius: 12))
                    }
                    .padding(8)
                }
                .onAppear {
                    checkModelAndAnalyze(item: item, imageData: data)
                }
                .onChange(of: settings.imageAnalysisEnabled) { _, newValue in
                    if newValue {
                        checkModelAndAnalyze(item: item, imageData: data)
                    }
                }
            } else {
                placeholderContent(icon: "photo", text: "Image preview unavailable")
            }
        case .file:
            VStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(LinearGradient.accentGradient)
                    .shadow(color: .clipAccent.opacity(0.3), radius: 12)
                
                Text(item.content)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .other:
            placeholderContent(icon: "doc", text: item.content)
        }
    }
    
    // MARK: - Image Analysis
    
    @ViewBuilder
    private func imageAnalysisSection(item: ClipboardItem, imageData: Data) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Custom header with model status on the right
            imageAnalysisHeader(item: item, imageData: imageData)
            
            // Content area
            if mlxService.isRefreshingStatus {
                // Checking model status at startup - no extra content needed, shown in header
                EmptyView()
            } else if mlxService.isDownloading && mlxService.downloadingModelName == settings.mlxSelectedVLMModel {
                // Downloading - progress shown in header
                EmptyView()
            } else if !mlxService.isModelReady(settings.mlxSelectedVLMModel) {
                // Not downloaded - download button shown in header
                EmptyView()
            } else if mlxService.isLoading {
                // Loading - shown in header
                EmptyView()
            } else if item.imageAnalysisProcessing {
                // Processing - animated skeleton placeholder
                AnalyzingPlaceholder()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            } else if let response = item.imageAnalysisResponse, !response.isEmpty {
                // Show analysis result
                Text(response)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
            // No "Ready to analyze" message - clean UI when ready
        }
        .background(Color.primary.opacity(0.03))
    }
    
    /// Custom header for image analysis section with model status on the right
    private func imageAnalysisHeader(item: ClipboardItem, imageData: Data) -> some View {
        HStack(spacing: 8) {
            // Left side: Icon and title
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LinearGradient.accentGradient)
            
            Text("AI Image Analysis")
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundStyle(.primary)
            
            if item.imageAnalysisProcessing {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
            
            Spacer()
            
            // Right side: Model status (download, progress, loading, or ready)
            imageAnalysisModelStatus(item: item, imageData: imageData)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
    
    /// Model status view for the right side of the header
    @ViewBuilder
    private func imageAnalysisModelStatus(item: ClipboardItem, imageData: Data) -> some View {
        if mlxService.isRefreshingStatus {
            // Checking model status
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
                Text("Checking...")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        } else if mlxService.isDownloading && mlxService.downloadingModelName == settings.mlxSelectedVLMModel {
            // Downloading progress
            HStack(spacing: 6) {
                Text("Image analysis module")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                if mlxService.overallProgress > 0 {
                    ProgressView(value: mlxService.overallProgress)
                        .frame(width: 60)
                    
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
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
                
                Button {
                    mlxService.cancelDownload()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Cancel download")
            }
        } else if !mlxService.isModelReady(settings.mlxSelectedVLMModel) {
            // Not downloaded - show download button
            HStack(spacing: 6) {
                Text("Image analysis module")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Button {
                    Task {
                        await downloadModelAndAnalyze(item: item, imageData: imageData)
                    }
                } label: {
                    Text("Download")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(LinearGradient.accentGradient)
                }
                .buttonStyle(.plain)
                .help("Download image analysis module")
            }
        } else if mlxService.isLoading {
            // Loading into memory
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
                Text("Loading...")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        // When ready - show nothing (clean header)
    }
    
    private func checkModelAndAnalyze(item: ClipboardItem, imageData: Data) {
        guard settings.imageAnalysisEnabled else { return }
        guard item.type == .image else { return }
        // Only auto-analyze if the image was captured when the toggle was ON
        guard item.shouldAnalyzeImage else { return }
        
        // Use cached status from MLXService (checked at startup)
        let isReady = mlxService.isModelReady(settings.mlxSelectedVLMModel)
        
        // If model is available and not yet analyzed, trigger analysis
        if isReady && item.imageAnalysisResponse == nil && !item.imageAnalysisProcessing {
            Task {
                await clipboardManager.analyzeImage(item)
            }
        }
    }
    
    private func downloadModelAndAnalyze(item: ClipboardItem, imageData: Data) async {
        // Trigger analysis - this will download the model if needed
        // MLXService will automatically refresh the cached status after download
        await clipboardManager.analyzeImage(item)
    }
    
    // MARK: - Text Processing Header (AI Response)
    
    /// Custom header for AI Response section with MLX model status on the right
    private func textProcessingHeader(item: ClipboardItem) -> some View {
        HStack(spacing: 8) {
            // Left side: Icon and title
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LinearGradient.accentGradient)
            
            Text("AI Response")
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundStyle(.primary)
            
            if item.llmProcessing {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
            
            Spacer()
            
            // Right side: Model status (only for MLX provider)
            if settings.selectedProvider == .mlx {
                textProcessingModelStatus(item: item)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
    
    /// Model status view for the right side of the text processing header
    @ViewBuilder
    private func textProcessingModelStatus(item: ClipboardItem) -> some View {
        // Get current text model name directly from settings
        let currentTextModel = settings.mlxSelectedTextModel
        
        if mlxService.isRefreshingStatus {
            // Checking model status
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
                Text("Checking...")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        } else if mlxService.isDownloading && mlxService.downloadingModelName == currentTextModel {
            // Downloading progress for text model
            HStack(spacing: 6) {
                Text("Text processing module")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                if mlxService.overallProgress > 0 {
                    ProgressView(value: mlxService.overallProgress)
                        .frame(width: 60)
                    
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
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
                
                Button {
                    mlxService.cancelDownload()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Cancel download")
            }
        } else if !mlxService.isModelReady(currentTextModel) {
            // Not downloaded - show download button
            HStack(spacing: 6) {
                Text("Text processing module")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Button {
                    // Explicitly download the TEXT model, not VLM
                    Task { @MainActor in
                        MLXService.shared.downloadModel(settings.mlxSelectedTextModel)
                    }
                } label: {
                    Text("Download")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(LinearGradient.accentGradient)
                }
                .buttonStyle(.plain)
                .help("Download text processing module")
            }
        } else if mlxService.isLoading {
            // Loading into memory
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
                Text("Loading...")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        // When ready - show nothing (clean header)
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(title: String, icon: String, isProcessing: Bool = false, isActive: Bool = true, timestamp: Date? = nil, copyAction: (() -> Void)? = nil) -> some View {
        HStack(spacing: 8) {
            // Icon - clickable if copyAction is provided
            if let copyAction = copyAction {
                CopyButton(action: copyAction)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(icon == "sparkles" ? AnyShapeStyle(LinearGradient.accentGradient) : AnyShapeStyle(.secondary))
            }
            
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundStyle(isActive ? .primary : .secondary)
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
            
            Spacer()
            
            // Show timestamp if provided (for Original section)
            if let timestamp = timestamp {
                Text(Self.dateFormatter.string(from: timestamp))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
    
    // Copy button with checkmark feedback
    private struct CopyButton: View {
        let action: () -> Void
        
        @State private var showingCheckmark = false
        @State private var isHovered = false
        
        var body: some View {
            Button {
                action()
                showingCheckmark = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingCheckmark = false
                }
            } label: {
                Image(systemName: showingCheckmark ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(showingCheckmark ? .green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .opacity(isHovered || showingCheckmark ? 1.0 : 0.7)
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .help("Copy to clipboard")
        }
    }
    
    // Date formatter for copied timestamp
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    // MARK: - Placeholders
    
    private var processingPlaceholder: some View {
        VStack(spacing: 14) {
            // Purple sparkles animation - centered in fixed container
            LLMProcessingIndicator()
                .frame(width: 40, height: 40)
            
            VStack(spacing: 4) {
                Text("Processing with AI...")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)
                
                Text("Analyzing your clipboard content")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var notProcessedPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(LinearGradient.accentGradient)
                .opacity(0.5)
            
            VStack(spacing: 4) {
                Text("Not processed yet")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
                
                Text("Enable AI toggle to process")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Tags Footer
    
    private func tagsFooter(tags: [String]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "tag")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.top, 3) // Align with first tag line
            
            FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    LLMTagView(tag: tag)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    private func placeholderContent(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Empty State
    
    private var emptyPreview: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.dashed")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 4) {
                Text("Select a clip")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(.secondary)
                
                Text("Choose an item from the list to preview")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Analyzing Placeholder (Skeleton Animation)

/// Animated skeleton placeholder shown while image analysis is in progress
struct AnalyzingPlaceholder: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Simulated text lines with varying widths
            SkeletonLine(width: 0.85)
            SkeletonLine(width: 0.6)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

/// Single animated skeleton line
private struct SkeletonLine: View {
    let width: CGFloat // Fraction of available width (0.0 - 1.0)
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.08),
                            Color.primary.opacity(0.15),
                            Color.primary.opacity(0.08)
                        ],
                        startPoint: isAnimating ? .leading : .trailing,
                        endPoint: isAnimating ? .trailing : .leading
                    )
                )
                .frame(width: geometry.size.width * width, height: 14)
        }
        .frame(height: 14)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    var tooltip: String = ""
    var isDestructive: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isDestructive && isHovered ? .red : .secondary)
                .frame(width: 30, height: 30)
                .background {
                    if isHovered {
                        Circle().glassEffect()
                    }
                }
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Link Action Button (Glassy Circle with Label)

struct LinkActionButton: View {
    let icon: String
    let label: String
    var showsCheckmark: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var showingCheckmark = false
    
    var body: some View {
        Button {
            action()
            
            if showsCheckmark {
                showingCheckmark = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingCheckmark = false
                }
            }
        } label: {
            VStack(spacing: 8) {
                // Glassy circle with icon - shows glass only on hover (toolbar style)
                ZStack {
                    if isHovered {
                        Circle().glassEffect()
                    }
                    
                    Image(systemName: showingCheckmark ? "checkmark" : icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(showingCheckmark ? .green : .primary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 44, height: 44)
                
                // Label
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .help(label)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Type Display Name

extension ClipboardType {
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case .image: return "Image"
        case .file: return "File"
        case .other: return "Other"
        }
    }
}

#Preview {
    HStack(spacing: 0) {
        PreviewPane(
            item: ClipboardItem(content: "Hello, this is some preview text that should be displayed in the preview pane.\n\nIt can have multiple lines and should be scrollable.")
        )
    }
    .frame(width: 450, height: 350)
    .glassEffect()
}
