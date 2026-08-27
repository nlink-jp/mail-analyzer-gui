# AGENTS.md — mail-analyzer-gui

## What it is

Native macOS desktop GUI for the mail-analyzer CLI: drop `.eml` / `.msg`
files (from Finder or straight out of Apple Mail), get a structured
suspicious-email verdict per message. Swift (SwiftUI + one AppKit drop
view), SwiftPM + Make, no Xcode project. **Apple Silicon, macOS 14+.**

**Status**: v0.3.0 is a ground-up Swift rewrite of the Tauri v2 + Svelte +
ObjC implementation (≤ v0.2.2). Decision record:
`docs/en/adr/0001-native-swift-rewrite.md`. The original product RFP in
`docs/{en,ja}/design/` still describes the feature set.

## Build / test / run

```sh
make build          # swift build -c release (artifacts in .build/, dist/)
make build-app      # assemble + codesign dist/MailAnalyzerGUI.app
make package        # build-app, notarize + staple, ditto-zip for release
make verify-release # gate: .notarized marker + stapler validate + zip exists
make test           # swift test (Core + GUI targets)
make run            # swift run (debug, no bundle — L10n falls back to en)
```

## Layout

```
mail-analyzer-gui/
├── Package.swift                     # 2 targets + 2 test targets
├── Info.plist                        # template; sed'd by make build-app
├── Sources/MailAnalyzerGUICore/      # pure logic — no AppKit imports allowed
│   ├── AnalysisResult.swift          # analyzer JSON schema (Codable, null-tolerant arrays)
│   ├── AnalyzerInvocation.swift      # subprocess contract: validation/env/interpretation
│   ├── ProcessRunner.swift           # async Process + timeout (the one impure Core file)
│   ├── AnalyzerSettings.swift        # UserDefaults persistence
│   ├── EnvTemplates.swift            # Vertex AI / Local LLM template definitions
│   ├── DropFilter.swift              # .eml/.msg whitelist
│   ├── PromiseDropSession.swift      # pure promise-drop state machine (injected clock)
│   └── LegacyImport.swift            # one-time Tauri-store migration
├── Sources/MailAnalyzerGUI/          # SwiftUI executable
│   ├── App.swift                     # @main, --version intercept, WindowGroup
│   ├── AppModel.swift                # state + sequential analysis queue
│   ├── ContentView.swift             # toolbar, drop-zone visual, notices
│   ├── ResultListView.swift          # expandable rows
│   ├── ResultDetailView.swift        # judgment + indicators
│   ├── SettingsView.swift            # binary path + env editor sheet
│   ├── DropView.swift                # AppKit drop target (file URLs + promises)
│   ├── PromiseDropController.swift   # per-drop temp dirs, poll loop, teardown
│   ├── L10n.swift / ResourceBundle.swift
│   └── Resources/{en,ja}.lproj/Localizable.strings
├── Tests/MailAnalyzerGUICoreTests/   # incl. testdata/ JSON fixtures
├── Tests/MailAnalyzerGUITests/
├── scripts/                          # vendored codesign/notarize/icns/brew (org templates)
└── docs/{en,ja}/                     # RFP (design of record) + adr/
```

## Project rules

- **MailAnalyzerGUICore stays UI-free.** No `import AppKit` in Core; all
  decision logic is pure and unit-tested (the promise-drop reducer takes an
  injected clock — keep it that way).
- **No PATH auto-detection for the analyzer binary.** The user sets an
  explicit path; nothing else is searched (anti-binary-injection, from the
  original RFP). Do not add "helpful" fallbacks.
- **Analyzer error strings are contract text** (mirrored from the legacy
  Rust implementation) and stay English; only GUI chrome is localized.
  Every GUI string goes through `L()` — tests enforce en/ja key parity.
- **`make build`, never bare `swift build`** outputs into the repo root;
  artifacts belong in `.build/` and `dist/`.
- **`--version` must keep answering on stdout without launching the UI**
  (`brew test` depends on it), including via the cask's bin symlink.
- Temp-file deletion stays guarded to the drop temp base
  (`$TMPDIR/mail-analyzer-gui-drop/`) — never delete outside it.

## Subprocess contract (mail-analyzer / mail-analyzer-local)

- Invocation: `<binary_path> <file>` — exactly one positional argument, no
  flags; JSON on stdout is the analyzer's default output.
- Environment: parent env inherited; configured vars applied only when
  non-empty (empty value = leave unset, never override-with-empty).
- Timeout: 300 s, then SIGTERM → 5 s → SIGKILL (`ProcessRunner`).
- Schema: see `AnalysisResult.swift`. Six array fields arrive as JSON
  `null` from the Go analyzer (`to`, `urls`, `attachments`,
  `suspicious_hops`, `reasons`, `tags`) and must decode as `[]`; the keys
  that were required in the legacy decoder stay required so garbage JSON
  fails loudly instead of rendering as a "safe" result.

## Gotchas

- **Apple Mail's promise reader block often never fires** (platform bug).
  `PromiseDropController` therefore polls the per-drop temp directory and
  decides completion by size quiescence + a quiet window
  (`PromiseDropSession`); the receiver count is only a hint — Mail reports
  one receiver with empty `fileNames` for multi-message drags. Every drop
  ends in a visible outcome; zero files at the 15 s deadline is a failure
  notice, never silence (the ≤ v0.2.2 implementation hung silently).
- **`Bundle.module` traps inside the hand-assembled .app** — resources are
  found via `ResourceBundleLocator` (`MailAnalyzerGUI_MailAnalyzerGUI.bundle`
  lives in `Contents/Resources`). Never reintroduce `Bundle.module`.
- The effective drop target is the **whole window** (the dashed box is
  decorative) — deliberate, inherited from the legacy app. The AppKit
  `DropView` sits as the SwiftUI root's `.background`; NSHostingView
  content registers no drag types, so window-wide drags route to it.
- Settings live in **UserDefaults** (`analyzer.binaryPath`,
  `analyzer.envVars`); v0.2.x Tauri-store settings are imported once at
  launch (`LegacyImport`, flag `migration.importedTauriSettings`), never
  clobbering user-created settings. Env values (API keys included) are
  plain text, as before — Keychain is recorded future work (ADR-0001).
- Analyses run **strictly sequentially** (FIFO across drop batches) — the
  backends are LLM calls; parallel invocations were never supported.
- The parse-error excerpt truncates with `String.prefix(500)` — the legacy
  Rust byte-slice panicked on multibyte output; keep truncation
  Character-safe.
- No entitlements file: pure SwiftUI needs no WebView JIT entitlements
  (those died with Tauri). Hardened Runtime only, non-sandboxed.
- macOS releases are Developer ID signed + notarized + stapled; the
  release artifact is a ditto-zipped `.app` (no .dmg), gated by
  `make verify-release`.
