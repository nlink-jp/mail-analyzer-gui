# ADR-0001: mail-analyzer-gui を Swift ネイティブアプリとして書き直す

- ステータス: 承認済み
- 日付: 2026-08-28
- 置き換え対象: Tauri v2 実装 (v0.1.0–v0.2.2)

## 背景

v0.2.2 までのアプリは Tauri v2 (Rust) + SvelteKit (TypeScript) + ネイティブ
ObjC ヘルパーという構成で、約 2,000 行のアプリケーションに対して 3 言語と
2 つの IPC／シリアライズ境界を抱えていた。問題が集中していたのは Apple Mail
のドラッグ&ドロップである。Mail のドラッグでは `NSFilePromiseReceiver` の
reader ブロックが発火しないことが多く（プラットフォーム側のバグ）、その回避策が
「Rust から実行時生成した ObjC クラス（`ClassBuilder` + 生の `msg_send`）、
共有一時ディレクトリを監視する FSEventStream、`extern "C"` 境界を渡る C 文字列
配列、WebView への Tauri IPC イベント」として実装されていた。約 200 行に
5 種類のメモリ所有権規約が同居していた。

この構造に根ざす既知の欠陥:

- ファイルが 1 つも生成されないプロミスドロップは**永久の沈黙**にタイムアウト
  する（イベントもエラーも出ず、run-loop スレッドと WatchContext がリーク）。
- Mail の複数メッセージドラッグが動作しない（単一メッセージのみ）。
- FSEvents はファイル作成時点で発火し、書き込み途中の `.eml` と競合する。
- 解析タイムアウトが無く、LLM バックエンドがハングすると行が永遠に
  「解析中」のまま。
- パースエラー時の 500 バイト切り詰めがマルチバイト文字の途中に落ちると
  Rust 側が panic する。
- ビルドチェーンに Node / Vite / SvelteKit / Rust / C コンパイラ / Tauri CLI
  が全て必要で、JSON スキーマは Rust と TypeScript に二重宣言されていた。

一方、組織側は macOS GUI アプリの Swift ハウステンプレート（zip-porter ほか）
に収斂していた: SwiftPM + Make、純粋な Core モジュール + 薄い UI モジュール、
vendored な codesign/notarize/brew スクリプト、en/ja ローカライズ。

## 決定

ハウステンプレートに則り、同一リポジトリ内で Swift ネイティブに書き直す。

- **SwiftUI** ライフサイクル（前例: image-forge-gui）。file URL と file
  promise の両方を単一の AppKit `NSView` ドロップターゲットで処理する。
- **MailAnalyzerGUICore**（AppKit 禁止）に、単一宣言化したアナライザー JSON
  スキーマ、legacy 文言そのままのサブプロセス契約、設定、そして**純粋な
  promise-drop 状態機械**（クロック注入）を置く。完了判定は「サイズ静止 +
  quiet window + 必ず結果を出す hard deadline」。レシーバ数はヒントとして
  扱い、これが複数メッセージドラッグを成立させる。
- プロミス解決は**ドロップごとの UUID 一時ディレクトリ**を 250ms ポーリングで
  監視する — FSEventStream も run-loop スレッドも使わない。
- 解析に 300 秒タイムアウト（SIGTERM → SIGKILL）。
- 設定は **UserDefaults** に移行し、Tauri store を初回一度だけインポート。
  ウィンドウ位置は標準の復元機構に任せる。
- Bundle ID は `jp.nlink.mail-analyzer-gui` を維持し、バンドル名はハウス慣例の
  `MailAnalyzerGUI.app` に変更。WebView JIT entitlement は削除（Hardened
  Runtime のみ）。
- UI 文字列は en/ja ローカライズ（legacy は英語のみ）。アナライザーのエラー
  文言は契約テキストとして英語のまま。

## 帰結

- 言語 1 つ、スキーマ宣言 1 つ、プロセス 1 つ。ツールチェーンは Swift + Make。
  Rust/Svelte/ObjC 約 2,100 行と npm 依存ツリーが消えた。
- arm64 専用、macOS 14+（ハウス標準。Tauri 版も arm64 専用だった）。
- 環境変数の値（API キーを含む）は引き続き平文保存（旧: JSON ファイル、
  新: UserDefaults）。**Keychain 対応は将来課題**として記録する。env 変数
  エディタの UX と併せて設計する必要がある。
- Mail 複数メッセージは構造上ベストエフォート: プラットフォームがドロップ数
  より少ないファイルしか渡さない場合、推測せずその旨を警告表示する。
- cask のインストール先アプリ名がアップグレード時に `mail-analyzer-gui.app`
  から `MailAnalyzerGUI.app` に変わる。手動インストールは旧バンドルが手動削除
  されるまで残る（リリースセッションで扱う）。
