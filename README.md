# Clipsa

A modern macOS clipboard manager with AI-powered content analysis. Built with SwiftUI and macOS Tahoe's Liquid Glass design.

![macOS](https://img.shields.io/badge/macOS-Tahoe%2026+-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Clipboard History** — Automatically tracks text, images, and files copied to your clipboard
- **AI Content Analysis** — Analyze clipboard content using local LLMs (Ollama or MLX)
- **Smart Tagging** — Auto-extract tags and categories from your clipboard content
- **Instant Paste** — Quickly paste any item from history with keyboard shortcuts
- **Global Hotkey** — Access Clipsa from anywhere with a configurable shortcut
- **Privacy First** — All data stays on your Mac; no cloud required

## Requirements

- **macOS Tahoe (26+)** — Required for Liquid Glass APIs
- **Apple Silicon (M1/M2/M3/M4)** — Required for MLX provider
- **Ollama** *(optional)* — For Ollama LLM provider (runs on localhost:11434)

## Installation

### Download

Download the latest release from [GitHub Releases](https://github.com/rudskoy/clipsa/releases).

1. Open the DMG file
2. Drag Clipsa to your Applications folder
3. Launch Clipsa
4. Grant Accessibility permission when prompted (required for paste functionality)

### Build from Source

```bash
# Clone the repository
git clone https://github.com/rudskoy/clipsa.git
cd clipsa

# Open in Xcode
open Clipsa.xcodeproj

# Build and run (Cmd+R)
```

**Requirements:** Xcode 26+ with macOS Tahoe SDK

## Usage

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+\` | Toggle Clipsa window (configurable) |
| `Enter` | Paste selected item (stays on clipboard) |
| `Shift+Enter` | Immediate paste (restores original clipboard) |
| `↑/↓` | Navigate clipboard history |
| `Cmd+,` | Open Settings |

### LLM Providers

Clipsa supports two AI providers for content analysis:

**Ollama** (Server-based)
- Install [Ollama](https://ollama.ai) and run it locally
- Select any installed model in Settings

**MLX** (On-device, Apple Silicon only)
- Models auto-download from HuggingFace on first use
- Runs entirely on your Mac's Neural Engine

### Settings

Access Settings via `Cmd+,` or the menu bar icon to configure:
- LLM provider and model selection
- Custom analysis prompts
- Auto-processing behavior
- Global keyboard shortcut
- Appearance (Light/Dark/System)

## Privacy

Clipsa is designed with privacy in mind:
- All clipboard data stays on your Mac
- LLM processing is 100% local (no API calls)
- No telemetry or analytics
- No account required

## License

MIT License — see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please open an issue or pull request on GitHub.

