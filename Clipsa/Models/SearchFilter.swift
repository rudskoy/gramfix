import Foundation

/// Parses search query to extract type filters and remaining search text
struct SearchFilter {
    /// Types to include (if non-empty, only show these types)
    let includedTypes: Set<ClipboardType>
    
    /// Types to exclude (hide these types)
    let excludedTypes: Set<ClipboardType>
    
    /// Remaining search text after filter extraction
    let searchText: String
    
    /// Whether any filters are active
    var hasFilters: Bool {
        !includedTypes.isEmpty || !excludedTypes.isEmpty
    }
    
    // MARK: - Suggestion Options
    
    /// A filter suggestion for autocomplete
    struct Suggestion: Identifiable {
        let id: String
        let displayName: String
        let aliases: String?
        
        var displayText: String {
            if let aliases = aliases {
                return "\(displayName) (\(aliases))"
            }
            return displayName
        }
    }
    
    /// Available filter suggestions for autocomplete
    static let suggestions: [Suggestion] = [
        Suggestion(id: "images", displayName: "images", aliases: "img"),
        Suggestion(id: "text", displayName: "text", aliases: "txt"),
        Suggestion(id: "links", displayName: "links", aliases: "url"),
        Suggestion(id: "files", displayName: "files", aliases: nil),
    ]
    
    /// Filter suggestions based on partial input
    static func filterSuggestions(matching partial: String) -> [Suggestion] {
        if partial.isEmpty {
            return suggestions
        }
        let lowercased = partial.lowercased()
        return suggestions.filter { suggestion in
            suggestion.displayName.lowercased().hasPrefix(lowercased) ||
            (suggestion.aliases?.lowercased().hasPrefix(lowercased) ?? false)
        }
    }
    
    // MARK: - Type Aliases
    
    /// Maps filter keywords to ClipboardType
    private static let typeAliases: [String: ClipboardType] = [
        // Text
        "text": .text,
        "txt": .text,
        // Image
        "image": .image,
        "images": .image,
        "img": .image,
        // Link
        "link": .link,
        "links": .link,
        "url": .link,
        "urls": .link,
        // File
        "file": .file,
        "files": .file,
        // Other
        "other": .other
    ]
    
    // MARK: - Parsing
    
    /// Parse a search query and extract filters
    /// Supports:
    /// - `-type` (exclude)
    /// - `+type` (include only)
    /// - `type:no` or `type: no` (exclude)
    /// - `type:yes` or `type: yes` (include only)
    static func parse(_ query: String) -> SearchFilter {
        var includedTypes = Set<ClipboardType>()
        var excludedTypes = Set<ClipboardType>()
        var remainingParts: [String] = []
        
        // Split query into tokens, preserving spaces for key:value parsing
        let tokens = tokenize(query)
        
        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            
            // Check for -type pattern (exclusion)
            if token.hasPrefix("-"), token.count > 1 {
                let typeKey = String(token.dropFirst()).lowercased()
                if let type = typeAliases[typeKey] {
                    excludedTypes.insert(type)
                    i += 1
                    continue
                }
            }
            
            // Check for +type pattern (inclusion)
            if token.hasPrefix("+"), token.count > 1 {
                let typeKey = String(token.dropFirst()).lowercased()
                if let type = typeAliases[typeKey] {
                    includedTypes.insert(type)
                    i += 1
                    continue
                }
            }
            
            // Check for type:value pattern
            if let colonIndex = token.firstIndex(of: ":") {
                let key = String(token[..<colonIndex]).lowercased()
                var value = String(token[token.index(after: colonIndex)...]).lowercased()
                
                // Handle case where value is empty (space after colon)
                if value.isEmpty, i + 1 < tokens.count {
                    value = tokens[i + 1].lowercased()
                    if value == "yes" || value == "no" || value == "only" {
                        i += 1 // Consume the next token
                    } else {
                        value = "" // Not a valid value, treat as regular text
                    }
                }
                
                if let type = typeAliases[key] {
                    if value == "no" {
                        excludedTypes.insert(type)
                        i += 1
                        continue
                    } else if value == "yes" || value == "only" {
                        includedTypes.insert(type)
                        i += 1
                        continue
                    }
                }
            }
            
            // Not a filter, keep as search text
            remainingParts.append(token)
            i += 1
        }
        
        let searchText = remainingParts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        
        return SearchFilter(
            includedTypes: includedTypes,
            excludedTypes: excludedTypes,
            searchText: searchText
        )
    }
    
    /// Tokenize query string, splitting on whitespace
    private static func tokenize(_ query: String) -> [String] {
        query.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    }
    
    // MARK: - Matching
    
    /// Check if a clipboard item matches this filter
    func matches(_ item: ClipboardItem) -> Bool {
        // First, check type filters
        if !matchesTypeFilter(item.type) {
            return false
        }
        
        // Then, check search text if present
        if !searchText.isEmpty {
            return item.matchesSearch(searchText)
        }
        
        return true
    }
    
    /// Check if an item type passes the inclusion/exclusion filters
    private func matchesTypeFilter(_ type: ClipboardType) -> Bool {
        // If we have inclusion filters, the type must be in the included set
        if !includedTypes.isEmpty {
            if !includedTypes.contains(type) {
                return false
            }
        }
        
        // If the type is in the excluded set, reject it
        if excludedTypes.contains(type) {
            return false
        }
        
        return true
    }
}

