import SwiftUI
import AppKit

// MARK: - Color Palette (Liquid Glass Compatible)

extension Color {
    // Base colors - now with transparency for glass effect
    static let clipBackground = Color.clear
    static let clipSurface = Color.white.opacity(0.05)
    static let clipSurfaceHover = Color.white.opacity(0.1)
    
    // Accent colors with glow potential
    static let clipAccent = Color(nsColor: NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0))
    static let clipAccentSubtle = Color(nsColor: NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.15))
    static let clipAccentGlow = Color(nsColor: NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.3))
    
    // Text colors - semantic for better adaptability
    static let clipTextPrimary = Color.primary
    static let clipTextSecondary = Color.secondary
    
    // Border with subtle visibility on glass
    static let clipBorder = Color.white.opacity(0.12)
    static let clipBorderSubtle = Color.white.opacity(0.06)
    
    // LLM-related colors - darker blue for visibility on both light and dark modes
    static let clipTagBackground = Color(nsColor: NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.2))
    static let clipTagText = Color(nsColor: NSColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 1.0))
    static let clipLLMProcessing = Color(nsColor: NSColor(red: 0.7, green: 0.5, blue: 1.0, alpha: 1.0))
    static let clipContentType = Color(nsColor: NSColor(red: 0.5, green: 0.85, blue: 0.6, alpha: 1.0))
}

// MARK: - Gradients

extension LinearGradient {
    static let accentGradient = LinearGradient(
        colors: [
            Color(nsColor: NSColor(red: 0.5, green: 0.6, blue: 1.0, alpha: 1.0)),
            Color(nsColor: NSColor(red: 0.7, green: 0.5, blue: 1.0, alpha: 1.0))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let mascotGlow = LinearGradient(
        colors: [
            Color.purple.opacity(0.3),
            Color.blue.opacity(0.2)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Typography (Rounded Design)

extension Font {
    static let clipTitle = Font.system(size: 14, weight: .semibold, design: .default)
    static let clipBody = Font.system(size: 12, weight: .regular, design: .default)
    static let clipCaption = Font.system(size: 10, weight: .medium, design: .default)
    static let clipMono = Font.system(size: 11, weight: .regular, design: .monospaced)
    static let clipHeader = Font.system(size: 16, weight: .semibold, design: .default)
}

// MARK: - Icon Helpers

struct ClipboardTypeIcon: View {
    let type: ClipboardType
    @Environment(\.colorScheme) private var colorScheme  // Forces re-render on theme change
    
    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .glassEffect(in: .rect(cornerRadius: 5))
            .id(colorScheme)  // Force complete re-render when theme changes
    }
    
    private var iconName: String {
        switch type {
        case .text: return "doc.text"
        case .link: return "link"
        case .image: return "photo"
        case .file: return "folder"
        case .other: return "doc"
        }
    }
}

// MARK: - LLM Tag View (Legacy - kept for compatibility)

struct LLMTagView: View {
    let tag: String
    
    var body: some View {
        Text(tag)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundColor(.clipTagText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .glassEffect(in: .capsule)
    }
}

// MARK: - Prompt Tag View (Multi-Prompt Selection)

struct PromptTagView: View {
    let promptType: TextPromptType
    let isSelected: Bool
    let isProcessing: Bool
    let hasResult: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    @State private var pulseAnimation = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 4) {
                // Status icon
                statusIcon
                    .font(.system(size: 8, weight: .bold))
                
                // Prompt name
                Text(promptType.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule().fill(backgroundFill)
            }
            .overlay {
                if isSelected {
                    Capsule()
                        .strokeBorder(Color.clipAccent.opacity(0.6), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(isHovered ? 1.0 : (isSelected ? 1.0 : 0.85))
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.2), value: isSelected)
        .onHover { isHovered = $0 }
        .onAppear {
            if isProcessing {
                startPulseAnimation()
            }
        }
        .onChange(of: isProcessing) { _, processing in
            if processing {
                startPulseAnimation()
            } else {
                pulseAnimation = false
            }
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        if isProcessing {
            Image(systemName: "circle.dotted")
                .opacity(pulseAnimation ? 0.4 : 1.0)
        } else if hasResult {
            Image(systemName: "checkmark")
                .foregroundStyle(.green)
        } else {
            Image(systemName: "circle")
                .opacity(0.5)
        }
    }
    
    private var foregroundStyle: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.white)
        } else if hasResult {
            return AnyShapeStyle(Color.primary)
        } else {
            return AnyShapeStyle(Color.secondary)
        }
    }
    
    private var backgroundFill: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(LinearGradient.accentGradient)
        } else if isHovered {
            return AnyShapeStyle(Color.white.opacity(0.15))
        } else {
            return AnyShapeStyle(Color.white.opacity(0.08))
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
    }
}

// MARK: - Language Flag View (Language Detection and Translation)

struct LanguageFlagView: View {
    let item: ClipboardItem
    let isFocused: Bool
    @Binding var showPopover: Bool
    let onSelectLanguage: (SupportedLanguage) -> Void
    
    @State private var isHovered = false
    @State private var pulseAnimation = false
    @State private var selectedLanguageIndex: Int = 0
    
    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            flagLabel
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            languageMenu
        }
        .onHover { isHovered = $0 }
        .onChange(of: isFocused) { _, focused in
            // Auto-open popover when focused via keyboard
            if focused && !showPopover {
                showPopover = true
                // Reset selection to first item when opening
                selectedLanguageIndex = 0
            } else if !focused && showPopover {
                // Close popover when focus is lost
                showPopover = false
            }
        }
        .onChange(of: item.languageDetectionProcessing) { _, processing in
            if processing {
                startPulseAnimation()
            } else {
                pulseAnimation = false
            }
        }
        .onAppear {
            if item.languageDetectionProcessing {
                startPulseAnimation()
            }
        }
    }
    
