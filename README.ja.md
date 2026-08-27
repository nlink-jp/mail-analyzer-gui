# mail-analyzer-gui

[mail-analyzer](https://github.com/nlink-jp/mail-analyzer) または [mail-analyzer-local](https://github.com/nlink-jp/mail-analyzer-local) を利用した不審メール分析の macOS ネイティブデスクトップアプリケーション。

Finder や Apple Mail から `.eml` / `.msg` ファイルをドラッグ＆ドロップするだけで、ルールベース指標と LLM 判定による分析結果を即座に表示します。

## 機能

- **ドラッグ＆ドロップ** — Finder または Apple Mail から `.eml`/`.msg` ファイルをドロップ（複数メッセージ対応）
- **デュアルバックエンド** — mail-analyzer (Vertex AI) と mail-analyzer-local (ローカル LLM) の両方に対応
- **テンプレートプリセット** — ワンクリックで Vertex AI / Local LLM の設定を切り替え
- **分析結果表示** — 判定（カテゴリ、信頼度、理由）を目立たせて表示。指標は行ごとに展開表示
- **汎用設定** — 任意のアナライザーバイナリと環境変数を設定可能
- **JSON エクスポート** — 分析結果を JSON 形式でクリップボードにコピー
- **解析タイムアウト** — バックエンドがハングしても 300 秒で打ち切り（永久に「解析中」にならない）
- **自動クリーンアップ** — Apple Mail ドロップの一時ファイルは分析後に自動削除
- **英語 / 日本語 UI**

## 動作要件

- macOS 14+（Sonoma）、Apple Silicon
- 以下のいずれかのアナライザーバックエンド:
  - [mail-analyzer](https://github.com/nlink-jp/mail-analyzer)（GCP/Vertex AI が必要）
  - [mail-analyzer-local](https://github.com/nlink-jp/mail-analyzer-local)（ローカル LLM サーバーが必要）

## インストール

```bash
brew install --cask nlink-jp/tap/mail-analyzer-gui
```

または [Releases](https://github.com/nlink-jp/mail-analyzer-gui/releases) から `.zip` をダウンロードして展開し、`MailAnalyzerGUI.app` をアプリケーションフォルダにドラッグしてください。`.app` は **Developer ID 署名 + Apple 公証（ステープル済み）** のため、Gatekeeper の警告なしに起動でき、オフラインでも動作します。

**v0.2.x（Tauri 版）からのアップグレード**: 設定（バイナリパスと環境変数）は初回起動時に自動でインポートされます。アプリ名は `MailAnalyzerGUI.app` に変わりました。Homebrew を使わずにインストールしていた場合は、旧 `mail-analyzer-gui.app` を手動で削除してください。

## セットアップ

1. アプリを起動
2. **設定** をクリック
3. **アナライザーのバイナリパス** を設定（例: `/usr/local/bin/mail-analyzer-local`）
4. **テンプレートボタン** をクリックして環境変数を展開:
   - **mail-analyzer (Vertex AI)** — クラウド分析向け
   - **mail-analyzer-local (Local LLM)** — オフライン分析向け
5. 値を入力して **保存** をクリック

## 使い方

1. `.eml` / `.msg` ファイルをウィンドウ内の任意の場所にドラッグ
2. 分析完了を待つ（ファイルは 1 件ずつ順番に分析され、スピナーが進行を示します）
3. 結果行をクリックして詳細を展開／折り畳み。**指標を表示** で認証・送信者・URL・添付・経路のシグナルを確認
4. **JSON をエクスポート** で結果をクリップボードにコピー
5. **クリア** で完了した結果を削除（解析中の項目は残ります）

## 技術スタック

- Swift（SwiftUI + AppKit ドロップビュー 1 枚）、SwiftPM + Make — Xcode プロジェクト不使用
- v0.2.x 以前は Tauri v2 + Svelte + Objective-C。置き換えの経緯は
  `docs/ja/adr/0001-native-swift-rewrite.ja.md` を参照

## ビルド

```bash
make build-app   # 署名済み dist/MailAnalyzerGUI.app
make test        # swift test
```

## 既知の制限

- Apple Mail の複数メッセージドロップはベストエフォートです。macOS が
  ドラッグした数より少ないファイルしか渡さないことがまれにあり、その場合は
  黙って失敗する代わりに「Received N of M」の警告を表示します。足りない
  メッセージを再ドロップするか、Finder に `.eml` として保存してから
  ドロップしてください。
- macOS 専用です。

## ライセンス

MIT
