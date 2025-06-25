# Build System Guide

Comprehensive guide to MacMusicPlayer's build system, distribution process, and automation tools.

## 🔨 Build System Overview

MacMusicPlayer uses a **dual build approach**:
- **Xcode**: Development and debugging
- **Makefile**: Distribution and automation

This separation allows developers to use familiar Xcode workflows while providing consistent, automated builds for releases.

## 🛠️ Makefile Build System

### Build Targets

The Makefile provides several build targets for different use cases:

```makefile
# Available targets
make help           # Show all available commands
make clean          # Clean build artifacts
make build          # Development build (current architecture)
make install-app    # Build and install to /Applications
make dmg            # Create distribution DMG files
make version        # Show version information
make check-arch     # Verify architecture compatibility
```

### Development Builds

#### Quick Development Build
```bash
make build
```

**What it does**:
- Builds for current architecture only
- Uses development code signing (`CODE_SIGN_IDENTITY="-"`)
- Output: `build/Release/MacMusicPlayer.app`
- Fast iteration for testing

**Build Configuration**:
```makefile
CONFIGURATION = Release
BUILT_APP_PATH = $(BUILD_DIR)/$(CONFIGURATION)/$(APP_NAME).app

build:
    xcodebuild \
        -scheme $(APP_NAME) \
        -configuration $(CONFIGURATION) \
        -destination 'platform=macOS' \
        build \
        SYMROOT=$(BUILD_DIR) \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY="-" \
        DEVELOPMENT_TEAM=""
```

#### Local Installation
```bash
make install-app
```

**Process**:
1. Builds app using `make build`
2. Removes existing installation at `/Applications/MacMusicPlayer.app`
3. Copies new build to `/Applications/`
4. Requires `sudo` for system directory access

**Safety Features**:
- Checks for existing installation before copying
- Validates build exists before installation
- Provides clear error messages

### Distribution Builds

#### Universal DMG Creation
```bash
make dmg
```

**Multi-Architecture Process**:
1. **Build x86_64 version** (`make build-x86_64`)
2. **Build arm64 version** (`make build-arm64`)
3. **Export both archives** using `exportOptions.plist`
4. **Self-sign applications** for distribution
5. **Create DMG files** for each architecture
6. **Verify architecture compatibility**

**Architecture-Specific Builds**:
```makefile
# Intel (x86_64) build
build-x86_64:
    xcodebuild clean archive \
        -project $(APP_NAME).xcodeproj \
        -scheme $(APP_NAME) \
        -configuration Release \
        -archivePath $(X86_64_ARCHIVE_PATH) \
        ARCHS="x86_64"

# Apple Silicon (arm64) build  
build-arm64:
    xcodebuild clean archive \
        -project $(APP_NAME).xcodeproj \
        -scheme $(APP_NAME) \
        -configuration Release \
        -archivePath $(ARM64_ARCHIVE_PATH) \
        ARCHS="arm64"
```

#### DMG Package Contents
Each DMG contains:
- `MacMusicPlayer.app` (architecture-specific)
- Symbolic link to `/Applications` folder
- Self-signed for immediate use

**DMG Naming Convention**:
- `MacMusicPlayer-x86_64.dmg` (Intel Macs)
- `MacMusicPlayer-arm64.dmg` (Apple Silicon)

### Version Management

#### Dynamic Versioning
```bash
make version
```

**Version Sources**:
```makefile
# Development builds use git commit hash
VERSION ?= $(if $(CI_BUILD),$(shell git describe --tags --always),Dev-$(shell git rev-parse --short HEAD))

# Example outputs:
# Development: Dev-abc1234
# Release: v1.0.0 (when CI_BUILD=1)
```

**Info.plist Integration**:
- `CURRENT_PROJECT_VERSION`: Full version string
- `MARKETING_VERSION`: Clean version for display
- `GitCommit`: Development commit hash

#### Version Display in App
```swift
private func getVersionString() -> String {
    #if DEBUG
        let gitCommit = Bundle.main.object(forInfoDictionaryKey: "GitCommit") as? String ?? "unknown"
        return String(format: NSLocalizedString("Dev: %@", comment: ""), gitCommit)
    #else
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return String(format: NSLocalizedString("Version %@", comment: ""), appVersion)
    #endif
}
```

## 🔐 Code Signing Strategy

### Development Signing
```makefile
CODE_SIGN_STYLE=Manual
CODE_SIGN_IDENTITY="-"          # Self-signed
DEVELOPMENT_TEAM=""             # No team required
```

**Benefits**:
- No developer account required
- Immediate local testing
- No provisioning profile dependencies

