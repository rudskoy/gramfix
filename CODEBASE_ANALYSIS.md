# Clipsa Codebase Structure Analysis

## Project Overview
Clipsa is a macOS clipboard manager with AI-powered content analysis. It's a modern SwiftUI application built with macOS Tahoe's Liquid Glass APIs, supporting two LLM providers: Ollama (server-based) and MLX (on-device Apple Silicon inference).

**Platform Requirements:**
- macOS Tahoe (26) or later (for Liquid Glass APIs)
- Xcode 26 or later
- Apple Silicon (M1/M2/M3/M4) recommended for MLX provider

---

## 1. Current Project Organization

### Directory Structure
```
/Users/Vladislav.Rudskoy/ij/Clipsa/
├── Clipsa/                          # Main app source code (19 Swift files)
│   ├── ClipsaApp.swift              # Entry point + AppDelegate + MenuBarExtra
│   ├── Models/
│   │   ├── ClipboardItem.swift      # Clipboard entry model (206 lines)
│   │   ├── LLMSettings.swift        # UserDefaults-backed singleton (154 lines)
│   │   └── LMModel.swift            # MLX model configuration
│   ├── Services/
│   │   ├── ClipboardManager.swift   # @MainActor - polling + orchestration (300+ lines)
│   │   ├── LLMService.swift         # Provider management + caching (200+ lines)
│   │   ├── OllamaProvider.swift     # Ollama API wrapper (actor, 100+ lines)
│   │   ├── MLXService.swift         # @Observable MLX inference
│   │   ├── MLXProvider.swift        # MLX LLMProvider implementation
│   │   ├── PasteService.swift       # Paste workflows + app tracking
│   │   └── AccessibilityService.swift # Permission handling
│   ├── Views/ (5 files)
│   │   ├── ContentView.swift        # Main NavigationSplitView
│   │   ├── PreviewPane.swift        # Detail panel
│   │   ├── ClipboardRow.swift       # List items
│   │   ├── SearchBar.swift          # Search input
│   │   └── SettingsView.swift       # Provider/model/prompt settings
│   ├── Support/
│   │   ├── HubApi+default.swift     # HuggingFace Hub config
│   │   └── KeyboardShortcuts+Names.swift # Global shortcut definitions
│   ├── Utilities/
│   │   └── Styling.swift            # Shared colors, fonts, modifiers
│   └── [Assets, entitlements, Info.plist]
├── ClipsaTests/ (3 test files)
│   ├── OllamaProviderTests.swift    # Integration tests
│   ├── LLMServiceTests.swift        # Service tests
│   └── LLMSettingsTests.swift       # Settings tests
├── Clipsa.xcodeproj/                # Xcode project (921 lines in pbxproj)
├── ARCHITECTURE.md                  # Detailed architecture docs
├── CLAUDE.md                        # AI assistant guidelines
├── CODEBASE_ANALYSIS.md             # This file
└── scripts/, junk/, build/          # Auxiliary directories
```

### Core Statistics
- **19 Swift files** in main app
- **3 test files**
- **~2000 lines** of Swift code (core app)
- **Clear separation**: Models, Services, Views, Utilities

---

## 2. Build System & Dependencies

