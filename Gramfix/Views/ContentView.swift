import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @ObservedObject var alertCoordinator = AccessibilityAlertCoordinator.shared
    @State private var selectedItemId: UUID?
    @State private var showSettings = false
    @State private var keyboardMonitor: Any?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var itemCountOnUnfocus: Int = 0
    @State private var searchAttention: Bool = false
    @State private var searchShowingSuggestions: Bool = false
    @State private var isLanguageFocused: Bool = false
    @State private var isLanguageDropdownOpen: Bool = false
    @State private var wasSearchFieldFocusedBeforeDropdown: Bool = false
    @State private var selectedTab: ClipboardType? = nil
    @State private var showUsefulTab: Bool = false
    
    private var selectedItem: ClipboardItem? {
        guard let id = selectedItemId else { return nil }
        return clipboardManager.items.first { $0.id == id }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - NavigationSplitView handles glass styling natively
            listPane
                .navigationSplitViewColumnWidth(min: 220, ideal: 300, max: 420)
        } detail: {
            // Detail pane - positioned next to sidebar, not under it
            PreviewPane(selectedItemId: selectedItemId, isLanguageFocused: $isLanguageFocused, isLanguageDropdownOpen: $isLanguageDropdownOpen)
                .frame(minWidth: 280)
                .overlay(alignment: .topLeading) {
                    FixedTooltipView(alignment: .leading)
                        .padding(.top, 4)
                        .padding(.leading, 8)
                }
                .overlay(alignment: .topTrailing) {
                    FixedTooltipView(alignment: .trailing)
                        .padding(.top, 4)
                        .padding(.trailing, 8)
                }
        }
        .navigationTitle("")
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                GlassToolbarGroup {
                    ToolbarActionButton(
                        icon: "doc.on.doc",
                        title: "Paste",
                        description: "Paste content and return to previous app",
                        shortcut: "⏎ Return",
                        isDisabled: selectedItem == nil
                    ) {
                        if let item = selectedItem {
                            pasteItem(item)
                        }
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    
                    ToolbarActionButton(
                        icon: "arrow.right.doc.on.clipboard",
                        title: "Quick Paste",
                        description: "Paste without modifying clipboard, preserves original",
                        shortcut: "⇧ Shift + ⏎ Return",
                        isDisabled: selectedItem == nil
                    ) {
                        if let item = selectedItem {
                            immediatePasteItem(item)
                        }
                    }
                    .keyboardShortcut(.return, modifiers: .shift)
                    
                    ToolbarActionButton(
                        icon: "doc.plaintext",
                        title: "Paste Original",
                        description: "Paste original content, ignoring AI response",
                        shortcut: "⌘ Cmd + ⏎ Return",
                        isDisabled: selectedItem == nil
                    ) {
                        if let item = selectedItem {
                            pasteOriginalItem(item)
                        }
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            
            ToolbarItem(placement: .navigation) {
                ToolbarActionButton(
                    icon: "trash",
                    title: "Delete",
                    description: "Remove this item from clipboard history",
                    isDisabled: selectedItem == nil
                ) {
                    if let item = selectedItem {
                        deleteItem(item)
                    }
                }
            }
            .sharedBackgroundVisibility(.hidden)
            
            ToolbarItem(placement: .primaryAction) {
                GlassToolbarGroup {
                    ThemeToggleButton()
                    
                    ImageAnalysisToggleButton()
                    
                    ToolbarActionButton(
                        icon: selectedItem?.isUseful == true ? "star.fill" : "star",
                        title: selectedItem?.isUseful == true ? "Unmark Useful" : "Mark Useful",
                        description: selectedItem?.isUseful == true ? "Remove useful tag from this item" : "Mark this item as useful",
                        shortcut: "⌘ Cmd + U",
                        isDisabled: selectedItem == nil,
                        tooltipAlignment: .trailing,
                        iconForegroundStyle: selectedItem?.isUseful == true ? AnyShapeStyle(LinearGradient.accentGradient) : nil
                    ) {
                        if let item = selectedItem {
                            clipboardManager.toggleUsefulFlag(for: item)
                        }
                    }
                    .keyboardShortcut("u", modifiers: .command)
                    
                    ToolbarActionButton(
                        icon: "sparkles",
                        title: "Process with AI",
                        description: "Analyze content using AI",
                        isDisabled: selectedItem == nil || selectedItem?.isProcessing == true || selectedItem?.imageAnalysisProcessing == true,
                        tooltipAlignment: .trailing
                    ) {
                        if let item = selectedItem {
                            Task {
                                if item.type == .image {
                                    await clipboardManager.analyzeImage(item)
                                } else {
                                    await clipboardManager.processItemWithLLM(item)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            autoSelectFirstItem()
            setupKeyboardMonitor()
            isSearchFieldFocused = true
            // Sync initial tab state
            selectedTab = clipboardManager.selectedTabType
            showUsefulTab = clipboardManager.showOnlyUseful
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onChange(of: clipboardManager.filteredItems) { _, newItems in
            // Auto-select first item if nothing is selected and list becomes non-empty
            if selectedItemId == nil, let firstItem = newItems.first {
                selectedItemId = firstItem.id
            }
        }
        .onChange(of: selectedItemId) { _, _ in
            // Reset language focus when changing items
            isLanguageFocused = false
            // Keep search field focused even when language dropdown opens
        }
        .onChange(of: isLanguageDropdownOpen) { _, isOpen in
            if isOpen {
                // Remember if search field was focused, then unfocus to allow popover interaction
                wasSearchFieldFocusedBeforeDropdown = isSearchFieldFocused
                isSearchFieldFocused = false
            } else {
                // Re-focus search field when dropdown closes (only if it was focused before)
                if wasSearchFieldFocusedBeforeDropdown {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isSearchFieldFocused = true
                    }
                }
            }
        }
        .onChange(of: showUsefulTab) { _, newValue in
            clipboardManager.showOnlyUseful = newValue
            // Clear type tab when useful tab is selected
            if newValue {
                selectedTab = nil
            }
            // Auto-select first item when tab changes
            if let firstItem = clipboardManager.filteredItems.first {
                selectedItemId = firstItem.id
            } else {
                selectedItemId = nil
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            clipboardManager.selectedTabType = newTab
            // Clear useful tab when type tab is selected
            if newTab != nil {
                showUsefulTab = false
            }
            // Auto-select first item when tab changes
            if let firstItem = clipboardManager.filteredItems.first {
                selectedItemId = firstItem.id
            } else {
                selectedItemId = nil
            }
        }
        .onChange(of: clipboardManager.searchQuery) { _, newQuery in
            if !newQuery.isEmpty {
                selectedItemId = clipboardManager.filteredItems.first?.id
            }
            // Sync tab selection with search query type filters
            let filter = SearchFilter.parse(newQuery)
            if filter.hasFilters {
                // If search has type filters, update tab to match
                if filter.includedTypes.count == 1, let type = filter.includedTypes.first {
                    // Single type filter - sync tab to match
                    selectedTab = type
                } else if !filter.includedTypes.isEmpty {
                    // Multiple types selected, clear tab (search filter takes precedence)
                    selectedTab = nil
                } else if !filter.excludedTypes.isEmpty {
                    // Excluded types - don't change tab, let exclusion work alongside tab
                    // Tab selection remains as is
                }
            } else if newQuery.isEmpty {
                // Search cleared - keep current tab selection
                // Tab selection remains as is
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Check if clipboard changed while app was unfocused
            if clipboardManager.hasClipboardChangedSinceUnfocus() {
                // Clipboard changed - process it and select first item
                clipboardManager.checkClipboardNow()
                // Use a small delay to ensure clipboard processing completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectFirstItem()
                }
            }
            isSearchFieldFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            itemCountOnUnfocus = clipboardManager.items.count
            clipboardManager.saveChangeCountOnUnfocus()
        }
        .overlay(alignment: .center) {
            alertOverlay
        }
        .onChange(of: alertCoordinator.showAlert) { _, showAlert in
            // Activate app when alert is shown to ensure it's visible
            if showAlert {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    // MARK: - Auto-Select First Item
    
    private func autoSelectFirstItem() {
        if selectedItemId == nil, let firstItem = clipboardManager.filteredItems.first {
            selectedItemId = firstItem.id
        }
    }
    
    private func selectFirstItem() {
        selectedItemId = clipboardManager.filteredItems.first?.id
    }
    
    // MARK: - List Pane
    
    private var listPane: some View {
        VStack(spacing: 0) {
            // Header (zIndex ensures suggestions overlay appears above list)
            header
                .zIndex(1)
            
            // List
            if clipboardManager.filteredItems.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("Gramfix")
                    .font(.clipHeader)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Settings button
                SettingsButton {
                    showSettings = true
                }
            }
            
            TypeFilterTabs(selectedTab: $selectedTab, showUsefulTab: $showUsefulTab)
            
            SearchBar(text: $clipboardManager.searchQuery, isFocused: $isSearchFieldFocused, triggerAttention: $searchAttention, showingSuggestions: $searchShowingSuggestions)
                .padding(.bottom, 4) // Extra space for shadow
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(clipboardManager)
        }
        .background {
            // Hidden button to capture Cmd+, keyboard shortcut for settings
            Button("") {
                showSettings = true
            }
            .keyboardShortcut(",", modifiers: .command)
            .hidden()
            
            // Hidden button to capture Cmd+F keyboard shortcut for search focus
            Button("") {
                if isSearchFieldFocused {
                    // Already focused - trigger attention animation
                    searchAttention.toggle()
                } else {
                    isSearchFieldFocused = true
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .hidden()
            
            // Hidden button to capture Cmd+U keyboard shortcut for toggling useful flag
            Button("") {
                if let item = selectedItem {
                    clipboardManager.toggleUsefulFlag(for: item)
                }
            }
            .keyboardShortcut("u", modifiers: .command)
            .hidden()
            
            // Hidden button to capture Cmd+1 keyboard shortcut for All tab
            Button("") {
                selectedTab = nil
                showUsefulTab = false
            }
            .keyboardShortcut("1", modifiers: .command)
            .hidden()
            
            // Hidden button to capture Cmd+2 keyboard shortcut for Useful tab
            Button("") {
                selectedTab = nil
                showUsefulTab = true
            }
            .keyboardShortcut("2", modifiers: .command)
            .hidden()
        }
    }
    
    // MARK: - Item List
    
    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(clipboardManager.filteredItems) { item in
                    ClipboardRow(item: item, isSelected: selectedItemId == item.id)
                        .id(item.id)
                        .onTapGesture {
                            selectedItemId = item.id
                        }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Keyboard Navigation
    
    private func selectPreviousItem() {
        let items = clipboardManager.filteredItems
        guard !items.isEmpty else { return }
        
        if let currentId = selectedItemId,
           let currentIndex = items.firstIndex(where: { $0.id == currentId }),
           currentIndex > 0 {
            selectedItemId = items[currentIndex - 1].id
        } else if selectedItemId == nil {
            selectedItemId = items.first?.id
        }
    }
    
    private func selectNextItem() {
        let items = clipboardManager.filteredItems
        guard !items.isEmpty else { return }
        
        if let currentId = selectedItemId,
           let currentIndex = items.firstIndex(where: { $0.id == currentId }),
           currentIndex < items.count - 1 {
            selectedItemId = items[currentIndex + 1].id
        } else if selectedItemId == nil {
            selectedItemId = items.first?.id
        }
    }
    
    // MARK: - Prompt Tag and Language Navigation
    
    private func selectPreviousPrompt(for item: ClipboardItem) {
        let allPrompts = TextPromptType.allCases
        
        // If language is focused, wrap to last prompt tag
        if isLanguageFocused {
            isLanguageFocused = false
            clipboardManager.selectPrompt(allPrompts[allPrompts.count - 1], for: item)
            return
        }
        
        guard let currentIndex = allPrompts.firstIndex(where: { $0.rawValue == item.selectedPromptId }) else {
            return
        }
        
        // If at first prompt, focus language flag
        if currentIndex == 0 {
            isLanguageFocused = true
        } else {
            clipboardManager.selectPrompt(allPrompts[currentIndex - 1], for: item)
        }
    }
    
    private func selectNextPrompt(for item: ClipboardItem) {
        let allPrompts = TextPromptType.allCases
        
        // If language is focused, move to first prompt tag
        if isLanguageFocused {
            isLanguageFocused = false
            clipboardManager.selectPrompt(allPrompts[0], for: item)
            return
        }
        
        guard let currentIndex = allPrompts.firstIndex(where: { $0.rawValue == item.selectedPromptId }) else {
            return
        }
        
        // If at last prompt, wrap to language flag
        if currentIndex == allPrompts.count - 1 {
            isLanguageFocused = true
        } else {
            clipboardManager.selectPrompt(allPrompts[currentIndex + 1], for: item)
        }
    }
    
    // MARK: - Keyboard Monitor (NSEvent)
    
    private func setupKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // Only check for user-controlled modifiers, not intrinsic flags like .function/.numericPad
            let userModifiers: NSEvent.ModifierFlags = [.command, .shift, .control, .option]
            let hasUserModifiers = !event.modifierFlags.intersection(userModifiers).isEmpty
            
            // Skip arrow handling when search suggestions are visible (let SearchBar handle them)
            if searchShowingSuggestions {
                return event
            }
            
            // Handle arrow keys for navigation
            switch event.keyCode {
            case 126: // Up arrow - list navigation
                if !hasUserModifiers {
                    // Skip up arrow when language dropdown is open (let LanguageFlagView handle it)
                    if isLanguageDropdownOpen {
                        return event
                    }
                    selectPreviousItem()
                    return nil // Consume the event
                }
            case 125: // Down arrow - list navigation
                if !hasUserModifiers {
                    // Skip down arrow when language dropdown is open (let LanguageFlagView handle it)
                    if isLanguageDropdownOpen {
                        return event
                    }
                    // If language tag is focused but dropdown isn't shown, open the dropdown
                    if isLanguageFocused {
                        isLanguageDropdownOpen = true
                        return nil // Consume the event
                    }
                    selectNextItem()
                    return nil // Consume the event
                }
            case 123: // Left arrow - previous prompt tag
                if !hasUserModifiers {
                    if let item = selectedItem {
                        selectPreviousPrompt(for: item)
                        return nil // Consume the event
                    }
                }
            case 124: // Right arrow - next prompt tag
                if !hasUserModifiers {
                    if let item = selectedItem {
                        selectNextPrompt(for: item)
                        return nil // Consume the event
                    }
                }
            default:
                break
            }
            
            // Handle 1-4 number keys for prompt selection (only when search field is not focused)
            // This allows typing numbers in search while providing quick prompt switching
            if !isSearchFieldFocused && !hasUserModifiers {
                var promptType: TextPromptType?
                switch event.keyCode {
                case 18: promptType = .grammar   // 1
                case 19: promptType = .formal    // 2
                case 20: promptType = .casual    // 3
                case 21: promptType = .polished  // 4
                default: break
                }
                if let promptType = promptType, let item = selectedItem {
                    clipboardManager.selectPrompt(promptType, for: item)
                    return nil // Consume the event
                }
            }
            
            return event // Pass through unhandled events
        }
    }
    
    private func removeKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            
            Text(clipboardManager.searchQuery.isEmpty ? "Ready to catch your clips!" : "No matching clips found")
                .font(.system(size: 15, weight: .semibold, design: .default))
                .foregroundStyle(.primary)
            
            Text(clipboardManager.searchQuery.isEmpty ? "Copy something to get started" : "Try a different search term")
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(.tertiary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Actions
    
    private func pasteItem(_ item: ClipboardItem) {
        switch item.type {
        case .text:
            // Use ALL original pasteboard data if pasting original content (not AI-processed)
            if item.pasteContent == item.content {
                if item.allPasteboardData != nil || item.rtfData != nil || item.htmlData != nil {
                    PasteService.shared.pasteAndReturn(
                        allPasteboardData: item.allPasteboardData,
                        rtfData: item.rtfData,
                        htmlData: item.htmlData,
                        content: item.pasteContent
                    )
                } else {
                    PasteService.shared.pasteAndReturn(content: item.pasteContent)
                }
            } else {
                // AI-processed content - just paste plain text
                PasteService.shared.pasteAndReturn(content: item.pasteContent)
            }
        case .link:
            // Use ALL original pasteboard data for links
            if item.allPasteboardData != nil || item.rtfData != nil || item.htmlData != nil {
                PasteService.shared.pasteAndReturn(
                    allPasteboardData: item.allPasteboardData,
                    rtfData: item.rtfData,
                    htmlData: item.htmlData,
                    content: item.content
                )
            } else {
                PasteService.shared.pasteAndReturn(content: item.content)
            }
        case .image:
            if let data = item.rawData {
                PasteService.shared.pasteAndReturn(data: data, type: .png)
            }
        case .file, .other:
            PasteService.shared.pasteAndReturn(content: item.content)
        }
        clipboardManager.recordPaste(for: item)
    }
    
    private func immediatePasteItem(_ item: ClipboardItem) {
        switch item.type {
        case .text:
            // Use ALL original pasteboard data if pasting original content (not AI-processed)
            if item.pasteContent == item.content {
                if item.allPasteboardData != nil || item.rtfData != nil || item.htmlData != nil {
                    PasteService.shared.immediatePasteAndReturn(
                        allPasteboardData: item.allPasteboardData,
                        rtfData: item.rtfData,
                        htmlData: item.htmlData,
                        content: item.pasteContent
                    )
                } else {
                    PasteService.shared.immediatePasteAndReturn(content: item.pasteContent)
                }
            } else {
                // AI-processed content - just paste plain text
                PasteService.shared.immediatePasteAndReturn(content: item.pasteContent)
            }
        case .link:
            // Use ALL original pasteboard data for links
            if item.allPasteboardData != nil || item.rtfData != nil || item.htmlData != nil {
                PasteService.shared.immediatePasteAndReturn(
                    allPasteboardData: item.allPasteboardData,
                    rtfData: item.rtfData,
                    htmlData: item.htmlData,
                    content: item.content
                )
            } else {
                PasteService.shared.immediatePasteAndReturn(content: item.content)
            }
        case .image:
            if let data = item.rawData {
                PasteService.shared.immediatePasteAndReturn(data: data, type: .png)
            }
        case .file, .other:
            PasteService.shared.immediatePasteAndReturn(content: item.content)
        }
        clipboardManager.recordPaste(for: item)
    }
    
    private func pasteOriginalItem(_ item: ClipboardItem) {
        switch item.type {
        case .text, .link:
            // Use ALL original pasteboard data if available (preserves app-specific formats like Telegram's)
            if item.allPasteboardData != nil || item.rtfData != nil || item.htmlData != nil {
                PasteService.shared.pasteAndReturn(
                    allPasteboardData: item.allPasteboardData,
                    rtfData: item.rtfData,
                    htmlData: item.htmlData,
                    content: item.content
                )
            } else {
                PasteService.shared.pasteAndReturn(content: item.content)
            }
        case .image:
            if let data = item.rawData {
                PasteService.shared.pasteAndReturn(data: data, type: .png)
            }
        case .file, .other:
            PasteService.shared.pasteAndReturn(content: item.content)
        }
        clipboardManager.recordPaste(for: item)
    }
    
    private func copyItem(_ item: ClipboardItem) {
        clipboardManager.copyToClipboard(item)
    }
    
    private func deleteItem(_ item: ClipboardItem) {
        let items = clipboardManager.filteredItems
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            // Select next or previous item
            if index + 1 < items.count {
                selectedItemId = items[index + 1].id
            } else if index > 0 {
                selectedItemId = items[index - 1].id
            } else {
                selectedItemId = nil
            }
        }
        clipboardManager.deleteItem(item)
    }
    
    // MARK: - Alert Overlay
    
    @ViewBuilder
    private var alertOverlay: some View {
        if alertCoordinator.showAlert {
            CustomAlertView(
                title: alertCoordinator.alertMessage,
                message: alertCoordinator.alertInformativeText,
                primaryButtonTitle: "Open System Settings",
                primaryButtonAction: {
                    alertCoordinator.handleOpenSettings()
                },
                isPresented: $alertCoordinator.showAlert
            )
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ClipboardManager())
        .frame(width: 700, height: 450)
}
