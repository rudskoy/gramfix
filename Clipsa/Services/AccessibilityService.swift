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
        let result = AXIsProcessTrustedWithOptions(opts)
        print("[AccessibilityService] isAccessibilityEnabled(prompt: \(prompt)) = \(result)")
        return result
    }
    
    /// Show a custom alert explaining why Accessibility permission is needed
    /// and offer to open System Settings (single button, Clipy-style)
    func showAccessibilityAuthenticationAlert() {
        let alert = NSAlert()
        alert.messageText = "Please allow Accessibility."
        alert.informativeText = "To do this action please allow Accessibility in Security & Privacy preferences, located in System Settings."
        alert.addButton(withTitle: "Open System Settings")
        alert.alertStyle = .warning
        
        NSApp.activate(ignoringOtherApps: true)
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Preserve previousApp when user returns from Settings
            PasteService.shared.shouldPreservePreviousApp = true
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
