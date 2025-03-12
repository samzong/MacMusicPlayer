.PHONY: clean dmg update-homebrew check-arch user-guide

# Variables
APP_NAME = MacMusicPlayer
BUILD_DIR = build
INTEL_ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME)-Intel.xcarchive
ARM64_ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME)-ARM64.xcarchive
INTEL_DMG_PATH = $(BUILD_DIR)/$(APP_NAME)-Intel.dmg
ARM64_DMG_PATH = $(BUILD_DIR)/$(APP_NAME)-ARM64.dmg
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

# Build for Intel
build-intel:
	@echo "==> 构建 Intel 架构的应用..."
	xcodebuild clean archive \
		-project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Release \
		-archivePath $(INTEL_ARCHIVE_PATH) \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="-" \
		DEVELOPMENT_TEAM="" \
		CURRENT_PROJECT_VERSION=$(VERSION) \
		MARKETING_VERSION=$(VERSION) \
		ARCHS="x86_64" \
		OTHER_CODE_SIGN_FLAGS="--options=runtime"

# Build for Apple Silicon
build-arm64:
	@echo "==> 构建 Apple Silicon 架构的应用..."
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

# Create DMG (builds Intel and Apple Silicon versions)
dmg: build-intel build-arm64
	# Export Intel archive
	xcodebuild -exportArchive \
		-archivePath $(INTEL_ARCHIVE_PATH) \
		-exportPath $(BUILD_DIR)/Intel \
		-exportOptionsPlist exportOptions.plist
	
	# Create temporary directory for Intel DMG
	rm -rf $(BUILD_DIR)/tmp-intel
	mkdir -p $(BUILD_DIR)/tmp-intel
	
	# Copy application to temporary directory
	cp -r "$(BUILD_DIR)/Intel/$(APP_NAME).app" "$(BUILD_DIR)/tmp-intel/"
	
	# 对 Intel 应用进行自签名
	@echo "==> 对 Intel 应用进行自签名..."
	codesign --force --deep --sign - "$(BUILD_DIR)/tmp-intel/$(APP_NAME).app"
	
	# Create symbolic link to Applications folder
	ln -s /Applications "$(BUILD_DIR)/tmp-intel/Applications"
	
	# Create Intel DMG
	hdiutil create -volname "$(DMG_VOLUME_NAME) (Intel)" \
		-srcfolder "$(BUILD_DIR)/tmp-intel" \
		-ov -format UDZO \
		"$(INTEL_DMG_PATH)"
	
	# Clean up
	rm -rf $(BUILD_DIR)/tmp-intel $(BUILD_DIR)/Intel
	
	# Export ARM64 archive
	xcodebuild -exportArchive \
		-archivePath $(ARM64_ARCHIVE_PATH) \
		-exportPath $(BUILD_DIR)/ARM64 \
		-exportOptionsPlist exportOptions.plist
	
	# Create temporary directory for ARM64 DMG
	rm -rf $(BUILD_DIR)/tmp-arm64
	mkdir -p $(BUILD_DIR)/tmp-arm64
	
	# Copy application to temporary directory
	cp -r "$(BUILD_DIR)/ARM64/$(APP_NAME).app" "$(BUILD_DIR)/tmp-arm64/"
	
	# 对 ARM64 应用进行自签名
	@echo "==> 对 ARM64 应用进行自签名..."
	codesign --force --deep --sign - "$(BUILD_DIR)/tmp-arm64/$(APP_NAME).app"
	
	# Create symbolic link to Applications folder
	ln -s /Applications "$(BUILD_DIR)/tmp-arm64/Applications"
	
	# Create ARM64 DMG
	hdiutil create -volname "$(DMG_VOLUME_NAME) (Apple Silicon)" \
		-srcfolder "$(BUILD_DIR)/tmp-arm64" \
		-ov -format UDZO \
		"$(ARM64_DMG_PATH)"
	
	# Clean up
	rm -rf $(BUILD_DIR)/tmp-arm64 $(BUILD_DIR)/ARM64
	
	# 检查架构兼容性
	@make check-arch
	
	@echo "==> 所有 DMG 文件已创建:"
	@echo "    - Intel 版本: $(INTEL_DMG_PATH)"
	@echo "    - Apple Silicon 版本: $(ARM64_DMG_PATH)"
	@echo ""
	@echo "注意: 这些应用使用了自签名，用户首次运行时可能需要在系统偏好设置中手动允许运行。"
	@echo "在 README 中添加相关说明可以帮助用户解决这个问题。"

# Check architecture compatibility
check-arch:
	@echo "==> 检查应用架构兼容性..."
	@if [ -f "$(INTEL_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" ]; then \
		echo "==> 检查 Intel 版本架构:"; \
		lipo -info "$(INTEL_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)"; \
		if lipo -info "$(INTEL_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" | grep -q "x86_64"; then \
			echo "✅ Intel 版本支持 x86_64 架构"; \
		else \
			echo "❌ Intel 版本不支持 x86_64 架构"; \
			exit 1; \
		fi; \
	fi
	
	@if [ -f "$(ARM64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" ]; then \
		echo "==> 检查 Apple Silicon 版本架构:"; \
		lipo -info "$(ARM64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)"; \
		if lipo -info "$(ARM64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" | grep -q "arm64"; then \
			echo "✅ Apple Silicon 版本支持 arm64 架构"; \
		else \
			echo "❌ Apple Silicon 版本不支持 arm64 架构"; \
			exit 1; \
		fi; \
	fi

