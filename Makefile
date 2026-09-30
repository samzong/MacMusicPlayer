BOLD  := \033[1m
CYAN  := \033[36m
RESET := \033[0m

.DEFAULT_GOAL := help

APP_NAME = MacMusicPlayer
BUILD_DIR = build
DMG_VOLUME_NAME = "$(APP_NAME) (Apple Silicon)"
MACOS_MIN = 12.0
ICON_SRC = $(APP_NAME)/Assets.xcassets/AppIcon.appiconset
ICONSET = $(BUILD_DIR)/AppIcon.iconset

BUILT_APP_PATH = $(BUILD_DIR)/$(APP_NAME).app
DMG_PATH = $(BUILD_DIR)/$(APP_NAME)-arm64.dmg
SWIFT_BUILD = swift build -c release --triple arm64-apple-macosx$(MACOS_MIN)
USER_APPLICATIONS = $(HOME)/Applications
INSTALL_PATH = $(USER_APPLICATIONS)/$(APP_NAME).app

GIT_COMMIT := $(shell git rev-parse --short HEAD)

# Prefer tagged versions; fall back to the nearest tag or commit hash automatically.
ifndef VERSION
VERSION := $(shell git describe --tags --always)
endif

ifndef MARKETING_SEMVER
MARKETING_SEMVER := $(shell \
    VERSION_STR="$(VERSION)"; \
    CLEAN=$$(echo $$VERSION_STR | sed -E 's/^v//; s/-.*//'); \
    if echo $$CLEAN | grep -Eq '^[0-9]+(\.[0-9]+){0,2}$$'; then \
        echo $$CLEAN; \
    else \
        echo 0.0.0; \
    fi)
endif

ifndef BUILD_NUMBER
BUILD_NUMBER := $(shell git rev-list --count HEAD)
endif

INFO_PLIST_KEYS = \
	CFBundleExecutable=$(APP_NAME) \
	CFBundleName=$(APP_NAME) \
	CFBundlePackageType=APPL \
	CFBundleInfoDictionaryVersion=6.0 \
	CFBundleDevelopmentRegion=en \
	LSApplicationCategoryType=public.app-category.music \
	NSPrincipalClass=NSApplication \
	CFBundleShortVersionString=$(MARKETING_SEMVER) \
	CFBundleVersion=$(BUILD_NUMBER) \
	GitCommit=$(GIT_COMMIT)

# ── Build ────────────────────────────────────────────────────────────────────

.PHONY: build install-app

build: ## Build the Release app into build/
	@echo "==> Build $(APP_NAME)..."
	$(SWIFT_BUILD)
	rm -rf "$(BUILT_APP_PATH)" "$(ICONSET)"
	mkdir -p "$(BUILT_APP_PATH)/Contents/MacOS" "$(BUILT_APP_PATH)/Contents/Resources" "$(ICONSET)"
	cp "$$($(SWIFT_BUILD) --show-bin-path)/$(APP_NAME)" "$(BUILT_APP_PATH)/Contents/MacOS/"
	cp $(APP_NAME)/Info.plist "$(BUILT_APP_PATH)/Contents/Info.plist"
	sed -i '' 's/\$${PRODUCT_NAME}/$(APP_NAME)/' "$(BUILT_APP_PATH)/Contents/Info.plist"
	for kv in $(INFO_PLIST_KEYS); do plutil -replace "$${kv%%=*}" -string "$${kv#*=}" "$(BUILT_APP_PATH)/Contents/Info.plist"; done
	for f in $(ICON_SRC)/icon_*_1x.png; do \
		name=$$(basename "$$f" _1x.png); \
		cp "$$f" "$(ICONSET)/$$name.png"; \
		cp "$${f%_1x.png}_2x.png" "$(ICONSET)/$$name@2x.png"; \
	done
	iconutil -c icns "$(ICONSET)" -o "$(BUILT_APP_PATH)/Contents/Resources/AppIcon.icns"
	cp -R $(APP_NAME)/Resources/Localization/*.lproj "$(BUILT_APP_PATH)/Contents/Resources/"
	codesign --force --sign - "$(BUILT_APP_PATH)"
	@echo "✅ Build completed!"
	@echo "📍 Application location: $(BUILT_APP_PATH)"

install-app: ## Quit, rebuild, install to ~/Applications, and launch
	@echo "⏹️  Force quitting any running $(APP_NAME) instances..."
	@if pgrep -x "$(APP_NAME)" >/dev/null 2>&1; then \
		pkill -KILL -x "$(APP_NAME)" >/dev/null 2>&1; \
		echo "✅ $(APP_NAME) has been force quit."; \
	else \
		echo "ℹ️  $(APP_NAME) is not currently running."; \
	fi
	@$(MAKE) --no-print-directory build
	@echo "📦 Install $(APP_NAME) to ~/Applications..."
	@if [ -d "$(INSTALL_PATH)" ]; then \
		echo "⚠️  Found installed version, deleting..."; \
		rm -rf "$(INSTALL_PATH)"; \
	fi
	@if [ -d "$(BUILT_APP_PATH)" ]; then \
		cp -R "$(BUILT_APP_PATH)" "$(USER_APPLICATIONS)/"; \
		echo "✅ $(APP_NAME) has been successfully installed to ~/Applications!"; \
		echo "🚀 Launching $(APP_NAME)..."; \
		open "$(INSTALL_PATH)"; \
		echo "✅ $(APP_NAME) launched."; \
	else \
		echo "❌ Error: Unable to find the built application file $(BUILT_APP_PATH)"; \
		echo "💡 Please rerun 'make install-app' to rebuild and install"; \
		exit 1; \
	fi

# ── Release ──────────────────────────────────────────────────────────────────

.PHONY: dmg version

dmg: build ## Build and package a self-signed arm64 DMG
	rm -rf $(BUILD_DIR)/dmg
	mkdir -p $(BUILD_DIR)/dmg
	cp -R "$(BUILT_APP_PATH)" $(BUILD_DIR)/dmg/
	ln -s /Applications $(BUILD_DIR)/dmg/Applications
	hdiutil create -volname $(DMG_VOLUME_NAME) -srcfolder $(BUILD_DIR)/dmg -ov -format UDZO "$(DMG_PATH)"
	rm -rf $(BUILD_DIR)/dmg
	@echo "==> DMG created: $(DMG_PATH)"
	@echo "Note: This DMG is self-signed; users may need to approve it in System Settings."

version: ## Print version info (override VERSION, MARKETING_SEMVER, BUILD_NUMBER)
	@echo "Version:     $(VERSION)"
	@echo "Git Commit:  $(GIT_COMMIT)"
	@echo "Marketing:   $(MARKETING_SEMVER)"
	@echo "Build Number: $(BUILD_NUMBER)"

# ── Maintenance ──────────────────────────────────────────────────────────────

.PHONY: clean

clean: ## Remove build artifacts
	rm -rf $(BUILD_DIR) .build

# ── Help ─────────────────────────────────────────────────────────────────────

.PHONY: help

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "; printf "\n$(BOLD)MacMusicPlayer$(RESET) — menu bar music player for macOS\n"} \
		/^# ── / {n = $$0; gsub(/(^# ── | (─)+$$)/, "", n); printf "\n$(BOLD)%s$(RESET)\n", n} \
		/^[a-zA-Z_-]+:.*## / {printf "  $(CYAN)make %-16s$(RESET) %s\n", $$1, $$2} \
		END {printf "\n"}' $(MAKEFILE_LIST)
