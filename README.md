# mail-analyzer-gui

A native macOS desktop application for analyzing suspicious emails via
[mail-analyzer](https://github.com/nlink-jp/mail-analyzer) or
[mail-analyzer-local](https://github.com/nlink-jp/mail-analyzer-local).

Drag & drop `.eml` or `.msg` files from Finder or Apple Mail to get instant
analysis results with rule-based indicators and LLM-powered judgment.

## Features

- **Drag & Drop** — Drop `.eml`/`.msg` files from Finder or directly from Apple Mail (multi-message drops supported)
- **Dual Backend** — Works with mail-analyzer (Vertex AI) or mail-analyzer-local (local LLM via LM Studio/Ollama)
- **Template Presets** — One-click settings for Vertex AI or Local LLM configuration
- **Visual Results** — Judgment (category, confidence, reasons) displayed prominently; indicators expandable per row
- **Generic Settings** — Configure any analyzer binary and arbitrary environment variables
- **JSON Export** — Copy analysis results to clipboard as JSON
- **Analysis Timeout** — A hung backend is terminated after 300 s instead of spinning forever
- **Auto Cleanup** — Temporary files from Apple Mail drops are deleted after analysis
- **English / Japanese UI**

## Requirements

- macOS 14+ (Sonoma), Apple Silicon
- One of the following analyzer backends:
  - [mail-analyzer](https://github.com/nlink-jp/mail-analyzer) (requires GCP/Vertex AI)
  - [mail-analyzer-local](https://github.com/nlink-jp/mail-analyzer-local) (requires local LLM server)

## Installation

```bash
brew install --cask nlink-jp/tap/mail-analyzer-gui
```

Or download the `.zip` from
[Releases](https://github.com/nlink-jp/mail-analyzer-gui/releases), unzip
it, and drag `MailAnalyzerGUI.app` to Applications. The `.app` is
**Developer ID signed and Apple-notarized** (stapled), so it launches
without Gatekeeper prompts and works offline.

**Upgrading from v0.2.x (Tauri)**: settings (binary path and environment
variables) are imported automatically on first launch. The app bundle is
named `MailAnalyzerGUI.app` now — remove the old `mail-analyzer-gui.app`
manually if you installed it without Homebrew.

## Setup

1. Launch the app
2. Click **Settings**
3. Set **Analyzer binary path** (e.g. `/usr/local/bin/mail-analyzer-local`)
4. Click a **template button** to populate environment variables:
   - **mail-analyzer (Vertex AI)** — for cloud-based analysis
   - **mail-analyzer-local (Local LLM)** — for offline analysis
5. Fill in the values and click **Save**

## Usage

1. Drag `.eml` or `.msg` files anywhere onto the window
2. Wait for analysis (files are analyzed one at a time; a spinner shows progress)
3. Click a result row to expand/collapse details; **Show Indicators** reveals authentication, sender, URL, attachment and routing signals
4. Use **Export JSON** to copy results to clipboard
5. Use **Clear** to remove finished results (in-flight analyses stay)

## Tech Stack

- Swift (SwiftUI + one AppKit drop view), SwiftPM + Make — no Xcode project
- v0.2.x and earlier were Tauri v2 + Svelte + Objective-C; see
  `docs/en/adr/0001-native-swift-rewrite.md` for why that was replaced

## Build

```bash
make build-app   # signed dist/MailAnalyzerGUI.app
make test        # swift test
```

## Known Limitations

- Apple Mail multi-message drops are best-effort: macOS occasionally
  delivers fewer files than were dragged. When that happens the app shows a
  "Received N of M" warning instead of failing silently; re-drop the
  missing messages or save them as `.eml` in Finder first.
- The app is macOS only.

## License

MIT
