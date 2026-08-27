# CLAUDE.md — mail-analyzer-gui

Organization rules: https://github.com/nlink-jp/.github/blob/main/CONVENTIONS.md
Workspace rules also apply (see the parent `nlink-jp/CLAUDE.md`).

## What this is

Native macOS drag-and-drop GUI for the mail-analyzer CLI (suspicious email
analysis). Swift/SwiftUI + SwiftPM + Make — no Xcode project.
**Apple Silicon, macOS 14+.** v0.3.0 replaced the Tauri v2 implementation;
see `docs/en/adr/0001-native-swift-rewrite.md` and AGENTS.md.

## Project rules

- **MailAnalyzerGUICore stays UI-free** — no `import AppKit` in Core; logic
  is pure, injected, and unit-tested.
- **No PATH auto-detection for the analyzer binary** (anti-binary-injection;
  RFP decision). The explicit path in Settings is the only source.
- **Analyzer error strings are contract text** and stay English; GUI chrome
  is localized through `L()` with enforced en/ja key parity.
- `make build`, never bare `swift build`; artifacts live in `.build/` and
  `dist/`.
- `--version` must keep answering on stdout without launching the UI.