    @ViewBuilder
    private var languageMenu: some View {
        let languages = SupportedLanguage.orderedList(detectedLanguage: item.detectedLanguage)
        
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(languages.enumerated()), id: \.element.id) { index, language in
                Button(action: {
                    onSelectLanguage(language)
                    showPopover = false
                }) {
                    HStack(spacing: 8) {
                        Text(language.flag)
                            .font(.system(size: 14))
                        
                        Text(language.displayName)
                            .font(.system(size: 12, weight: .medium))
                        
                        Spacer()
                        
                        // Show checkmark for current selection
                        if isCurrentSelection(language) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.green)
                        }
                        
                        // Show "(detected)" or processing indicator
                        if language == item.detectedLanguage {
                            Text("source")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2), in: Capsule())
                        } else if item.translationProcessingLanguages.contains(language.rawValue) {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        } else if item.translatedResults[language.rawValue] != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.green.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(minWidth: 160, alignment: .leading)
                    .contentShape(Rectangle())
                    .background(
                        (index == selectedLanguageIndex || isCurrentSelection(language)) 
                            ? Color.clipAccent.opacity(0.15) 
                            : Color.clear, 
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .allowsHitTesting(true)
        .onKeyPress(.upArrow) {
            if !languages.isEmpty {
                selectedLanguageIndex = (selectedLanguageIndex - 1 + languages.count) % languages.count
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if !languages.isEmpty {
                selectedLanguageIndex = (selectedLanguageIndex + 1) % languages.count
            }
            return .handled
        }
        .onKeyPress(.return) {
            if !languages.isEmpty && selectedLanguageIndex < languages.count {
                onSelectLanguage(languages[selectedLanguageIndex])
                showPopover = false
            }
            return .handled
        }
        .onKeyPress(.escape) {
            showPopover = false
            return .handled
        }
        .onAppear {
            // Always start selection from first item
            selectedLanguageIndex = 0
        }
        .onChange(of: showPopover) { _, isOpen in
            // Reset selection to first item when opening
            if isOpen {
                selectedLanguageIndex = 0
            }
        }
    }
    
    @ViewBuilder
    private var flagLabel: some View {
        HStack(spacing: 4) {
            // Flag emoji or processing indicator
            if item.languageDetectionProcessing || item.translationProcessing {
                // Processing state - animated globe
                Text("🌐")
                    .font(.system(size: 12))
                    .opacity(pulseAnimation ? 0.4 : 1.0)
                
                Text("Detecting...")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            } else if let language = item.displayLanguage {
                // Show current language flag + name
                Text(language.flag)
                    .font(.system(size: 12))
                
                Text(language.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            } else {
                // No language detected yet - globe placeholder
                Text("🌐")
                    .font(.system(size: 12))
                    .opacity(0.6)
                
                Text("Language")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            // Always show dropdown indicator
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule().fill(backgroundFill)
        }
        .overlay {
            if isFocused {
                Capsule()
                    .strokeBorder(Color.clipAccent.opacity(0.6), lineWidth: 1.5)
            }
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }
    
    private var foregroundStyle: some ShapeStyle {
        if isFocused {
            return AnyShapeStyle(Color.white)
        } else {
            return AnyShapeStyle(Color.primary)
        }
    }
    
    private var backgroundFill: AnyShapeStyle {
        if isFocused {
            return AnyShapeStyle(LinearGradient.accentGradient)
        } else if isHovered {
            return AnyShapeStyle(Color.white.opacity(0.15))
        } else {
            return AnyShapeStyle(Color.white.opacity(0.08))
        }
    }
    
    private func isCurrentSelection(_ language: SupportedLanguage) -> Bool {
        // If no target selected, the detected language is current
        if let target = item.selectedTargetLanguage {
            return language == target
        } else {
            return language == item.detectedLanguage
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
    }
}

// MARK: - Flow Layout (for wrapping tags)

struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.replacingUnspecifiedDimensions(), subviews: subviews)
        return CGSize(width: proposal.width ?? result.width, height: result.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            // Check if we need to wrap to next line
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + verticalSpacing
                lineHeight = 0
            }
            
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            
            currentX += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
    
    private func layout(in size: CGSize, subviews: Subviews) -> CGSize {
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            if currentX + subviewSize.width > size.width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + verticalSpacing
                lineHeight = 0
            }
            
            maxWidth = max(maxWidth, currentX + subviewSize.width)
            lineHeight = max(lineHeight, subviewSize.height)
            currentX += subviewSize.width + horizontalSpacing
        }
        
        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }
}

