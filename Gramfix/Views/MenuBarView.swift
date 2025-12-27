import SwiftUI
import Sparkle

/// Rich menu bar popover view (Kandji-inspired design)
struct MenuBarView: View {
    @ObservedObject private var settings = LLMSettings.shared
    @ObservedObject private var updateViewModel: CheckForUpdatesViewModel
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    @State private var settingsHovered = false
    @State private var isCheckingForUpdates = false
    
    init() {
        self.updateViewModel = CheckForUpdatesViewModel(updater: UpdateService.shared.updater)
    }
    
    /// Count of clipboard items captured today
    private var todayItemsCount: Int {
        clipboardManager.items.filter { Calendar.current.isDateInToday($0.timestamp) }.count
    }
    
    /// Total items in history
    private var totalItemsCount: Int {
        clipboardManager.items.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header
            headerSection
            
            Divider()
                .padding(.horizontal, 16)
            
            // MARK: - AI Status Section
            aiStatusSection
            
            Divider()
                .padding(.horizontal, 16)
            
            // MARK: - Stats Section
            statsSection
            
            Divider()
                .padding(.horizontal, 16)
            
            // MARK: - Action Links
            actionLinksSection
            
            Divider()
                .padding(.horizontal, 16)
            
            // MARK: - Footer
            footerSection
        }
        .frame(width: 280)
        .padding(.vertical, 8)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            // App branding
            Text("Gramfix")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            // Settings gear button
            SettingsLink {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background {
                        if settingsHovered {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        }
                    }
            }
            .buttonStyle(.plain)
            .focusable(false)
            .onHover { settingsHovered = $0 }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - AI Status Section
    
    private var aiStatusSection: some View {
        HStack(spacing: 12) {
            // Provider icon
            Image(systemName: settings.selectedProvider.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(settings.autoProcess ? Color.clipAccent : .secondary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                )
            
            // Provider info
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.selectedProvider.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(settings.autoProcess ? "Local AI processing" : "AI Processing Paused")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Toggle switch
            Toggle("", isOn: $settings.autoProcess)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text("Clipboard Stats")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                // Today's items
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(todayItemsCount)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Today")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 32)
                
                // Total items
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(totalItemsCount)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Total")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Action Links Section
    
    private var actionLinksSection: some View {
        VStack(spacing: 2) {
            // Show Window
            MenuBarActionRow(
                icon: "macwindow",
                title: "Show Window",
                action: {
                    AppDelegate.showMainWindow()
                }
            )
            
            MenuBarActionRow(
                icon: "bubble.left.and.exclamationmark.bubble.right",
                title: "Give Feedback",
                action: {
                    if let url = URL(string: "https://github.com/rudskoy/gramfix/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
            )
            
            MenuBarActionRow(
                icon: "info.circle",
                title: "About Gramfix",
                action: {
                    if let url = URL(string: "https://github.com/rudskoy/gramfix") {
                        NSWorkspace.shared.open(url)
                    }
                }
            )
            
            // Check for Updates with loading state
            if isCheckingForUpdates {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 20)
                    
                    Text("Checking for Updates...")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                MenuBarActionRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Check for Updates...",
                    isDisabled: !updateViewModel.canCheckForUpdates,
                    action: {
                        isCheckingForUpdates = true
                        updateViewModel.checkForUpdates()
                    }
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .onChange(of: updateViewModel.canCheckForUpdates) { _, canCheck in
            // When canCheckForUpdates becomes true again, checking is complete
            if canCheck && isCheckingForUpdates {
                isCheckingForUpdates = false
            }
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            HStack {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .medium))
                
                Text("Quit Gramfix")
                    .font(.system(size: 13, weight: .medium))
                
                Spacer()
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Menu Bar Action Row

private struct MenuBarActionRow: View {
    let icon: String
    let title: String
    var shortcut: String? = nil
    var isDisabled: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isDisabled ? .tertiary : .secondary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(isDisabled ? .secondary : .primary)
                
                Spacer()
                
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered && !isDisabled ? Color.white.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(ClipboardManager())
        .frame(width: 280)
        .background(Color.black.opacity(0.8))
}

