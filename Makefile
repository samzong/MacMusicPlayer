.PHONY: clean build install-app dmg update-homebrew check-arch

# Variables
APP_NAME = MacMusicPlayer
BUILD_DIR = build
DMG_VOLUME_NAME = "$(APP_NAME)"

# Install variables
CONFIGURATION = Release
BUILT_APP_PATH = $(BUILD_DIR)/$(CONFIGURATION)/$(APP_NAME).app
USER_APPLICATIONS = $(HOME)/Applications
INSTALL_PATH = $(USER_APPLICATIONS)/$(APP_NAME).app

# Version information
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

ARCHES := x86_64 arm64
.PHONY: $(foreach arch,$(ARCHES),build-$(arch))

archive_path = $(BUILD_DIR)/$(APP_NAME)-$(1).xcarchive
dmg_path = $(BUILD_DIR)/$(APP_NAME)-$(1).dmg

DMG_LABEL_x86_64 = Intel
DMG_LABEL_arm64 = Apple Silicon

define build_archive_for_arch
	@echo "==> Build $(1) architecture application..."
	xcodebuild clean archive \
		-project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Release \
		-archivePath $(2) \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="-" \
		DEVELOPMENT_TEAM="" \
		CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) \
		MARKETING_VERSION=$(MARKETING_SEMVER) \
		ARCHS="$(1)" \
		OTHER_CODE_SIGN_FLAGS="--options=runtime"
endef

define package_dmg_for_arch
	xcodebuild -exportArchive \
		-archivePath $(2) \
		-exportPath $(BUILD_DIR)/$(1) \
		-exportOptionsPlist exportOptions.plist

	rm -rf $(BUILD_DIR)/tmp-$(1)
	mkdir -p $(BUILD_DIR)/tmp-$(1)

	cp -r "$(BUILD_DIR)/$(1)/$(APP_NAME).app" "$(BUILD_DIR)/tmp-$(1)/"

	@echo "==> Self-sign $(1) application..."
	codesign --force --deep --sign - "$(BUILD_DIR)/tmp-$(1)/$(APP_NAME).app"

	ln -s /Applications "$(BUILD_DIR)/tmp-$(1)/Applications"

	hdiutil create -volname "$(DMG_VOLUME_NAME) ($(3))" \
		-srcfolder "$(BUILD_DIR)/tmp-$(1)" \
		-ov -format UDZO \
		"$(4)"

	rm -rf $(BUILD_DIR)/tmp-$(1) $(BUILD_DIR)/$(1)
endef

define package_template

	$(call package_dmg_for_arch,$(1),$(call archive_path,$(1)),$(DMG_LABEL_$(1)),$(call dmg_path,$(1)))
endef

define echo_dmg_line

	@echo "    - $(1) version: $(call dmg_path,$(1))"
endef

# Homebrew related variables
HOMEBREW_TAP_REPO = homebrew-tap
CASK_FILE = Casks/mac-music-player.rb
BRANCH_NAME = update-mac-music-player-$(MARKETING_SEMVER)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	xcodebuild clean -scheme $(APP_NAME)

# Build for local development (current architecture)
build:
	@echo "🔨 Build $(APP_NAME) application (local development version)..."
	@mkdir -p $(BUILD_DIR)
	xcodebuild \
		-scheme $(APP_NAME) \
		-configuration $(CONFIGURATION) \
		-destination 'platform=macOS' \
		build \
		SYMROOT=$(BUILD_DIR) \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="-" \
		DEVELOPMENT_TEAM="" \
		CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) \
		MARKETING_VERSION=$(MARKETING_SEMVER)
	@echo "✅ Build completed!"
	@echo "📍 Application location: $(BUILT_APP_PATH)"

# Install app to ~/Applications and launch it
install-app:
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

# Build for specific architectures
define build_target_template
.PHONY: build-$(1)
build-$(1):
	$(call build_archive_for_arch,$(1),$(call archive_path,$(1)))
endef
$(foreach arch,$(ARCHES),$(eval $(call build_target_template,$(arch))))

# Create DMG (builds all defined architectures)
dmg: $(foreach arch,$(ARCHES),build-$(arch))
	$(foreach arch,$(ARCHES),$(call package_template,$(arch)))
	@$(MAKE) --no-print-directory check-arch
	@echo "==> All DMG files have been created:"
	$(foreach arch,$(ARCHES),$(call echo_dmg_line,$(arch)))
	@echo ""
	@echo "Note: These DMGs are self-signed; users may need to approve them in System Settings."

# Check architecture compatibility
check-arch:
	@echo "==> Check application architecture compatibility..."
	@for arch in $(ARCHES); do \
		BINARY="$(call archive_path,$$arch)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)"; \
		if [ -f "$$BINARY" ]; then \
			echo "==> Check $$arch version architecture:"; \
			lipo -info "$$BINARY"; \
			if lipo -info "$$BINARY" | grep -q "$$arch"; then \
				echo "✅ $$arch version supports $$arch architecture"; \
			else \
				echo "❌ $$arch version does not support $$arch architecture"; \
				exit 1; \
			fi; \
		fi; \
	done


# Show version information
version:
	@echo "Version:     $(VERSION)"
	@echo "Git Commit:  $(GIT_COMMIT)"
	@echo "Marketing:   $(MARKETING_SEMVER)"
	@echo "Build Number: $(BUILD_NUMBER)"

