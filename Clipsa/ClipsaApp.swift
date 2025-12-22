import SwiftUI
import AppKit
import HotKey

@main
struct ClipsaApp: App {
    @StateObject private var clipboardManager = ClipboardManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Use Window instead of WindowGroup to ensure single window
        Window("Clipsa", id: "main") {
            ContentView()
                .environmentObject(clipboardManager)
        }
        .defaultSize(width: 750, height: 500)
        .commands {
            // Remove "New Window" command to prevent multiple windows
            CommandGroup(replacing: .newItem) { }
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

class AppDelegate: NSObject, NSApplicationDelegate {
    // Global hotkey using HotKey library (Cmd+Shift+\)
    private var hotKey: HotKey?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupGlobalShortcut()
        checkAccessibilityPermission()
        
        // Save previous app when app is about to become active
        NotificationCenter.default.addObserver(
            forName: NSApplication.willBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            PasteService.shared.savePreviousApp()
        }
    }
    
    /// Check Accessibility permission on startup and prompt if needed
    /// Required since macOS 10.14 Mojave for CGEvent keyboard simulation
    private func checkAccessibilityPermission() {
        // Request permission with prompt on first launch
        AccessibilityService.shared.isAccessibilityEnabled(prompt: true)
    }
    
    private func setupGlobalShortcut() {
        // Cmd+Shift+\ global shortcut using HotKey library
        hotKey = HotKey(key: .backslash, modifiers: [.command, .shift])
        
        hotKey?.keyDownHandler = {
            PasteService.shared.savePreviousApp()
            AppDelegate.showMainWindow()
        }
    }
    
    static func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // Find the main Clipsa window
        if let window = NSApplication.shared.windows.first(where: { $0.title == "Clipsa" }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
