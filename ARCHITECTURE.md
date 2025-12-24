# Clipsa Architecture

> macOS clipboard manager with AI-powered content analysis (Ollama & MLX)

## Structure

```
Clipsa/
├── ClipsaApp.swift              # Entry point, window config, MenuBarExtra
├── Models/
│   ├── ClipboardItem.swift      # Clipboard entry (content, type, LLM fields)
│   ├── LLMSettings.swift        # AI settings, app theme (provider, model, prompt, theme via UserDefaults)
│   └── LMModel.swift            # MLX model configuration (name, type, HuggingFace config)
├── Services/
│   ├── ClipboardManager.swift   # State manager, clipboard polling, LLM trigger
│   ├── PasteService.swift       # Paste actions: regular (modifies clipboard) & immediate (preserves clipboard)
│   ├── AccessibilityService.swift # Accessibility permission handling (required for CGEvent)
│   ├── LLMService.swift         # LLM orchestration, caching, provider management, protocols
│   ├── LLMProviderImpl.swift    # Unified LLM provider with shared prompt/parsing logic
│   ├── OllamaClient.swift       # Ollama client implementing TextGenerationClient
│   ├── MLXClient.swift          # MLX client implementing TextGenerationClient
│   ├── MLXService.swift         # MLX model loading, caching, generation
│   └── UpdateService.swift      # Sparkle automatic update controller
├── Support/
│   ├── HubApi+default.swift     # HuggingFace Hub configuration for model downloads
│   └── KeyboardShortcuts+Names.swift # Global shortcut name definitions
├── Views/
│   ├── ContentView.swift        # NavigationSplitView with Liquid Glass sidebar
│   ├── ClipboardRow.swift       # List items with hover effects
│   ├── PreviewPane.swift        # Detail panel with AI response + mascot states
│   ├── SearchBar.swift          # Search input
│   ├── SettingsView.swift       # Provider selection, model picker, prompt editor
│   └── CheckForUpdatesView.swift # Sparkle update check button
└── Utilities/
    └── Styling.swift            # Colors, fonts, shared components

ClipsaTests/
├── LLMProviderImplTests.swift   # Unit tests for LLMProviderImpl (uses MockTextGenerationClient)
├── OllamaProviderTests.swift    # Integration tests for OllamaClient (requires Ollama running)
├── MLXProviderTests.swift       # Unit tests for MLXClient (uses MockMLXService)
├── LLMServiceTests.swift        # Integration tests for LLMService
└── LLMSettingsTests.swift       # Tests for LLMSettings
```

## Data Flow

```
NSPasteboard ──(0.5s poll)──▶ ClipboardManager ──▶ items[]
                                    │
                                    ▼ (if autoProcess)
                              LLMProviderImpl
                                    │
                          ┌─────────┴─────────┐
                          │                   │
                    OllamaClient          MLXClient
                          │                   │
                    ollama-swift          MLXService
                          │                   │
                          └─────────┬─────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
           Main Custom Prompt              Tag Extraction Query
           (uses customPrompt)             (if detectTags enabled)
                    │                               │
                    ▼                               ▼
           Update llmResponse              Update llmTags
```

Both queries run as independent async tasks - either can complete first.

## LLM Provider Architecture

Clipsa uses a unified provider architecture with dependency injection for testability:

```
┌─────────────────────────────────────────────────────────┐
│                    LLMProviderImpl                       │
│  (shared prompt building & response parsing logic)       │
│                                                          │
│  - buildPrompt(for:text:)                               │
│  - parseResponse(_:requestType:)                        │
│  - parseJSONResponse(_:)                                │
│  - parseCustomResponse(_:)                              │
└───────────────────────┬─────────────────────────────────┘
                        │ uses
                        ▼
            ┌───────────────────────┐
            │ TextGenerationClient  │ (protocol)
            │  - name: String       │
            │  - isAvailable()      │
            │  - generate(prompt:)  │
            └───────────┬───────────┘
                        │ implemented by
            ┌───────────┴───────────┐
            │                       │
    ┌───────▼───────┐       ┌───────▼───────┐
    │  OllamaClient │       │   MLXClient   │
    │   (actor)     │       │   (@MainActor)│
    │               │       │               │
    │ ollama-swift  │       │  MLXService   │
    └───────────────┘       └───────────────┘
```

