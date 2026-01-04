import SwiftUI
import AppKit
import KeyboardShortcuts

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var appIcon: NSImage? {
        if let icon = NSApp.applicationIconImage {
            return icon
        }
        // Fallback: try to load from bundle
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            return icon
        }
        // Try AppIcon from asset catalog
        return NSImage(named: "AppIcon")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            // Subtle separator
            Rectangle()
                .fill(Color.clipBorder)
                .frame(height: 1)
            
            // Content
            VStack(spacing: 18) {
                // App icon and name
                VStack(spacing: 10) {
                    if let icon = appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                    } else {
                        // Fallback to system icon if app icon not found
                        Image(systemName: "sparkles.square.filled.on.square")
                            .font(.system(size: 64))
                            .foregroundStyle(LinearGradient.accentGradient)
                    }
                    
                    Text("Gramfix")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text("Version \(version)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 16)
                
                // Description
                VStack(alignment: .leading, spacing: 10) {
                    Text("Simple and secure clipboard history manager with AI processing.")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    Text("Features:")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        featureRow(icon: "lock.fill", text: "Encrypted by default")
                        featureRow(icon: "cpu.fill", text: "Local AI processing (MLX/Ollama)")
                        
                        // Supported languages
                        HStack(spacing: 6) {
                            Image(systemName: "cpu.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.clipAccent)
                                .frame(width: 16)
                                .opacity(0)
                            
                            HStack(spacing: 3) {
                                ForEach(SupportedLanguage.allCases) { language in
                                    HStack(spacing: 2) {
                                        Text(language.flag)
                                            .font(.system(size: 10))
                                        Text(language.displayName)
                                            .font(.system(size: 10, weight: .regular, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    if language.id != SupportedLanguage.allCases.last?.id {
                                        Text(",")
                                            .font(.system(size: 9, weight: .regular))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                        
                        featureRow(icon: "keyboard", text: "Keyboard shortcuts")
                        featureRow(icon: "eye.fill", text: "Search over images (beta)")
                    }
                }
                .padding(.horizontal, 20)
                
                // Shortcut section
                shortcutSection
                
                // Links
                VStack(spacing: 10) {
                    linkButton(
                        icon: "link",
                        title: "GitHub",
                        url: "https://github.com/rudskoy/gramfix"
                    )
                    
                    linkButton(
                        icon: "bubble.left.and.exclamationmark.bubble.right",
                        title: "Give Feedback",
                        url: "https://github.com/rudskoy/gramfix/issues"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("About")
                    .font(.clipHeader)
                    .foregroundStyle(.primary)
                
                Text("Gramfix")
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
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.clipAccent)
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
    
    private func linkButton(icon: String, title: String, url: String) -> some View {
        Button {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.clipAccent)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Shortcut Section
    
    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.clipAccent)
                
                Text("Global Shortcut")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            
            Text("Press the shortcut keys to change")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
            
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Toggle Gramfix")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Show/hide clipboard manager from anywhere")
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                KeyboardShortcuts.Recorder(for: .toggleGramfix)
            }
            .padding(8)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    AboutView()
}

