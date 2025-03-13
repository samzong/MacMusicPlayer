.PHONY: clean dmg update-homebrew check-arch

# Variables
APP_NAME = MacMusicPlayer
BUILD_DIR = build
X86_64_ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME)-x86_64.xcarchive
ARM64_ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME)-arm64.xcarchive
X86_64_DMG_PATH = $(BUILD_DIR)/$(APP_NAME)-x86_64.dmg
ARM64_DMG_PATH = $(BUILD_DIR)/$(APP_NAME)-arm64.dmg
DMG_VOLUME_NAME = "$(APP_NAME)"

# 签名相关变量 - 使用自签名选项
SELF_SIGN = true
TEAM_ID = 
APPLE_ID = 
APP_BUNDLE_ID = com.seimotech.MacMusicPlayer
APP_PASSWORD = 

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

# Build for x86_64 (Intel)
build-x86_64:
	@echo "==> 构建 x86_64 架构的应用..."
	xcodebuild clean archive \
		-project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Release \
		-archivePath $(X86_64_ARCHIVE_PATH) \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="-" \
		DEVELOPMENT_TEAM="" \
		CURRENT_PROJECT_VERSION=$(VERSION) \
		MARKETING_VERSION=$(VERSION) \
		ARCHS="x86_64" \
		OTHER_CODE_SIGN_FLAGS="--options=runtime"

# Build for arm64 (Apple Silicon)
build-arm64:
	@echo "==> 构建 arm64 架构的应用..."
	xcodebuild clean archive \
		-project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Release \
		-archivePath $(ARM64_ARCHIVE_PATH) \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="-" \
		DEVELOPMENT_TEAM="" \
		CURRENT_PROJECT_VERSION=$(VERSION) \
		MARKETING_VERSION=$(VERSION) \
		ARCHS="arm64" \
		OTHER_CODE_SIGN_FLAGS="--options=runtime"

# Create DMG (builds x86_64 and arm64 versions)
dmg: build-x86_64 build-arm64
	# Export x86_64 archive
	xcodebuild -exportArchive \
		-archivePath $(X86_64_ARCHIVE_PATH) \
		-exportPath $(BUILD_DIR)/x86_64 \
		-exportOptionsPlist exportOptions.plist
	
	# Create temporary directory for x86_64 DMG
	rm -rf $(BUILD_DIR)/tmp-x86_64
	mkdir -p $(BUILD_DIR)/tmp-x86_64
	
	# Copy application to temporary directory
	cp -r "$(BUILD_DIR)/x86_64/$(APP_NAME).app" "$(BUILD_DIR)/tmp-x86_64/"
	
	# 对 x86_64 应用进行自签名
	@echo "==> 对 x86_64 应用进行自签名..."
	codesign --force --deep --sign - "$(BUILD_DIR)/tmp-x86_64/$(APP_NAME).app"
	
	# Create symbolic link to Applications folder
	ln -s /Applications "$(BUILD_DIR)/tmp-x86_64/Applications"
	
	# Create x86_64 DMG
	hdiutil create -volname "$(DMG_VOLUME_NAME) (Intel)" \
		-srcfolder "$(BUILD_DIR)/tmp-x86_64" \
		-ov -format UDZO \
		"$(X86_64_DMG_PATH)"
	
	# Clean up
	rm -rf $(BUILD_DIR)/tmp-x86_64 $(BUILD_DIR)/x86_64
	
	# Export arm64 archive
	xcodebuild -exportArchive \
		-archivePath $(ARM64_ARCHIVE_PATH) \
		-exportPath $(BUILD_DIR)/arm64 \
		-exportOptionsPlist exportOptions.plist
	
	# Create temporary directory for arm64 DMG
	rm -rf $(BUILD_DIR)/tmp-arm64
	mkdir -p $(BUILD_DIR)/tmp-arm64
	
	# Copy application to temporary directory
	cp -r "$(BUILD_DIR)/arm64/$(APP_NAME).app" "$(BUILD_DIR)/tmp-arm64/"
	
	# 对 arm64 应用进行自签名
	@echo "==> 对 arm64 应用进行自签名..."
	codesign --force --deep --sign - "$(BUILD_DIR)/tmp-arm64/$(APP_NAME).app"
	
	# Create symbolic link to Applications folder
	ln -s /Applications "$(BUILD_DIR)/tmp-arm64/Applications"
	
	# Create arm64 DMG
	hdiutil create -volname "$(DMG_VOLUME_NAME) (Apple Silicon)" \
		-srcfolder "$(BUILD_DIR)/tmp-arm64" \
		-ov -format UDZO \
		"$(ARM64_DMG_PATH)"
	
	# Clean up
	rm -rf $(BUILD_DIR)/tmp-arm64 $(BUILD_DIR)/arm64
	
	# 检查架构兼容性
	@make check-arch
	
	@echo "==> 所有 DMG 文件已创建:"
	@echo "    - x86_64 版本: $(X86_64_DMG_PATH)"
	@echo "    - arm64 版本: $(ARM64_DMG_PATH)"
	@echo ""
	@echo "注意: 这些应用使用了自签名，用户首次运行时可能需要在系统偏好设置中手动允许运行。"
	@echo "在 README 中添加相关说明可以帮助用户解决这个问题。"

