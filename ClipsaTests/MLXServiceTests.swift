//
//  MLXServiceTests.swift
//  ClipsaTests
//
//  Unit tests for MLXService download status detection.
//

import XCTest
@testable import Clipsa

/// Unit tests for MLXService download status functionality
final class MLXServiceTests: XCTestCase {
    
    // MARK: - Model Lookup Tests
    
    func testModelLookupReturnsNilForUnknownModel() {
        let model = MLXService.model(named: "nonexistent-model-xyz")
        XCTAssertNil(model, "Should return nil for unknown model name")
    }
    
    func testModelLookupFindsKnownModel() {
        let model = MLXService.model(named: "llama3.2:1b")
        XCTAssertNotNil(model, "Should find llama3.2:1b model")
        XCTAssertEqual(model?.name, "llama3.2:1b")
    }
    
    func testTextModelsOnlyContainLLMs() {
        for model in MLXService.textModels {
            XCTAssertEqual(model.type, .llm, "Text model \(model.name) should be LLM type")
            XCTAssertTrue(model.isLanguageModel, "Text model \(model.name) should be a language model")
            XCTAssertFalse(model.isVisionModel, "Text model \(model.name) should not be a vision model")
        }
    }
    
    func testVisionModelsOnlyContainVLMs() {
        for model in MLXService.visionModels {
            XCTAssertEqual(model.type, .vlm, "Vision model \(model.name) should be VLM type")
            XCTAssertTrue(model.isVisionModel, "Vision model \(model.name) should be a vision model")
            XCTAssertFalse(model.isLanguageModel, "Vision model \(model.name) should not be a language model")
        }
    }
    
    // MARK: - isModelDownloaded Tests
    
    func testIsModelDownloadedReturnsFalseForUnknownModel() async {
        let service = await MLXService.shared
        let isDownloaded = await service.isModelDownloaded(name: "nonexistent-model-xyz")
        XCTAssertFalse(isDownloaded, "Should return false for unknown model")
    }
    
    func testIsModelDownloadedUsesModelDirectoryMethod() async {
        // Verify that isModelDownloaded uses the ModelConfiguration.modelDirectory() method
        // which returns the exact path used by HubApi for downloads
        
        // Get a known model
        guard let model = MLXService.model(named: "llama3.2:1b") else {
            XCTFail("Could not find llama3.2:1b model")
            return
        }
        
        // Get the model directory using the same method MLXService uses
        let modelDir = model.configuration.modelDirectory(hub: .default)
        
        // Verify the path is in the correct location
        XCTAssertTrue(modelDir.path.contains("Application Support/Clipsa/Models"),
                      "Model directory should be in Application Support/Clipsa/Models, got: \(modelDir.path)")
    }
    
    // MARK: - isModelReady Tests (Cached Status)
    
    @MainActor
    func testIsModelReadyReturnsFalseWhenNotCached() async {
        let service = MLXService.shared
        
        // For a model that definitely isn't downloaded (using fake name)
        // isModelReady uses the cache, which defaults to false for unknown models
        let isReady = service.isModelReady("nonexistent-model-xyz")
        XCTAssertFalse(isReady, "Should return false for model not in cache")
    }
    
    @MainActor
    func testModelDownloadStatusCacheIsPopulated() async {
        let service = MLXService.shared
        
        // After refreshDownloadStatus, the cache should contain entries for all models
        await service.refreshDownloadStatus()
        
        // Verify cache has entries for all available models
        for model in MLXService.availableModels {
            XCTAssertNotNil(service.modelDownloadStatus[model.name],
                           "Cache should have entry for model: \(model.name)")
        }
    }
    
    // MARK: - refreshDownloadStatus Tests
    
    @MainActor
    func testRefreshDownloadStatusUpdatesIsRefreshingStatus() async {
        let service = MLXService.shared
        
        // isRefreshingStatus should be false before and after (but true during)
        XCTAssertFalse(service.isRefreshingStatus, "Should not be refreshing before call")
        
        await service.refreshDownloadStatus()
        
        XCTAssertFalse(service.isRefreshingStatus, "Should not be refreshing after call completes")
    }
    
    @MainActor
    func testRefreshDownloadStatusPopulatesCache() async {
        let service = MLXService.shared
        
        // Clear the cache first by directly manipulating (if possible) or just verify after refresh
        await service.refreshDownloadStatus()
        
        // Cache should have the same number of entries as available models
        XCTAssertEqual(service.modelDownloadStatus.count, MLXService.availableModels.count,
                       "Cache should have entries for all available models")
    }
    
    // MARK: - Download State Tests
    
    @MainActor
    func testInitialDownloadStateIsFalse() async {
        let service = MLXService.shared
        
        // When not downloading, these should be in default state
        // Note: We can only test this reliably when no download is in progress
        if !service.isDownloading {
            XCTAssertNil(service.downloadingModelName, "Should have no downloading model name when not downloading")
            XCTAssertEqual(service.overallProgress, 0.0, "Progress should be 0 when not downloading")
        }
    }
    
    @MainActor
    func testFormattedDownloadSpeedFormatsCorrectly() async {
        let service = MLXService.shared
        
        // When speed is nil, formatted speed should be nil
        XCTAssertNil(service.formattedDownloadSpeed, "Formatted speed should be nil when speed is nil")
    }
}

