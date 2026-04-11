# mail-analyzer-gui

[mail-analyzer](https://github.com/nlink-jp/mail-analyzer) を利用した不審メール分析のmacOSデスクトップアプリケーション。

FinderやApple Mailから `.eml` / `.msg` ファイルをドラッグ＆ドロップするだけで、ルールベース指標とLLM判定による分析結果を即座に表示します。

## 機能

- **ドラッグ＆ドロップ** — Finderまたは Apple Mail から `.eml`/`.msg` ファイルをドロップ
- **分析結果表示** — 判定（カテゴリ、信頼度、理由）を目立たせて表示。指標は展開表示
- **設定画面** — mail-analyzerバイナリパス、環境変数（GCPプロジェクト、モデル、言語）を設定
- **JSONエクスポート** — 分析結果をJSON形式でクリップボードにコピー
- **ウィンドウ状態記憶** — ウィンドウの位置とサイズをセッション間で保持

## 動作要件

- macOS 10.15+（Catalina以降）
- [mail-analyzer](https://github.com/nlink-jp/mail-analyzer) バイナリ
- GCP認証情報（mail-analyzerがVertex AIを使用）

## インストール

[Releases](https://github.com/nlink-jp/mail-analyzer-gui/releases) から `.dmg` をダウンロードし、`mail-analyzer-gui.app` をアプリケーションフォルダにドラッグしてください。

> **注意:** Apple Developer証明書で署名されていません。初回起動時はシステム設定 > プライバシーとセキュリティから許可するか、以下を実行してください：
> ```
> xattr -d com.apple.quarantine /Applications/mail-analyzer-gui.app
> ```

## セットアップ

1. アプリを起動
2. **Settings** をクリック
3. **mail-analyzer binary path** を設定（例: `/usr/local/bin/mail-analyzer`）
4. **MAIL_ANALYZER_PROJECT** にGCPプロジェクトIDを設定
5. 必要に応じて他の環境変数を調整
6. **Save** をクリック

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
