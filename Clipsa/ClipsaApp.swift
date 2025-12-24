import SwiftUI
import AppKit
import KeyboardShortcuts

@main
struct ClipsaApp: App {
    @StateObject private var clipboardManager = ClipboardManager()
    @AppStorage("app_theme") private var appThemeRaw: String = AppTheme.system.rawValue
    @State private var systemIsDark: Bool = false  // Safe default, updated in onAppear
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    /// Always returns explicit ColorScheme (never nil) for immediate updates
    private var colorScheme: ColorScheme {
        guard let theme = AppTheme(rawValue: appThemeRaw) else { return .light }
        switch theme {
        case .light: return .light
        case .dark: return .dark
        case .system: return systemIsDark ? .dark : .light
        }
    }
    
    /// Safely detect current system appearance (NSApp may be nil early in lifecycle)
    private func detectSystemAppearance() -> Bool {
        guard let app = NSApp else { return false }
        return app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
    
    var body: some Scene {
        // Use Window instead of WindowGroup to ensure single window
        Window("Clipsa", id: "main") {
            ContentView()
                .environmentObject(clipboardManager)
                .preferredColorScheme(colorScheme)
                .onAppear {
                    // Detect system appearance once NSApp is available
                    systemIsDark = detectSystemAppearance()
                }
                .onReceive(DistributedNotificationCenter.default().publisher(
                    for: Notification.Name("AppleInterfaceThemeChangedNotification")
                )) { _ in
                    // Update when macOS system appearance changes
                    systemIsDark = detectSystemAppearance()
                }
        }
        .defaultSize(width: 750, height: 500)
        .commands {
            // Remove "New Window" command to prevent multiple windows
            CommandGroup(replacing: .newItem) { }
            
            // Hide Services menu
            CommandGroup(replacing: .systemServices) { }
        }
        
        // Settings scene automatically adds "Settings..." menu item with ⌘,
        Settings {
            SettingsView()
        }
        
        MenuBarExtra("Clipsa", image: "MenuBarIcon") {
            Button("Show Window") {
                AppDelegate.showMainWindow()
            }
            .keyboardShortcut("o", modifiers: .command)
            
            Divider()
            
            Button("Quit Clipsa") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

// MARK: - App Delegate for Global Shortcut

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupGlobalShortcut()
        
        // Save previous app when app is about to become active
        NotificationCenter.default.addObserver(
            forName: NSApplication.willBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            PasteService.shared.savePreviousApp()
        }
        
        // Configure window appearance when it becomes available
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first(where: { $0.title == "Clipsa" }) {
                window.delegate = self
                window.titlebarAppearsTransparent = true
                window.collectionBehavior = [.moveToActiveSpace]
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)  // Hide the window
        return false          // Prevent actual close
    }
    
    private func setupGlobalShortcut() {
        // Global shortcut using KeyboardShortcuts library (configurable in Settings)
        KeyboardShortcuts.onKeyUp(for: .toggleClipsa) {
            if NSApplication.shared.isActive {
                // Toggle off: return to previous app
                PasteService.shared.returnToPreviousApp()
            } else {
                // Toggle on: save previous app and show Clipsa
                PasteService.shared.savePreviousApp()
                AppDelegate.showMainWindow()
            }
        }
    }
    
    static func showMainWindow() {
        // Find the main Clipsa window FIRST
        if let window = NSApplication.shared.windows.first(where: { $0.title == "Clipsa" }) {
            window.titlebarAppearsTransparent = true
            // Set collection behavior BEFORE activating to prevent space switch
            window.collectionBehavior = [.moveToActiveSpace]
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.collectionBehavior = [.moveToActiveSpace]
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            // Fallback if no window found yet
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
