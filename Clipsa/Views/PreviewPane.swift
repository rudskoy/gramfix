import SwiftUI
import AppKit

struct PreviewPane: View {
    let item: ClipboardItem?
    
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
                        sectionHeader(title: "AI Response", icon: "sparkles", isProcessing: item.llmProcessing, isActive: true)
                        
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
        case .image:
            if let data = item.rawData, let nsImage = NSImage(data: data) {
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    var tooltip: String = ""
    var isDestructive: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isDestructive && isHovered ? .red : .secondary)
                .frame(width: 30, height: 30)
                .background {
                    if isHovered {
                        Circle().glassEffect()
                    }
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Type Display Name

extension ClipboardType {
    var displayName: String {
        switch self {
        case .text: return "Text"
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