### Supported Providers

| Provider | Description | Requirements |
|----------|-------------|--------------|
| **Ollama** | Local server-based inference | Ollama running on localhost:11434 |
| **MLX** | On-device Apple Silicon inference | Apple Silicon Mac (arm64) |

### Provider Selection

- **Auto-detection**: Defaults to MLX on Apple Silicon (M1/M2/M3/M4), Ollama on Intel Macs
- Provider can be changed in Settings dialog
- Each provider maintains its own model selection
- Cache is cleared when switching providers

### MLX Models (Predefined)

| Model | Size | Type |
|-------|------|------|
| llama3.2:1b | ~1 GB | LLM |
| qwen2.5:1.5b | ~1.5 GB | LLM |
| smolLM:135m | ~135 MB | LLM |
| qwen3:0.6b-4b | ~0.6-4 GB | LLM |

Models are downloaded from HuggingFace on first use and cached locally.

## Key Components

| Component | Role |
|-----------|------|
| `ClipboardManager` | `@StateObject` - owns items[], search, initializes LLM providers |
| `ClipboardItem` | Struct with content + LLM fields (summary, tags, type) |
| `PasteService` | Singleton for paste workflows (regular & immediate), supports text/image/file types |
| `AccessibilityService` | Singleton for Accessibility permission (required since macOS 10.14) |
| `LLMService` | Manages providers, caches results by content hash, syncs with settings |
| `LLMSettings` | Singleton storing provider selection, models, custom prompt, detectTags toggle, app theme (UserDefaults) |
| `LLMProviderImpl` | Unified provider with shared prompt building & response parsing logic |
| `TextGenerationClient` | Protocol for low-level text generation (enables DI and mocking) |
| `OllamaClient` | Actor implementing `TextGenerationClient` for Ollama API |
| `MLXClient` | Class implementing `TextGenerationClient` for MLX (uses `MLXServiceProtocol` for DI) |
| `MLXServiceProtocol` | Protocol for MLX generation (enables mocking in tests) |
| `MLXService` | `@Observable` class implementing `MLXServiceProtocol` for model loading, caching, generation |
| `LMModel` | MLX model configuration with HuggingFace ModelConfiguration |

## Window Management

The app uses a "hide instead of close" pattern common to menu bar apps:

| Action | Result |
|--------|--------|
| Close button (red X) | Window hides, app stays in menu bar |
| Cmd+W | Window hides (same behavior) |
| Menu bar "Show Window" | Window reappears instantly |
| Global shortcut | Window reappears instantly |
| Menu bar "Quit Clipsa" | App terminates completely |
| Cmd+Q | App terminates completely |

Implementation:
- `AppDelegate` conforms to `NSWindowDelegate`
- `windowShouldClose(_:)` calls `orderOut(nil)` and returns `false`
- `applicationShouldTerminateAfterLastWindowClosed(_:)` returns `false`

## Global Shortcut & Paste Flow

### Global Shortcut (Default: Cmd+Shift+\\)
Uses [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) library for configurable global hotkey:
- Registered in `AppDelegate.setupGlobalShortcut()`
- **Configurable**: Users can change the shortcut in Settings via built-in recorder UI
- **Default**: Cmd+Shift+\\ (defined in `KeyboardShortcuts+Names.swift`)
- **Toggle behavior**: 
  - If Clipsa is not active: saves previous app, then activates Clipsa window
  - If Clipsa is active: returns focus to the previously saved app via `returnToPreviousApp()`

### Paste Actions

Two paste modes are available, both supporting text, images, and files:

