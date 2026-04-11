# AGENTS.md — mail-analyzer-gui

## Summary

macOS desktop GUI for mail-analyzer. Tauri v2 (Rust + Svelte) app that accepts
email files via drag & drop and displays analysis results.

## Build

```bash
npm install
npm run tauri build          # Release build → .app + .dmg
npm run tauri dev             # Dev mode with hot reload
cargo test --manifest-path src-tauri/Cargo.toml   # Rust tests
```

## Project Structure

```
mail-analyzer-gui/
├── src/                        # Svelte frontend
│   ├── lib/
│   │   ├── components/         # DropZone, ResultList, ResultDetail, Settings
│   │   └── types/              # TypeScript types matching mail-analyzer JSON
│   └── routes/
│       └── +page.svelte        # Main page
├── src-tauri/
│   ├── src/
│   │   ├── lib.rs              # App setup, plugin registration, window events
│   │   ├── main.rs             # Entry point
│   │   ├── commands.rs         # Tauri commands (analyze_file, settings, export)
│   │   ├── analyzer.rs         # mail-analyzer subprocess execution
│   │   ├── settings.rs         # Settings persistence via tauri-plugin-store
│   │   ├── types.rs            # Rust types for mail-analyzer JSON
│   │   ├── window_state.rs     # Window position/size persistence
│   │   ├── native_drop.rs      # macOS file-promise overlay (Apple Mail D&D)
│   │   └── objc_helper.m       # ObjC helper for NSFilePromiseReceiver + FSEventStream
│   ├── capabilities/           # Tauri permission config
│   └── tauri.conf.json         # App config
└── docs/
    ├── design/                 # RFP and architecture documents
    └── ja/                     # Japanese documentation
```

## Architecture

Two drag & drop paths:
1. **Finder drops**: Tauri built-in DragDropEvent → file URLs → analyze
2. **Apple Mail drops**: Native NSView overlay → ObjC file-promise resolver → FSEventStream → Tauri event → analyze

mail-analyzer binary is called as a subprocess. Settings (binary path, env vars,
window state) are persisted via tauri-plugin-store.

## Gotchas

- Apple Mail file promises have a known platform bug where the reader block
  callback is never called. FSEventStream is used as a workaround.
- mail-analyzer may return `null` for array fields (attachments, urls).
  Rust types use `deserialize_with = "deserialize_null_vec"` to handle this.
- The app is unsigned. First launch requires Gatekeeper bypass.
- Multi-message Apple Mail D&D is not yet supported (single message only).
