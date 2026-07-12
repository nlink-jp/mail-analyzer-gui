# mail-analyzer-gui

A macOS desktop application for analyzing suspicious emails via [mail-analyzer](https://github.com/nlink-jp/mail-analyzer) or [mail-analyzer-local](https://github.com/nlink-jp/mail-analyzer-local).

Drag & drop `.eml` or `.msg` files from Finder or Apple Mail to get instant analysis results with rule-based indicators and LLM-powered judgment.

## Features

- **Drag & Drop** — Drop `.eml`/`.msg` files from Finder or directly from Apple Mail
- **Dual Backend** — Works with mail-analyzer (Vertex AI) or mail-analyzer-local (local LLM via LM Studio/Ollama)
- **Template Presets** — One-click settings for Vertex AI or Local LLM configuration
- **Visual Results** — Judgment (category, confidence, reasons) displayed prominently; indicators expandable
- **Generic Settings** — Configure any analyzer binary and arbitrary environment variables
- **JSON Export** — Copy analysis results to clipboard as JSON
- **Window State** — Remembers window position and size across sessions
- **Auto Cleanup** — Temporary files from Apple Mail drops are deleted after analysis

## Requirements

- macOS 10.15+ (Catalina or later)
- One of the following analyzer backends:
  - [mail-analyzer](https://github.com/nlink-jp/mail-analyzer) (requires GCP/Vertex AI)
  - [mail-analyzer-local](https://github.com/nlink-jp/mail-analyzer-local) (requires local LLM server)

## Installation

Download the `.zip` from [Releases](https://github.com/nlink-jp/mail-analyzer-gui/releases), unzip it, and drag `mail-analyzer-gui.app` to Applications. The `.app` is **Developer ID signed and Apple-notarized** (stapled), so it launches without Gatekeeper prompts and works offline.

## Setup

1. Launch the app
2. Click **Settings**
3. Set **Analyzer binary path** (e.g. `/usr/local/bin/mail-analyzer-local`)
4. Click a **template button** to populate environment variables:
   - **mail-analyzer (Vertex AI)** — for cloud-based analysis
   - **mail-analyzer-local (Local LLM)** — for offline analysis
5. Fill in the values and click **Save**

## Usage

1. Drag `.eml` or `.msg` files onto the drop zone
2. Wait for analysis (spinner shows progress)
3. Click a result row to expand/collapse details
4. Use **Export JSON** to copy results to clipboard
5. Use **Clear** to remove all results

## Tech Stack

- [Tauri v2](https://tauri.app/) (Rust + WebView)
- [SvelteKit](https://svelte.dev/) + TypeScript (frontend)
- Native Objective-C helper for Apple Mail file-promise handling

## Build

```bash
npm install
npm run tauri build
```

Output: `src-tauri/target/release/bundle/macos/mail-analyzer-gui.app`

## Known Limitations

- Apple Mail drag & drop currently supports single-message drops only. Multi-message drops are under investigation.
- The app is macOS only.

## License

MIT
