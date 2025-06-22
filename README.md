# MacMusicPlayer

<div align="center">
  <img src="./MacMusicPlayer/Assets.xcassets/AppIcon.appiconset/icon_256x256_2x.png" alt="mac-music-player logo" width="200" />
  <br />
  <p>MacMusicPlayer is an elegant and minimalist music player for macOS, designed as a menu bar application to provide a seamless music playback experience. Built with SwiftUI, it perfectly integrates into the macOS ecosystem, delivering an exceptional user experience.</p>
  <p>
    <a href="https://github.com/samzong/MacMusicPlayer/releases"><img src="https://img.shields.io/github/v/release/samzong/MacMusicPlayer" alt="Release Version" /></a>
    <a href="https://github.com/samzong/MacMusicPlayer/blob/main/LICENSE"><img src="https://img.shields.io/github/license/samzong/MacMusicPlayer" alt="MIT License" /></a>
    <a href="https://deepwiki.com/samzong/MacMusicPlayer"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>
  </p>
</div>

## 📦 Installation

### Method 1: Homebrew

Need to install Homebrew first, Follow the [Homebrew Installation Guide](https://brew.sh/) to install Homebrew.

```bash
brew tap samzong/tap
brew install samzong/tap/mac-music-player
```

### Method 2: Download DMG

Download the latest `MacMusicPlayer.dmg` from the [Releases](https://github.com/samzong/MacMusicPlayer/releases) page.

### ⚠️ About Security Warnings

Since the app is not notarized by Apple, you may encounter a security warning when first launching it. This is a macOS security feature and does not indicate any security issues with the app.

**Solution:**

1. **Right-click on the app** and select "Open" (instead of double-clicking)
2. In the dialog that appears, click "Open"
3. After this, the system will remember your choice and allow normal usage

**For Homebrew users**: The installation script automatically handles this issue, no additional steps required.

**If you still can't open the app**, run this command in Terminal:
```bash
xattr -dr com.apple.quarantine /Applications/MacMusicPlayer.app
```

## 🚀 Usage Guide

[![VIDEO](https://img.youtube.com/vi/fzz35W4FNkw/0.jpg)](https://www.youtube.com/watch?v=fzz35W4FNkw)

1. On first launch, click the menu bar icon and select "Set Music Source"
2. Choose a folder containing Audio files
3. Access the following features through the menu bar icon:
   - Play/Pause
   - Previous/Next Track
   - Switch Playback Mode
   - Download Music from Online Sources (Single tracks or entire playlists)
   - Enable/Disable System Sleep Prevention
   - Configure Launch at Login
   - Reconfigure Music Folder

## ✨ Key Features

- 🎵 Lightweight menu bar player for instant music control
- 🎨 Native macOS interface with perfect light/dark theme support
- 🌍 Multi-language support (English, Simplified Chinese, Traditional Chinese, Japanese, Korean)
- 🎧 Audio format support (mp3, m4a, wav, flac, acc, aiff, etc.)
- 🔄 Multiple playback modes (Sequential, Single Loop, Random)
- 📥 Download music from online sources (YouTube, SoundCloud, etc.)
- 🎵 Batch playlist download with intelligent URL detection
- 💾 Smart memory of last music folder location
- 🚀 Launch at login support
- 😴 Prevent system sleep for uninterrupted music
- ⌨️ Media key control support (Play/Pause/Previous/Next)

## 🛠 Technical Architecture

- **Framework**: SwiftUI + AppKit
- **Audio Engine**: AVFoundation
- **Design Pattern**: MVVM
- **Localization**: Multi-language support
- **State Management**: Native SwiftUI state management
- **Persistence**: UserDefaults
- **System Integration**: 
  - MediaPlayer framework for media control
  - ServiceManagement for launch at login
  - IOKit for sleep management
- **Download Engine**:
  - yt-dlp for online media extraction
  - ffmpeg for audio conversion

## 🔨 Development Guide

### Requirements

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+
- For music download feature: yt-dlp and ffmpeg (can be installed via Homebrew)

### Build Steps

1. Clone the repository
```bash
git clone https://github.com/samzong/MacMusicPlayer.git
```

2. Open the project
```bash
cd MacMusicPlayer
open MacMusicPlayer.xcodeproj
```

3. Build and Run
- Using Xcode: Command + R
- Using command line: `make build`

### Project Structure

```
MacMusicPlayer/
├── Managers/           # Business Managers
│   ├── PlayerManager   # Playback Control
│   ├── LaunchManager   # Launch Management
│   ├── SleepManager    # Sleep Control
│   └── DownloadManager # Music Download
├── Models/             # Data Models
├── Views/              # UI Components
├── Helpers/            # Utility Classes
└── Resources/          # Resource Files
```

### Localization Support

The project supports multiple languages with localization files located at:
- `MacMusicPlayer/en.lproj/`
- `MacMusicPlayer/zh-Hans.lproj/`
- `MacMusicPlayer/zh-Hant.lproj/`
- `MacMusicPlayer/ja.lproj/`
- `MacMusicPlayer/ko.lproj/`

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

## 🌟 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=samzong/macmusicplayer&type=Timeline)](https://star-history.com/#samzong/macmusicplayer&Timeline)

## 🙏 Acknowledgments

Thanks to all the developers who have contributed to this project!

---

For questions or suggestions, please feel free to open an Issue or Pull Request.
