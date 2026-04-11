# RFP: mail-analyzer-gui

> Generated: 2026-04-11
> Status: Draft

## 1. Problem Statement

OS標準メーラー（Apple Mail等）でメールを閲覧中に、不審なメールを即座に分析したい場面がある。現状のmail-analyzerはCLIツールであり、メールファイルを一度保存してからターミナルで実行する必要がある。mail-analyzer-guiは、メーラーから直接ドラッグ＆ドロップでメールを投入し、分析結果をGUI上でわかりやすく表示するデスクトップアプリケーションである。ターゲットユーザーはmail-analyzerの利用者自身で、日常的なメール分析のワークフローを高速化する。

## 2. Functional Specification

### Commands / API Surface

デスクトップGUIアプリケーション。CLIインターフェースは持たない。

### Input / Output

- **入力**: `.eml` / `.msg` ファイル（ドラッグ＆ドロップ）。複数ファイル同時投入対応
- **出力**: GUI上での分析結果表示。JSONエクスポート機能あり

### Configuration

設定画面で以下を管理：

| 設定項目 | 説明 |
|----------|------|
| `mail-analyzer binary path` | mail-analyzerバイナリの絶対パス（PATHからの自動検出は行わない。バイナリインジェクション防止） |
| `MAIL_ANALYZER_PROJECT` | GCPプロジェクトID |
| `MAIL_ANALYZER_LOCATION` | Vertex AIリージョン（デフォルト: us-central1） |
| `MAIL_ANALYZER_MODEL` | 使用モデル（デフォルト: gemini-2.5-flash） |
| `MAIL_ANALYZER_LANG` | 出力言語（オプション） |

設定は永続化し、アプリ再起動後も保持する。

### External Dependencies

- **mail-analyzer** バイナリ（util-series、別途ビルド済みであること）
- mail-analyzerが内部で使用するVertex AI (Gemini) の認証情報（ADCまたはサービスアカウント）

## 3. Design Decisions

### 技術スタック

- **Tauri** (Rust + WebView): デスクトップアプリケーションフレームワーク
- **Svelte**: フロントエンドフレームワーク（Tauri推奨、UIがシンプルなため適切）
- **mail-analyzer CLI子プロセス呼び出し**: Goコードのimportではなく疎結合を維持

### Tauriを選択した理由

- 軽量なWebViewベース（Electronより大幅に軽い）
- Rustバックエンドでプロセス管理が堅牢
- macOSネイティブWebView (WKWebView) を使用
- nlink-jpでの新技術スタック試行という側面もある

### 既存ツールとの関係

- mail-analyzerのGUIフロントエンドとして機能
- mail-analyzerのコードは改変しない
- 他ツール（mail-triage等）との連携は現時点でスコープ外

### スコープ外

- オフラインモード（`--offline`）のUI切り替え
- mail-analyzerのコード改変
- 他nlink-jpツールとの連携
- Windows/Linux対応（将来検討）
- Apple Developer署名/公証

## 4. Development Plan

### Phase 1: Core

- 設計資料・アーキテクチャドキュメント作成
- Tauriプロジェクトスキャフォールド（Rust + Svelte）
- ドラッグ＆ドロップでeml/msgファイルを受け取る機能
- mail-analyzerバイナリの子プロセス呼び出し
- 分析結果JSONのパースと表示（judgment目立たせ、indicators展開表示）
- 複数ファイル対応（順次処理 + スピナー表示）
- 設定画面（バイナリパス、環境変数）
- Rustバックエンドのユニットテスト

### Phase 2: Features

- JSONエクスポート機能
- エラーハンドリング強化（バイナリ未設定、分析失敗、タイムアウト等）
- UI改善（ユーザーフィードバック反映）

### Phase 3: Release

- ドキュメント（README.md, docs/ja/README.md, CHANGELOG.md）
- macOS向け `.app` バンドルビルド
- AGENTS.md整備

### レビュー単位

各Phaseを独立してレビュー可能。Phase 1完了時点で実用可能な最小構成となる。

## 5. Required API Scopes / Permissions

None。GUI自体は外部APIを直接呼び出さない。Vertex AI認証はmail-analyzerバイナリ側で管理される。

## 6. Series Placement

Series: **util-series**
Reason: mail-analyzerと同じシリーズに配置。関連ツールとしてまとめる。

## 7. External Platform Constraints

- **macOS Gatekeeper**: Apple Developer未登録のため署名/公証なし。初回起動時にGatekeeper警告が表示される（`xattr -d com.apple.quarantine` で回避）。利用者は想定内
- **macOS最低バージョン**: 10.15+ (Catalina以降、Tauri要件)
- **Apple MailのD&D動作**: Apple Mailからメールをドラッグすると `.eml` ファイルとしてドロップされることを確認済み
- **Vertex AI**: mail-analyzerのLLM呼び出しにはGCP認証が必要。レスポンスに数秒かかる場合がある

---

## Discussion Log

1. **ツール名決定**: `mail-analyzer-gui` で確定
2. **ユースケース明確化**: メーラーで表示中のメールをそのままD&Dで分析したいという動機。CLIに慣れていない他者向けではなく、自身のワークフロー高速化が目的
3. **アーキテクチャ選定**: Wails (Go統合)、Tauri (Rust+WebView)、SwiftUI、Wails+CLI子プロセスの4案を比較。Wails+Goライブラリ統合を推奨したが、ユーザーの判断でTauri (方式B) を試行することに決定
4. **mail-analyzerとの結合方式**: internal/パッケージの公開(pkg/)案も提示したが、Tauri選択によりCLI子プロセス呼び出し（疎結合）で確定
5. **セキュリティ設計**: バイナリパスはPATHからの自動検出ではなく設定画面で明示指定。バイナリインジェクション防止のため
6. **環境変数管理**: mail-analyzer呼び出し時の環境変数（PROJECT, LOCATION, MODEL, LANG）も設定画面で管理
7. **設計資料の早期作成**: Tauri/Rustはnlink-jp初の技術スタックであるため、Phase 1の最初に設計資料・アーキテクチャドキュメントを作成
8. **シリーズ配置**: lab-seriesでの実験的開始を提案したが、ユーザーの判断でutil-seriesに配置
9. **Gatekeeper**: Apple Developer未登録のため署名困難。警告は想定内で許容
