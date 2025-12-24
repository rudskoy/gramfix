import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var selectedItemId: UUID?
    @State private var showSettings = false
    @State private var keyboardMonitor: Any?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var itemCountOnUnfocus: Int = 0
    @State private var searchAttention: Bool = false
    @State private var searchShowingSuggestions: Bool = false
    
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
            PreviewPane(item: selectedItem)
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
                    
                    ToolbarActionButton(
                        icon: "sparkles",
                        title: "Process with AI",
                        description: "Analyze content using Ollama LLM",
                        isDisabled: selectedItem == nil || selectedItem?.llmProcessing == true,
                        tooltipAlignment: .trailing
                    ) {
                        if let item = selectedItem {
                            Task {
                                await clipboardManager.processItemWithLLM(item)
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
        .onChange(of: clipboardManager.searchQuery) { _, newQuery in
            if !newQuery.isEmpty {
                selectedItemId = clipboardManager.filteredItems.first?.id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if clipboardManager.items.count != itemCountOnUnfocus {
                selectFirstItem()
            }
            isSearchFieldFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            itemCountOnUnfocus = clipboardManager.items.count
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
                Text("Clipsa")
                    .font(.clipHeader)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Settings button
                SettingsButton {
                    showSettings = true
                }
            }
            
            SearchBar(text: $clipboardManager.searchQuery, isFocused: $isSearchFieldFocused, triggerAttention: $searchAttention, showingSuggestions: $searchShowingSuggestions)
                .padding(.bottom, 4) // Extra space for shadow
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .sheet(isPresented: $showSettings) {
            SettingsView()
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
        }
    }
    
    // MARK: - Item List
    
    private var itemList: some View {
        ScrollViewReader { proxy in
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
            .onChange(of: selectedItemId) { _, newId in
                if let id = newId {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
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
            
            // Handle arrow keys for list navigation (works even when search field is focused,
            // since up/down arrows have no useful function in a single-line text field)
            switch event.keyCode {
            case 126: // Up arrow
                if !hasUserModifiers {
                    selectPreviousItem()
                    return nil // Consume the event
                }
            case 125: // Down arrow
                if !hasUserModifiers {
                    selectNextItem()
                    return nil // Consume the event
                }
            default:
                break
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
            PasteService.shared.pasteAndReturn(content: item.pasteContent)
        case .link:
            PasteService.shared.pasteAndReturn(content: item.content)
        case .image:
            if let data = item.rawData {
                PasteService.shared.pasteAndReturn(data: data, type: .png)
            }
        case .file, .other:
            PasteService.shared.pasteAndReturn(content: item.content)
        }
    }
    
    private func immediatePasteItem(_ item: ClipboardItem) {
        switch item.type {
        case .text:
            PasteService.shared.immediatePasteAndReturn(content: item.pasteContent)
        case .link:
            PasteService.shared.immediatePasteAndReturn(content: item.content)
        case .image:
            if let data = item.rawData {
                PasteService.shared.immediatePasteAndReturn(data: data, type: .png)
            }
        case .file, .other:
            PasteService.shared.immediatePasteAndReturn(content: item.content)
        }
    }
    
    private func pasteOriginalItem(_ item: ClipboardItem) {
        switch item.type {
        case .text:
            PasteService.shared.pasteAndReturn(content: item.content)
        case .link:
            PasteService.shared.pasteAndReturn(content: item.content)
        case .image:
            if let data = item.rawData {
                PasteService.shared.pasteAndReturn(data: data, type: .png)
            }
        case .file, .other:
            PasteService.shared.pasteAndReturn(content: item.content)
        }
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
}

#Preview {
    ContentView()
        .environmentObject(ClipboardManager())
        .frame(width: 700, height: 450)
}
