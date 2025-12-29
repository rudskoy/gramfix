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
    
    /// Request to show the accessibility alert via SwiftUI coordinator
    /// Replaces the blocking NSAlert with SwiftUI's async alert system
    @MainActor
    func requestAccessibilityAlert() {
        AccessibilityAlertCoordinator.shared.requestAccessibilityAlert()
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