// MARK: - LLM Content Type Badge

struct ContentTypeBadge: View {
    let contentType: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 9, weight: .medium))
            Text(contentType.capitalized)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.clipContentType)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(in: .capsule)
    }
    
    private var iconName: String {
        switch contentType.lowercased() {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "email": return "envelope"
        case "url": return "link"
        case "note": return "note.text"
        case "json": return "curlybraces"
        case "command": return "terminal"
        case "phone": return "phone"
        case "path": return "folder"
        case "address": return "mappin"
        default: return "doc"
        }
    }
}

// MARK: - LLM Processing Indicator

struct LLMProcessingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(LinearGradient.accentGradient)
            .opacity(isAnimating ? 0.4 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - LLM Toggle Button

struct LLMToggleButton: View {
    @Binding var isEnabled: Bool
    let isProcessing: Bool
    
    @State private var isHovered = false
    @State private var isPulsing = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isEnabled.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .medium))
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                
                Text(isEnabled ? "AI Enabled" : "AI Disabled")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
//            .foregroundStyle(isEnabled ? LinearGradient.accentGradient : LinearGradient(colors: [.secondary], startPoint: .leading, endPoint: .trailing))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.1), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        isEnabled ? Color.clipLLMProcessing.opacity(0.5) : Color.white.opacity(0.15),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(isEnabled ? "AI processing enabled (click to disable)" : "AI processing disabled (click to enable)")
        .onHover { isHovered = $0 }
        .onChange(of: isProcessing) { _, processing in
            if processing {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }
}

