# ADR-0001: Rewrite mail-analyzer-gui as a native Swift app

- Status: Accepted
- Date: 2026-08-28
- Supersedes: the Tauri v2 implementation (v0.1.0–v0.2.2)

## Context

Through v0.2.2 the app was Tauri v2 (Rust) + SvelteKit (TypeScript) + a
native ObjC helper — three languages and two IPC/serialization boundaries
for a ~2,000-line application. The pain concentrated in Apple Mail
drag & drop: `NSFilePromiseReceiver`'s reader block often never fires for
Mail drags (platform bug), and the workaround lived as an ObjC class
generated at runtime from Rust (`ClassBuilder` + raw `msg_send`), an
FSEventStream on a shared temp directory, C-string arrays across an
`extern "C"` boundary, and a Tauri IPC event into the WebView. Five
memory-ownership regimes coexisted in ~200 lines.

Known defects rooted in that construction:

- A promise drop that produced zero files timed out into **permanent
  silence** (no event, no error, a leaked run-loop thread and WatchContext).
- Multi-message Mail drags did not work (single message only): the
  receiver-count heuristic and the WKWebView overlay both fought the
  platform.
- FSEvents fired on file creation, racing partially written `.eml` files.
- No analysis timeout: a hung LLM backend left the row "analyzing" forever.
- A multibyte character at the 500-byte parse-error truncation point
  panicked the Rust side.
- The build chain required Node, Vite, SvelteKit, Rust, a C compiler, and
  the Tauri CLI; the JSON schema was declared twice (Rust and TypeScript)
  with diverging null-handling.

Meanwhile the organization converged on a Swift house template for macOS
GUI apps (zip-porter et al.): SwiftPM + Make, a pure Core module + thin UI
module, vendored codesign/notarize/brew scripts, en/ja localization.

## Decision

Rewrite in place as a native Swift app on the house template:

- **SwiftUI** app lifecycle (precedent: image-forge-gui) with a single
  AppKit `NSView` drop target handling both file URLs and file promises.
- **MailAnalyzerGUICore** (no AppKit) holds the analyzer JSON schema —
  single-sourced now — the subprocess contract with its legacy-verbatim
  error strings, settings, and a **pure promise-drop state machine** with
  an injected clock: completion by size quiescence + quiet window +
  hard deadline that always yields an outcome. The receiver count is a
  hint, which is what makes multi-message Mail drags work.
- Promise resolution watches a **per-drop UUID temp directory** with a
  250 ms poll — no FSEventStream, no run-loop thread; the poll doubles as
  the reducer's clock and the teardown is a `Task` cancellation.
- Analyses get a 300 s timeout (SIGTERM → SIGKILL).
- Settings move to **UserDefaults** with a one-time import of the Tauri
  store; window frames use the standard restoration machinery (fixing the
  offscreen-restore and write-per-frame defects wholesale).
- Bundle ID stays `jp.nlink.mail-analyzer-gui`; the bundle is renamed to
  house-style `MailAnalyzerGUI.app`. The WebView JIT entitlements are
  deleted — Hardened Runtime only.
- UI strings are localized en/ja (the legacy UI was English-only);
  analyzer error strings remain English contract text.

## Consequences

- One language, one schema declaration, one process; the toolchain is
  Swift + Make. ~2,100 lines of Rust/Svelte/ObjC and the npm dependency
  tree are gone.
- arm64-only, macOS 14+ (house floor; the Tauri build also shipped
  arm64-only).
- Env values — API keys included — are still stored in plain text
  (UserDefaults now, JSON file before). **Keychain storage is recorded as
  future work**; it must be designed together with the env-var editor UX.
- Mail multi-message drags are best-effort by construction: if the
  platform delivers fewer files than dropped, the app says so instead of
  guessing (partial-delivery warning). Platform behavior may still cap
  what arrives; the quiet-window design is the honest ceiling.
- The cask's installed app renames from `mail-analyzer-gui.app` to
  `MailAnalyzerGUI.app` on upgrade; manual installs keep the old bundle
  until removed by hand (release-session concern).
