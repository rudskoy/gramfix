import AppKit

/// Service for handling macOS Accessibility permissions
/// Required since macOS 10.14 Mojave for CGEvent keyboard simulation
final class AccessibilityService {
    static let shared = AccessibilityService()
    
    private init() {}
    
    /// Check if Accessibility permission is enabled
    /// - Parameter prompt: If true, shows the system prompt to enable accessibility
    /// - Returns: true if accessibility is enabled
    func isAccessibilityEnabled(prompt: Bool = false) -> Bool {
        let checkOptionPromptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [checkOptionPromptKey: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }
    
    /// Show an alert explaining why Accessibility permission is needed
    /// and offer to open System Settings
    func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Clipsa needs Accessibility permission to paste content into other applications. Please enable it in System Settings > Privacy & Security > Accessibility."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        NSApp.activate(ignoringOtherApps: true)
        
        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }
    
    /// Open System Settings to the Accessibility pane
    @discardableResult
    func openAccessibilitySettings() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }
}