# Check architecture compatibility
check-arch:
	@echo "==> 检查应用架构兼容性..."
	@if [ -f "$(X86_64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" ]; then \
		echo "==> 检查 x86_64 版本架构:"; \
		lipo -info "$(X86_64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)"; \
		if lipo -info "$(X86_64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" | grep -q "x86_64"; then \
			echo "✅ x86_64 版本支持 x86_64 架构"; \
		else \
			echo "❌ x86_64 版本不支持 x86_64 架构"; \
			exit 1; \
		fi; \
	fi
	
	@if [ -f "$(ARM64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" ]; then \
		echo "==> 检查 arm64 版本架构:"; \
		lipo -info "$(ARM64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)"; \
		if lipo -info "$(ARM64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" | grep -q "arm64"; then \
			echo "✅ arm64 版本支持 arm64 架构"; \
		else \
			echo "❌ arm64 版本不支持 arm64 架构"; \
			exit 1; \
		fi; \
	fi


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
	
	@echo "==> Downloading DMG files..."
	@curl -L -o tmp/$(APP_NAME)-x86_64.dmg "https://github.com/samzong/$(APP_NAME)/releases/download/v$(CLEAN_VERSION)/$(APP_NAME)-x86_64.dmg"
	@curl -L -o tmp/$(APP_NAME)-arm64.dmg "https://github.com/samzong/$(APP_NAME)/releases/download/v$(CLEAN_VERSION)/$(APP_NAME)-arm64.dmg"
	
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
		sed -i '' "s/version \".*\"/version \"$(CLEAN_VERSION)\"/" $(CASK_FILE); \
		if grep -q "Hardware::CPU.arm" $(CASK_FILE); then \
			sed -i '' "/if Hardware::CPU.arm/,/else/ s/sha256 \".*\"/sha256 \"$$ARM64_SHA256\"/" $(CASK_FILE); \
			sed -i '' "/else/,/end/ s/sha256 \".*\"/sha256 \"$$X86_64_SHA256\"/" $(CASK_FILE); \
			sed -i '' "s|url \".*v#{version}/.*-ARM64.dmg\"|url \"https://github.com/samzong/$(APP_NAME)/releases/download/v#{version}/$(APP_NAME)-arm64.dmg\"|" $(CASK_FILE); \
			sed -i '' "s|url \".*v#{version}/.*-Intel.dmg\"|url \"https://github.com/samzong/$(APP_NAME)/releases/download/v#{version}/$(APP_NAME)-x86_64.dmg\"|" $(CASK_FILE); \
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
		git commit -m "chore: update $(APP_NAME) to v$(CLEAN_VERSION)"; \
		git push -u origin $(BRANCH_NAME); \
		pr_data=$$(printf '{"title":"chore: update %s to v%s","body":"Auto-generated PR\\n- Version: %s\\n- x86_64 SHA256: %s\\n- arm64 SHA256: %s","head":"%s","base":"main"}' \
			"$(APP_NAME)" "$(CLEAN_VERSION)" "$(CLEAN_VERSION)" "$$X86_64_SHA256" "$$ARM64_SHA256" "$(BRANCH_NAME)"); \
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
	@echo "  make dmg             - Create DMG installers (Intel and Apple Silicon)"
	@echo "  make version         - Show version information"
	@echo "  make check-arch      - 检查应用架构兼容性"
	@echo "  make update-homebrew - Update Homebrew cask (requires GH_PAT)"

.DEFAULT_GOAL := help
