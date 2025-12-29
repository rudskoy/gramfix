import Foundation
import AppKit
import Combine
import os.log

private let logger = Logger(subsystem: "com.gramfix.app", category: "ClipboardManager")

@MainActor
class ClipboardManager: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var searchQuery: String = ""
    @Published var selectedTabType: ClipboardType? = nil
    @Published var showOnlyUseful: Bool = false
    
    /// LLM service for processing clipboard content
    let llmService = LLMService()
    
    /// Whether automatic LLM processing is enabled (backed by LLMSettings)
    var llmAutoProcess: Bool {
        get { LLMSettings.shared.autoProcess }
        set { LLMSettings.shared.autoProcess = newValue }
    }
    
    private var lastChangeCount: Int = 0
    private var changeCountOnUnfocus: Int = 0
    private var timer: Timer?
    private let maxItems = 100
    private var cancellables = Set<AnyCancellable>()
    
    /// Whether initial history load has completed
    private var historyLoaded = false
    
    var filteredItems: [ClipboardItem] {
        var filtered = items
        
        // Parse search filter
        let baseFilter = !searchQuery.isEmpty ? SearchFilter.parse(searchQuery) : SearchFilter(includedTypes: [], excludedTypes: [], useful: nil, searchText: "")
        
        // If UI toggle is active and search doesn't have useful filter, add it
        let searchFilter: SearchFilter
        if showOnlyUseful && baseFilter.useful == nil {
            searchFilter = SearchFilter(
                includedTypes: baseFilter.includedTypes,
                excludedTypes: baseFilter.excludedTypes,
                useful: true,
                searchText: baseFilter.searchText
            )
        } else {
            searchFilter = baseFilter
        }
        
        // Apply tab type filter if selected
        if let tabType = selectedTabType {
            filtered = filtered.filter { $0.type == tabType }
        }
        
        // Apply search query filters (includes useful, type, and text)
        if searchFilter.hasFilters || !searchFilter.searchText.isEmpty {
            filtered = filtered.filter { searchFilter.matches($0) }
        }
        
        return filtered
    }
    
    init() {
        lastChangeCount = NSPasteboard.general.changeCount
        changeCountOnUnfocus = NSPasteboard.general.changeCount
        setupLLMProviders()
        observeModelChanges()
        setupPersistence()
        startMonitoring()
        
        // Listen for internal paste operations to avoid re-processing
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("GramfixInternalPaste"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let changeCount = notification.userInfo?["changeCount"] as? Int {
                Task { @MainActor in
                    self?.lastChangeCount = changeCount
                    logger.debug("🔇 Ignoring internal paste operation (changeCount: \(changeCount))")
                }
            }
        }
        
        // Load persisted history
        Task { @MainActor in
            await loadPersistedHistory()
            
            #if DEBUG
            // Only load test data if no persisted history exists
            if items.isEmpty {
                loadTestData()
            }
            #endif
        }
    }
    
    #if DEBUG
    /// Load sample test data for development - only available in Debug builds
    private func loadTestData() {
        let sampleItems: [(String, ClipboardType, String?)] = [
            ("Hello, World! This is a simple text snippet.", .text, "Notes"),
            ("SELECT * FROM users WHER active = true ORDER BY created_at DESC;", .text, "DataGrip"),
            ("The quic brown fox jump over the lazi dog.", .text, "TextEdit"),
            ("Gramfix - Your friendly grammar fixer!", .text, "Slack"),
        ]
        
        for (content, type, appName) in sampleItems.reversed() {
            let item = ClipboardItem(
                content: content,
                type: type,
                appName: appName
            )
            items.insert(item, at: 0)
        }
        
        logger.info("🧪 Loaded \(sampleItems.count) test items for development")
    }
    #endif
    
    /// Setup default LLM providers
    /// MLX service instance for on-device inference (uses shared singleton)
    private var mlxService: MLXService { MLXService.shared }
    
    private func setupLLMProviders() {
        // Register Ollama provider (requires Ollama to be running)
        let ollamaClient = OllamaClient()
        let ollamaProvider = LLMProviderImpl(client: ollamaClient)
        llmService.registerProvider(ollamaProvider, type: .ollama)
        
        // Register MLX provider (on-device Apple Silicon inference)
        let mlxClient = MLXClient(mlxService: mlxService)
        let mlxProvider = LLMProviderImpl(client: mlxClient)
        llmService.registerProvider(mlxProvider, type: .mlx)
        
        // Sync with current settings
        llmService.syncWithSettings()
    }
    
    /// Observe model and provider changes and update LLM service accordingly
    private func observeModelChanges() {
        // Observe Ollama model changes
        LLMSettings.shared.$selectedModel
            .dropFirst() // Skip initial value
            .sink { [weak self] newModel in
                logger.info("🔄 Ollama model changed to: \(newModel), clearing LLM cache")
                self?.llmService.clearCache()
            }
            .store(in: &cancellables)
        
        // Observe MLX text model changes
        LLMSettings.shared.$mlxSelectedTextModel
            .dropFirst()
            .sink { [weak self] newModel in
                logger.info("🔄 MLX text model changed to: \(newModel), clearing LLM cache")
                self?.llmService.clearCache()
            }
            .store(in: &cancellables)
        
        // Observe MLX VLM model changes
        LLMSettings.shared.$mlxSelectedVLMModel
            .dropFirst()
            .sink { [weak self] newModel in
                logger.info("🔄 MLX VLM model changed to: \(newModel)")
                // VLM cache clearing handled separately if needed
            }
            .store(in: &cancellables)
        
        // Observe provider changes
        LLMSettings.shared.$selectedProvider
            .dropFirst()
            .sink { [weak self] newProvider in
                logger.info("🔄 Provider changed to: \(newProvider.rawValue), syncing LLM service")
                self?.llmService.syncWithSettings()
                self?.llmService.clearCache()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Persistence
    
    /// Setup debounced persistence - saves 2 seconds after changes stop
    private func setupPersistence() {
        $items
            .dropFirst() // Skip initial empty value
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self = self, self.historyLoaded else { return }
                Task {
                    await self.saveHistory(items)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Load persisted clipboard history from disk
    private func loadPersistedHistory() async {
        do {
            let loadedItems = try await ClipboardPersistence.shared.load()
            if !loadedItems.isEmpty {
                items = loadedItems
                logger.info("📂 Restored \(loadedItems.count) items from persistent storage")
            }
        } catch {
            logger.error("❌ Failed to load clipboard history: \(error.localizedDescription)")
        }
        historyLoaded = true
    }
    
    /// Save clipboard history to disk
    private func saveHistory(_ itemsToSave: [ClipboardItem]) async {
        do {
            try await ClipboardPersistence.shared.save(itemsToSave)
        } catch {
            logger.error("❌ Failed to save clipboard history: \(error.localizedDescription)")
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Save the current clipboard change count (called when app resigns active)
    func saveChangeCountOnUnfocus() {
        changeCountOnUnfocus = NSPasteboard.general.changeCount
    }
    
    /// Check if clipboard changed since app was unfocused
    func hasClipboardChangedSinceUnfocus() -> Bool {
        let currentChangeCount = NSPasteboard.general.changeCount
        return currentChangeCount != changeCountOnUnfocus
    }
    
    /// Force an immediate clipboard check (useful when app becomes active)
    func checkClipboardNow() {
        checkClipboard()
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        
        // Get the frontmost app name
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName
        
        // Try to get string content
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            // Avoid duplicates
            if let lastItem = items.first, lastItem.content == string {
                return
            }
            
            // Detect if content is a link
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let isLink = Self.isValidURL(trimmed)
            
            // Try to capture RTF and HTML data if available (preserves formatting)
            let rtfData = pasteboard.data(forType: .rtf)
            let htmlData = pasteboard.data(forType: .html)
            
            // Capture ALL pasteboard types to preserve app-specific formats (e.g., Telegram's internal format)
            var allData: [String: Data] = [:]
            if let types = pasteboard.types {
                for type in types {
                    // Skip very large data and binary formats that we handle separately
                    if type == .png || type == .tiff || type == .fileURL {
                        continue
                    }
                    if let data = pasteboard.data(forType: type) {
                        // Skip very large items (> 1MB) to avoid memory issues
                        if data.count < 1_000_000 {
                            allData[type.rawValue] = data
                        }
                    }
                }
            }
            
            let item = ClipboardItem(
                content: string,
                rtfData: rtfData,
                htmlData: htmlData,
                allPasteboardData: allData.isEmpty ? nil : allData,
                type: isLink ? .link : .text,
                appName: appName
            )
            addItem(item)
        }
        // Try to get image
        else if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            // Capture whether image analysis is enabled NOW - this determines if the image
            // should ever be auto-analyzed (even when focused later)
            let item = ClipboardItem(
                content: "[Image]",
                rawData: imageData,
                type: .image,
                appName: appName,
                shouldAnalyzeImage: LLMSettings.shared.imageAnalysisEnabled
            )
            addItem(item)
        }
        // Try to get file URLs
        else if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            let fileNames = urls.map { $0.lastPathComponent }.joined(separator: ", ")
            let item = ClipboardItem(
                content: fileNames,
                type: .file,
                appName: appName
            )
            addItem(item)
        }
    }
    
    private func addItem(_ item: ClipboardItem) {
        items.insert(item, at: 0)
        if items.count > maxItems {
            items.removeLast()
        }
        
        let contentPreview = String(item.content.prefix(40)).replacingOccurrences(of: "\n", with: " ")
        logger.info("📋 New clipboard item: type=\(item.type.rawValue), content=\"\(contentPreview)...\"")
        
        // Trigger LLM processing for text items if auto-processing is enabled
        if llmAutoProcess && item.type == .text {
            logger.info("🤖 Auto-processing enabled, starting LLM processing...")
            Task {
                await processItemWithLLM(item)
            }
            // Also trigger language detection in parallel
            Task {
                await detectLanguage(item)
            }
        } else if !llmAutoProcess {
            logger.debug("⏸️ LLM auto-processing is disabled")
        }
        
        // Trigger image analysis for image items if enabled at capture time and model is ready
        if item.shouldAnalyzeImage && item.type == .image {
            let vlmModelName = LLMSettings.shared.mlxSelectedVLMModel
            if MLXService.shared.isModelReady(vlmModelName) {
                logger.info("🖼️ Image analysis enabled, starting analysis...")
                Task {
                    await analyzeImage(item)
                }
            } else {
                logger.debug("⏸️ Image analysis enabled but VLM model not ready: \(vlmModelName)")
            }
        }
    }
    
    /// Process a clipboard item with all prompts in parallel
    func processItemWithLLM(_ item: ClipboardItem) async {
        guard item.type == .text else {
            logger.debug("Skipping LLM processing: type=\(item.type.rawValue)")
            return
        }
        
        // Skip if already has any results
        if item.hasAnyPromptResult {
            logger.debug("Skipping LLM processing: already has results")
            return
        }
        
        // Find the item index
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            logger.warning("Item not found in list, skipping processing")
            return
        }
        
        let itemId = item.id
        let content = Self.extractPlainTextForLLM(from: item)
        
        logger.info("Starting parallel LLM processing for item \(itemId) with \(TextPromptType.allCases.count) prompts")
        
        // Mark all prompts as processing
        items[index] = items[index].withAllPromptsProcessing()
        
        // Get the active provider
        guard let provider = llmService.activeProvider as? LLMProviderImpl else {
            logger.error("No active LLM provider available")
            if let idx = items.firstIndex(where: { $0.id == itemId }) {
                items[idx] = ClipboardItem(
                    id: items[idx].id,
                    content: items[idx].content,
                    rawData: items[idx].rawData,
                    type: items[idx].type,
                    timestamp: items[idx].timestamp,
                    appName: items[idx].appName,
                    promptResults: [:],
                    selectedPromptId: items[idx].selectedPromptId,
                    promptProcessingIds: [],
                    imageAnalysisResponse: items[idx].imageAnalysisResponse,
                    imageAnalysisProcessing: items[idx].imageAnalysisProcessing,
                    shouldAnalyzeImage: items[idx].shouldAnalyzeImage
                )
            }
            return
        }
        
        // Run all prompts in parallel using individual tasks (so results stream in)
        for promptType in TextPromptType.allCases {
            Task { @MainActor in
                do {
                    let response = try await provider.processWithPromptType(content, promptType: promptType)
                    
                    // Update the item with this prompt's result
                    if let currentIndex = items.firstIndex(where: { $0.id == itemId }) {
                        items[currentIndex] = items[currentIndex].withPromptResult(type: promptType, response: response)
                        logger.info("Completed prompt '\(promptType.displayName)' for item \(itemId)")
                        
                        // If language is already detected and we have AI-processed content, trigger translations
                        // Trigger when we get the first prompt result (to update translations with AI content)
                        let updatedItem = items[currentIndex]
                        if updatedItem.detectedLanguage != nil,
                           updatedItem.selectedPromptResult != nil,
                           updatedItem.promptResults.count == 1 { // Only trigger once on first prompt completion
                            // Trigger translations in parallel (will use AI-processed content)
                            // translateToAllLanguages will handle re-translation if needed
                            Task {
                                await translateToAllLanguages(updatedItem)
                            }
                        }
                    }
                } catch {
                    logger.error("Failed prompt '\(promptType.displayName)': \(error.localizedDescription)")
                    // Clear processing state for this prompt on failure
                    if let currentIndex = items.firstIndex(where: { $0.id == itemId }) {
                        items[currentIndex] = items[currentIndex].withPromptProcessing(type: promptType, processing: false)
                    }
                }
            }
        }
    }
    
    /// Minimum image dimensions required by VLM models
    private static let minimumImageDimension: CGFloat = 32
    
    /// Analyze an image clipboard item using MLX VLM (on-device inference)
    func analyzeImage(_ item: ClipboardItem) async {
        guard item.type == .image, let imageData = item.rawData else {
            logger.debug("⏭️ Skipping image analysis: not an image type or no data")
            return
        }
        
        // Check image dimensions - VLM requires at least 32x32 pixels
        guard let nsImage = NSImage(data: imageData) else {
            logger.warning("⚠️ Could not create image from data")
            return
        }
        
        let imageSize = nsImage.size
        if imageSize.width < Self.minimumImageDimension || imageSize.height < Self.minimumImageDimension {
            logger.info("⏭️ Image too small for analysis: \(Int(imageSize.width))x\(Int(imageSize.height)) (minimum: 32x32)")
            return
        }
        
        // Find the item index
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            logger.warning("⚠️ Item not found in list, skipping image analysis")
            return
        }
        
        let itemId = item.id
        
        logger.info("🖼️ Starting image analysis for item \(itemId) (\(Int(imageSize.width))x\(Int(imageSize.height))) using MLX VLM")
        
        // Mark as processing
        items[index] = items[index].withImageAnalysisProcessingState(true)
        
        do {
            // Get the VLM model from settings
            let selectedVLMName = LLMSettings.shared.mlxSelectedVLMModel
            guard let vlmModel = MLXService.model(named: selectedVLMName) else {
                logger.error("❌ VLM model not found: \(selectedVLMName)")
                if let idx = items.firstIndex(where: { $0.id == itemId }) {
                    items[idx] = items[idx].withImageAnalysisProcessingState(false)
                }
                return
            }
            
            // Generate image description using MLX
            let prompt = "Describe this screenshot in 5-10 words for a filename. Output ONLY the description, nothing else."
            let response = try await mlxService.generate(
                prompt: prompt,
                systemPrompt: "You are a helpful assistant that describes images concisely.",
                images: [imageData],
                model: vlmModel
            )
            
            // Update the item with analysis result
            if let currentIndex = items.firstIndex(where: { $0.id == itemId }) {
                let cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                items[currentIndex] = items[currentIndex].withImageAnalysisResult(cleanedResponse)
                logger.info("✅ Image analysis complete for item \(itemId): \(cleanedResponse)")
            }
        } catch {
            logger.error("❌ Image analysis failed: \(error.localizedDescription)")
            if let idx = items.firstIndex(where: { $0.id == itemId }) {
                items[idx] = items[idx].withImageAnalysisProcessingState(false)
            }
        }
    }
    
    /// Reprocess an item with LLM (useful for manual retry)
    func reprocessItemWithLLM(_ item: ClipboardItem) async {
        guard item.type == .text else { return }
        
        // Find and reset the item
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        var resetItem = items[index]
        resetItem.promptResults = [:]
        resetItem.promptProcessingIds = []
        items[index] = resetItem
        
        // Clear cache for this content
        llmService.clearCache()
        
        await processItemWithLLM(resetItem)
    }
    
    /// Update the selected prompt for an item
    func selectPrompt(_ promptType: TextPromptType, for item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = items[index].withSelectedPrompt(promptType.rawValue)
    }
    
    /// Toggle the useful flag for an item
    func toggleUsefulFlag(for item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = items[index].withUsefulFlag(!items[index].isUseful)
    }
    
    // MARK: - Language Detection and Translation
    
    /// Detect the language of a clipboard item's content
    func detectLanguage(_ item: ClipboardItem) async {
        guard item.type == .text else {
            logger.debug("Skipping language detection: type=\(item.type.rawValue)")
            return
        }
        
        // Skip if already detected
        if item.detectedLanguage != nil {
            logger.debug("Skipping language detection: already detected")
            return
        }
        
        // Find the item index
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            logger.warning("Item not found in list, skipping language detection")
            return
        }
        
        let itemId = item.id
        let content = Self.extractPlainTextForLLM(from: item)
        
        // Skip very short content
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5 else {
            logger.debug("Skipping language detection: content too short")
            return
        }
        
        logger.info("Starting language detection for item \(itemId)")
        
        // Mark as processing
        items[index] = items[index].withLanguageDetectionProcessingState(true)
        
        // Get the active provider
        guard let provider = llmService.activeProvider as? LLMProviderImpl else {
            logger.error("No active LLM provider available for language detection")
            if let idx = items.firstIndex(where: { $0.id == itemId }) {
                items[idx] = items[idx].withLanguageDetectionProcessingState(false)
            }
            return
        }
        
        do {
            let prompt = SupportedLanguage.detectionPrompt.replacingOccurrences(of: "{text}", with: trimmed)
            let response = try await provider.generate(prompt: prompt, context: nil)
            let cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            // Parse the language code
            var detectedLang: SupportedLanguage = .english
            if let parsed = SupportedLanguage.from(code: cleanedResponse) {
                detectedLang = parsed
                logger.info("Language detected for item \(itemId): \(detectedLang.displayName) \(detectedLang.flag)")
            } else {
                logger.warning("Failed to parse language code: '\(cleanedResponse)', defaulting to English")
            }
            
            // Update item with detected language
            if let currentIndex = items.firstIndex(where: { $0.id == itemId }) {
                items[currentIndex] = items[currentIndex].withDetectedLanguage(detectedLang)
                
                // Trigger automatic translation to all other languages
                let updatedItem = items[currentIndex]
                await translateToAllLanguages(updatedItem)
            }
        } catch {
            logger.error("Language detection failed: \(error.localizedDescription)")
            if let idx = items.firstIndex(where: { $0.id == itemId }) {
                items[idx] = items[idx].withLanguageDetectionProcessingState(false)
            }
        }
    }
    
    /// Translate content to ALL other languages in parallel (called after detection or when AI processing completes)
    func translateToAllLanguages(_ item: ClipboardItem) async {
        guard item.type == .text else { return }
        guard let detectedLanguage = item.detectedLanguage else { return }
        
        // Find the item index
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        let itemId = item.id
        
        // Get the content to translate - prefer AI-processed content if available
        // If using original content, extract plain text from RTF/HTML to avoid formatting markers
        let contentToTranslate = item.selectedPromptResult ?? Self.extractPlainTextForLLM(from: item)
        
        // Get languages to translate to (all except detected)
        let languagesToTranslate = SupportedLanguage.allCases.filter { $0 != detectedLanguage }
        
        logger.info("Starting parallel translation for item \(itemId) to \(languagesToTranslate.count) languages (using \(item.selectedPromptResult != nil ? "AI-processed" : "original") content)")
        
        // Mark languages as processing only if they don't already have translations
        // This allows re-translation with AI-processed content if needed
        var languagesNeedingTranslation: [SupportedLanguage] = []
        for language in languagesToTranslate {
            if items[index].translatedResults[language.rawValue] == nil {
                languagesNeedingTranslation.append(language)
                items[index] = items[index].withTranslationProcessing(languageCode: language.rawValue, processing: true)
            }
        }
        
        // If all translations already exist and we're using original content, skip
        // But if we have AI-processed content and translations were done with original, re-translate
        if languagesNeedingTranslation.isEmpty && item.selectedPromptResult != nil {
            // Check if existing translations were done with original content
            // If so, re-translate with AI-processed content
            let hasOriginalTranslations = !items[index].translatedResults.isEmpty
            if hasOriginalTranslations {
                // Re-translate all languages with AI-processed content
                languagesNeedingTranslation = languagesToTranslate
                // Mark all as processing
                items[index] = items[index].withAllTranslationsProcessing()
            } else {
                // All translations already exist and are up to date
                return
            }
        }
        
        if languagesNeedingTranslation.isEmpty {
            return
        }
        
        // Get the active provider
        guard let provider = llmService.activeProvider as? LLMProviderImpl else {
            logger.error("No active LLM provider available for translation")
            if let idx = items.firstIndex(where: { $0.id == itemId }) {
                for language in languagesNeedingTranslation {
                    items[idx] = items[idx].withTranslationProcessing(languageCode: language.rawValue, processing: false)
                }
            }
            return
        }
        
        // Run all translations in parallel
        for targetLanguage in languagesNeedingTranslation {
            Task { @MainActor in
                do {
                    let prompt = SupportedLanguage.translationPrompt(to: targetLanguage)
                        .replacingOccurrences(of: "{text}", with: contentToTranslate)
                    let response = try await provider.generate(prompt: prompt, context: nil)
                    let translatedText = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Store translation result
                    if let currentIndex = items.firstIndex(where: { $0.id == itemId }) {
                        items[currentIndex] = items[currentIndex].withTranslationResult(
                            languageCode: targetLanguage.rawValue,
                            translation: translatedText
                        )
                        logger.info("Translation complete for item \(itemId) to \(targetLanguage.displayName)")
                    }
                } catch {
                    logger.error("Translation to \(targetLanguage.displayName) failed: \(error.localizedDescription)")
                    if let currentIndex = items.firstIndex(where: { $0.id == itemId }) {
                        items[currentIndex] = items[currentIndex].withTranslationProcessing(
                            languageCode: targetLanguage.rawValue,
                            processing: false
                        )
                    }
                }
            }
        }
    }
    
    /// Select target language for an item (instantly shows pre-translated result)
    func selectTargetLanguage(_ language: SupportedLanguage, for item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        // If selecting the detected language, clear the target (show original)
        if language == item.detectedLanguage {
            items[index] = items[index].withSelectedTargetLanguage(nil)
            return
        }
        
        // Set the target language
        items[index] = items[index].withSelectedTargetLanguage(language)
        
        // Check if translation exists, if not trigger it
        let updatedItem = items[index]
        if updatedItem.translatedResults[language.rawValue] == nil {
            // Translation doesn't exist yet, trigger it
            Task {
                await translateLanguage(language, for: updatedItem)
            }
        }
    }
    
    /// Translate content to a specific language (used when user selects a language without translation)
    private func translateLanguage(_ targetLanguage: SupportedLanguage, for item: ClipboardItem) async {
        guard item.type == .text else { return }
        guard let detectedLanguage = item.detectedLanguage else { return }
        guard targetLanguage != detectedLanguage else { return }
        
        // Find the item index
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        let itemId = item.id
        
        // Get the content to translate - prefer AI-processed content if available
        // If using original content, extract plain text from RTF/HTML to avoid formatting markers
        let contentToTranslate = item.selectedPromptResult ?? Self.extractPlainTextForLLM(from: item)
        
        logger.info("Starting translation for item \(itemId) to \(targetLanguage.displayName)")
        
        // Mark as processing
        items[index] = items[index].withTranslationProcessing(languageCode: targetLanguage.rawValue, processing: true)
        
        // Get the active provider
        guard let provider = llmService.activeProvider as? LLMProviderImpl else {
            logger.error("No active LLM provider available for translation")
            if let idx = items.firstIndex(where: { $0.id == itemId }) {
                items[idx] = items[idx].withTranslationProcessing(languageCode: targetLanguage.rawValue, processing: false)
            }
            return
        }
        
        do {
            let prompt = SupportedLanguage.translationPrompt(to: targetLanguage)
                .replacingOccurrences(of: "{text}", with: contentToTranslate)
            let response = try await provider.generate(prompt: prompt, context: nil)
            let translatedText = response.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Store translation result
            if let currentIndex = items.firstIndex(where: { $0.id == itemId }) {
                items[currentIndex] = items[currentIndex].withTranslationResult(
                    languageCode: targetLanguage.rawValue,
                    translation: translatedText
                )
                logger.info("Translation complete for item \(itemId) to \(targetLanguage.displayName)")
            }
        } catch {
            logger.error("Translation to \(targetLanguage.displayName) failed: \(error.localizedDescription)")
            if let currentIndex = items.firstIndex(where: { $0.id == itemId }) {
                items[currentIndex] = items[currentIndex].withTranslationProcessing(
                    languageCode: targetLanguage.rawValue,
                    processing: false
                )
            }
        }
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text, .link:
            // If we have all original pasteboard data, restore everything (preserves app-specific formats)
            if let allData = item.allPasteboardData, !allData.isEmpty {
                let types = allData.keys.map { NSPasteboard.PasteboardType($0) }
                pasteboard.declareTypes(types, owner: nil)
                
                for (typeString, data) in allData {
                    let type = NSPasteboard.PasteboardType(typeString)
                    pasteboard.setData(data, forType: type)
                }
            } else {
                // Fall back to RTF/HTML/string
                var types: [NSPasteboard.PasteboardType] = []
                if item.htmlData != nil { types.append(.html) }
                if item.rtfData != nil { types.append(.rtf) }
                types.append(.string)
                
                pasteboard.declareTypes(types, owner: nil)
                
                if let htmlData = item.htmlData {
                    pasteboard.setData(htmlData, forType: .html)
                }
                if let rtfData = item.rtfData {
                    pasteboard.setData(rtfData, forType: .rtf)
                }
                pasteboard.setString(item.content, forType: .string)
            }
        case .image:
            if let data = item.rawData {
                pasteboard.setData(data, forType: .png)
            }
        case .file, .other:
            pasteboard.setString(item.content, forType: .string)
        }
        
        // Update change count to avoid re-capturing our own paste
        lastChangeCount = pasteboard.changeCount
    }
    
    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
    }
    
    func clearHistory() {
        items.removeAll()
        
        // Also clear persisted history
        Task {
            do {
                try await ClipboardPersistence.shared.clearHistory()
            } catch {
                logger.error("❌ Failed to clear persisted history: \(error.localizedDescription)")
            }
        }
    }
    
    /// Clear only items from today
    func clearHistoryForToday() {
        let calendar = Calendar.current
        let todayCount = items.filter { calendar.isDateInToday($0.timestamp) }.count
        items.removeAll { calendar.isDateInToday($0.timestamp) }
        logger.info("🗑️ Cleared \(todayCount) items from today")
        // Persistence will auto-save via debounced observer
    }
    
    /// Count of items from today
    var todayItemsCount: Int {
        let calendar = Calendar.current
        return items.filter { calendar.isDateInToday($0.timestamp) }.count
    }
    
    // MARK: - Plain Text Extraction
    
    /// Extract plain text from RTF or HTML data, falling back to provided string
    /// Used when sending content to LLM to avoid formatting markers in responses
    /// - Parameters:
    ///   - item: ClipboardItem containing RTF/HTML data and content
    /// - Returns: Plain text string without formatting markers
    private static func extractPlainTextForLLM(from item: ClipboardItem) -> String {
        /// Strip formatting markers (underscores, asterisks) from text
        /// These can appear in RTF-extracted text even after NSAttributedString conversion
        func stripFormattingMarkers(_ text: String) -> String {
            var cleaned = text
            // Remove markdown-style formatting markers that might be in the text
            // Match underscores/asterisks that are used for formatting (not in code blocks)
            // Simple approach: remove standalone underscores and asterisks used for emphasis
            cleaned = cleaned.replacingOccurrences(of: "_", with: "")
            cleaned = cleaned.replacingOccurrences(of: "*", with: "")
            return cleaned
        }
        
        // Try RTF first
        if let rtfData = item.rtfData, !rtfData.isEmpty {
            if let nsAttr = try? NSAttributedString(
                data: rtfData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) {
                let plainText = nsAttr.string
                if !plainText.isEmpty {
                    let cleanedText = stripFormattingMarkers(plainText)
                    return cleanedText
                }
            }
        }
        
        // Try HTML if RTF not available or failed
        if let htmlData = item.htmlData, !htmlData.isEmpty {
            if let nsAttr = try? NSAttributedString(
                data: htmlData,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            ) {
                let plainText = nsAttr.string
                if !plainText.isEmpty {
                    let cleanedText = stripFormattingMarkers(plainText)
                    return cleanedText
                }
            }
        }
        
        // Fall back to item.content (may contain formatting markers, but better than nothing)
        let cleanedContent = stripFormattingMarkers(item.content)
        return cleanedContent
    }
    
    // MARK: - URL Detection
    
    /// Check if a string is a valid URL (http, https, ftp, or mailto)
    private static func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" || scheme == "ftp" || scheme == "mailto" else {
            return false
        }
        return url.host != nil || scheme == "mailto"
    }
}

