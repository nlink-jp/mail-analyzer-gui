# mail-analyzer-gui

[mail-analyzer](https://github.com/nlink-jp/mail-analyzer) または [mail-analyzer-local](https://github.com/nlink-jp/mail-analyzer-local) を利用した不審メール分析のmacOSデスクトップアプリケーション。

FinderやApple Mailから `.eml` / `.msg` ファイルをドラッグ＆ドロップするだけで、ルールベース指標とLLM判定による分析結果を��座に表示します。

## 機能

- **ドラッグ＆ドロップ** — Finderまたは Apple Mail から `.eml`/`.msg` ファイルをドロップ
- **デュアルバックエンド** — mail-analyzer (Vertex AI) と mail-analyzer-local (ローカルLLM) の両方に対応
- **テンプレートプリセット** — ワンクリックで Vertex AI / Local LLM の設定を切り替え
- **分析結果表示** — 判定（カテゴリ、信頼度、理由）を目立たせて表示。指標は展開表示
- **汎用設定** — 任意のアナライザーバイナリと環境変数を設定可能
- **JSONエクスポート** — 分析結果をJSON形式でクリップボードにコピー
- **ウィンドウ状態記憶** — ウィンドウの位置とサイズをセッション間で保持
- **自動クリーンアップ** — Apple Mailドロップの一時ファイルは分析後に自動削除

## 動作要件

- macOS 10.15+（Catalina以降）
- 以下のいずれかのアナライザーバックエンド：
  - [mail-analyzer](https://github.com/nlink-jp/mail-analyzer)（GCP/Vertex AI必要）
  - [mail-analyzer-local](https://github.com/nlink-jp/mail-analyzer-local)（ローカルLLMサーバー必要）

## インストール

[Releases](https://github.com/nlink-jp/mail-analyzer-gui/releases) から `.dmg` をダウンロードし、`mail-analyzer-gui.app` をアプリケーションフォ��ダにドラッグしてください。

`.dmg` は **Apple Developer ID 署名済 + Apple notarize 済** (ticket staple 済) です。Gatekeeper ダイアログなしで起動でき、オフラインでも動作します。

## セットアップ

1. アプリを起動
2. **Settings** をクリック
3. **Analyzer binary path** を設定（例: `/usr/local/bin/mail-analyzer-local`）
4. **テンプレートボタン** をクリックして環境変数をプリセット：
   - **mail-analyzer (Vertex AI)** — クラウド分析用
   - **mail-analyzer-local (Local LLM)** — オフライン分析用
5. 値を入力して **Save** をクリック

## 使い方

1. `.eml` / `.msg` ファイルをドロップゾーンにドラッグ
2. 分析完了を待つ（スピナーが進行状況を表示）
3. 結果行をクリックして詳細を展開/折りたたみ
4. **Export JSON** で結果をクリップボードにコピー
5. **Clear** で全結果を削除

## 技術スタック

- [Tauri v2](https://tauri.app/)（Rust + WebView）
- [SvelteKit](https://svelte.dev/) + TypeScript（フロントエンド）
- ネイティブObjective-Cヘルパー（Apple Mailファイルプロミス処理）

## ビルド

```bash
npm install
npm run tauri build
```

出力: `src-tauri/target/release/bundle/macos/mail-analyzer-gui.app`

## 既知の制限

- Apple Mailからのドラッグ＆ドロップは現在1通のみ対応。複数メール同時ドロップは調査中
- macOS専用

## ライセンス

MIT
