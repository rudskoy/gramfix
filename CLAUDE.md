# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clipsa is a macOS clipboard manager with AI-powered content analysis. It uses SwiftUI with macOS Tahoe's Liquid Glass APIs and supports two LLM providers: Ollama (server-based) and MLX (on-device Apple Silicon).

## Build & Test Commands

### Building
```bash
# Open in Xcode
open Clipsa.xcodeproj

# Build from command line (requires xcodebuild)
xcodebuild -project Clipsa.xcodeproj -scheme Clipsa -configuration Debug build
xcodebuild -project Clipsa.xcodeproj -scheme Clipsa -configuration Release build
```

### Testing
```bash
# Run all tests
xcodebuild test -project Clipsa.xcodeproj -scheme Clipsa

# Run specific test (use Xcode Test Navigator for single test execution)
```

Note: Tests are integration tests requiring Ollama to be running locally for `OllamaProviderTests`.

### Running
- Run directly from Xcode (Cmd+R)
- Debug builds automatically load sample clipboard data on launch via `ClipboardManager.loadTestData()` (controlled by `#if DEBUG`)

## System Requirements

- **Xcode 26+** and **macOS Tahoe (26)+** required for Liquid Glass APIs
- **Apple Silicon** (M1/M2/M3/M4) required for MLX provider
- **Ollama** (optional, running on localhost:11434) for Ollama provider

## Architecture Essentials

### Core Data Flow

The app follows a polling-based clipboard monitoring pattern:

```
NSPasteboard (0.5s poll) → ClipboardManager → items[]
                                ↓
                        LLMService (if autoProcess)
                                ↓
                    ┌───────────┴───────────┐
                    ↓                       ↓
            OllamaProvider              MLXProvider
```

- **ClipboardManager**: `@StateObject` that owns the items array, search logic, and LLM processing
- **LLMService**: Manages provider switching, caches results by content hash
- **LLMSettings**: Singleton backed by UserDefaults for provider/model selection and custom prompts

### LLM Provider System

Both providers implement the `LLMProvider` protocol and can be hot-swapped in Settings:

- **Ollama**: Uses `ollama-swift` library, communicates with local Ollama server
- **MLX**: Uses `mlx-swift` and `swift-transformers` for on-device inference with Apple Silicon

Provider selection auto-detects Apple Silicon (defaults to MLX) or Intel (defaults to Ollama). Cache is cleared when switching providers.

### Dual Query System

Content analysis uses two independent async queries:
1. **Main custom prompt**: User-configurable, updates `ClipboardItem.llmResponse`
2. **Tag extraction**: Hardcoded prompt (if `LLMSettings.detectTags` enabled), updates `ClipboardItem.llmTags`

Both queries run concurrently and can complete in any order.

### Global Shortcut & Paste Flow

- **Global shortcut**: Cmd+Shift+\ (via HotKey library using Carbon APIs)
- **Toggle behavior**: Shows Clipsa if inactive, returns to previous app if active
- **Paste actions**:
  - `Enter`: Regular paste (copies to clipboard, pastes, keeps on clipboard)
  - `Shift+Enter`: Immediate paste (pastes then restores original clipboard after 200ms)
- **Accessibility permission**: Required for CGEvent keyboard simulation, checked lazily before paste actions (not on launch)

### Keyboard Navigation

