APP        := mail-analyzer-gui
VERSION    := $(shell node -p "require('./package.json').version")

# macOS Developer ID signing / notarization (see nlink-jp/.github
# CONVENTIONS.md §Code Signing → GUI apps). The signing step happens
# inside `tauri build` — Tauri reads APPLE_SIGNING_IDENTITY from the
# environment and, when set, calls codesign with the entitlements
# configured in src-tauri/tauri.conf.json (bundle.macOS.entitlements).
# Builds without the cert fall through to ad-hoc with a one-line
# warning. Bundling is restricted to the `app` target (`--bundles app`)
# so no .dmg is produced: nlink-jp ships a zipped .app, not a .dmg
# (see §Release Archive Standard).
CODESIGN_IDENTITY ?= Developer ID Application
NOTARY_PROFILE    ?= nlink-jp-notary
NOTARIZE_SCRIPT   := scripts/notarize-darwin-app.sh

# We ship a zipped .app, not a DMG — no Rust-triplet arch juggling needed.
APP_PATH := src-tauri/target/release/bundle/macos/$(APP).app

# Homebrew tap generation (see scripts/release-brew.mk). After `make package`,
# `make brew` generates this cask from the built darwin-arm64 zip into the local
# nlink-jp/homebrew-tap checkout. VERSION comes from package.json (no leading v),
# so BREW_ZIP is set explicitly to match the `-v$(VERSION)` package artifact.
BREW_KIND      := cask
BREW_DESC      := Drag-and-drop desktop app for suspicious email analysis
BREW_NAME      := $(APP)
BREW_APP       := $(APP).app
BREW_BUNDLE_ID := jp.nlink.mail-analyzer-gui
BREW_ZIP       := dist/$(APP)-v$(VERSION)-darwin-arm64.zip
include scripts/release-brew.mk

.PHONY: build package dev test clean

## build: Tauri release build (app bundle only, no DMG). If a Developer
## ID identity is present in the keychain, Tauri signs the .app with
## Hardened Runtime + entitlements during bundling.
build:
	@if security find-identity -v -p codesigning 2>/dev/null | grep -q "$(CODESIGN_IDENTITY)"; then \
		echo "[codesign] Building with APPLE_SIGNING_IDENTITY=$(CODESIGN_IDENTITY)"; \
		APPLE_SIGNING_IDENTITY="$(CODESIGN_IDENTITY)" npm run tauri build -- --bundles app; \
	else \
		echo "[codesign] No '$(CODESIGN_IDENTITY)' identity in keychain; bundle keeps ad-hoc signature"; \
		npm run tauri build -- --bundles app; \
	fi

## package: notarize + staple the .app, then ditto-zip it as
## $(APP)-v$(VERSION)-darwin-arm64.zip (the org Release Archive Standard
## name). The .app is the shipped artifact — no .dmg.
package: build
	@$(NOTARIZE_SCRIPT) $(APP_PATH) "$(NOTARY_PROFILE)"
	@mkdir -p dist
	@cd $(dir $(APP_PATH)) && /usr/bin/ditto -c -k --keepParent \
		$(APP).app "$(CURDIR)/dist/$(APP)-v$(VERSION)-darwin-arm64.zip"
	@ls -la "$(CURDIR)/dist/$(APP)-v$(VERSION)-darwin-arm64.zip"

dev:
	npm run tauri dev

test:
	cd src-tauri && cargo test

clean:
	rm -rf build src-tauri/target node_modules/.vite dist
