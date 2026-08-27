# Changelog

## v0.3.1 (2026-08-28)

### Fixed

- Result tags wrap across lines again instead of overflowing the window —
  the Swift rewrite dropped the legacy CSS `flex-wrap` behavior (found in
  post-release code review).
- A stale settings auto-close (save → cancel → reopen within the 600 ms
  "Settings saved." window) no longer dismisses the reopened sheet.

## v0.3.0 (2026-08-28)

### Changed

- **Ground-up rewrite as a native Swift app** (SwiftUI + one AppKit drop
  view, SwiftPM + Make), replacing the Tauri v2 + Svelte + Objective-C
  implementation. One language, one JSON-schema declaration, one process —
  the Rust↔ObjC↔JS event bridge, the runtime-generated ObjC class, the
  FSEventStream watcher and the npm/cargo toolchain are gone. Decision
  record: `docs/en/adr/0001-native-swift-rewrite.md`.
- **App bundle renamed** `mail-analyzer-gui.app` → `MailAnalyzerGUI.app`
  (house naming; bundle ID unchanged). Homebrew cask upgrades handle the
  rename; manual installs should delete the old `.app`.
- Settings moved from the Tauri store file to `UserDefaults`; existing
  v0.2.x settings (binary path + env vars) are **imported automatically
  once** at first launch. Window position/size now uses the standard macOS
  restoration machinery.
- Requires macOS 14+ (was 10.15+ nominally; releases were arm64-only
  already). WebView JIT entitlements removed — Hardened Runtime only.

### Added

- **Apple Mail multi-message drag & drop.** Promise drops resolve into a
  per-drop temp directory watched for size quiescence; the receiver count
  is treated as a hint, so multi-message drags deliver every file that
  lands. If macOS delivers fewer than dragged, a "Received N of M" warning
  is shown.
- **Analysis timeout** (300 s, SIGTERM → SIGKILL) — a hung LLM backend no
  longer leaves a row analyzing forever.
- Drop errors are shown in the UI (the legacy `drop-error` event was
  emitted but never displayed), including a loud failure when a promise
  drop produces no files (previously: permanent silence).
- Non-`.eml`/`.msg` drops surface a notice instead of vanishing silently.
- Japanese UI localization (en/ja; analyzer error messages stay English as
  contract text).

### Fixed

- Partial-write race: analysis no longer starts on files Apple Mail is
  still writing (size-stabilization window).
- Concurrent/repeated Mail drops no longer share one temp directory
  (per-drop UUID directories; no name collisions, no cross-drop
  misattribution; stale directories are swept at launch).
- Crash on multibyte analyzer output at the 500-char parse-error
  truncation point (byte slice → character-safe prefix).
- Window frames are no longer written to disk on every move/resize frame,
  and offscreen restores are handled by the system.
- Version number is single-sourced from git describe via Info.plist
  (was duplicated across package.json / tauri.conf.json / Cargo.toml).

## v0.2.2 (2026-07-12)

### Changed

- **Release archive is now a zipped `.app` instead of a `.dmg`**
  (`mail-analyzer-gui-vX.Y.Z-darwin-arm64.zip` containing the notarized,
  stapled `mail-analyzer-gui.app`), per `nlink-jp/.github` CONVENTIONS.md
  §Release Archive Standard. The build now uses `tauri build --bundles app`
  (no DMG); the `.app` is notarized + stapled via the shared
  `scripts/notarize-darwin-app.sh`, then archived with
  `ditto -c -k --keepParent`. mail-analyzer-gui remains **darwin/arm64 only**.

No change to the app's behaviour — a packaging / release-format change.

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
