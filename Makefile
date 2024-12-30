.PHONY: clean build archive dmg install uninstall

# Variables
APP_NAME = MacMusicPlayer
BUILD_DIR = build
DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData
ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME).xcarchive
DMG_PATH = $(BUILD_DIR)/$(APP_NAME).dmg
INSTALL_PATH = /Applications
DMG_VOLUME_NAME = "$(APP_NAME)"

# Version information
GIT_COMMIT = $(shell git rev-parse --short HEAD)
GIT_BRANCH = $(shell git rev-parse --abbrev-ref HEAD)
BUILD_DATE = $(shell date +"%Y-%m-%d")
VERSION = $(GIT_COMMIT)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	xcodebuild clean -scheme $(APP_NAME)

# Build the application
build:
	xcodebuild build \
		-scheme $(APP_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		CURRENT_PROJECT_VERSION=$(VERSION) \
		MARKETING_VERSION=$(VERSION)

# Create archive
archive:
	xcodebuild clean archive \
		-scheme $(APP_NAME) \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH) \
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

# Install application to Applications folder
install: build
	cp -r "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app" "$(INSTALL_PATH)/"

# Uninstall application from Applications folder
uninstall:
	@if pgrep "$(APP_NAME)" > /dev/null; then \
		echo "正在关闭 $(APP_NAME)..."; \
		killall "$(APP_NAME)" || true; \
		sleep 2; \
	fi
	@echo "正在卸载 $(APP_NAME)..."
	rm -rf "$(INSTALL_PATH)/$(APP_NAME).app"
	@echo "卸载完成"

# Show version information
version:
	@echo "Version:     $(VERSION)"
	@echo "Git Commit:  $(GIT_COMMIT)"
	@echo "Git Branch:  $(GIT_BRANCH)"
	@echo "Build Date:  $(BUILD_DATE)"

# Default target
all: clean build dmg

# Help command
help:
	@echo "Available commands:"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make build     - Build the application"
	@echo "  make archive   - Create an archive"
	@echo "  make dmg      - Create a DMG installer"
	@echo "  make install   - Install to Applications folder"
	@echo "  make uninstall - Uninstall from Applications folder"
	@echo "  make version   - Show version information"
	@echo "  make all      - Clean, build, and create DMG" 