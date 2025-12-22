import SwiftUI

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var selectedItemId: UUID?
    @State private var showSettings = false
    @FocusState private var isSearchFieldFocused: Bool
    
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
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    if let item = selectedItem {
                        PasteService.shared.pasteAndReturn(content: item.pasteContent)
                    }
                } label: {
                    Label("Paste", systemImage: "doc.on.doc")
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(selectedItem == nil)
                .help("Paste and return to previous app (⏎)")
                
                Button {
                    if let item = selectedItem {
                        PasteService.shared.immediatePasteAndReturn(content: item.pasteContent)
                    }
                } label: {
                    Label("Immediate Paste", systemImage: "arrow.right.doc.on.clipboard")
                }
                .keyboardShortcut(.return, modifiers: .shift)
                .disabled(selectedItem == nil)
                .help("Paste and restore original clipboard (⇧⏎)")
                
                Button {
                    if let item = selectedItem {
                        deleteItem(item)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(selectedItem == nil)
                .help("Delete item (⌫)")
                
                Button {
                    if let item = selectedItem {
                        Task {
                            await clipboardManager.processItemWithLLM(item)
                        }
                    }
                } label: {
                    Label("Process with AI", systemImage: "sparkles")
                }
                .disabled(selectedItem == nil || selectedItem?.llmProcessing == true)
                .help("Process with AI")
            }
        }
        .onAppear {
            autoSelectFirstItem()
        }
        .onChange(of: clipboardManager.filteredItems) { _, newItems in
            // Auto-select first item if nothing is selected and list becomes non-empty
            if selectedItemId == nil, let firstItem = newItems.first {
                selectedItemId = firstItem.id
            }
        }
        .onKeyPress(keys: [.upArrow]) { keyPress in
            // Only handle plain arrow keys (no modifiers) when search field is not focused
            guard !isSearchFieldFocused && keyPress.modifiers.isEmpty else {
                return .ignored
            }
            selectPreviousItem()
            return .handled
        }
        .onKeyPress(keys: [.downArrow]) { keyPress in
            // Only handle plain arrow keys (no modifiers) when search field is not focused
            guard !isSearchFieldFocused && keyPress.modifiers.isEmpty else {
                return .ignored
            }
            selectNextItem()
            return .handled
        }
        .onKeyPress(keys: [.return]) { keyPress in
            // Don't intercept return when search field is focused
            guard !isSearchFieldFocused else {
                return .ignored
            }
            if let item = selectedItem {
                if keyPress.modifiers.contains(.shift) {
                    // Shift+Enter: Immediate paste (preserves clipboard)
                    PasteService.shared.immediatePasteAndReturn(content: item.pasteContent)
                } else {
                    // Enter: Regular paste (modifies clipboard)
                    PasteService.shared.pasteAndReturn(content: item.pasteContent)
                }
            }
            return .handled
        }
        .onKeyPress(keys: [.delete]) { keyPress in
            // Only handle delete when search field is not focused
            guard !isSearchFieldFocused else {
                return .ignored
            }
            if let item = selectedItem {
                deleteItem(item)
            }
            return .handled
        }
        .onKeyPress(characters: .alphanumerics.union(.punctuationCharacters).union(.whitespaces)) { keyPress in
            // Type-to-search: forward character input to search field
            // Only when search field is not focused and no modifiers are pressed
            if !isSearchFieldFocused && keyPress.modifiers.isEmpty {
                clipboardManager.searchQuery.append(keyPress.characters)
                isSearchFieldFocused = true
                return .handled
            }
            return .ignored
        }
    }
    
    // MARK: - Auto-Select First Item
    
    private func autoSelectFirstItem() {
        if selectedItemId == nil, let firstItem = clipboardManager.filteredItems.first {
            selectedItemId = firstItem.id
        }
    }
    
    // MARK: - List Pane
    
    private var listPane: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            // Subtle separator
            Rectangle()
                .fill(Color.clipBorder)
                .frame(height: 1)
            
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
                
                // LLM toggle button
                LLMToggleButton(
                    isEnabled: $clipboardManager.llmAutoProcess,
                    isProcessing: clipboardManager.llmService.isProcessing
                )
                
                // Item count badge
                Text("\(clipboardManager.items.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.1), in: Capsule())
            }
            
            SearchBar(text: $clipboardManager.searchQuery, isFocused: $isSearchFieldFocused)
        }
        .padding(12)
        .sheet(isPresented: $showSettings) {
            SettingsView()
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
    
    // MARK: - Empty State (with Otter Mascot)
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Otter mascot as the centerpiece
            OtterMascot(size: 100, animated: true)
            
            VStack(spacing: 6) {
                Text(clipboardManager.searchQuery.isEmpty ? "Ready to catch your clips!" : "No matching clips found")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(clipboardManager.searchQuery.isEmpty ? "Copy something to get started" : "Try a different search term")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Actions
    
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
