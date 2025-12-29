import SwiftUI
import AppKit

/// Coordinator for managing accessibility alert state in SwiftUI
/// Bridges service classes (which don't have view context) to SwiftUI alerts
@MainActor
final class AccessibilityAlertCoordinator: ObservableObject {
    static let shared = AccessibilityAlertCoordinator()
    
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = "Please allow Accessibility."
    @Published var alertInformativeText: String = "To do this action please allow Accessibility in Security & Privacy preferences, located in System Settings."
    
    private init() {}
    
    /// Request to show the accessibility alert
    /// Called from service classes that don't have view context
    func requestAccessibilityAlert() {
        alertMessage = "Please allow Accessibility."
        alertInformativeText = "To do this action please allow Accessibility in Security & Privacy preferences, located in System Settings."
        
        // Ensure window is visible before showing alert
        // Find and show the main window if it exists
        if let window = NSApplication.shared.windows.first(where: { $0.title == "Gramfix" && $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
        
        // Activate app to ensure alert is visible
        NSApp.activate(ignoringOtherApps: true)
        
        // Small delay to ensure window is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showAlert = true
        }
    }
    
    /// Handle the "Open System Settings" button action
    func handleOpenSettings() {
        // Preserve previousApp when user returns from Settings
        PasteService.shared.shouldPreservePreviousApp = true
        
        // Open System Settings to Accessibility pane
        AccessibilityService.shared.openAccessibilitySettings()
        
        // Dismiss alert
        showAlert = false
    }
}

