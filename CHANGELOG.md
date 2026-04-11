# Changelog

## v0.2.0 (2026-04-11)

### Features

- Settings: generic key-value environment variables (replaces hardcoded Vertex AI fields)
- Settings: template buttons for mail-analyzer (Vertex AI) and mail-analyzer-local (Local LLM)
- Support mail-analyzer-local as backend — local LLM email analysis via GUI
- Auto-cleanup of Apple Mail temp files after analysis

## v0.1.1 (2026-04-11)

### Fixes

- Suppress build warnings in ObjC helper and Rust native drop module

### Docs

- Add MIT license
- Add bilingual documentation (docs/en, docs/ja) for architecture and RFP

## v0.1.0 (2026-04-11)

Initial release.

### Features

- Drag & drop `.eml`/`.msg` files from Finder
- Drag & drop single email from Apple Mail (via native file-promise handler)
- Analysis results with judgment display (category, confidence, reasons, tags)
- Expandable indicator details (authentication, sender, URLs, attachments, routing)
- Multiple panels can be expanded simultaneously
- Settings: mail-analyzer binary path and environment variables
- JSON export to clipboard
- Clear button to remove all results
- Window position and size persistence across sessions
- macOS `.app` bundle and `.dmg` distribution

### Known Limitations

- Apple Mail multi-message drag & drop not yet supported
- macOS only