# Update Homebrew Cask
update-homebrew:
	@echo "==> Starting Homebrew cask update process..."
	@if [ -z "$(GH_PAT)" ]; then \
		echo "❌ Error: GH_PAT environment variable is required"; \
		exit 1; \
	fi

	@echo "==> Current version information:"
	@echo "    - VERSION: $(VERSION)"
	@echo "    - MARKETING_SEMVER: $(MARKETING_SEMVER)"

	@echo "==> Preparing working directory..."
	@rm -rf tmp && mkdir -p tmp
	
	@echo "==> Downloading DMG files..."
	@curl -L -o tmp/$(APP_NAME)-x86_64.dmg "https://github.com/samzong/$(APP_NAME)/releases/download/v$(MARKETING_SEMVER)/$(APP_NAME)-x86_64.dmg"
	@curl -L -o tmp/$(APP_NAME)-arm64.dmg "https://github.com/samzong/$(APP_NAME)/releases/download/v$(MARKETING_SEMVER)/$(APP_NAME)-arm64.dmg"

	@echo "==> Calculating SHA256 checksums..."
	@X86_64_SHA256=$$(shasum -a 256 tmp/$(APP_NAME)-x86_64.dmg | cut -d ' ' -f 1) && echo "    - x86_64 SHA256: $$X86_64_SHA256"
	@ARM64_SHA256=$$(shasum -a 256 tmp/$(APP_NAME)-arm64.dmg | cut -d ' ' -f 1) && echo "    - arm64 SHA256: $$ARM64_SHA256"
	
	@echo "==> Cloning Homebrew tap repository..."
	@cd tmp && git clone https://$(GH_PAT)@github.com/samzong/$(HOMEBREW_TAP_REPO).git
	@cd tmp/$(HOMEBREW_TAP_REPO) && echo "    - Creating new branch: $(BRANCH_NAME)" && git checkout -b $(BRANCH_NAME)

	@echo "==> Updating cask file..."
	@cd tmp/$(HOMEBREW_TAP_REPO) && \
	X86_64_SHA256=$$(shasum -a 256 ../$(APP_NAME)-x86_64.dmg | cut -d ' ' -f 1) && \
	ARM64_SHA256=$$(shasum -a 256 ../$(APP_NAME)-arm64.dmg | cut -d ' ' -f 1) && \
	if [ -f $(CASK_FILE) ]; then \
		echo "    - Updating existing cask file with sed..."; \
		echo "    - Updating version to $(MARKETING_SEMVER)"; \
		sed -i '' 's/version "[^"]*"/version "$(MARKETING_SEMVER)"/' $(CASK_FILE); \
		if grep -q "on_arm" $(CASK_FILE); then \
			echo "    - Updating arm64 SHA256 to $$ARM64_SHA256"; \
			sed -i '' '/on_arm/,/end/{s/sha256 "[^"]*"/sha256 "'"$$ARM64_SHA256"'"/;}' $(CASK_FILE); \
			echo "    - Updating x86_64 SHA256 to $$X86_64_SHA256"; \
			sed -i '' '/on_intel/,/end/{s/sha256 "[^"]*"/sha256 "'"$$X86_64_SHA256"'"/;}' $(CASK_FILE); \
		else \
			echo "❌ Unknown cask format, cannot update SHA256 values"; \
			exit 1; \
		fi; \
	else \
		echo "❌ Error: Cask file not found. Please create it manually first."; \
		exit 1; \
	fi
	
	@echo "==> Checking for changes..."
	@cd tmp/$(HOMEBREW_TAP_REPO) && \
	if ! git diff --quiet $(CASK_FILE); then \
		echo "    - Changes detected, creating pull request..."; \
		git add $(CASK_FILE); \
		git config user.name "GitHub Actions"; \
		git config user.email "actions@github.com"; \
		git commit -m "chore: update $(APP_NAME) to v$(MARKETING_SEMVER)"; \
		git push -u origin $(BRANCH_NAME); \
		pr_data=$$(printf '{"title":"chore: update %s to v%s","body":"Auto-generated PR\\n- Version: %s\\n- x86_64 SHA256: %s\\n- arm64 SHA256: %s","head":"%s","base":"main"}' \
			"$(APP_NAME)" "$(MARKETING_SEMVER)" "$(MARKETING_SEMVER)" "$$X86_64_SHA256" "$$ARM64_SHA256" "$(BRANCH_NAME)"); \
		curl -X POST \
			-H "Authorization: token $(GH_PAT)" \
			-H "Content-Type: application/json" \
			https://api.github.com/repos/samzong/$(HOMEBREW_TAP_REPO)/pulls \
			-d "$$pr_data"; \
		echo "✅ Pull request created successfully"; \
	else \
		echo "❌ No changes detected in cask file"; \
		exit 1; \
	fi

	@echo "==> Cleaning up temporary files..."
	@rm -rf tmp
	@echo "✅ Homebrew cask update process completed"

# Help command
help:
	@echo "MacMusicPlayer build targets:"
	@echo "  make build         Build app for the current architecture"
	@echo "  make install-app   Build, install to ~/Applications, and launch"
	@echo "  make dmg           Produce self-signed DMGs for x86_64 and arm64"
	@echo "  make check-arch    Confirm archive slices for each architecture"
	@echo "  make version       Print version, marketing, and build numbers"
	@echo "  make clean         Remove build artifacts"
	@echo "  make update-homebrew GH_PAT=token  Update Homebrew cask"
	@echo "  make build-<arch>    Build single-arch archives (arches: $(ARCHES))"
	@echo ""
	@echo "Override MARKETING_SEMVER/BUILD_NUMBER when needed, e.g. MARKETING_SEMVER=1.2.3 make build"
	@echo ""
	@echo "All DMGs are self-signed; users may need to allow them manually."

.DEFAULT_GOAL := help
