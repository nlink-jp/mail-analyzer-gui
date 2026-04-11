# Architecture: mail-analyzer-gui

> Updated: 2026-04-11

## Overview

mail-analyzer-gui は Tauri v2 (Rust + Svelte) で構築するデスクトップアプリケーション。
mail-analyzer CLI バイナリを子プロセスとして呼び出し、分析結果を GUI 上で表示する。

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
│  - tauri-plugin-shell (子プロセス実行)             │
│  - tauri-plugin-store (設定永続化)                 │
│  - Built-in DragDrop event (D&D)                 │
└─────────────────────────────────────────────────┘
```

## Data Flow

```
1. User drops .eml/.msg file(s) onto DropZone
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

## Directory Structure

```
mail-analyzer-gui/
├── docs/
│   ├── design/
│   │   ├── mail-analyzer-gui-rfp.md
│   │   └── architecture.md
│   └── ja/
│       └── README.md
├── src/                        # Svelte frontend
│   ├── lib/
│   │   ├── components/
│   │   │   ├── DropZone.svelte
│   │   │   ├── ResultList.svelte
│   │   │   ├── ResultDetail.svelte
│   │   │   └── Settings.svelte
│   │   ├── stores/
│   │   │   └── analysis.ts     # Svelte store for results
│   │   └── types.ts            # TypeScript types for mail-analyzer JSON
│   ├── App.svelte
│   └── main.ts
├── src-tauri/
│   ├── src/
│   │   ├── lib.rs              # Tauri app setup + command registration
│   │   ├── main.rs             # Entry point
│   │   ├── commands.rs         # tauri::command definitions
│   │   ├── analyzer.rs         # mail-analyzer subprocess execution
│   │   ├── settings.rs         # Settings read/write via plugin-store
│   │   └── types.rs            # Rust types matching mail-analyzer JSON
│   ├── capabilities/
│   │   └── default.json        # shell:allow-execute, store:default
│   ├── Cargo.toml
│   └── tauri.conf.json
├── static/
├── package.json
├── svelte.config.js
├── vite.config.ts
├── tsconfig.json
├── Makefile
├── AGENTS.md
├── CHANGELOG.md
└── README.md
```

## Tauri Commands (Rust → Frontend API)

| Command | Input | Output | Description |
|---------|-------|--------|-------------|
| `analyze_file` | `path: String` | `AnalysisResult` | mail-analyzerを実行し結果を返す |
| `get_settings` | — | `Settings` | 現在の設定を取得 |
| `save_settings` | `settings: Settings` | `()` | 設定を永続化 |
| `export_json` | `results: Vec<AnalysisResult>` | `String` (path) | 結果をJSONファイルに保存 |

## Key Types

### Settings

```typescript
interface Settings {
  binaryPath: string;       // mail-analyzer binary absolute path
  envVars: {
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

- **Binary path**: PATHからの自動検出は行わない。設定画面で絶対パスを明示指定し、バイナリインジェクションを防止
- **Subprocess execution**: tauri-plugin-shell の capabilities で許可するコマンドを最小限に制限
- **Environment variables**: GCPプロジェクトID等の機密情報はローカルストアに保存。ファイルはアプリデータディレクトリ内
- **Input validation**: ドロップされたファイルの拡張子を検証（.eml, .msg のみ受け付け）
- **Capabilities**: Tauri v2 の capabilities で権限を最小限に設定

## Build & Distribution

- `npm run tauri build` で `.app` バンドルを生成
- Apple Developer未登録のため署名/公証なし
- 初回起動時は `xattr -d com.apple.quarantine` で Gatekeeper を回避
- macOS 10.15+ (Catalina) 対応
