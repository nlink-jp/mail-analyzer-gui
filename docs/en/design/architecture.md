# Architecture: mail-analyzer-gui

> Updated: 2026-08-28 (v0.3.0 — native Swift rewrite; the Tauri v2
> architecture this replaces is preserved in git history ≤ v0.2.2 and
> summarized in ADR-0001)

## Overview

mail-analyzer-gui is a native Swift macOS application (SwiftUI, with one
AppKit view for drag & drop). It invokes the mail-analyzer CLI binary as a
subprocess and displays analysis results in a GUI. Two SwiftPM targets:

- **MailAnalyzerGUICore** — pure, UI-free logic (no AppKit imports).
  Everything that decides is here, unit-tested with injected dependencies.
- **MailAnalyzerGUI** — the SwiftUI executable: views, the app model, and
  the impure halves (Process, FileManager, pasteboard, promise receivers).

## Component Diagram

```
┌────────────────────────────────────────────────────────────────┐
│  MailAnalyzerGUI.app (single process, single language)         │
│                                                                │
│  SwiftUI                    AppKit                             │
│  ┌───────────────────┐      ┌──────────────────────────┐       │
│  │ ContentView        │      │ DropView (root background)│      │
│  │  ├ DropZoneVisual  │◀────▶│  file URLs + file promises│      │
│  │  ├ ResultListView  │      └────────────┬─────────────┘       │
│  │  │  └ ResultDetail │                   │ promises            │
│  │  └ SettingsView    │      ┌────────────▼─────────────┐       │
│  └─────────┬─────────┘      │ PromiseDropController     │       │
│            │                │  per-drop UUID temp dir,  │       │
│  ┌─────────▼─────────┐      │  250ms poll → reducer     │       │
│  │ AppModel           │◀────┴──────────────────────────┘       │
│  │  sequential FIFO   │                                        │
│  │  analysis queue    │───▶ ProcessRunner ── subprocess ──▶ mail-analyzer(-local)
│  └───────────────────┘                                         │
│                                                                │
│  MailAnalyzerGUICore (pure):                                   │
│   AnalysisResult (Codable schema) · AnalyzerInvocation          │
│   PromiseDropSession (state machine) · DropFilter               │
│   AnalyzerSettings (UserDefaults) · EnvTemplates · LegacyImport │
└────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Finder drop (file URLs)

1. `DropView.performDragOperation` reads file URLs from the pasteboard.
2. `AppModel.handleDropped` filters through `DropFilter` (.eml/.msg,
   case-insensitive; rejections surface a notice), prepends entries
   (newest first) and queues them.
3. A single worker drains the FIFO queue strictly sequentially: validate
   binary path → `ProcessRunner.run` (300 s timeout) →
   `AnalyzerInvocation.interpret` → entry state `done`/`error`.

### Apple Mail drop (file promises)

Measured pasteboard reality (2026-08): a single-message Mail drag offers
both the modern promise (`NSFilePromiseReceiver`, empty `fileNames`) and
the pre-10.12 protocol (`com.apple.pasteboard.promised-file-url`); a
multi-message drag offers **only** the pre-10.12 protocol.

1. `DropView` routes promises legacy-first: the old protocol is resolved
   inside `performDragOperation` via `namesOfPromisedFilesDropped`
   (deprecated, deliberately kept — it is the only API Mail supports for
   multi-message drags and it returns the **exact** promised-name count).
   Modern receivers are the fallback for sources without the old protocol.
2. Either way the controller owns
   `$TMPDIR/mail-analyzer-gui-drop/<UUID>/r<i>/` and polls it every 250 ms
   into the pure `PromiseDropSession` reducer (the modern path also arms
   the reader callbacks — they often never fire for Mail; platform bug).
3. The reducer completes on: reader delivering the expected count; an
   **exact** count fully on disk and size-stable (~0.75 s — the fast
   path); an inexact hint size-stable + a 2 s quiet window; or a 15 s
   deadline that **always** yields an outcome (partial files with a
   warning, or a failure notice; never silence).
4. Delivered files enter the same `handleDropped` path with
   `promiseTemp: true`; after analysis each temp file is deleted (guarded
   to the temp base) and empty drop directories are pruned. Day-old
   leftovers are swept at launch.

### Subprocess contract

`<binary_path> <file>` — one positional argument, no flags. Parent env
inherited; configured env vars applied only when non-empty. stdout/stderr
fully drained before exit-wait (no pipe deadlock). Validation and error
message formats are legacy-verbatim contract text (English).

### Settings

`AnalyzerSettings` ⇄ `UserDefaults` (`analyzer.binaryPath`,
`analyzer.envVars`). `LegacyImport` migrates the v0.2.x Tauri store once
(flag `migration.importedTauriSettings`), never overwriting user-created
settings. No PATH auto-detection — anti-binary-injection (RFP §5).

## Testing strategy

Decision logic is pure and clock-injected: the promise-drop reducer, the
invocation contract, templates, filter, settings, and legacy import are
tested without timers or real drags. `ProcessRunner` is tested against
real `/bin/sh` fixtures (timeout, pipe volume). GUI-side tests cover the
model's sequencing/cleanup guarantees, DropView's handlers (fake
`NSDraggingInfo`), the promise controller against a real temp directory,
and en/ja localization parity.
