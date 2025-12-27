import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global shortcut to toggle Gramfix window visibility
    static let toggleGramfix = Self("toggleGramfix", default: .init(.backslash, modifiers: [.command, .shift]))
}

