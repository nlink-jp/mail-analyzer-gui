# mail-analyzer-gui

A macOS desktop application for analyzing suspicious emails via [mail-analyzer](https://github.com/nlink-jp/mail-analyzer).

Drag & drop `.eml` or `.msg` files from Finder or Apple Mail to get instant analysis results with rule-based indicators and LLM-powered judgment.

## Features

- **Drag & Drop** — Drop `.eml`/`.msg` files from Finder or directly from Apple Mail
- **Visual Results** — Judgment (category, confidence, reasons) displayed prominently; indicators expandable
- **Settings** — Configure mail-analyzer binary path and environment variables (GCP project, model, language)
- **JSON Export** — Copy analysis results to clipboard as JSON
- **Window State** — Remembers window position and size across sessions

## Requirements

- macOS 10.15+ (Catalina or later)
- [mail-analyzer](https://github.com/nlink-jp/mail-analyzer) binary installed
- GCP credentials for Vertex AI (used by mail-analyzer for LLM analysis)

## Installation

Download the `.dmg` from [Releases](https://github.com/nlink-jp/mail-analyzer-gui/releases) and drag `mail-analyzer-gui.app` to Applications.

> **Note:** The app is not signed with an Apple Developer certificate. On first launch, you may need to allow it via System Settings > Privacy & Security, or run:
> ```
> xattr -d com.apple.quarantine /Applications/mail-analyzer-gui.app
> ```

## Setup

1. Launch the app
2. Click **Settings**
3. Set **mail-analyzer binary path** (e.g. `/usr/local/bin/mail-analyzer`)
4. Set **MAIL_ANALYZER_PROJECT** to your GCP project ID
5. Adjust other environment variables as needed
6. Click **Save**

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
