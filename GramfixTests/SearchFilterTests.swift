//
//  SearchFilterTests.swift
//  GramfixTests
//
//  Unit tests for SearchFilter parsing and matching logic.
//

import XCTest
@testable import Gramfix

/// Unit tests for SearchFilter
final class SearchFilterTests: XCTestCase {
    
    // MARK: - Parse Basic Tests
    
    func testParseEmptyQuery() {
        let filter = SearchFilter.parse("")
        
        XCTAssertTrue(filter.includedTypes.isEmpty)
        XCTAssertTrue(filter.excludedTypes.isEmpty)
        XCTAssertEqual(filter.searchText, "")
        XCTAssertFalse(filter.hasFilters)
    }
    
    func testParseRegularSearchText() {
        let filter = SearchFilter.parse("hello world")
        
        XCTAssertTrue(filter.includedTypes.isEmpty)
        XCTAssertTrue(filter.excludedTypes.isEmpty)
        XCTAssertEqual(filter.searchText, "hello world")
        XCTAssertFalse(filter.hasFilters)
    }
    
    // MARK: - Exclusion Filter Tests (-type)
    
    func testParseExcludeImages() {
        let filter = SearchFilter.parse("-images")
        
        XCTAssertTrue(filter.includedTypes.isEmpty)
        XCTAssertEqual(filter.excludedTypes, [.image])
        XCTAssertEqual(filter.searchText, "")
        XCTAssertTrue(filter.hasFilters)
    }
    
    func testParseExcludeImageAlias() {
        let filter = SearchFilter.parse("-img")
        
        XCTAssertEqual(filter.excludedTypes, [.image])
    }
    
    func testParseExcludeText() {
        let filter = SearchFilter.parse("-text")
        
        XCTAssertEqual(filter.excludedTypes, [.text])
    }
    
    func testParseExcludeTextAlias() {
        let filter = SearchFilter.parse("-txt")
        
        XCTAssertEqual(filter.excludedTypes, [.text])
    }
    
    func testParseExcludeLinks() {
        let filter = SearchFilter.parse("-links")
        
        XCTAssertEqual(filter.excludedTypes, [.link])
    }
    
    func testParseExcludeLinkAliases() {
        XCTAssertEqual(SearchFilter.parse("-link").excludedTypes, [.link])
        XCTAssertEqual(SearchFilter.parse("-url").excludedTypes, [.link])
        XCTAssertEqual(SearchFilter.parse("-urls").excludedTypes, [.link])
    }
    
    func testParseExcludeFiles() {
        let filter = SearchFilter.parse("-files")
        
        XCTAssertEqual(filter.excludedTypes, [.file])
    }
    
    func testParseExcludeFileAlias() {
        let filter = SearchFilter.parse("-file")
        
        XCTAssertEqual(filter.excludedTypes, [.file])
    }
    
    func testParseExcludeOther() {
        let filter = SearchFilter.parse("-other")
        
        XCTAssertEqual(filter.excludedTypes, [.other])
    }
    
    func testParseMultipleExclusions() {
        let filter = SearchFilter.parse("-images -links")
        
        XCTAssertTrue(filter.includedTypes.isEmpty)
        XCTAssertEqual(filter.excludedTypes, [.image, .link])
        XCTAssertEqual(filter.searchText, "")
    }
    
    // MARK: - Inclusion Filter Tests (+type)
    
    func testParseIncludeImages() {
        let filter = SearchFilter.parse("+images")
        
        XCTAssertEqual(filter.includedTypes, [.image])
        XCTAssertTrue(filter.excludedTypes.isEmpty)
        XCTAssertEqual(filter.searchText, "")
        XCTAssertTrue(filter.hasFilters)
    }
    
    func testParseIncludeText() {
        let filter = SearchFilter.parse("+text")
        
        XCTAssertEqual(filter.includedTypes, [.text])
    }
    
    func testParseMultipleInclusions() {
        let filter = SearchFilter.parse("+images +text")
        
        XCTAssertEqual(filter.includedTypes, [.image, .text])
        XCTAssertTrue(filter.excludedTypes.isEmpty)
    }
    
