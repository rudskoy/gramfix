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
            .glassEffect(in: .rect(cornerRadius: 5, style: .continuous))
            .id(colorScheme)  // Force complete re-render when theme changes
    }
    
    private var iconName: String {
        switch type {
        case .text: return "doc.text"
        case .image: return "photo"
        case .file: return "folder"
        case .other: return "doc"
        }
    }
}

// MARK: - LLM Tag View

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

// MARK: - Otter Mascot View

struct OtterMascot: View {
    var size: CGFloat = 80
    var animated: Bool = false
    @State private var isAnimating = false
    
    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.15, style: .continuous))
            .rotationEffect(.degrees(animated && isAnimating ? -3 : 3))
            .animation(
                animated ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default,
                value: isAnimating
            )
            .onAppear {
                if animated {
                    isAnimating = true
                }
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

struct ToolbarActionButton: View {
    let icon: String
    let title: String
    let description: String
    let shortcut: String?
    let isDisabled: Bool
    let tooltipAlignment: TooltipAlignment
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
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.shortcut = shortcut
        self.isDisabled = isDisabled
        self.tooltipAlignment = tooltipAlignment
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
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
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
                .padding(10)
                .frame(width: 200, alignment: .leading)
                .glassEffect(in: .rect(cornerRadius: 8, style: .continuous))
                .compositingGroup()
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: tooltipState.activeTooltip)
    }
}