Uses `NSEvent.addLocalMonitorForEvents` (not SwiftUI's `.onKeyPress()`) for app-wide Up/Down arrow navigation:
- Works regardless of focus (including when search field is focused)
- Blocked only when Cmd/Shift/Ctrl/Option are held
- Must exclude `.function` and `.numericPad` modifier flags (intrinsic to arrow keys)

### UI System

Built on macOS Tahoe's Liquid Glass APIs:
- `NavigationSplitView` with `.glassEffect()` on sidebar
- `.backgroundExtensionEffect()` on detail pane
- System handles floating appearance, rounded corners, translucent blur, and traffic lights

Custom components:
- `HoverScaleModifier`: Interactive hover animations
- `GlowEffect`: Accent glow for selections

## Key Implementation Patterns

### Model Management

**Ollama**: Users can select installed models or download new ones via `OllamaProvider.pullModel()` with real-time progress.

**MLX**: Predefined models (llama3.2:1b, qwen2.5:1.5b, smolLM:135m, qwen3:0.6b-4b) auto-download from HuggingFace on first use. Progress tracked by file count (e.g., "Downloading 3/7 files") since HuggingFace reports per-file progress.

Model changes trigger cache clearing in `ClipboardManager`.

### Clipboard Item Structure

`ClipboardItem` is a struct containing:
- Content data (text, image, file)
- `rawData`: Raw NSData for images
- `type`: Content type classification
- `llmResponse`: Main AI analysis result
- `llmTags`: Extracted tags (array)
- Processing flags: `llmProcessing`, `llmTagsProcessing`

### Supported Content Types

Paste actions support:
- **Text**: Direct paste or AI-processed response
- **Image**: PNG data from `ClipboardItem.rawData`
- **File**: File names as text

### Window Management

- Uses `Window` (not `WindowGroup`) for single-window enforcement
- `CommandGroup(replacing: .newItem) { }` removes "New Window" menu item
- `MenuBarExtra` provides status bar menu with "Show Window" and "Quit"
- Window configured with `.titlebarAppearsTransparent = true` and `.collectionBehavior = [.moveToActiveSpace]`

## File Organization

```
Clipsa/
├── ClipsaApp.swift              # Entry point, AppDelegate, global shortcut, MenuBarExtra
├── Models/                      # Data structures
│   ├── ClipboardItem.swift      # Clipboard entry with LLM fields
│   ├── LLMSettings.swift        # UserDefaults-backed settings singleton
│   └── LMModel.swift            # MLX model config with HuggingFace setup
├── Services/                    # Business logic
│   ├── ClipboardManager.swift   # State management, polling, LLM orchestration
│   ├── LLMService.swift         # Provider management, caching
│   ├── OllamaProvider.swift     # Ollama API wrapper (actor)
│   ├── MLXService.swift         # MLX model loading (@Observable)
│   ├── MLXProvider.swift        # MLX LLMProvider implementation
│   ├── PasteService.swift       # Paste workflows (regular & immediate)
│   └── AccessibilityService.swift # Permission handling
├── Views/                       # UI components
│   ├── ContentView.swift        # Main NavigationSplitView with keyboard handling
│   ├── ClipboardRow.swift       # List item with hover effects
│   ├── PreviewPane.swift        # Detail panel with AI response
│   ├── SearchBar.swift          # Search input
│   └── SettingsView.swift       # Provider/model/prompt configuration
├── Utilities/
│   └── Styling.swift            # Shared colors, fonts, modifiers
└── Support/
    └── HubApi+default.swift     # HuggingFace Hub config for MLX downloads

ClipsaTests/
├── OllamaProviderTests.swift    # Integration tests (requires Ollama running)
├── LLMServiceTests.swift        # Integration tests
└── LLMSettingsTests.swift       # Settings tests
```

## Dependencies

- **[ollama-swift](https://github.com/mattt/ollama-swift)**: Ollama API client
- **[mlx-swift](https://github.com/ml-explore/mlx-swift)** (v0.29.1+): MLX for Apple Silicon
- **[swift-transformers](https://github.com/huggingface/swift-transformers)** (v1.1.0+): HuggingFace Hub API
- **[HotKey](https://github.com/soffes/HotKey)**: Global keyboard shortcuts via Carbon APIs

## Important Constraints

- Always use `NSEvent.addLocalMonitorForEvents` for keyboard shortcuts (not `.onKeyPress()`) to support focus-independent navigation
- When working with arrow key events, exclude `.function` and `.numericPad` from modifier checks (these are intrinsic flags)
- Accessibility permission must be checked lazily (before paste actions), never on app launch
- Debug test data is automatically loaded via `#if DEBUG` - ensure this is never shipped in Release builds
- MLX provider requires Apple Silicon - auto-detection uses architecture check
- Settings changes (provider/model) must trigger cache clearing in `ClipboardManager`
