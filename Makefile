.PHONY: clean archive dmg

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

# Help command
help:
	@echo "Available commands:"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make archive   - Create an archive"
	@echo "  make dmg       - Create a DMG installer"
	@echo "  make version   - Show version information"

.DEFAULT_GOAL := help
