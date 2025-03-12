.PHONY: clean archive dmg update-homebrew

# Variables
APP_NAME = MacMusicPlayer
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME).xcarchive
DMG_PATH = $(BUILD_DIR)/$(APP_NAME).dmg
DMG_VOLUME_NAME = "$(APP_NAME)"

# Version information
GIT_COMMIT = $(shell git rev-parse --short HEAD)
# If CI_BUILD is set (for release), use git tag; otherwise use commit hash for dev build
VERSION ?= $(if $(CI_BUILD),$(shell git describe --tags --always),Dev-$(shell git rev-parse --short HEAD))
CLEAN_VERSION = $(shell echo $(VERSION) | sed 's/^v//')

# Homebrew related variables
HOMEBREW_TAP_REPO = homebrew-tap
CASK_FILE = Casks/mac-music-player.rb
BRANCH_NAME = update-mac-music-player-$(CLEAN_VERSION)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	xcodebuild clean -scheme $(APP_NAME)

# Create archive
archive:
	xcodebuild clean archive \
		-project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH) \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="-" \
		DEVELOPMENT_TEAM="" \
		CURRENT_PROJECT_VERSION=$(VERSION) \
		MARKETING_VERSION=$(VERSION)

# Create DMG
dmg: archive
	# Export archive
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(BUILD_DIR) \
		-exportOptionsPlist exportOptions.plist
	
	# Create temporary directory for DMG
	rm -rf $(BUILD_DIR)/tmp
	mkdir -p $(BUILD_DIR)/tmp
	
	# Copy application to temporary directory
	cp -r "$(BUILD_DIR)/$(APP_NAME).app" "$(BUILD_DIR)/tmp/"
	
	# Create symbolic link to Applications folder
	ln -s /Applications "$(BUILD_DIR)/tmp/Applications"
	
	# Create DMG
	hdiutil create -volname $(DMG_VOLUME_NAME) \
		-srcfolder "$(BUILD_DIR)/tmp" \
		-ov -format UDZO \
		"$(DMG_PATH)"
	
	# Clean up
	rm -rf $(BUILD_DIR)/tmp

# Show version information
version:
	@echo "Version:     $(VERSION)"
	@echo "Git Commit:  $(GIT_COMMIT)"

# Update Homebrew Cask
update-homebrew:
	@echo "==> Starting Homebrew cask update process..."
	@if [ -z "$(GH_PAT)" ]; then \
		echo "❌ Error: GH_PAT environment variable is required"; \
		exit 1; \
	fi

	@echo "==> Current version information:"
	@echo "    - VERSION: $(VERSION)"
	@echo "    - CLEAN_VERSION: $(CLEAN_VERSION)"

	@echo "==> Preparing working directory..."
	@rm -rf tmp && mkdir -p tmp
	
	@echo "==> Downloading DMG file..."
	@curl -L -o tmp/$(APP_NAME).dmg "https://github.com/samzong/$(APP_NAME)/releases/download/v$(CLEAN_VERSION)/$(APP_NAME).dmg"
	
	@echo "==> Calculating SHA256..."
	@SHA256=$$(shasum -a 256 tmp/$(APP_NAME).dmg | cut -d ' ' -f 1) && echo "    - SHA256: $$SHA256"
	
	@echo "==> Cloning Homebrew tap repository..."
	@cd tmp && git clone https://$(GH_PAT)@github.com/samzong/$(HOMEBREW_TAP_REPO).git
	@cd tmp/$(HOMEBREW_TAP_REPO) && echo "    - Creating new branch: $(BRANCH_NAME)" && git checkout -b $(BRANCH_NAME)

	@echo "==> Updating cask file..."
	@cd tmp/$(HOMEBREW_TAP_REPO) && \
	SHA256=$$(shasum -a 256 ../$(APP_NAME).dmg | cut -d ' ' -f 1) && \
	sed -i '' 's/version "[^"]*"/version "$(CLEAN_VERSION)"/' $(CASK_FILE) && \
	sed -i '' 's/sha256 "[^"]*"/sha256 "'$$SHA256'"/' $(CASK_FILE)
	
	@echo "==> Checking for changes..."
	@cd tmp/$(HOMEBREW_TAP_REPO) && \
	if ! git diff --quiet $(CASK_FILE); then \
		echo "    - Changes detected, creating pull request..."; \
		git add $(CASK_FILE); \
		git config user.name "GitHub Actions"; \
		git config user.email "actions@github.com"; \
		git commit -m "chore: update MacMusicPlayer to v$(CLEAN_VERSION)"; \
		git push -u origin $(BRANCH_NAME); \
		pr_data=$$(jq -n \
			--arg title "chore: update MacMusicPlayer to v$(CLEAN_VERSION)" \
			--arg body "Auto-generated PR\n- Version: $(CLEAN_VERSION)\n- SHA256: $$SHA256" \
			--arg head "$(BRANCH_NAME)" \
			--arg base "main" \
			'{title: $$title, body: $$body, head: $$head, base: $$base}'); \
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
	@echo "Available commands:"
	@echo "  make clean           - Clean build artifacts"
	@echo "  make archive         - Create an archive"
	@echo "  make dmg             - Create a DMG installer"
	@echo "  make version         - Show version information"
	@echo "  make update-homebrew - Update Homebrew cask (requires GH_PAT)"

.DEFAULT_GOAL := help
