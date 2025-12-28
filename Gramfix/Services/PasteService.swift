import AppKit
import Carbon.HIToolbox

class PasteService {
    static let shared = PasteService()
    
    private var previousApp: NSRunningApplication?
    
    /// When true, the next savePreviousApp() call will be skipped.
    /// Used to preserve previousApp when returning from accessibility permission flow.
    var shouldPreservePreviousApp = false
    
    func savePreviousApp() {
        // Skip updating if we're returning from the accessibility permission flow
        if shouldPreservePreviousApp {
            shouldPreservePreviousApp = false
            return
        }
        
        let currentApp = NSWorkspace.shared.frontmostApplication
        if currentApp != NSRunningApplication.current {
            previousApp = currentApp
        }
    }
    
    /// Return focus to the previously saved app without pasting
    func returnToPreviousApp() {
        guard let app = previousApp, app != NSRunningApplication.current else {
            NSApplication.shared.hide(nil)
            return
        }
        NSApplication.shared.hide(nil)
        app.activate()
    }
    
    // MARK: - Regular Paste (modifies clipboard)
    
    /// Paste content to the previous app. The content stays on the clipboard.
    func pasteAndReturn(content: String) {
        // Check Accessibility permission
        guard AccessibilityService.shared.isAccessibilityEnabled(prompt: false) else {
            AccessibilityService.shared.showAccessibilityAuthenticationAlert()
            return
        }
        
        guard let app = previousApp, app != NSRunningApplication.current else {
            NSApplication.shared.hide(nil)
            return
        }
        
        // 1. Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        
        // Notify ClipboardManager to ignore this change
        NotificationCenter.default.post(
            name: NSNotification.Name("GramfixInternalPaste"),
            object: nil,
            userInfo: ["changeCount": pasteboard.changeCount]
        )
        
        // 2. Hide Gramfix
        NSApplication.shared.hide(nil)
        
        // 3. Activate previous app
        app.activate()
        
        // 4. Simulate Cmd+V after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
        }
    }
    
    /// Paste RTF content to the previous app. The content stays on the clipboard.
    /// Preserves formatting when available.
    func pasteAndReturn(rtfData: Data, content: String) {
        // Check Accessibility permission
        guard AccessibilityService.shared.isAccessibilityEnabled(prompt: false) else {
            AccessibilityService.shared.showAccessibilityAuthenticationAlert()
            return
        }
        
        guard let app = previousApp, app != NSRunningApplication.current else {
            NSApplication.shared.hide(nil)
            return
        }
        
        // 1. Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(rtfData, forType: .rtf)
        // Always set plain text as fallback for compatibility
        pasteboard.setString(content, forType: .string)
        
        // Notify ClipboardManager to ignore this change
        NotificationCenter.default.post(
            name: NSNotification.Name("GramfixInternalPaste"),
            object: nil,
            userInfo: ["changeCount": pasteboard.changeCount]
        )
        
        // 2. Hide Gramfix
        NSApplication.shared.hide(nil)
        
        // 3. Activate previous app
        app.activate()
        
        // 4. Simulate Cmd+V after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
        }
    }
    
    /// Paste raw data to the previous app. The content stays on the clipboard.
    /// Used for images and other binary content.
    func pasteAndReturn(data: Data, type: NSPasteboard.PasteboardType) {
        // Check Accessibility permission
        guard AccessibilityService.shared.isAccessibilityEnabled(prompt: false) else {
            AccessibilityService.shared.showAccessibilityAuthenticationAlert()
            return
        }
        
        guard let app = previousApp, app != NSRunningApplication.current else {
            NSApplication.shared.hide(nil)
            return
        }
        
        // 1. Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: type)
        
        // Notify ClipboardManager to ignore this change
        NotificationCenter.default.post(
            name: NSNotification.Name("GramfixInternalPaste"),
            object: nil,
            userInfo: ["changeCount": pasteboard.changeCount]
        )
        
        // 2. Hide Gramfix
        NSApplication.shared.hide(nil)
        
        // 3. Activate previous app
        app.activate()
        
        // 4. Simulate Cmd+V after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
        }
    }
    
    // MARK: - Immediate Paste (preserves clipboard)
    
    /// Paste content to the previous app, then restore the original clipboard contents.
    func immediatePasteAndReturn(content: String) {
        // Check Accessibility permission
        guard AccessibilityService.shared.isAccessibilityEnabled(prompt: false) else {
            AccessibilityService.shared.showAccessibilityAuthenticationAlert()
            return
        }
        
        guard let app = previousApp, app != NSRunningApplication.current else {
            NSApplication.shared.hide(nil)
            return
        }
        
        // 1. Save current clipboard contents
        let savedItems = saveClipboard()
        
        // 2. Copy new content to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        
        // Notify ClipboardManager to ignore this change
        NotificationCenter.default.post(
            name: NSNotification.Name("GramfixInternalPaste"),
            object: nil,
            userInfo: ["changeCount": pasteboard.changeCount]
        )
        
        // 3. Hide Gramfix
        NSApplication.shared.hide(nil)
        
        // 4. Activate previous app
        app.activate()
        
        // 5. Simulate Cmd+V after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
            
            // 6. Restore original clipboard after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.restoreClipboard(savedItems)
            }
        }
    }
    
    /// Paste RTF content to the previous app, then restore the original clipboard contents.
    /// Preserves formatting when available.
    func immediatePasteAndReturn(rtfData: Data, content: String) {
        // Check Accessibility permission
        guard AccessibilityService.shared.isAccessibilityEnabled(prompt: false) else {
            AccessibilityService.shared.showAccessibilityAuthenticationAlert()
            return
        }
        
        guard let app = previousApp, app != NSRunningApplication.current else {
            NSApplication.shared.hide(nil)
            return
        }
        
        // 1. Save current clipboard contents
        let savedItems = saveClipboard()
        
        // 2. Copy new content to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(rtfData, forType: .rtf)
        // Always set plain text as fallback for compatibility
        pasteboard.setString(content, forType: .string)
        
        // Notify ClipboardManager to ignore this change
        NotificationCenter.default.post(
            name: NSNotification.Name("GramfixInternalPaste"),
            object: nil,
            userInfo: ["changeCount": pasteboard.changeCount]
        )
        
        // 3. Hide Gramfix
        NSApplication.shared.hide(nil)
        
        // 4. Activate previous app
        app.activate()
        
        // 5. Simulate Cmd+V after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
            
            // 6. Restore original clipboard after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.restoreClipboard(savedItems)
            }
        }
    }
    
    /// Paste raw data to the previous app, then restore the original clipboard contents.
    /// Used for images and other binary content.
    func immediatePasteAndReturn(data: Data, type: NSPasteboard.PasteboardType) {
        // Check Accessibility permission
        guard AccessibilityService.shared.isAccessibilityEnabled(prompt: false) else {
            AccessibilityService.shared.showAccessibilityAuthenticationAlert()
            return
        }
        
        guard let app = previousApp, app != NSRunningApplication.current else {
            NSApplication.shared.hide(nil)
            return
        }
        
        // 1. Save current clipboard contents
        let savedItems = saveClipboard()
        
        // 2. Copy new content to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: type)
        
        // Notify ClipboardManager to ignore this change
        NotificationCenter.default.post(
            name: NSNotification.Name("GramfixInternalPaste"),
            object: nil,
            userInfo: ["changeCount": pasteboard.changeCount]
        )
        
        // 3. Hide Gramfix
        NSApplication.shared.hide(nil)
        
        // 4. Activate previous app
        app.activate()
        
        // 5. Simulate Cmd+V after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
            
            // 6. Restore original clipboard after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.restoreClipboard(savedItems)
            }
        }
    }
    
    // MARK: - Clipboard Save/Restore
    
    /// Save current clipboard contents for later restoration
    private func saveClipboard() -> [NSPasteboardItem] {
        let pasteboard = NSPasteboard.general
        return pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []
    }
    
    /// Restore previously saved clipboard contents
    private func restoreClipboard(_ items: [NSPasteboardItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
        
        // Notify ClipboardManager to ignore this change
        NotificationCenter.default.post(
            name: NSNotification.Name("GramfixInternalPaste"),
            object: nil,
            userInfo: ["changeCount": pasteboard.changeCount]
        )
    }
    
    // MARK: - Keyboard Simulation
    
    /// Simulate Cmd+V keystroke using CGEvent
    /// Uses CGEventSource for more reliable event simulation (from Clipy)
    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Disable local keyboard events while pasting
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        
        let vKeyCode: CGKeyCode = 0x09 // V key
        
        // Press Command + V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        
        // Release Command + V
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