### Swift Package Manager Dependencies
**Resolved in**: `Clipsa.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

#### LLM Core
| Package | Version | Purpose |
|---------|---------|---------|
| ollama-swift | 1.8.0 | Ollama API client |
| mlx-swift | 0.29.1 | Core MLX framework |
| mlx-swift-lm | 2.29.2 | MLX LLM utilities |
| swift-transformers | 1.1.6 | HuggingFace Hub API |

#### Supporting
| Package | Version | Purpose |
|---------|---------|---------|
| KeyboardShortcuts | 2.4.0 | Configurable global shortcuts |
| HotKey | main | Legacy shortcuts (Carbon) |
| swift-numerics | 1.1.1 | Numerical computation |
| swift-collections | 1.3.0 | Apple collections |
| swift-jinja | 2.2.0 | Template support |

#### MLX Submodules (10+)
MLX, MLXFFT, MLXFast, MLXLinalg, MLXNN, MLXOptimizers, MLXRandom, MLXEmbedders, MLXLLM, MLXLMCommon

### Build Configuration
- **Xcode Version**: 90 (macOS Tahoe)
- **Frameworks**: SwiftUI, AppKit, Foundation, Combine, os.log
- **Entitlements**: No sandbox (required for clipboard access)
- **Target**: macOS (deployment target configurable)

### Build Commands
```bash
open Clipsa.xcodeproj                                    # Open in Xcode
xcodebuild build -project Clipsa.xcodeproj -scheme Clipsa -configuration Debug
xcodebuild build -project Clipsa.xcodeproj -scheme Clipsa -configuration Release
xcodebuild test -project Clipsa.xcodeproj -scheme Clipsa  # Run tests
```

---

## 3. Architecture & Key Components

### Data Flow
```
NSPasteboard ──(0.5s poll)──> ClipboardManager ──> items[]
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
              Main Query              Tag Extraction Query
            (Custom Prompt)           (Concurrent async)
                    │                             │
                    ▼                             ▼
             llmResponse             llmTags[]
            llmContentType
```

### Core Services

#### ClipboardManager (@MainActor, ~300 lines)
**Location**: `Clipsa/Services/ClipboardManager.swift`

**Key Responsibilities**:
- Owns `@Published var items: [ClipboardItem]` - primary state
- Polls NSPasteboard every 0.5 seconds
- Detects content type (text, image, file)
- Orchestrates LLM processing (dual async queries)
- Manages search filtering
- Limits history to 100 items
- Loads test data in DEBUG builds

**Critical Methods**:
- `checkClipboard()` - Poll NSPasteboard.changeCount
- `addItem(_ item: ClipboardItem)` - Add to history
- `processItemWithLLM(_ item: ClipboardItem)` - Fire dual queries
- `reprocessItemWithLLM(_ item: ClipboardItem)` - Manual retry

**State Sync**:
- Watches `LLMSettings` via Combine (.dropFirst())
- Clears LLM cache on provider/model change
- Observes notifications from PasteService

#### LLMService (@MainActor, ~200 lines)
**Location**: `Clipsa/Services/LLMService.swift`

**Key Responsibilities**:
- Provider registration and switching
- Result caching (content hash based)
- Routes requests to active provider
- Availability checks

**Provider Protocol**:
```swift
protocol LLMProvider: Sendable {
    var name: String { get }
    func isAvailable() async -> Bool
    func process(_ text: String, requestType: LLMRequestType) async throws -> LLMResult
    func generate(prompt: String, context: String?) async throws -> String
}
```

**Request Types**:
- `.summarize` - 1-sentence summary
- `.extractTags` - Tag extraction
- `.classify` - Content classification
- `.custom` - Uses LLMSettings.customPrompt

**Caching**:
- Hash-based (text.hashValue)
- Max 100 results per session
- Cleared on provider/model switch

#### OllamaProvider (actor, ~100 lines)
**Location**: `Clipsa/Services/OllamaProvider.swift`

**Architecture**: Actor for thread-safe Ollama access

**Responsibilities**:
- Ollama API communication via ollama-swift library
- Model listing/pulling
- Response generation
- Model name: reads from LLMSettings.selectedModel

**Key Features**:
- Lazy client initialization
- Static methods for model management
- Default model: `qwen2.5:1.5b`
- Connects to localhost:11434

#### MLXService (@Observable @MainActor)
**Location**: `Clipsa/Services/MLXService.swift`

**Responsibilities**:
- On-device LLM inference via MLX
- Model loading from HuggingFace Hub
- Model caching (NSCache<NSString, ModelContainer>)
- Download progress tracking
- Singleton pattern (`MLXService.shared`)

**Available Models**:
```
- llama3.2:1b          (1 GB)
- qwen2.5:1.5b         (1.5 GB, default)
- smolLM:135m          (135 MB)
- qwen3:0.6b-4b        (0.6-4 GB variants)
```

**Progress Tracking**:
- `downloadedFileCount` / `totalFileCount`
- File-based (HuggingFace reports per-file)
- Updates UI incrementally

#### MLXProvider (@MainActor, @unchecked Sendable)
**Location**: `Clipsa/Services/MLXProvider.swift`

**Pattern**: Wrapper around MLXService (dependency injection)

**Responsibilities**:
- Implements LLMProvider for MLX
- Prompt building based on request type
- Response parsing
- Apple Silicon detection via `#if arch(arm64)`