| Action | Shortcut | Behavior |
|--------|----------|----------|
| **Paste** | Enter | Copies to clipboard, pastes to previous app. Item stays on clipboard. |
| **Immediate Paste** | Shift+Enter | Copies to clipboard, pastes, then restores original clipboard. |
| **Settings** | Cmd+, | Opens settings dialog (provider, model selection, prompt editor) |

#### Supported Content Types
- **Text**: Uses `pasteAndReturn(content:)` with text string (or AI response if available)
- **Image**: Uses `pasteAndReturn(data:type:)` with PNG data from `ClipboardItem.rawData`
- **File/Other**: Uses `pasteAndReturn(content:)` with file names as text

#### Regular Paste (Enter)
```
User presses Enter ──▶ ContentView.pasteItem()
                              │
                              ├──▶ Switch on item.type
                              ├──▶ Call appropriate PasteService method
                              │       (content: for text, data:type: for images)
                              ├──▶ Copy to NSPasteboard
                              ├──▶ Hide Clipsa
                              ├──▶ Activate previous app
                              └──▶ Simulate Cmd+V (CGEvent)
```

#### Immediate Paste (Shift+Enter)
```
User presses Shift+Enter ──▶ ContentView.immediatePasteItem()
                                    │
                                    ├──▶ Switch on item.type
                                    ├──▶ Save current clipboard
                                    ├──▶ Call appropriate PasteService method
                                    ├──▶ Copy to NSPasteboard
                                    ├──▶ Hide Clipsa
                                    ├──▶ Activate previous app
                                    ├──▶ Simulate Cmd+V (CGEvent)
                                    └──▶ Restore original clipboard (after 200ms)
```

### Accessibility Permission
Required since macOS 10.14 Mojave for `CGEvent` keyboard simulation.
- **Not checked on app launch** - only when actually needed
- Checked before each paste action via `AccessibilityService.isAccessibilityEnabled(prompt: false)`
- If not granted, shows custom alert (Clipy-style) with single "Open System Settings" button

### Keyboard Navigation
Uses `NSEvent.addLocalMonitorForEvents` for in-app keyboard handling:
- **Up/Down arrows** - Navigate through clip list
- Implemented in `ContentView.setupKeyboardMonitor()`
- Works regardless of which UI element has focus (standard macOS pattern)
- Arrow keys work even when search field is focused (no useful text function for single-line field)
- Only blocked when user holds Cmd/Shift/Ctrl/Option modifiers
- Monitor is added on view appear, removed on disappear

Note: SwiftUI's `.onKeyPress()` was not used because it requires explicit view focus, which `NavigationSplitView` doesn't provide by default. Arrow keys also have intrinsic `.function` and `.numericPad` modifier flags that must be excluded from modifier checks.

## UI Design System

### Liquid Glass (macOS Tahoe / Xcode 26)
Uses Apple's native Liquid Glass APIs introduced at WWDC 2025:

- **`NavigationSplitView`** - Main layout with sidebar + detail
- **`.glassEffect()`** - Applied to sidebar for floating translucent panel
- **`.backgroundExtensionEffect()`** - Detail pane extends under sidebar

The system automatically handles:
- Floating appearance with inset margins
- Rounded corners and translucent blur
- Traffic lights integrated inside sidebar panel
- Native Finder-like behavior

### Components
- `HoverScaleModifier` - Interactive hover animations
- `GlowEffect` - Accent glow for selected/active states
- `ThemeToggleButton` - Toolbar button for cycling between system/light/dark themes

### Theme Switching
The app supports Light, Dark, and System themes with immediate switching:

- **Storage**: `@AppStorage("app_theme")` in `ClipsaApp` for automatic SwiftUI reactivity
- **System detection**: Listens to `AppleInterfaceThemeChangedNotification` via `DistributedNotificationCenter`
- **Always explicit**: Resolves "System" to actual `.light`/`.dark` ColorScheme (never passes `nil` to `.preferredColorScheme()`) for reliable Liquid Glass updates
- **Icon refresh**: `ClipboardTypeIcon` uses `.id(colorScheme)` to force re-render of glass effects on theme change