// MARK: - Settings Button

struct SettingsButton: View {
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var rotation: Double = 0
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                rotation += 90
            }
            action()
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(rotation))
                .frame(width: 28, height: 28)
                .background {
                    if isHovered {
                        Circle().glassEffect()
                    }
                }
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("Settings")
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Useful Filter Button

struct UsefulFilterButton: View {
    let isActive: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? "star.fill" : "star")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? AnyShapeStyle(LinearGradient.accentGradient) : AnyShapeStyle(.secondary))
                .frame(width: 28, height: 28)
                .background {
                    if isHovered {
                        Circle().glassEffect()
                    }
                }
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(isActive ? "Show all items" : "Show only useful items")
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Theme Toggle Button

struct ThemeToggleButton: View {
    @ObservedObject private var settings = LLMSettings.shared
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                settings.appTheme = settings.appTheme.next
            }
        } label: {
            // Use explicit rendering mode to prevent toolbar from applying template colors
            Group {
                switch settings.appTheme {
                case .light:
                    Image(systemName: "sun.max.fill")
                        .symbolRenderingMode(.multicolor)
                case .dark:
                    Image(systemName: "moon.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.indigo)
                case .system:
                    Image(systemName: "circle.lefthalf.filled")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.primary, .primary.opacity(0.3))
                }
            }
            .contentTransition(.symbolEffect(.replace))
        }
        .help("Theme: \(settings.appTheme.displayName)")
    }
}

// MARK: - Image Analysis Toggle Button

struct ImageAnalysisToggleButton: View {
    @ObservedObject private var settings = LLMSettings.shared
    @ObservedObject private var tooltipState = TooltipState.shared
    @State private var hoverTask: Task<Void, Never>?
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                settings.imageAnalysisEnabled.toggle()
            }
        } label: {
            Group {
                if settings.imageAnalysisEnabled {
                    Image(systemName: "eye")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(LinearGradient.accentGradient)
                } else {
                    Image(systemName: "eye.slash")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.secondary)
                }
            }
            .contentTransition(.symbolEffect(.replace))
        }
        .onHover { hovering in
            hoverTask?.cancel()
            if hovering {
                hoverTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(200))
                    if !Task.isCancelled {
                        tooltipState.activeTooltip = TooltipInfo(
                            title: "Image Analysis",
                            description: settings.imageAnalysisEnabled
                                ? "Auto-analyze copied images with AI"
                                : "Enable to auto-analyze copied images",
                            shortcut: nil,
                            alignment: .trailing
                        )
                    }
                }
            } else {
                tooltipState.activeTooltip = nil
            }
        }
    }
}

// MARK: - Glow Effect Modifier

struct GlowEffect: ViewModifier {
    var color: Color = .clipAccent
    var radius: CGFloat = 10
    var isActive: Bool = true
    
    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(0.5) : .clear, radius: radius)
            .shadow(color: isActive ? color.opacity(0.3) : .clear, radius: radius * 0.5)
    }
}

extension View {
    func glow(color: Color = .clipAccent, radius: CGFloat = 10, isActive: Bool = true) -> some View {
        modifier(GlowEffect(color: color, radius: radius, isActive: isActive))
    }
}

// MARK: - Hover Scale Modifier

struct HoverScaleModifier: ViewModifier {
    @State private var isHovered = false
    var scale: CGFloat = 1.02
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

extension View {
    func hoverScale(_ scale: CGFloat = 1.02) -> some View {
        modifier(HoverScaleModifier(scale: scale))
    }
}

// MARK: - Toolbar Tooltip System

enum TooltipAlignment: Equatable {
    case leading
    case trailing
}

struct TooltipInfo: Equatable {
    let title: String
    let description: String
    let shortcut: String?
    let alignment: TooltipAlignment
}

class TooltipState: ObservableObject {
    @Published var activeTooltip: TooltipInfo?
    static let shared = TooltipState()
}

// MARK: - Glass Toolbar Group

struct GlassToolbarGroup<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 4) {
                content
            }
        }
        .glassEffect()
    }
}

