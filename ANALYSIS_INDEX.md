# Clipsa Codebase Analysis - Index

This directory contains comprehensive documentation of the Clipsa architecture and codebase structure.

## Documentation Files

### 1. CODEBASE_ANALYSIS.md (Primary Analysis - 604 lines)
**Comprehensive technical analysis** covering:
- Project organization & file structure
- Build system & all dependencies
- Core architecture patterns
- Key services in detail
- Data flow diagrams
- Implementation patterns
- Critical details
- Known issues & TODOs
- File statistics

**Use this for**: Understanding the full architecture, dependencies, and design patterns

### 2. ARCHITECTURE.md (Design Documentation)
**Design-focused documentation** covering:
- High-level structure overview
- Data flow diagrams
- LLM provider architecture
- Key components & roles
- Global shortcut & paste flow
- UI design system
- Model management
- Development guidelines

**Use this for**: Understanding design decisions and architecture patterns

### 3. CLAUDE.md (AI Assistant Guidelines)
**Project-specific guidance** for Claude Code including:
- Project overview
- Build & test commands
- System requirements
- Architecture essentials
- Key implementation patterns
- File organization
- Dependencies
- Important constraints

**Use this for**: AI-assisted development and understanding project constraints

---

## Quick Navigation

### Understanding the Architecture

**Start here:** CODEBASE_ANALYSIS.md § 3 (Architecture & Key Components)

**Key concepts:**
- Data flow: NSPasteboard (0.5s poll) → ClipboardManager → LLMService → Providers
- Dual async queries: Main prompt + Tag extraction (concurrent)
- Provider system: Ollama (server) or MLX (on-device)

### Finding Code

**Main Services:**
- `Clipsa/Services/ClipboardManager.swift` - State management & orchestration
- `Clipsa/Services/LLMService.swift` - Provider management
- `Clipsa/Services/OllamaProvider.swift` - Ollama integration
- `Clipsa/Services/MLXService.swift` - MLX model management
- `Clipsa/Services/MLXProvider.swift` - On-device inference

**Models:**
- `Clipsa/Models/ClipboardItem.swift` - Core data structure
- `Clipsa/Models/LLMSettings.swift` - Settings management
- `Clipsa/Models/LMModel.swift` - MLX model config

**Views:**
- `Clipsa/Views/ContentView.swift` - Main UI layout
- `Clipsa/Views/PreviewPane.swift` - Detail view
- `Clipsa/Views/SettingsView.swift` - Settings UI

### Understanding Features

**Clipboard Management:**
- CODEBASE_ANALYSIS.md § 7 (Clipboard Polling Loop)
- ClipboardManager.swift (checkClipboard, addItem methods)

**LLM Processing:**
- CODEBASE_ANALYSIS.md § 7 (LLM Processing Flow)
- ClipboardManager.swift (processItemWithLLM)
- LLMService.swift (processContent method)

**Paste Workflows:**
- CODEBASE_ANALYSIS.md § 7 (Paste Workflow)
- PasteService.swift (pasteAndReturn methods)

**Keyboard Handling:**
- CODEBASE_ANALYSIS.md § 6 (Keyboard Handling)
- ContentView.swift (setupKeyboardMonitor)
- ClipsaApp.swift (AppDelegate.setupGlobalShortcut)

### Understanding Testing

**Test Location:** `ClipsaTests/`

**Test Files:**
1. OllamaProviderTests.swift - Ollama integration (requires Ollama running)
2. LLMServiceTests.swift - Service tests
3. LLMSettingsTests.swift - Settings tests

**Run tests:**
```bash
xcodebuild test -project Clipsa.xcodeproj -scheme Clipsa
```

### Understanding Dependencies

**See CODEBASE_ANALYSIS.md § 2 (Build System & Dependencies)**

**Core LLM packages:**
- ollama-swift (1.8.0) - Ollama API
- mlx-swift (0.29.1) - MLX framework
- swift-transformers (1.1.6) - HuggingFace integration

**All dependencies:**
- Resolved in: `Clipsa.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

### Understanding Security

**Permissions:**
- CODEBASE_ANALYSIS.md § 9 (Security & Permissions)
- Accessibility permission (required for Cmd+V)
- Checked lazily, not on launch

**Data Privacy:**
- In-memory clipboard history (100 items max)
- UserDefaults for settings (local only)
- No cloud data transmission

---

## Key Information at a Glance

### Project Stats
- 19 Swift files (main app)
- 3 test files
- 2,000+ lines of code
- 10 SPM packages
- 1 initial commit (4de6f4b)

### Core Architecture
```
NSPasteboard
    ↓
