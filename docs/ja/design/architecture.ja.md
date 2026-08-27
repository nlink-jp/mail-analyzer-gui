# アーキテクチャ: mail-analyzer-gui

> 更新: 2026-08-28（v0.3.0 — Swift ネイティブ書き直し。置き換え前の
> Tauri v2 構成は git 履歴（≤ v0.2.2）と ADR-0001 に残る）

## 概要

mail-analyzer-gui は Swift 製の macOS ネイティブアプリケーション
（SwiftUI + ドラッグ&ドロップ用の AppKit ビュー 1 枚）。mail-analyzer CLI
バイナリをサブプロセスとして起動し、分析結果を GUI に表示する。
SwiftPM の 2 ターゲット構成:

- **MailAnalyzerGUICore** — 純粋で UI 非依存のロジック（AppKit import 禁止）。
  「判断」はすべてここにあり、依存注入で単体テストされる。
- **MailAnalyzerGUI** — SwiftUI 実行ターゲット: ビュー、アプリモデル、
  非純粋な半分（Process / FileManager / ペーストボード / promise receiver）。

## コンポーネント図

```
┌────────────────────────────────────────────────────────────────┐
│  MailAnalyzerGUI.app（単一プロセス・単一言語）                    │
│                                                                │
│  SwiftUI                    AppKit                             │
│  ┌───────────────────┐      ┌──────────────────────────┐       │
│  │ ContentView        │      │ DropView（ルート背景）     │      │
│  │  ├ DropZoneVisual  │◀────▶│  file URL + file promise  │      │
│  │  ├ ResultListView  │      └────────────┬─────────────┘       │
│  │  │  └ ResultDetail │                   │ promise             │
│  │  └ SettingsView    │      ┌────────────▼─────────────┐       │
│  └─────────┬─────────┘      │ PromiseDropController     │       │
│            │                │  ドロップ毎 UUID 一時 dir、 │      │
│  ┌─────────▼─────────┐      │  250ms poll → reducer     │       │
│  │ AppModel           │◀────┴──────────────────────────┘       │
│  │  逐次 FIFO 解析     │                                        │
│  │  キュー             │───▶ ProcessRunner ── subprocess ──▶ mail-analyzer(-local)
│  └───────────────────┘                                         │
│                                                                │
│  MailAnalyzerGUICore（純粋）:                                    │
│   AnalysisResult（Codable スキーマ）· AnalyzerInvocation          │
│   PromiseDropSession（状態機械）· DropFilter                      │
│   AnalyzerSettings（UserDefaults）· EnvTemplates · LegacyImport   │
└────────────────────────────────────────────────────────────────┘
```

## データフロー

### Finder ドロップ（file URL）

1. `DropView.performDragOperation` がペーストボードから file URL を読む。
2. `AppModel.handleDropped` が `DropFilter` で選別（.eml/.msg、大小文字
   無視。除外分は通知表示）し、エントリを先頭に追加（新しい順）して
   キューに積む。
3. 単一ワーカーが FIFO を厳密に逐次処理: バイナリパス検証 →
   `ProcessRunner.run`（300 秒タイムアウト）→
   `AnalyzerInvocation.interpret` → エントリ状態 `done`/`error`。

### Apple Mail ドロップ（file promise）

1. `DropView` が promise 型を検出（promise 優先）し、
   `NSFilePromiseReceiver` 群を新しい `PromiseDropController` に渡す。
2. controller は `$TMPDIR/mail-analyzer-gui-drop/<UUID>/r<i>/` を作成し、
   `receivePromisedFiles` を発行（reader は非 main キュー。Mail では発火
   しないことが多い — プラットフォームバグ）し、ディレクトリを 250ms
   間隔でポーリングして純粋な `PromiseDropSession` reducer に流す。
3. reducer の完了条件: reader が期待数を届けた／全ファイルのサイズが静止し
   2 秒の quiet window が経過（レシーバ数はヒント扱い — これが複数
   メッセージドラッグを成立させる）／15 秒の deadline で**必ず**結果を出す
   （不足分は警告付き部分配達、0 件は失敗通知。沈黙はない）。
4. 届いたファイルは `promiseTemp: true` で同じ `handleDropped` 経路へ。
   解析後に一時ファイルを削除（temp base 配下ガード付き）し、空になった
   ドロップディレクトリを掃除。1 日超の残骸は起動時に一掃する。

### サブプロセス契約

`<binary_path> <file>` — 位置引数 1 つ、フラグ無し。親環境を継承し、設定
された環境変数は非空の場合のみ適用。stdout/stderr は exit 待ちの前に全量
ドレイン（パイプデッドロック無し）。検証とエラーメッセージの書式は legacy
文言そのままの契約テキスト（英語）。

### 設定

`AnalyzerSettings` ⇄ `UserDefaults`（`analyzer.binaryPath`,
`analyzer.envVars`）。`LegacyImport` が v0.2.x の Tauri store を一度だけ
移行（フラグ `migration.importedTauriSettings`）し、ユーザーが作成済みの
設定は決して上書きしない。PATH 自動検出は行わない — バイナリインジェク
ション防止（RFP §5）。

## テスト戦略

判断ロジックは純粋かつクロック注入: promise-drop reducer、呼び出し契約、
テンプレート、フィルタ、設定、legacy import はタイマーも実ドラッグも
使わずにテストされる。`ProcessRunner` は実 `/bin/sh` フィクスチャ
（タイムアウト、パイプ量）で検証。GUI 側はモデルの逐次性・クリーンアップ
保証、DropView ハンドラ（fake `NSDraggingInfo`）、実一時ディレクトリに
対する promise controller、en/ja ローカライズのパリティを検証する。