### Colors
- Semantic colors (`.primary`, `.secondary`, `.tertiary`)
- Liquid Glass-compatible colors
- Gradient accents for LLM/AI features

## Model Management

Settings allow users to:

### Ollama
1. Select from locally installed Ollama models
2. Download new models by name (via `OllamaClient.pullModel`)
3. View download progress in real-time

### MLX
1. Select from predefined MLX models optimized for Apple Silicon
2. Models download automatically from HuggingFace on first use
3. View download progress in Settings (shows file count: "Downloading 3/7 files")

Note: MLX models consist of multiple files from HuggingFace. Progress is tracked by file count rather than bytes because HuggingFace Hub reports per-file progress separately.

Model and provider changes trigger cache clearing in `ClipboardManager`.

## Async Tag Extraction

Tags are extracted via a separate LLM query that runs independently of the main custom prompt:

- **Controlled by**: `LLMSettings.detectTags` toggle (default: enabled)
- **Prompt**: Hardcoded tag extraction prompt (not user-configurable)
- **Limit**: Maximum 5 tags per item (enforced in parsing, even if model returns more)
- **Execution**: Fires as a separate async Task, can complete before or after main prompt
- **State tracking**: `ClipboardItem.llmTagsProcessing` tracks tag query progress

This allows the main prompt result to be displayed immediately while tags are still being extracted.

## Development

### Debug Test Data
In Debug builds (when building from Xcode), sample clipboard items are automatically loaded on launch. This includes various content types: plain text, URLs, code snippets, JSON, SQL, and emoji. The test data is controlled by `#if DEBUG` in `ClipboardManager.loadTestData()` and is stripped from Release builds.

## Automatic Updates (Sparkle)

The app uses [Sparkle](https://github.com/sparkle-project/Sparkle) framework for automatic updates:

| Component | Role |
|-----------|------|
| `UpdateService` | Singleton managing `SPUStandardUpdaterController` |
| `CheckForUpdatesView` | SwiftUI button for menu bar "Check for Updates…" command |
| `appcast.xml` | Update feed hosted on GitHub (raw.githubusercontent.com) |

### Update Flow
```
App Launch ──▶ UpdateService.init() ──▶ SPUStandardUpdaterController
                                              │
                                              ▼ (if automatic checks enabled)
                                        Fetch appcast.xml
                                              │
                                              ▼ (if new version available)
                                        Show update dialog
                                              │
                                              ▼ (user clicks Install)
                                        Download, verify EdDSA signature, install
```

### Releasing Updates
1. Build release DMG
2. Sign with `./build/DerivedData/SourcePackages/checkouts/Sparkle/bin/sign_update Clipsa.dmg`
3. Update `appcast.xml` with new version, signature, and download URL
4. Create GitHub Release, attach DMG

## Dependencies

- **Xcode 26+** / **macOS Tahoe (26)+** - Required for Liquid Glass APIs
- **Apple Silicon** - Required for MLX provider
- **Ollama** running locally (optional, for Ollama provider, default model: `qwen2.5:1.5b`)
- **[ollama-swift](https://github.com/mattt/ollama-swift)** - Swift client library for Ollama API
- **[mlx-swift](https://github.com/ml-explore/mlx-swift)** - MLX for Apple Silicon (v0.29.1+)
- **[swift-transformers](https://github.com/huggingface/swift-transformers)** - HuggingFace Hub API (v1.1.0+)
- **[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)** - Configurable global keyboard shortcuts with SwiftUI recorder
- **[Sparkle](https://github.com/sparkle-project/Sparkle)** (v2.x) - Automatic app updates with EdDSA signing
- SwiftUI + AppKit (macOS only)

---
*Update this file when architecture changes.*