ClipboardManager (@MainActor)
    ├─ Polling (0.5s)
    ├─ Type detection
    └─ LLM orchestration
        ↓
    LLMService (@MainActor)
        ├─ Provider switching
        └─ Result caching
            ↓
        ├─ OllamaProvider (actor)    [Server-based]
        └─ MLXProvider (@MainActor)   [On-device]
```

### LLM Providers
| Provider | Type | Default Model | Auto-Detect |
|----------|------|---------------|-------------|
| Ollama | Server | qwen2.5:1.5b | Intel Mac |
| MLX | On-device | qwen2.5:1.5b | Apple Silicon |

### State Management
- **@MainActor**: ClipboardManager, LLMService, MLXProvider
- **@Observable**: MLXService
- **@Published**: LLMSettings properties
- **@StateObject**: ClipsaApp's ClipboardManager
- **Actors**: OllamaProvider (thread-safe)

### Key Classes
1. **ClipboardManager** - State & polling (300+ lines)
2. **LLMService** - Provider management (200+ lines)
3. **OllamaProvider** - Ollama integration (100+ lines)
4. **MLXService** - Model management
5. **MLXProvider** - On-device inference
6. **PasteService** - Paste workflows
7. **LLMSettings** - Settings persistence (154 lines)
8. **ClipboardItem** - Data model (206 lines)

### Important Enums
- **ClipboardType**: text, image, file, other
- **LLMProviderType**: ollama, mlx
- **LLMRequestType**: summarize, extractTags, classify, custom

---

## Development Workflow

### Building
```bash
open Clipsa.xcodeproj                                    # Open in Xcode
xcodebuild -project Clipsa.xcodeproj -scheme Clipsa -configuration Debug build
```

### Testing
```bash
xcodebuild test -project Clipsa.xcodeproj -scheme Clipsa
```

### Configuration Files
- `Clipsa.xcodeproj/project.pbxproj` - Project configuration
- `Clipsa.xcodeproj/project.xcworkspace/` - Workspace
- `Clipsa/Clipsa.entitlements` - App entitlements (no sandbox)
- `Clipsa/Info.plist` - Bundle configuration

---

## Known Issues & Limitations

### VLM Support Disabled
- Issue: MLXVLM.Message conflicts with Ollama.Message
- Status: Unresolved
- Impact: No image analysis via MLX
- Files: LMModel.swift, MLXService.swift

### Git Status
- Only 1 initial commit
- Multiple uncommitted changes (19 files)
- Suggests active refactoring
- Multiple duplicate files need cleanup

---

## Performance Characteristics

### Polling
- **Frequency**: 0.5 seconds (NSPasteboard check)
- **Detection**: Change count comparison
- **Duplicates**: Last item content check

### LLM Processing
- **Concurrency**: Main prompt + tag extraction run concurrently
- **Non-blocking**: Fire-and-forget Tasks
- **Caching**: Content hash-based (max 100 results)
- **Throttling**: None (process all clipboard changes)

### Memory
- **History**: 100 items max
- **Model cache**: NSCache (unlimited size)
- **Result cache**: 100 LLM results per session

---

## File Size Reference

| File | Lines | Purpose |
|------|-------|---------|
| ClipboardManager.swift | 300+ | State & orchestration |
| LLMService.swift | 200+ | Provider management |
| OllamaProvider.swift | 100+ | Ollama integration |
| ClipboardItem.swift | 206 | Data model |
| LLMSettings.swift | 154 | Settings |
| ClipsaApp.swift | 100 | Entry point |
| ContentView.swift | 100+ | Main UI |
| MLXService.swift | 80+ | Model loading |

---

## Related Documentation

- **ARCHITECTURE.md** - Design patterns & decisions
- **CLAUDE.md** - AI assistant guidelines
- **README files** - In scripts/ and junk/ directories

---

## Analysis Metadata

- **Created**: 2025-12-23
- **Codebase Snapshot**: main branch, 4de6f4b Initial Commit
- **Analysis Depth**: Comprehensive (all files examined)
- **Status**: Feature-complete, active development

---

## How to Use This Documentation

1. **New to the project?** → Start with ARCHITECTURE.md then CODEBASE_ANALYSIS.md
2. **Need to understand a service?** → Find it in CODEBASE_ANALYSIS.md § 3
3. **Want to modify functionality?** → Check CODEBASE_ANALYSIS.md § 7 (Implementation Details)
4. **Need to add tests?** → Reference ClipsaTests/ and CODEBASE_ANALYSIS.md § 5
5. **Want to understand build system?** → See CODEBASE_ANALYSIS.md § 2

---

For detailed technical information, see **CODEBASE_ANALYSIS.md** (primary reference).
