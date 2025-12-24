import Foundation
import AppKit
import Combine
import os.log

private let logger = Logger(subsystem: "com.clipsa.app", category: "ClipboardManager")

@MainActor
class ClipboardManager: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var searchQuery: String = ""
    
    /// LLM service for processing clipboard content
    let llmService = LLMService()
    
    /// Whether automatic LLM processing is enabled (backed by LLMSettings)
    var llmAutoProcess: Bool {
        get { LLMSettings.shared.autoProcess }
        set { LLMSettings.shared.autoProcess = newValue }
    }
    
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let maxItems = 100
    private var cancellables = Set<AnyCancellable>()
    
    /// Whether initial history load has completed
    private var historyLoaded = false
    
    var filteredItems: [ClipboardItem] {
        if searchQuery.isEmpty {
            return items
        }
        // Use smart search that includes LLM fields
        return items.filter { $0.matchesSearch(searchQuery) }
    }
    
    init() {
        lastChangeCount = NSPasteboard.general.changeCount
        setupLLMProviders()
        observeModelChanges()
        setupPersistence()
        startMonitoring()
        
        // Listen for internal paste operations to avoid re-processing
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ClipsaInternalPaste"),
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
            ("🦦 Clipsa - Your friendi clipboard manager!", .text, "Slack"),
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
        
        // Observe MLX model changes
        LLMSettings.shared.$mlxSelectedModel
            .dropFirst()
            .sink { [weak self] newModel in
                logger.info("🔄 MLX model changed to: \(newModel), clearing LLM cache")
                self?.llmService.clearCache()
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
            
            let item = ClipboardItem(
                content: string,
                type: .text,
                appName: appName
            )
            addItem(item)
        }
        // Try to get image
        else if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            let item = ClipboardItem(
                content: "[Image]",
                rawData: imageData,
                type: .image,
                appName: appName
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
        } else if !llmAutoProcess {
            logger.debug("⏸️ LLM auto-processing is disabled")
        }
    }
    
    /// Process a clipboard item with the LLM service
    /// Fires main prompt and tag extraction as independent async queries
    func processItemWithLLM(_ item: ClipboardItem) async {
        guard item.type == .text, !item.llmProcessed else {
            logger.debug("⏭️ Skipping LLM processing: type=\(item.type.rawValue), alreadyProcessed=\(item.llmProcessed)")
            return
        }
        
        // Find the item index
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            logger.warning("⚠️ Item not found in list, skipping processing")
            return
        }
        
        let itemId = item.id
        let content = item.content
        
        logger.info("🔄 Starting LLM processing for item \(itemId)")
        
        // Mark as processing (main prompt)
        items[index] = items[index].withProcessingState(true)
        
        // Also mark tags as processing if detectTags is enabled
        if LLMSettings.shared.detectTags {
            if let idx = items.firstIndex(where: { $0.id == itemId }) {
                items[idx] = items[idx].withTagsProcessingState(true)
            }
        }
        
        // Fire main custom prompt query (independent task)
        Task { @MainActor in
            let result = await llmService.processContent(content)
            
            // Update the item with main prompt results
            if let currentIndex = items.firstIndex(where: { $0.id == itemId }) {
                items[currentIndex] = items[currentIndex].withLLMResult(result)
                if let error = result.error {
                    logger.error("❌ LLM processing failed: \(error)")
                } else {
                    logger.info("✅ LLM main prompt complete for item \(itemId)")
                }
            }
        }
        
        // Fire tag extraction query (independent async task)
        if LLMSettings.shared.detectTags {
            Task { @MainActor in
                logger.info("🏷️ Starting async tag extraction for item \(itemId)")
                let tagResult = await llmService.processContent(content, requestType: .extractTags)
                
                // Update the item with tags only
                if let currentIndex = items.firstIndex(where: { $0.id == itemId }) {
                    items[currentIndex] = items[currentIndex].withTagsResult(tagResult.tags)
                    if let error = tagResult.error {
                        logger.error("❌ Tag extraction failed: \(error)")
                    } else {
                        logger.info("✅ Tag extraction complete for item \(itemId): \(tagResult.tags)")
                    }
                }
            }
        }
    }
    
    /// Reprocess an item with LLM (useful for manual retry)
    func reprocessItemWithLLM(_ item: ClipboardItem) async {
        guard item.type == .text else { return }
        
        // Find and reset the item
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        var resetItem = items[index]
        resetItem.llmProcessed = false
        resetItem.llmTags = []
        items[index] = resetItem
        
        // Clear cache for this content
        llmService.clearCache()
        
        await processItemWithLLM(resetItem)
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text:
            pasteboard.setString(item.content, forType: .string)
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
}

