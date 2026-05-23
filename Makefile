APP        := mail-analyzer-gui
VERSION    := $(shell node -p "require('./package.json').version")
# Tauri names its DMG with Rust triplet arch — aarch64, not arm64.
ARCH       := $(shell uname -m | sed 's/^arm64$$/aarch64/')

# macOS Developer ID signing / notarization (see nlink-jp/.github
# CONVENTIONS.md §Code Signing → Wails / GUI apps; the same .app /
# .dmg bundle pipeline applies to Tauri). The signing step happens
# inside `tauri build` — Tauri reads APPLE_SIGNING_IDENTITY from the
# environment and, when set, calls codesign with the entitlements
# configured in src-tauri/tauri.conf.json (bundle.macOS.entitlements).
# Builds without the cert fall through to ad-hoc with a one-line
# warning, mirroring the codesign-darwin-app.sh contract.
CODESIGN_IDENTITY ?= Developer ID Application
NOTARY_PROFILE    ?= nlink-jp-notary

BUNDLE_DIR := src-tauri/target/release/bundle
APP_PATH   := $(BUNDLE_DIR)/macos/$(APP).app
DMG_PATH   := $(BUNDLE_DIR)/dmg/$(APP)_$(VERSION)_$(ARCH).dmg

.PHONY: build package dev test clean

## build: Tauri release build. If a Developer ID identity is present
## in the keychain, Tauri signs the .app + .dmg with Hardened Runtime
## + entitlements during bundling.
build:
	@if security find-identity -v -p codesigning 2>/dev/null | grep -q "$(CODESIGN_IDENTITY)"; then \
		echo "[codesign] Building with APPLE_SIGNING_IDENTITY=$(CODESIGN_IDENTITY)"; \
		APPLE_SIGNING_IDENTITY="$(CODESIGN_IDENTITY)" npm run tauri build; \
	else \
		echo "[codesign] No '$(CODESIGN_IDENTITY)' identity in keychain; bundle will keep linker ad-hoc signature"; \
		npm run tauri build; \
	fi

## package: notarize and staple the .dmg produced by `build`. The
## .dmg is a bundle format that supports stapler, so the notarization
## ticket travels with the disk image — offline first-launch works
## without a Gatekeeper dialog.
package: build
	@if [ -f "$(DMG_PATH)" ] && security find-identity -v -p codesigning 2>/dev/null | grep -q "$(CODESIGN_IDENTITY)"; then \
		if xcrun notarytool history --keychain-profile "$(NOTARY_PROFILE)" >/dev/null 2>&1; then \
			echo "[notarize] Submitting $(DMG_PATH) to Apple notary service (this typically takes 30s-2m)..."; \
			xcrun notarytool submit "$(DMG_PATH)" --keychain-profile "$(NOTARY_PROFILE)" --wait; \
			echo "[notarize] Stapling notarisation ticket to $(DMG_PATH)..."; \
			xcrun stapler staple "$(DMG_PATH)"; \
			xcrun stapler validate "$(DMG_PATH)"; \
			echo "[notarize] $(DMG_PATH): Accepted and stapled"; \
		else \
			echo "[notarize] Keychain profile '$(NOTARY_PROFILE)' not found; $(DMG_PATH) ships un-notarised"; \
		fi; \
	fi
	@ls -la "$(DMG_PATH)" 2>/dev/null || true

dev:
	npm run tauri dev

test:
	cd src-tauri && cargo test

clean:
	rm -rf build src-tauri/target node_modules/.vite