#### PasteService (singleton)
**Location**: `Clipsa/Services/PasteService.swift`

**Two Paste Modes**:
1. **Regular (Enter)**: Modifies clipboard, pastes, keeps on clipboard
2. **Immediate (Shift+Enter)**: Pastes, restores original after 200ms

**Key Methods**:
- `savePreviousApp()` - Before showing Clipsa
- `returnToPreviousApp()` - Toggle off behavior
- `pasteAndReturn(content:)` - Text paste
- `pasteAndReturn(data:type:)` - Image paste
- `simulatePaste()` - Cmd+V via CGEvent

**Implementation Details**:
- Posts "ClipsaInternalPaste" notification to avoid re-processing
- Accessibility permission checked lazily (not on launch)
- 100ms delay before Cmd+V to allow app activation

#### AccessibilityService (singleton)
**Location**: `Clipsa/Services/AccessibilityService.swift`

**Responsibilities**:
- Lazy Accessibility permission checking
- Shows macOS system settings alert if needed
- Required for CGEvent keyboard simulation

#### LLMSettings (ObservableObject singleton)
**Location**: `Clipsa/Models/LLMSettings.swift` (154 lines)

**Persistence**: UserDefaults.standard

**Published Properties**:
```swift
@Published var customPrompt: String       // User-defined template {text}
@Published var autoProcess: Bool          // Default: true
@Published var detectTags: Bool           // Default: true
@Published var selectedProvider: LLMProviderType
@Published var selectedModel: String      // Ollama model
@Published var mlxSelectedModel: String   // MLX model
```

**Auto-Detection**:
```swift
static var defaultProvider: LLMProviderType {
    #if arch(arm64)
    return .mlx    // Apple Silicon
    #else
    return .ollama // Intel
    #endif
}
```

**Default Models**:
- Ollama: `qwen2.5:1.5b`
- MLX: `qwen2.5:1.5b`

#### ClipboardItem (struct, 206 lines)
**Location**: `Clipsa/Models/ClipboardItem.swift`

**Content Fields**:
```swift
let id: UUID
let content: String
let rawData: Data?           // Images
let type: ClipboardType      // text, image, file, other
let timestamp: Date
let appName: String?
let formattedTime: String    // Cached relative time
```

**LLM Fields**:
```swift
var llmResponse: String?     // Main custom prompt output
var llmSummary: String?      // Legacy field
var llmTags: [String]        // From tag extraction query
var llmContentType: String?  // Classified (code, email, etc.)
```

**Processing State**:
```swift
var llmProcessed: Bool       // Main prompt completed
var llmProcessing: Bool      // Main prompt in progress
var llmTagsProcessing: Bool  // Tag extraction in progress
```

**Helper Methods**:
- `withLLMResult(_ result)` - Update main result
- `withTagsResult(_ tags)` - Update tags only
- `smartPreview` - AI response or content
- `pasteContent` - AI response or original
- `matchesSearch(_ query)` - Full-text search

---

## 4. Recent Changes & Evolution

### Added Since CLAUDE.md
1. **MLXService + MLXProvider** - Complete on-device inference
2. **LMModel** - MLX model configuration
3. **KeyboardShortcuts Library** - Replaces HotKey
4. **Async Tag Extraction** - Dual concurrent queries

### Architectural Improvements
1. **Dual Query System**:
   - Main prompt runs independently
   - Tag extraction runs concurrently
   - Both tracked with separate processing flags
   - Results update incrementally

2. **Provider Hot-Swapping**:
   - No app restart required
   - Cache clearing on switch
   - Settings-driven selection

3. **Apple Silicon Optimization**:
   - Auto-detection and default to MLX on arm64
   - On-device inference with progress tracking
   - HuggingFace Hub integration for models

### Git Status
- Only 1 commit: `4de6f4b Initial Commit`
- 19 modified files (uncommitted)
- 6 staged files (ready to commit)
- Indicates active refactoring in progress