# 添加用户指南命令
user-guide:
	@echo "==> MacMusicPlayer 用户指南"
	@echo "由于应用未经过 Apple 公证，用户首次运行时可能会遇到安全警告。"
	@echo ""
	@echo "解决方法:"
	@echo "1. 右键点击应用，选择'打开'"
	@echo "2. 在弹出的对话框中，点击'打开'"
	@echo "3. 之后应用将被系统记住，可以正常使用"
	@echo ""
	@echo "对于 Homebrew 用户，可以在安装后运行以下命令:"
	@echo "xattr -dr com.apple.quarantine /Applications/MacMusicPlayer.app"
	@echo ""
	@echo "这将移除应用的隔离属性，允许应用正常运行。"

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
	@curl -L -o tmp/$(APP_NAME)-Intel.dmg "https://github.com/samzong/$(APP_NAME)/releases/download/v$(CLEAN_VERSION)/$(APP_NAME)-Intel.dmg"
	@curl -L -o tmp/$(APP_NAME)-ARM64.dmg "https://github.com/samzong/$(APP_NAME)/releases/download/v$(CLEAN_VERSION)/$(APP_NAME)-ARM64.dmg"
	
	@echo "==> Calculating SHA256 checksums..."
	@INTEL_SHA256=$$(shasum -a 256 tmp/$(APP_NAME)-Intel.dmg | cut -d ' ' -f 1) && echo "    - Intel SHA256: $$INTEL_SHA256"
	@ARM64_SHA256=$$(shasum -a 256 tmp/$(APP_NAME)-ARM64.dmg | cut -d ' ' -f 1) && echo "    - ARM64 SHA256: $$ARM64_SHA256"
	
	@echo "==> Cloning Homebrew tap repository..."
	@cd tmp && git clone https://$(GH_PAT)@github.com/samzong/$(HOMEBREW_TAP_REPO).git
	@cd tmp/$(HOMEBREW_TAP_REPO) && echo "    - Creating new branch: $(BRANCH_NAME)" && git checkout -b $(BRANCH_NAME)

	@echo "==> Updating cask file..."
	@cd tmp/$(HOMEBREW_TAP_REPO) && \
	INTEL_SHA256=$$(shasum -a 256 ../$(APP_NAME)-Intel.dmg | cut -d ' ' -f 1) && \
	ARM64_SHA256=$$(shasum -a 256 ../$(APP_NAME)-ARM64.dmg | cut -d ' ' -f 1) && \
	cat > $(CASK_FILE) << EOF \
cask "mac-music-player" do\
  version "$(CLEAN_VERSION)"\
  \
  on_intel do\
    sha256 "$$INTEL_SHA256"\
    \
    url "https://github.com/samzong/MacMusicPlayer/releases/download/v#{version}/MacMusicPlayer-Intel.dmg"\
  end\
  \
  on_arm do\
    sha256 "$$ARM64_SHA256"\
    \
    url "https://github.com/samzong/MacMusicPlayer/releases/download/v#{version}/MacMusicPlayer-ARM64.dmg"\
  end\
  \
  name "MacMusicPlayer"\
  desc "Simple music player for macOS"\
  homepage "https://github.com/samzong/MacMusicPlayer"\
  \
  auto_updates false\
  \
  app "MacMusicPlayer.app"\
  \
  postflight do\
    system_command "/usr/bin/xattr",\
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/MacMusicPlayer.app"],\
                   sudo: false\
  end\
  \
  caveats <<~EOS\
    由于应用未经过 Apple 公证，首次运行时可能会遇到安全警告。\
    如果安装后仍然无法打开，请尝试在终端中运行:\
      xattr -dr com.apple.quarantine /Applications/MacMusicPlayer.app\
  EOS\
  \
  zap trash: [\
    "~/Library/Application Support/MacMusicPlayer",\
    "~/Library/Caches/MacMusicPlayer",\
    "~/Library/Preferences/com.seimotech.MacMusicPlayer.plist",\
  ]\
end\
EOF
	
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
			--arg body "Auto-generated PR\n- Version: $(CLEAN_VERSION)\n- Intel SHA256: $$INTEL_SHA256\n- ARM64 SHA256: $$ARM64_SHA256" \
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
	@echo "  make dmg             - Create DMG installers (Intel and Apple Silicon)"
	@echo "  make version         - Show version information"
	@echo "  make check-arch      - 检查应用架构兼容性"
	@echo "  make update-homebrew - Update Homebrew cask (requires GH_PAT)"
	@echo "  make user-guide      - 显示用户指南，帮助用户解决安全警告问题"

.DEFAULT_GOAL := help
