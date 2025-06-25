# Developer Setup Guide

Complete guide for setting up MacMusicPlayer development environment.

## 🛠️ Prerequisites

### System Requirements
- **macOS 13.0+** (Ventura or later)
- **Xcode 15.0+** with Swift 5.9+
- **Homebrew** package manager
- **Git** for version control

### External Tools (for download features)
```bash
brew install yt-dlp ffmpeg
```

## 📦 Project Setup

### 1. Clone Repository
```bash
git clone https://github.com/samzong/MacMusicPlayer.git
cd MacMusicPlayer
```

### 2. Open in Xcode
```bash
open MacMusicPlayer.xcodeproj
```

### 3. Verify Build Settings
- **Deployment Target**: macOS 13.0
- **Swift Language Version**: Swift 5
- **Code Signing**: Development Team set (for testing)

## 🔨 Build System

MacMusicPlayer uses a **Makefile-based build system** for distribution and a **direct Xcode workflow** for development.

### Development Builds

#### Quick Development Build
```bash
make build
```
- Builds for current architecture
- Uses development code signing
- Output: `build/Release/MacMusicPlayer.app`

#### Install Locally
```bash
make install-app
```
- Builds and installs to `/Applications/`
- Requires `sudo` permissions
- Automatically removes existing version

### Distribution Builds

#### Create DMG Packages
```bash
make dmg
```
- Builds both x86_64 and arm64 versions
- Creates signed DMG files
- Output: `build/MacMusicPlayer-{arch}.dmg`

#### Clean Build Artifacts
```bash
make clean
```

### Version Management
```bash
make version
```
Shows current version info:
```
Version:     Dev-abc1234
Git Commit:  abc1234
```

## 🏗️ Project Structure

```
MacMusicPlayer/
├── MacMusicPlayer.xcodeproj/          # Xcode project
├── MacMusicPlayer/                    # Source code
│   ├── AppDelegate.swift              # App coordinator
│   ├── MacMusicPlayerApp.swift        # SwiftUI app entry
│   ├── Managers/                      # Business logic
│   │   ├── PlayerManager.swift        # Audio playback
│   │   ├── LibraryManager.swift       # Music libraries
│   │   ├── DownloadManager.swift      # Online downloads
│   │   ├── ConfigManager.swift        # Settings
│   │   ├── SleepManager.swift         # Sleep prevention
│   │   ├── LaunchManager.swift        # Auto-launch
│   │   └── YTSearchManager.swift      # Search API
│   ├── Models/                        # Data structures
│   │   ├── Track.swift                # Music track
│   │   └── MusicLibrary.swift         # Library metadata
│   ├── Views/                         # SwiftUI views
│   │   ├── ContentView.swift          # Main interface
│   │   ├── ControlOverlay.swift       # Playback controls
│   │   └── CustomTableRowView.swift   # Track list
│   ├── Controllers/                   # AppKit controllers
│   │   ├── ConfigViewController.swift # Settings window
│   │   └── DownloadViewController.swift # Download interface
│   ├── Resources/                     # Assets and localization
│   │   └── Localization/             # 5 language files
│   ├── Assets.xcassets/              # App icons and images
│   ├── Info.plist                    # App configuration
│   └── MacMusicPlayer.entitlements   # Security permissions
├── Makefile                          # Build automation
├── exportOptions.plist               # Export configuration
└── docs/                             # Documentation
```

## 🔧 Development Workflow

### 1. **Local Development**
- Use Xcode for day-to-day development
- Run directly from Xcode for debugging
- Use `make build` for testing distribution builds

### 2. **Code Organization**
- **Managers**: Business logic, one responsibility per manager
- **Models**: Simple data structures, `Codable` when needed
- **Views**: Lightweight SwiftUI components
- **Controllers**: AppKit integration for complex UI

### 3. **Styling Guidelines**
```swift
// GOOD: Clear, descriptive names
func addLibrary(name: String, path: String) { }

// GOOD: @Published for reactive properties
@Published var currentTrack: Track?

// GOOD: Error handling with custom errors
enum DownloadError: Error {
    case ytDlpNotFound
}
```

## 🧪 Testing Strategy

### Manual Testing Checklist
- [ ] App launches and shows menu bar icon
- [ ] Music library loads and displays tracks
- [ ] Playback controls work (play/pause/next/previous)
- [ ] Equalizer settings apply correctly
- [ ] Download features work (requires yt-dlp/ffmpeg)
- [ ] Settings persist across app restarts
- [ ] Multi-language support functions

### Debug Builds
```bash
# Build with debug configuration
xcodebuild -scheme MacMusicPlayer -configuration Debug

# Run with debug logging
./MacMusicPlayer.app/Contents/MacOS/MacMusicPlayer
```

### Performance Testing
- Monitor memory usage in Activity Monitor
- Test with large music libraries (1000+ tracks)
- Verify audio doesn't stutter during UI operations

## 🔍 Debugging Tools

### 1. **Xcode Debugger**
- Set breakpoints in manager classes
- Use View Hierarchy debugger for UI issues
- Memory graph debugger for leak detection

### 2. **Console Logging**
```swift
// Already included throughout the codebase
print("PlayerManager: Loading track \(track.title)")
```

### 3. **External Tool Debugging**
```bash
# Test yt-dlp directly
yt-dlp --list-formats "https://youtube.com/watch?v=..."

# Test ffmpeg
ffmpeg -i input.webm -acodec mp3 output.mp3
```

## 🚀 Distribution Process

### 1. **Prepare Release**
```bash
# Tag release
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# Build distribution packages
CI_BUILD=1 make dmg
```

### 2. **Sign Packages** (Optional)
For distribution outside Mac App Store:
```bash
# Self-signing is automatic in Makefile
# For developer signing, update TEAM_ID in Makefile
```

### 3. **Update Homebrew** (Automated)
```bash
# Only run from CI with GH_PAT token
make update-homebrew
```

## 🔐 Security Considerations

### Code Signing
- Development builds use self-signing (`CODE_SIGN_IDENTITY="-"`)
- Distribution builds can use developer certificates
- Entitlements disable sandboxing for external tool access

### External Tools
- yt-dlp and ffmpeg are user-installed dependencies
- Path validation prevents arbitrary command execution
- Process arguments are carefully controlled

## 📝 Code Contribution Guidelines

### 1. **Branch Strategy**
```bash
# Create feature branch
git checkout -b feature/new-equalizer-preset

# Make changes and commit
git commit -m "feat: add electronic equalizer preset"

# Push and create PR
git push origin feature/new-equalizer-preset
```

### 2. **Code Style**
- Follow Swift conventions
- Use `@Published` for reactive properties
- Handle errors with proper Error types
- Add localized strings for user-facing text

### 3. **Testing Requirements**
- Test on multiple macOS versions if possible
- Verify both Intel and Apple Silicon compatibility
- Test with and without external tools installed

### 4. **Documentation**
- Update relevant documentation for new features
- Add inline comments for complex business logic
- Update CLAUDE.md for new build commands

## 🆘 Common Issues

### Build Failures
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/MacMusicPlayer-*

# Reset Xcode settings
defaults delete com.apple.dt.Xcode
```

### Code Signing Issues
```bash
# Reset signing identity
security delete-identity -c "Mac Developer"
# Re-add in Xcode Preferences > Accounts
```

### External Tool Issues
```bash
# Verify tools are in PATH
which yt-dlp
which ffmpeg

# Reinstall if needed
brew reinstall yt-dlp ffmpeg
```

---

🎉 **You're ready to contribute!** Start with small changes and gradually work up to larger features. The modular architecture makes it easy to add new functionality without breaking existing code.