**Limitations**:
- Gatekeeper warnings on other machines
- No automatic updates capability
- Manual security bypass required

### Distribution Signing

For official releases, update Makefile variables:
```makefile
SELF_SIGN = false
TEAM_ID = YOUR_TEAM_ID
APPLE_ID = your@email.com
APP_BUNDLE_ID = com.seimotech.MacMusicPlayer
```

**Advanced Signing Options**:
```makefile
# Developer ID signing (outside Mac App Store)
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"

# Notarization support
OTHER_CODE_SIGN_FLAGS="--options=runtime"
```

## 🚀 CI/CD Integration

### GitHub Actions Integration

The build system supports automated releases:

```yaml
# Example GitHub Actions workflow
name: Build and Release
on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build DMG
        run: CI_BUILD=1 make dmg
      - name: Upload Release
        uses: actions/upload-artifact@v3
        with:
          name: dmg-packages
          path: build/*.dmg
```

### Homebrew Automation

```bash
# Automated Homebrew cask updates (CI only)
GH_PAT=github_token make update-homebrew
```

**Process**:
1. Downloads released DMG files
2. Calculates SHA256 checksums
3. Updates Homebrew cask file
4. Creates pull request automatically

## 🔧 Build Configuration

### Export Options
**File**: `exportOptions.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
</dict>
</plist>
```

### Xcode Project Settings

**Key Build Settings**:
- **Deployment Target**: macOS 13.0
- **Swift Language Version**: Swift 5
- **Architectures**: Standard (x86_64, arm64)
- **Code Signing**: Manual

**Info.plist Configuration**:
```xml
<key>LSUIElement</key>
<true/>                    <!-- Menu bar app, no dock icon -->

<key>NSPowerManagementUsageDescription</key>
<string>Prevent system sleep for uninterrupted music playback</string>

<key>CFBundleIdentifier</key>
<string>com.seimotech.MacMusicPlayer</string>
```

## 🧹 Build Maintenance

### Cleaning Build Artifacts
```bash
make clean
```

**Removes**:
- `build/` directory contents
- Xcode derived data for project
- Temporary export files

### Architecture Verification
```bash
make check-arch
```

**Validates**:
- x86_64 build contains Intel architecture
- arm64 build contains Apple Silicon architecture  
- Binary compatibility with target systems

**Example Output**:
```
==> Checking x86_64 version architecture:
Architectures in the fat file: MacMusicPlayer are: x86_64
✅ x86_64 version supports x86_64 architecture

==> Checking arm64 version architecture:  
Architectures in the fat file: MacMusicPlayer are: arm64
✅ arm64 version supports arm64 architecture
```

## 🐛 Build Troubleshooting

### Common Build Issues

#### Code Signing Failures
```bash
# Error: No signing identity found
# Solution: Verify signing configuration
security find-identity -v -p codesigning

# Reset signing if needed
make clean
```

#### Missing Dependencies
```bash
# Error: yt-dlp not found during testing
# Solution: Install external tools
brew install yt-dlp ffmpeg
```

#### Architecture Mismatches
```bash
# Error: Wrong architecture built
# Solution: Clean and rebuild
make clean
make dmg
```

### Build Performance Optimization

#### Parallel Builds
```makefile
# Enable parallel builds (automatic in Xcode 14+)
xcodebuild -parallelizeTargets
```

#### Build Cache Management
```bash
# Clear Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/MacMusicPlayer-*

# Clear build cache
make clean
```

## 📊 Build Metrics

### Build Times (Typical)

| Build Type | Duration | Output Size |
|------------|----------|-------------|
| Development | 30-60s | ~15MB |
| Single DMG | 2-3 mins | ~25MB |
| Universal DMG | 4-6 mins | ~50MB total |

### Size Analysis
```bash
# Analyze app bundle size
du -sh build/Release/MacMusicPlayer.app

# Binary size breakdown
otool -l build/Release/MacMusicPlayer.app/Contents/MacOS/MacMusicPlayer
```

## 🔄 Continuous Integration

### Local CI Simulation
```bash
# Simulate CI build process
CI_BUILD=1 make dmg

# Verify release-ready builds
make check-arch
make version
```

### Release Checklist
- [ ] Clean build environment (`make clean`)
- [ ] Update version tags (`git tag v1.0.0`)
- [ ] Build universal DMGs (`CI_BUILD=1 make dmg`)
- [ ] Verify architecture compatibility (`make check-arch`)
- [ ] Test installation on clean system
- [ ] Update documentation if needed

---

This build system provides a robust foundation for both development iteration and production releases, ensuring consistent, reliable builds across different environments and architectures.