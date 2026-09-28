APP_NAME    := Instant Translate Enhanced
NAME        := instant-translate-enhanced
BUNDLE_ID   := com.anonymousaga.instant-translate-enhanced
VERSION     := $(shell git describe --tags --always --dirty 2>/dev/null || echo "0.1.0")
BUILD_DIR   := .build/release
DIST_DIR    := dist
APP_BUNDLE  := $(DIST_DIR)/$(APP_NAME).app

# App icon: a 1024x1024 source PNG; build-app generates AppIcon.icns into the
# bundle's Resources (sips + iconutil). Missing source → app builds without icon.
ICON_SRC := assets/AppIcon-1024.png

# macOS records the SDK an app was linked against in LC_BUILD_VERSION, and the
# system reads that field to decide which generation of window chrome to draw.
# Since the Xcode 27 / Swift 6.4 toolchain, `swift build` stamps it with the
# deployment target instead of the SDK actually used, so a release built without
# this renders with the previous design — square window corners. Passing
# -platform_version explicitly restores it. MACOS_MIN is read from Package.swift
# so there is one deployment target, not two.
MACOS_MIN := $(shell sed -n -e 's/.*\.macOS(\.v\([0-9][0-9]*\)).*/\1.0/p' \
                            -e 's/.*\.macOS("\([0-9][0-9.]*\)").*/\1/p' Package.swift | head -1)
MACOS_SDK := $(shell xcrun --sdk macosx --show-sdk-version)
SDK_LINK_FLAGS := -Xlinker -platform_version -Xlinker macos -Xlinker $(MACOS_MIN) -Xlinker $(MACOS_SDK)

.PHONY: build build-app package verify-release test clean run

## build: build the release binary
build:
	@mkdir -p $(DIST_DIR)
	@test -n "$(MACOS_MIN)" || { echo "Makefile: no macOS deployment target found in Package.swift"; exit 1; }
	@test -n "$(MACOS_SDK)" || { echo "Makefile: xcrun could not report the macOS SDK version"; exit 1; }
	swift build -c release $(SDK_LINK_FLAGS)

## build-app: assemble the unsigned .app bundle
build-app: build
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BUILD_DIR)/InstantTranslate" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@sed 's/$${VERSION}/$(VERSION)/g; s/$${BUNDLE_ID}/$(BUNDLE_ID)/g; s/$${APP_NAME}/$(APP_NAME)/g' \
		Info.plist > "$(APP_BUNDLE)/Contents/Info.plist"
	@if [ -f "$(ICON_SRC)" ]; then \
		scripts/make-icns.sh "$(ICON_SRC)" "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"; \
	else \
		echo "[icon] WARN: $(ICON_SRC) not found — building without an app icon"; \
	fi
	@echo "Built $(APP_BUNDLE) ($(VERSION))"

## package: build-app, then zip the unsigned .app for release
package: build-app
	@cd "$(DIST_DIR)" && /usr/bin/ditto --norsrc --noextattr -c -k --keepParent "$(APP_NAME).app" "$(NAME)-$(VERSION)-darwin-arm64.zip"
	@ls -la "$(DIST_DIR)/$(NAME)-$(VERSION)-darwin-arm64.zip"

## verify-release: verify the unsigned release archive
verify-release:
	@test -f "$(DIST_DIR)/$(NAME)-$(VERSION)-darwin-arm64.zip" || { \
		echo "verify-release: FAIL — release zip missing: $(DIST_DIR)/$(NAME)-$(VERSION)-darwin-arm64.zip"; exit 1; }
	@scripts/verify-app-zip.sh "$(DIST_DIR)/$(NAME)-$(VERSION)-darwin-arm64.zip"
	@sdk=$$(otool -l "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)" | awk '/LC_BUILD_VERSION/{f=1} f && /^ *sdk /{print $$2; exit}'); \
		test "$$sdk" = "$(MACOS_SDK)" || { \
			echo "verify-release: FAIL — linked SDK is $$sdk, expected $(MACOS_SDK)."; \
			echo "  macOS draws an app linked against an old SDK with the previous window chrome."; \
			exit 1; }
	@echo "verify-release: OK ($(VERSION) — unsigned archive, linked against SDK $(MACOS_SDK))"

## test: run tests
test:
	swift test

## run: build and run (debug)
run:
	swift run

## clean: remove build artifacts
clean:
	rm -rf $(DIST_DIR) .build

# Homebrew tap generation (see scripts/release-brew.mk). After `make package`,
# `make brew` generates this cask from the built darwin-arm64 zip.
BREW_KIND := cask
BREW_DESC := Lightweight menu-bar translator using macOS on-device Translation
BREW_NAME := $(NAME)
BREW_APP := $(APP_NAME).app
BREW_BUNDLE_ID := $(BUNDLE_ID)
BREW_REPO := instant-translate-enhanced
# macOS 26 Translation API — the cask floor must be :tahoe, not the :big_sur default.
BREW_MACOS_FLOOR := :tahoe
include scripts/release-brew.mk
