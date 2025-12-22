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
    
    /// Whether automatic LLM processing is enabled
    @Published var llmAutoProcess: Bool = true
    
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let maxItems = 100
    private var cancellables = Set<AnyCancellable>()
    
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
        startMonitoring()
        
        // Listen for internal paste operations to avoid re-processing
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ClipsaInternalPaste"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let changeCount = notification.userInfo?["changeCount"] as? Int {
                self?.lastChangeCount = changeCount
                logger.debug("🔇 Ignoring internal paste operation (changeCount: \(changeCount))")
            }
        }
    }
    
    /// Setup default LLM providers
    private func setupLLMProviders() {
        // Register Ollama as the provider (requires Ollama to be running)
        let ollamaProvider = OllamaProvider()
        llmService.registerProvider(ollamaProvider)
    }
    
    /// Observe model changes and clear cache when model changes
    private func observeModelChanges() {
        LLMSettings.shared.$selectedModel
            .dropFirst() // Skip initial value
            .sink { [weak self] newModel in
                logger.info("🔄 Model changed to: \(newModel), clearing LLM cache")
                self?.llmService.clearCache()
            }
            .store(in: &cancellables)
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
        
        logger.info("🔄 Starting LLM processing for item \(item.id)")
        
        // Mark as processing
        items[index] = items[index].withProcessingState(true)
        
        // Process with LLM
        let result = await llmService.processContent(item.content)
        
        // Update the item with results
        if let currentIndex = items.firstIndex(where: { $0.id == item.id }) {
            items[currentIndex] = items[currentIndex].withLLMResult(result)
//            logger.info("THE RESULT: \(items[currentIndex].llmResponse)")
            if let error = result.error {
                logger.error("❌ LLM processing failed: \(error)")
            } else {
                logger.info("✅ LLM processing complete for item \(item.id)")
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
    }
}