    // MARK: - Colon Syntax Tests (type:yes/no)
    
    func testParseTypeColonNo() {
        let filter = SearchFilter.parse("images:no")
        
        XCTAssertEqual(filter.excludedTypes, [.image])
        XCTAssertTrue(filter.includedTypes.isEmpty)
    }
    
    func testParseTypeColonYes() {
        let filter = SearchFilter.parse("images:yes")
        
        XCTAssertEqual(filter.includedTypes, [.image])
        XCTAssertTrue(filter.excludedTypes.isEmpty)
    }
    
    func testParseTypeColonOnly() {
        let filter = SearchFilter.parse("text:only")
        
        XCTAssertEqual(filter.includedTypes, [.text])
    }
    
    func testParseTypeColonWithSpace() {
        let filter = SearchFilter.parse("images: no")
        
        XCTAssertEqual(filter.excludedTypes, [.image])
    }
    
    func testParseTypeColonYesWithSpace() {
        let filter = SearchFilter.parse("links: yes")
        
        XCTAssertEqual(filter.includedTypes, [.link])
    }
    
    // MARK: - Combined Filter and Search Tests
    
    func testParseFilterWithSearchText() {
        let filter = SearchFilter.parse("-images hello world")
        
        XCTAssertEqual(filter.excludedTypes, [.image])
        XCTAssertEqual(filter.searchText, "hello world")
    }
    
    func testParseSearchTextWithFilterAtEnd() {
        let filter = SearchFilter.parse("hello -images")
        
        XCTAssertEqual(filter.excludedTypes, [.image])
        XCTAssertEqual(filter.searchText, "hello")
    }
    
    func testParseFilterBetweenSearchWords() {
        let filter = SearchFilter.parse("hello -images world")
        
        XCTAssertEqual(filter.excludedTypes, [.image])
        XCTAssertEqual(filter.searchText, "hello world")
    }
    
    func testParseMultipleFiltersWithSearch() {
        let filter = SearchFilter.parse("+text +links search query")
        
        XCTAssertEqual(filter.includedTypes, [.text, .link])
        XCTAssertEqual(filter.searchText, "search query")
    }
    
    // MARK: - Invalid Filter Tests
    
    func testParseInvalidTypeIgnored() {
        let filter = SearchFilter.parse("-invalid")
        
        XCTAssertTrue(filter.excludedTypes.isEmpty)
        XCTAssertEqual(filter.searchText, "-invalid")
    }
    
    func testParseDashAloneIsSearchText() {
        let filter = SearchFilter.parse("-")
        
        XCTAssertTrue(filter.excludedTypes.isEmpty)
        XCTAssertEqual(filter.searchText, "-")
    }
    
    func testParsePlusAloneIsSearchText() {
        let filter = SearchFilter.parse("+")
        
        XCTAssertTrue(filter.includedTypes.isEmpty)
        XCTAssertEqual(filter.searchText, "+")
    }
    
    // MARK: - Suggestion Tests
    
    func testFilterSuggestionsEmpty() {
        let suggestions = SearchFilter.filterSuggestions(matching: "")
        
        XCTAssertEqual(suggestions.count, 5)
    }
    