---

## 5. Test Structure

### Test Files
**Location**: `ClipsaTests/`

1. **OllamaProviderTests.swift**
   - Integration tests (requires Ollama running)
   - Tests: availability, summarize, tag extraction, classification
   - Gracefully skips if Ollama unavailable (XCTSkipUnless)

2. **LLMServiceTests.swift**
   - Service-level integration tests
   - Provider switching, caching

3. **LLMSettingsTests.swift**
   - UserDefaults persistence
   - Unit tests

### Running Tests
```bash
xcodebuild test -project Clipsa.xcodeproj -scheme Clipsa
```

### Requirements
- Ollama server running locally (optional, tests gracefully skip)
- No external cloud services needed

---

## 6. Key Implementation Patterns

### State Management
- **@MainActor**: ClipboardManager, MLXService, MLXProvider
- **@Observable**: MLXService (modern reactive state)
- **@Published**: LLMSettings fields
- **@StateObject**: ClipsaApp's ClipboardManager

### Concurrency
- **Timer-based polling**: 0.5s NSPasteboard checks (main thread)
- **Fire-and-forget Tasks**: Concurrent LLM queries
- **Actor isolation**: OllamaProvider
- **Async/await**: All LLM operations

### Keyboard Handling
- `NSEvent.addLocalMonitorForEvents` (not .onKeyPress)
- Global shortcuts via KeyboardShortcuts library (configurable)
- App-wide arrow key navigation
- Focus-independent (works when search field focused)

### UI Architecture
- **Liquid Glass**: NavigationSplitView with .glassEffect()
- **Detail pane**: .backgroundExtensionEffect()
- **Components**: HoverScaleModifier, GlowEffect

### Performance Optimizations
- Content hash caching in LLMService
- ModelCache in MLXService
- Cached relative date formatting on ClipboardItem
- Internal paste detection avoids re-processing
- Duplicate detection (last item content check)

---

## 7. Critical Implementation Details

### Clipboard Polling Loop
1. Timer fires every 0.5 seconds
2. Check NSPasteboard.changeCount
3. If changed: detect type (text/image/file)
4. Avoid duplicates (compare with last item)
5. Add to history (insert at index 0)
6. Trigger LLM if autoProcess enabled

### LLM Processing Flow
```
1. ClipboardManager.addItem() called
2. If autoProcess && type == .text:
   a. Mark item as processing (llmProcessing = true)
   b. Fire main query Task:
      - buildPrompt(customPrompt, content)
      - provider.process(text, .custom)
      - Update llmResponse, llmContentType
      - Mark llmProcessed = true
   c. If detectTags enabled:
      - Mark tags processing (llmTagsProcessing = true)
      - Fire tag query Task:
         - provider.process(text, .extractTags)
         - Update llmTags
      - Mark tags done (llmTagsProcessing = false)
3. UI updates incrementally as results arrive
```

### Provider Selection
```
Startup:
  1. Auto-detect Apple Silicon (#if arch(arm64))
  2. Prefer MLX on ARM, Ollama on Intel
  3. Read saved preference from UserDefaults
  4. Register both providers in LLMService

On Provider Change:
  1. Update LLMSettings.selectedProvider
  2. LLMService.syncWithSettings()
  3. Clear result cache
  4. No restart needed
```

### Paste Workflow
```
Regular Paste (Enter):
  1. Check Accessibility permission
  2. Copy content to NSPasteboard
  3. Post ClipsaInternalPaste notification
  4. Hide Clipsa
  5. Activate previous app
  6. After 100ms: simulate Cmd+V

Immediate Paste (Shift+Enter):
  1. Same as above
  2. After 200ms additional: restore original clipboard
```

---

## 8. Security & Permissions

### Required Permissions
- **Accessibility**: For CGEvent keyboard simulation (Cmd+V)
  - Checked lazily (before first paste)
  - Shows system settings alert if needed
  - NOT checked on app launch

### Entitlements
```xml
<!-- No sandbox - required for full clipboard access -->
<key>com.apple.security.app-sandbox</key>
<false/>
```

