# Clipsa Architecture

> macOS clipboard manager with AI-powered content analysis (Ollama)

## Structure

```
Clipsa/
├── ClipsaApp.swift              # Entry point, window config, MenuBarExtra
├── Models/
│   ├── ClipboardItem.swift      # Clipboard entry (content, type, LLM fields)
│   └── LLMSettings.swift        # AI settings: model selection, prompt (UserDefaults)
├── Services/
│   ├── ClipboardManager.swift   # State manager, clipboard polling, LLM trigger
│   ├── PasteService.swift       # Paste actions: regular (modifies clipboard) & immediate (preserves clipboard)
│   ├── AccessibilityService.swift # Accessibility permission handling (required for CGEvent)
│   ├── LLMService.swift         # LLM orchestration, caching, provider management
│   └── OllamaProvider.swift     # Ollama via ollama-swift library
├── Views/
│   ├── ContentView.swift        # NavigationSplitView with Liquid Glass sidebar
│   ├── ClipboardRow.swift       # List items with hover effects
│   ├── PreviewPane.swift        # Detail panel with AI response + mascot states
│   ├── SearchBar.swift          # Search input
│   └── SettingsView.swift       # AI model selector + prompt editor
└── Utilities/
    └── Styling.swift            # Colors, fonts, shared components

ClipsaTests/
├── OllamaProviderTests.swift    # Integration tests for OllamaProvider
├── LLMServiceTests.swift        # Integration tests for LLMService
└── LLMSettingsTests.swift       # Tests for LLMSettings
```

## Data Flow

```
NSPasteboard ──(0.5s poll)──▶ ClipboardManager ──▶ items[]
                                    │
                                    ▼ (if autoProcess)
                              OllamaProvider ──▶ LLMResult ──▶ update item
```

## Key Components

| Component | Role |
|-----------|------|
| `ClipboardManager` | `@StateObject` - owns items[], search, LLM toggle |
| `ClipboardItem` | Struct with content + LLM fields (summary, tags, type) |
| `PasteService` | Singleton for paste workflows (regular & immediate) |
| `AccessibilityService` | Singleton for Accessibility permission (required since macOS 10.14) |
| `LLMService` | Manages providers, caches results by content hash |
| `LLMSettings` | Singleton storing selected model & custom prompt |
| `OllamaProvider` | Actor for Ollama API: generate, list/pull models |
| `OllamaModel` | Model metadata struct (name, size, modifiedAt) |

## Global Shortcut & Paste Flow

### Global Shortcut (Cmd+Shift+\\)
Uses [HotKey](https://github.com/soffes/HotKey) library (Carbon APIs) for reliable global hotkey:
- Registered in `AppDelegate.setupGlobalShortcut()`
- Saves previous app, then activates Clipsa window

### Paste Actions

Two paste modes are available:

| Action | Shortcut | Method | Behavior |
|--------|----------|--------|----------|
| **Paste** | Enter | `pasteAndReturn()` | Copies to clipboard, pastes to previous app. Item stays on clipboard. |
| **Immediate Paste** | Shift+Enter | `immediatePasteAndReturn()` | Copies to clipboard, pastes, then restores original clipboard. |

#### Regular Paste (Enter)
```
User presses Enter ──▶ PasteService.pasteAndReturn()
                              │
                              ├──▶ Copy to NSPasteboard
                              ├──▶ Hide Clipsa
                              ├──▶ Activate previous app
                              └──▶ Simulate Cmd+V (CGEvent)
```

#### Immediate Paste (Shift+Enter)
```
User presses Shift+Enter ──▶ PasteService.immediatePasteAndReturn()
                                    │
                                    ├──▶ Save current clipboard
                                    ├──▶ Copy new content to NSPasteboard
                                    ├──▶ Hide Clipsa
                                    ├──▶ Activate previous app
                                    ├──▶ Simulate Cmd+V (CGEvent)
                                    └──▶ Restore original clipboard (after 200ms)
```

### Accessibility Permission
Required since macOS 10.14 Mojave for `CGEvent` keyboard simulation.
- Checked on app launch via `AccessibilityService.isAccessibilityEnabled(prompt: true)`
- If not granted, shows alert with button to open System Settings

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

### Otter Mascot
- `OtterMascot` view - Reusable mascot component with optional animation
- Used in: Empty states, AI processing indicator

### Components
- `HoverScaleModifier` - Interactive hover animations
- `GlowEffect` - Accent glow for selected/active states

### Colors
- Semantic colors (`.primary`, `.secondary`, `.tertiary`)
- Liquid Glass-compatible colors
- Gradient accents for LLM/AI features

## Model Management

Settings allow users to:
1. Select from locally installed Ollama models
2. Download new models by name (via `OllamaProvider.pullModel`)
3. View download progress in real-time

Model changes trigger cache clearing in `ClipboardManager`.

## Dependencies

- **Xcode 26+** / **macOS Tahoe (26)+** - Required for Liquid Glass APIs
- **Ollama** running locally (model configurable in Settings, default: `qwen2.5:1.5b`)
- **[ollama-swift](https://github.com/mattt/ollama-swift)** - Swift client library for Ollama API
- **[HotKey](https://github.com/soffes/HotKey)** - Global keyboard shortcuts via Carbon APIs
- SwiftUI + AppKit (macOS only)

---
*Update this file when architecture changes.*
