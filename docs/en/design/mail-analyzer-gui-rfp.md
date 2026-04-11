# RFP: mail-analyzer-gui

> Generated: 2026-04-11
> Status: Draft

## 1. Problem Statement

When viewing emails in a native mail client (Apple Mail, etc.), there are situations where a suspicious email needs to be analyzed immediately. The current mail-analyzer is a CLI tool that requires saving the email file first and then running it from the terminal. mail-analyzer-gui is a desktop application that allows users to drag & drop emails directly from their mail client and view analysis results in a GUI. The target user is the mail-analyzer user themselves, aiming to speed up the daily email analysis workflow.

## 2. Functional Specification

### Commands / API Surface

Desktop GUI application. No CLI interface.

### Input / Output

- **Input**: `.eml` / `.msg` files (drag & drop). Multiple file support.
- **Output**: Analysis results displayed in GUI. JSON export available.

### Configuration

Managed via a settings screen:

| Setting | Description |
|---------|-------------|
| `mail-analyzer binary path` | Absolute path to the mail-analyzer binary (no auto-detection from PATH; prevents binary injection) |
| `MAIL_ANALYZER_PROJECT` | GCP project ID |
| `MAIL_ANALYZER_LOCATION` | Vertex AI region (default: us-central1) |
| `MAIL_ANALYZER_MODEL` | Model to use (default: gemini-2.5-flash) |
| `MAIL_ANALYZER_LANG` | Output language (optional) |

Settings are persisted across app restarts.

### External Dependencies

- **mail-analyzer** binary (util-series, must be pre-built)
- Vertex AI (Gemini) credentials used internally by mail-analyzer (ADC or service account)

## 3. Design Decisions

### Tech Stack

- **Tauri** (Rust + WebView): Desktop application framework
- **Svelte**: Frontend framework (Tauri-recommended, appropriate for simple UI)
- **mail-analyzer CLI subprocess**: Loosely coupled, no Go code import

### Why Tauri

- Lightweight WebView-based (significantly lighter than Electron)
- Robust process management with Rust backend
- Uses macOS native WebView (WKWebView)
- Also serves as a new tech stack trial for nlink-jp

### Relationship with Existing Tools

- Functions as a GUI frontend for mail-analyzer
- Does not modify mail-analyzer code
- Integration with other tools (mail-triage, etc.) is out of scope

### Out of Scope

- Offline mode (`--offline`) UI toggle
- mail-analyzer code modification
- Integration with other nlink-jp tools
- Windows/Linux support (future consideration)
- Apple Developer signing/notarization

## 4. Development Plan

### Phase 1: Core

- Design documents and architecture documentation
- Tauri project scaffolding (Rust + Svelte)
- Drag & drop to receive eml/msg files
- mail-analyzer binary subprocess invocation
- Analysis result JSON parsing and display (judgment prominent, indicators expandable)
- Multiple file support (sequential processing + spinner)
- Settings screen (binary path, environment variables)
- Rust backend unit tests

### Phase 2: Features

- JSON export
- Enhanced error handling (binary not configured, analysis failure, timeout, etc.)
- UI improvements (based on user feedback)

### Phase 3: Release

- Documentation (README.md, docs/ja/README.md, CHANGELOG.md)
- macOS `.app` bundle build
- AGENTS.md

### Review Units

Each Phase can be reviewed independently. Phase 1 completion provides a minimum viable product.

## 5. Required API Scopes / Permissions

None. The GUI itself does not directly call external APIs. Vertex AI authentication is managed by the mail-analyzer binary.

## 6. Series Placement

Series: **util-series**
Reason: Placed in the same series as mail-analyzer. Grouped as a related tool.

## 7. External Platform Constraints

- **macOS Gatekeeper**: No signing/notarization (Apple Developer not registered). Gatekeeper warning on first launch (bypass with `xattr -d com.apple.quarantine`). Acceptable to users.
- **macOS minimum version**: 10.15+ (Catalina, Tauri requirement)
- **Apple Mail D&D behavior**: Confirmed that dragging emails from Apple Mail drops them as `.eml` files
- **Vertex AI**: GCP authentication required for mail-analyzer's LLM calls. Response may take several seconds.

---

## Discussion Log

1. **Tool name**: Confirmed as `mail-analyzer-gui`
2. **Use case clarification**: Motivation is to analyze emails by D&D directly from the mail client. Not for non-CLI users, but to speed up the user's own workflow.
3. **Architecture selection**: Compared 4 options: Wails (Go integration), Tauri (Rust+WebView), SwiftUI, Wails+CLI subprocess. Recommended Wails+Go library integration, but user chose Tauri (option B) for trial.
4. **Coupling with mail-analyzer**: Proposed exposing internal/ packages (pkg/), but Tauri selection confirmed CLI subprocess (loose coupling).
5. **Security design**: Binary path explicitly set in Settings, not auto-detected from PATH. Prevents binary injection.
6. **Environment variable management**: Environment variables for mail-analyzer invocation (PROJECT, LOCATION, MODEL, LANG) also managed in Settings.
7. **Early design documentation**: Since Tauri/Rust is a new tech stack for nlink-jp, design documents created at the start of Phase 1.
8. **Series placement**: Proposed experimental start in lab-series, but user chose util-series.
9. **Gatekeeper**: Signing difficult without Apple Developer registration. Warning is acceptable.