struct ToolbarActionButton: View {
    let icon: String
    let title: String
    let description: String
    let shortcut: String?
    let isDisabled: Bool
    let tooltipAlignment: TooltipAlignment
    let iconForegroundStyle: AnyShapeStyle?
    let action: () -> Void
    
    @ObservedObject private var tooltipState = TooltipState.shared
    @State private var hoverTask: Task<Void, Never>?
    
    init(
        icon: String,
        title: String,
        description: String,
        shortcut: String? = nil,
        isDisabled: Bool = false,
        tooltipAlignment: TooltipAlignment = .leading,
        iconForegroundStyle: AnyShapeStyle? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.shortcut = shortcut
        self.isDisabled = isDisabled
        self.tooltipAlignment = tooltipAlignment
        self.iconForegroundStyle = iconForegroundStyle
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Group {
                if let foregroundStyle = iconForegroundStyle {
                    Image(systemName: icon)
                        .foregroundStyle(foregroundStyle)
                } else {
                    Image(systemName: icon)
                }
            }
        }
        .disabled(isDisabled)
        .onHover { hovering in
            hoverTask?.cancel()
            if hovering {
                hoverTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(200))
                    if !Task.isCancelled {
                        tooltipState.activeTooltip = TooltipInfo(
                            title: title,
                            description: description,
                            shortcut: shortcut,
                            alignment: tooltipAlignment
                        )
                    }
                }
            } else {
                tooltipState.activeTooltip = nil
            }
        }
    }
}

struct FixedTooltipView: View {
    let alignment: TooltipAlignment
    @ObservedObject private var tooltipState = TooltipState.shared
    
    init(alignment: TooltipAlignment = .leading) {
        self.alignment = alignment
    }
    
    var body: some View {
        Group {
            if let tooltip = tooltipState.activeTooltip, tooltip.alignment == alignment {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tooltip.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(tooltip.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let shortcut = tooltip.shortcut {
                        Text(shortcut)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                .padding(10)
                .frame(width: 200, alignment: .leading)
                .glassEffect(in: .rect(cornerRadius: 8))
                .compositingGroup()
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: tooltipState.activeTooltip)
    }
}

// MARK: - Type Filter Tabs

struct TypeFilterTabs: View {
    @Binding var selectedTab: ClipboardType?
    @Binding var showUsefulTab: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            // All tab
            TabButton(
                title: "All",
                icon: "square.grid.2x2",
                isSelected: selectedTab == nil && !showUsefulTab,
                action: {
                    selectedTab = nil
                    showUsefulTab = false
                }
            )
            
            // Useful tab
            TabButton(
                title: "Useful",
                icon: "star.fill",
                isSelected: showUsefulTab,
                action: {
                    selectedTab = nil
                    showUsefulTab = true
                }
            )
            
            Spacer()
        }
    }
}

private struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule().fill(backgroundFill)
            }
            .overlay {
                if isSelected {
                    Capsule()
                        .strokeBorder(Color.clipAccent.opacity(0.6), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(isHovered ? 1.0 : (isSelected ? 1.0 : 0.85))
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.2), value: isSelected)
        .onHover { isHovered = $0 }
    }
    
    private var foregroundStyle: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.white)
        } else {
            return AnyShapeStyle(Color.primary)
        }
    }
    
    private var backgroundFill: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(LinearGradient.accentGradient)
        } else if isHovered {
            return AnyShapeStyle(Color.white.opacity(0.15))
        } else {
            return AnyShapeStyle(Color.white.opacity(0.08))
        }
    }
}

// MARK: - Image Extensions

extension Image {
    /// Create a SwiftUI Image from Data
    /// - Parameter data: Image data (PNG, JPEG, TIFF, etc.)
    /// - Returns: Optional Image if data can be converted
    init?(data: Data) {
        guard let nsImage = NSImage(data: data) else {
            return nil
        }
        self.init(nsImage: nsImage)
    }
}


