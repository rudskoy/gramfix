import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global shortcut to toggle Gramfix window visibility
    static let toggleGramfix = Self("toggleGramfix", default: .init(.backslash, modifiers: [.command, .shift]))
    
    /// Shortcut to reset settings to default values
    static let resetSettings = Self("resetSettings", default: .init(.r, modifiers: [.command, .shift]))
}