    func testFilterSuggestionsMatchingPrefix() {
        let suggestions = SearchFilter.filterSuggestions(matching: "im")
        
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.id, "images")
    }
    
    func testFilterSuggestionsMatchingAlias() {
        let suggestions = SearchFilter.filterSuggestions(matching: "txt")
        
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.id, "text")
    }
    
    func testFilterSuggestionsNoMatch() {
        let suggestions = SearchFilter.filterSuggestions(matching: "xyz")
        
        XCTAssertTrue(suggestions.isEmpty)
    }
    
    func testFilterSuggestionsCaseInsensitive() {
        let suggestions = SearchFilter.filterSuggestions(matching: "IMAGES")
        
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.id, "images")
    }
    
    // MARK: - Matching Tests
    
    func testMatchesWithNoFilters() {
        let filter = SearchFilter.parse("")
        let item = ClipboardItem(content: "test", type: .text)
        
        XCTAssertTrue(filter.matches(item))
    }
    
    func testMatchesExcludesType() {
        let filter = SearchFilter.parse("-images")
        
        let textItem = ClipboardItem(content: "test", type: .text)
        let imageItem = ClipboardItem(content: "image.png", type: .image)
        
        XCTAssertTrue(filter.matches(textItem))
        XCTAssertFalse(filter.matches(imageItem))
    }
    
    func testMatchesIncludesOnlyType() {
        let filter = SearchFilter.parse("+images")
        
        let textItem = ClipboardItem(content: "test", type: .text)
        let imageItem = ClipboardItem(content: "image.png", type: .image)
        
        XCTAssertFalse(filter.matches(textItem))
        XCTAssertTrue(filter.matches(imageItem))
    }
    
    func testMatchesMultipleInclusions() {
        let filter = SearchFilter.parse("+images +text")
        
        let textItem = ClipboardItem(content: "test", type: .text)
        let imageItem = ClipboardItem(content: "image.png", type: .image)
        let linkItem = ClipboardItem(content: "https://example.com", type: .link)
        
        XCTAssertTrue(filter.matches(textItem))
        XCTAssertTrue(filter.matches(imageItem))
        XCTAssertFalse(filter.matches(linkItem))
    }
    
    func testMatchesWithSearchText() {
        let filter = SearchFilter.parse("hello")
        
        let matchingItem = ClipboardItem(content: "hello world", type: .text)
        let nonMatchingItem = ClipboardItem(content: "goodbye", type: .text)
        
        XCTAssertTrue(filter.matches(matchingItem))
        XCTAssertFalse(filter.matches(nonMatchingItem))
    }
    
    func testMatchesCombinedFilterAndSearch() {
        let filter = SearchFilter.parse("-images hello")
        
        let matchingText = ClipboardItem(content: "hello world", type: .text)
        let nonMatchingText = ClipboardItem(content: "goodbye", type: .text)
        let matchingImage = ClipboardItem(content: "hello.png", type: .image)
        
        XCTAssertTrue(filter.matches(matchingText))
        XCTAssertFalse(filter.matches(nonMatchingText))
        XCTAssertFalse(filter.matches(matchingImage)) // excluded by -images filter
    }
    
    // MARK: - Suggestion DisplayText Tests
    
    func testSuggestionDisplayTextWithAlias() {
        let suggestion = SearchFilter.Suggestion(id: "images", displayName: "images", aliases: "img")
        
        XCTAssertEqual(suggestion.displayText, "images (img)")
    }
    
    func testSuggestionDisplayTextWithoutAlias() {
        let suggestion = SearchFilter.Suggestion(id: "files", displayName: "files", aliases: nil)
        
        XCTAssertEqual(suggestion.displayText, "files")
    }
    
    // MARK: - Edge Cases
    
    func testParseCaseInsensitiveFilters() {
        let filter = SearchFilter.parse("-IMAGES")
        
        XCTAssertEqual(filter.excludedTypes, [.image])
    }
    
    func testParseWhitespaceHandling() {
        let filter = SearchFilter.parse("  -images   hello   world  ")
        
        XCTAssertEqual(filter.excludedTypes, [.image])
        XCTAssertEqual(filter.searchText, "hello world")
    }
    
    func testHasFiltersPropertyWithInclusion() {
        let filter = SearchFilter.parse("+images")
        
        XCTAssertTrue(filter.hasFilters)
    }
    
    func testHasFiltersPropertyWithExclusion() {
        let filter = SearchFilter.parse("-images")
        
        XCTAssertTrue(filter.hasFilters)
    }
    
    func testHasFiltersPropertyWithOnlySearch() {
        let filter = SearchFilter.parse("hello")
        
        XCTAssertFalse(filter.hasFilters)
    }
}