### Data Privacy
- Clipboard history: In-memory only (up to 100 items)
- Settings: UserDefaults (local machine)
- LLM communication: Local only (Ollama on localhost:11434)
- MLX models: Downloaded from HuggingFace, stored locally

---

## 9. Known Issues & TODOs

### Code Issues
1. **Vision-Language Models (VLM) Disabled**
   - File: `Clipsa/Models/LMModel.swift`, `Clipsa/Services/MLXService.swift`
   - Issue: MLXVLM's Message type conflicts with Ollama's Message
   - Status: Unresolved, VLM imports commented out
   - Impact: No image analysis capability via MLX

### Git Issues
- Only 1 initial commit
- Multiple uncommitted changes suggest refactoring in progress
- Duplicate files in different directories (HubApi+default.swift)
- Stale test file: `Clipsa.xcodeproj/New Group/123.swift`

### Architecture Issues
- Extra files at project root (should be in Clipsa/Support/)
- Multiple copies of HubApi+default.swift

---

## 10. File Organization & Statistics

### Main Application Files

| Category | Files | Lines |
|----------|-------|-------|
| Entry Point | ClipsaApp.swift | 100 |
| Models | ClipboardItem, LLMSettings, LMModel | 360 |
| Services | ClipboardManager, LLMService, Providers | 700+ |
| Views | ContentView, PreviewPane, Others | 400+ |
| Support | Styling, KeyboardShortcuts+Names, HubApi | 200 |
| Tests | 3 test files | 200+ |

**Total**: ~2000 lines of Swift (core functionality)

### Directory Breakdown
- `Clipsa/`: 19 Swift files
- `ClipsaTests/`: 3 test files
- `Clipsa.xcodeproj/`: Project configuration
- Supporting: Scripts, assets, configuration files

---

## 11. Summary & Assessment

### Strengths
1. **Clear Architecture**: Well-separated concerns (Models, Services, Views)
2. **Modern Swift**: Uses latest concurrency patterns (@Observable, async/await)
3. **Dual LLM Support**: Pluggable provider system with hot-swapping
4. **Performance**: Hash caching, lazy initialization, incremental updates
5. **macOS Integration**: Liquid Glass APIs, global shortcuts, window management
6. **User Experience**: Configurable settings, progress tracking, AI responses
7. **Testing**: Integration tests with graceful degradation

### Areas for Improvement
1. **VLM Support**: Disabled due to type conflicts
2. **Test Coverage**: Only 3 test files
3. **Error Handling**: Could be more robust in some areas
4. **Documentation**: Some complex logic could use inline comments

### Current Status
- **Feature-Complete**: All major features implemented
- **Active Development**: Uncommitted changes suggest ongoing work
- **Stable**: Single production-ready commit
- **Ready for**: Testing, deployment, community contribution

### Performance Characteristics
- **Clipboard Polling**: 0.5s interval (responsive)
- **LLM Processing**: Concurrent (main + tags), non-blocking UI
- **Model Loading**: Async with progress tracking
- **Memory**: 100-item history limit, model caching

---

## Quick Reference

### Key Classes & Protocols
- `ClipboardManager` (@MainActor) - State & orchestration
- `LLMService` (@MainActor) - Provider management
- `LLMProvider` (protocol) - Provider interface
- `OllamaProvider` (actor) - Ollama implementation
- `MLXProvider` (@MainActor) - MLX implementation
- `MLXService` (@Observable) - Model management
- `PasteService` (singleton) - Paste workflows
- `LLMSettings` (ObservableObject) - Settings singleton
- `ClipboardItem` (struct) - Data model

### Key Directories
- `Clipsa/Services/` - Business logic
- `Clipsa/Models/` - Data structures
- `Clipsa/Views/` - SwiftUI components
- `Clipsa/Support/` - Configuration & extensions
- `Clipsa/Utilities/` - Shared styling

### Key Enums
- `ClipboardType` - text, image, file, other
- `LLMProviderType` - ollama, mlx
- `LLMRequestType` - summarize, extractTags, classify, custom

---

*Analysis generated: 2025-12-23*
*For updates, see ARCHITECTURE.md and CLAUDE.md*
