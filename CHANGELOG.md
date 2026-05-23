# Changelog

## v0.2.1 (2026-05-23)

### Changed

- **macOS builds are Developer ID signed and Apple-notarized.**
  Replaces Tauri's default ad-hoc signature with a full Apple
  Developer ID Application signature on the `.app` bundle (Hardened
  Runtime + Apple secure timestamp + minimal WebKit JIT entitlements),
  applied during `tauri build` by setting `APPLE_SIGNING_IDENTITY`
  and pointing `bundle.macOS.entitlements` at
  `scripts/entitlements.plist`. `make package` then submits the
  `.dmg` to Apple's notary service and staples the ticket onto the
  disk image so offline first-launch works without a Gatekeeper
  verification dialog. End users on macOS no longer need the
  `xattr -d com.apple.quarantine` workaround documented in v0.2.0's
  README. Local users who place `mail-analyzer-gui.app` under
  Dropbox / iCloud / OneDrive-synced paths are no longer killed by
  macOS's ad-hoc + `com.apple.provenance` distrust policy.
- Adds a `Makefile` at the project root that wraps Tauri's npm
  scripts with the codesign / notarize / staple steps, following the
  org-wide convention in `nlink-jp/.github` CONVENTIONS.md §Code
  Signing → Wails / GUI apps (the same `.app` / `.dmg` pipeline
  applies to Tauri).

No behaviour change to the app itself — feature-wise this is
identical to v0.2.0.

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
