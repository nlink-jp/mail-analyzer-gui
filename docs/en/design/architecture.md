# Architecture: mail-analyzer-gui

> Updated: 2026-04-11

## Overview

mail-analyzer-gui is a desktop application built with Tauri v2 (Rust + Svelte).
It invokes the mail-analyzer CLI binary as a subprocess and displays analysis
results in a GUI.

## Component Diagram

```
┌─────────────────────────────────────────────────┐
│  mail-analyzer-gui (.app)                       │
│                                                 │
│  ┌──────────────────────┐  ┌─────────────────┐  │
│  │  Frontend (Svelte)   │  │  Backend (Rust)  │  │
│  │                      │  │                  │  │
│  │  DropZone component  │  │  analyze_file()  │──── subprocess ──▶ mail-analyzer
│  │  ResultList component│◀─┤  get_settings()  │  │
│  │  ResultDetail comp.  │  │  save_settings() │  │
│  │  Settings view       │  │  export_json()   │  │
│  │                      │  │                  │  │
│  └──────┬───────────────┘  └──────────────────┘  │
│         │ invoke()              │                 │
│         └───────────────────────┘                 │
│                                                   │
│  Plugins:                                        │
│  - tauri-plugin-shell (subprocess execution)     │
│  - tauri-plugin-store (settings persistence)     │
│  - Built-in DragDrop event (Finder D&D)          │
│                                                   │
│  Native:                                         │
│  - NSView overlay (Apple Mail file promises)     │
│  - ObjC helper + FSEventStream                   │
└─────────────────────────────────────────────────┘
```

## Data Flow

### Finder Drops (file URLs)

```
1. User drops .eml/.msg file(s) onto the window
2. Tauri DragDropEvent fires with file paths
3. Frontend calls invoke('analyze_file', { path })
4. Rust backend:
   a. Reads settings (binary path, env vars) from store
   b. Spawns mail-analyzer subprocess with env vars
   c. Captures stdout (JSON)
   d. Parses and validates JSON
   e. Returns Result to frontend
5. Frontend renders result in ResultList/ResultDetail
```

### Apple Mail Drops (file promises)

```
1. User drops email from Apple Mail onto the window
2. Native NSView overlay accepts the file-promise drag
3. ObjC helper calls receivePromisedFilesAtDestination
4. FSEventStream detects new .eml file in temp directory
5. Rust callback emits "files-dropped" Tauri event
6. Frontend receives event, calls invoke('analyze_file', { path })
7. Same analysis flow as Finder drops
```

## Directory Structure

```
mail-analyzer-gui/
├── docs/
│   ├── en/                     # English documentation
│   │   ├── README.md
│   │   └── design/
│   └── ja/                     # Japanese documentation
│       ├── README.md
│       └── design/
├── src/                        # Svelte frontend
│   ├── lib/
│   │   ├── components/
│   │   │   ├── DropZone.svelte
│   │   │   ├── ResultList.svelte
│   │   │   ├── ResultDetail.svelte
│   │   │   └── Settings.svelte
│   │   └── types/
│   │       └── index.ts        # TypeScript types for mail-analyzer JSON
│   └── routes/
│       └── +page.svelte        # Main page
├── src-tauri/
│   ├── src/
│   │   ├── lib.rs              # Tauri app setup + command registration
│   │   ├── main.rs             # Entry point
│   │   ├── commands.rs         # Tauri command definitions
│   │   ├── analyzer.rs         # mail-analyzer subprocess execution
│   │   ├── settings.rs         # Settings read/write via plugin-store
│   │   ├── types.rs            # Rust types matching mail-analyzer JSON
│   │   ├── window_state.rs     # Window position/size persistence
│   │   ├── native_drop.rs      # macOS file-promise overlay (Apple Mail D&D)
│   │   └── objc_helper.m       # ObjC: NSFilePromiseReceiver + FSEventStream
│   ├── capabilities/
│   │   └── default.json        # Permission config
│   ├── Cargo.toml
│   └── tauri.conf.json
├── static/
├── package.json
├── AGENTS.md
├── CHANGELOG.md
├── LICENSE
└── README.md
```

## Tauri Commands (Rust → Frontend API)

| Command | Input | Output | Description |
|---------|-------|--------|-------------|
| `analyze_file` | `path: String` | `AnalysisResult` | Run mail-analyzer and return results |
| `get_settings` | — | `Settings` | Get current settings |
| `save_settings` | `settings: Settings` | `()` | Persist settings |
| `export_json` | `results: Vec<AnalysisResult>` | `String` | Serialize results to JSON |

## Key Types

### Settings

```typescript
interface Settings {
  binary_path: string;      // mail-analyzer binary absolute path
  env_vars: {
    project: string;        // MAIL_ANALYZER_PROJECT
    location: string;       // MAIL_ANALYZER_LOCATION (default: "us-central1")
    model: string;          // MAIL_ANALYZER_MODEL (default: "gemini-2.5-flash")
    lang: string;           // MAIL_ANALYZER_LANG (optional)
  };
}
```

### AnalysisResult (mail-analyzer JSON output)

```typescript
interface AnalysisResult {
  source_file: string;
  hash: string;
  message_id: string;
  subject: string;
  from: string;
  to: string[];
  date: string;
  indicators: {
    authentication: AuthResult;
    sender: SenderResult;
    urls: URLResult[];
    attachments: AttachResult[];
    routing: RoutingResult;
  };
  judgment: {
    is_suspicious: boolean;
    category: "phishing" | "spam" | "malware-delivery" | "bec" | "scam" | "safe";
    confidence: number;
    summary: string;
    reasons: string[];
    tags: string[];
  };
}
```

## Security Considerations

- **Binary path**: No auto-detection from PATH. Absolute path must be explicitly set in Settings to prevent binary injection.
- **Subprocess execution**: Tauri capabilities restrict allowed commands to the minimum.
- **Environment variables**: Sensitive values (GCP project ID, etc.) stored in local app data directory.
- **Input validation**: Only `.eml` and `.msg` file extensions are accepted.
- **Capabilities**: Tauri v2 capabilities configured with minimal permissions.

## Build & Distribution

- `npm run tauri build -- --bundles app` generates the `.app` bundle only — no `.dmg`; the release artifact is a ditto-zipped `.app` (CONVENTIONS.md §Release Archive Standard)
- Releases v0.2.1+ are Developer ID signed + notarized + stapled via `make package`; releases up to v0.2.0 were ad-hoc signed and required a Gatekeeper bypass (`xattr -d com.apple.quarantine`)
- macOS 10.15+ (Catalina) supported
