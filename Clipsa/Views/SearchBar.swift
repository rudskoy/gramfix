import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    @Binding var triggerAttention: Bool
    @Binding var showingSuggestions: Bool  // Exposed for keyboard handling coordination
    
    @State private var breatheScale: CGFloat = 1.0
    
    // Autocomplete state
    @State private var showSuggestions = false {
        didSet { showingSuggestions = showSuggestions && !filteredSuggestions.isEmpty }
    }
    @State private var selectedSuggestionIndex = 0
    @State private var currentFilterPrefix: String? = nil // "-" or "+"
    @State private var currentPartialType: String = ""
    @State private var filteredSuggestions: [SearchFilter.Suggestion] = [] {
        didSet { showingSuggestions = showSuggestions && !filteredSuggestions.isEmpty }
    }
    
    var body: some View {
        searchField
            .overlay(alignment: .topLeading) {
                if showSuggestions && !filteredSuggestions.isEmpty {
                    suggestionsView
                        .offset(y: 40) // Position below the search bar
                }
            }
            .zIndex(100) // Ensure suggestions appear above other content
    }
    
    // MARK: - Search Field
    
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            TextField("Search clipboard...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .rounded))
                .focused(isFocused)
                .onKeyPress(.upArrow) {
                    if showSuggestions {
                        moveSuggestionSelection(by: -1)
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.downArrow) {
                    if showSuggestions {
                        moveSuggestionSelection(by: 1)
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.return) {
                    if showSuggestions && !filteredSuggestions.isEmpty {
                        selectCurrentSuggestion()
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.escape) {
                    if showSuggestions {
                        hideSuggestions()
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.tab) {
                    if showSuggestions && !filteredSuggestions.isEmpty {
                        selectCurrentSuggestion()
                        return .handled
                    }
                    return .ignored
                }
            
            if text.isEmpty {
                HStack(spacing: 2) {
                    Text("⌘")
                        .font(.system(size: 11, weight: .medium))
                    Text("F")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.tertiary)
            } else {
                Button(action: { 
                    withAnimation(.easeOut(duration: 0.2)) {
                        text = "" 
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .scaleEffect(breatheScale)
        .glassEffect(in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isFocused.wrappedValue ? Color.clipAccent.opacity(0.4) : .clear,
                    lineWidth: 1.5
                )
        }
        .shadow(color: isFocused.wrappedValue ? Color.clipAccent.opacity(0.15) : .clear, radius: 6)
        .animation(.easeOut(duration: 0.2), value: isFocused.wrappedValue)
        .onChange(of: triggerAttention) { _, _ in
            // Breathing animation: scale up then back to normal
            withAnimation(.easeOut(duration: 0.15)) {
                breatheScale = 1.03
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    breatheScale = 1.0
                }
            }
        }
        .onChange(of: text) { _, newValue in
            updateSuggestions(for: newValue)
        }
    }
    
    // MARK: - Suggestions View
    
    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(filteredSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                suggestionRow(suggestion: suggestion, isSelected: index == selectedSuggestionIndex)
                    .onTapGesture {
                        selectedSuggestionIndex = index
                        selectCurrentSuggestion()
                    }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.08))
        )
        .glassEffect(in: .rect(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
    
    private func suggestionRow(suggestion: SearchFilter.Suggestion, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isSelected ? "chevron.right" : "")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.clipAccent)
                .frame(width: 10)
            
            Text(suggestion.displayName)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
            
            if let aliases = suggestion.aliases {
                Text("(\(aliases))")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.clipAccent.opacity(0.15) : .clear)
        )
        .contentShape(Rectangle())
    }
    
    // MARK: - Suggestion Logic
    
    private func updateSuggestions(for query: String) {
        // Find the last word being typed
        let words = query.split(separator: " ", omittingEmptySubsequences: false)
        guard let lastWord = words.last, !lastWord.isEmpty else {
            hideSuggestions()
            return
        }
        
        let lastWordStr = String(lastWord)
        
        // Check if last word starts with - or +
        if lastWordStr.hasPrefix("-") || lastWordStr.hasPrefix("+") {
            currentFilterPrefix = String(lastWordStr.prefix(1))
            currentPartialType = String(lastWordStr.dropFirst())
            
            // Filter suggestions
            filteredSuggestions = SearchFilter.filterSuggestions(matching: currentPartialType)
            
            if !filteredSuggestions.isEmpty {
                selectedSuggestionIndex = 0
                showSuggestions = true
            } else {
                hideSuggestions()
            }
        } else {
            hideSuggestions()
        }
    }
    
    private func hideSuggestions() {
        showSuggestions = false
        currentFilterPrefix = nil
        currentPartialType = ""
        filteredSuggestions = []
    }
    
    private func moveSuggestionSelection(by offset: Int) {
        guard !filteredSuggestions.isEmpty else { return }
        let newIndex = selectedSuggestionIndex + offset
        selectedSuggestionIndex = max(0, min(newIndex, filteredSuggestions.count - 1))
    }
    
    private func selectCurrentSuggestion() {
        guard selectedSuggestionIndex < filteredSuggestions.count,
              let prefix = currentFilterPrefix else { return }
        
        let suggestion = filteredSuggestions[selectedSuggestionIndex]
        
        // Replace the partial filter with the complete one
        var words = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        if !words.isEmpty {
            words[words.count - 1] = prefix + suggestion.displayName
        }
        
        // Add a space after the filter for convenience
        text = words.joined(separator: " ") + " "
        
        hideSuggestions()
    }
}

struct SearchBarPreview: View {
    @State private var text1 = ""
    @State private var text2 = "Hello"
    @FocusState private var focus1: Bool
    @FocusState private var focus2: Bool
    @State private var attention1 = false
    @State private var attention2 = false
    @State private var suggestions1 = false
    @State private var suggestions2 = false
    
    var body: some View {
        VStack(spacing: 20) {
            SearchBar(text: $text1, isFocused: $focus1, triggerAttention: $attention1, showingSuggestions: $suggestions1)
            SearchBar(text: $text2, isFocused: $focus2, triggerAttention: $attention2, showingSuggestions: $suggestions2)
        }
        .padding()
        .frame(width: 300)
        .glassEffect()
    }
}

#Preview {
    SearchBarPreview()
}
