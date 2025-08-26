# MacMusicPlayer

[English](README.md) | [简体中文](README_zh.md)

<div align="center">
  <img src="./MacMusicPlayer/Assets.xcassets/AppIcon.appiconset/icon_256x256_2x.png" alt="mac-music-player logo" width="200" />
  <br />
  <div id="download-section" style="margin: 20px 0;">
    <a href="#" onclick="downloadLatest(); return false;" style="text-decoration: none;">
      <img src="https://img.shields.io/badge/⬇%20Download%20for%20Your%20System-28a745?style=for-the-badge&labelColor=28a745" alt="Download" />
    </a>
  </div>
  <p>An elegant and minimalist music player for macOS, designed as a menu bar application to provide a seamless music playback experience. Built with SwiftUI, it perfectly integrates into the macOS ecosystem.</p>
  <p>
    <a href="https://github.com/samzong/MacMusicPlayer/releases"><img src="https://img.shields.io/github/v/release/samzong/MacMusicPlayer" alt="Release Version" /></a>
    <a href="https://github.com/samzong/MacMusicPlayer/blob/main/LICENSE"><img src="https://img.shields.io/github/license/samzong/MacMusicPlayer" alt="MIT License" /></a>
    <a href="https://deepwiki.com/samzong/MacMusicPlayer"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>
  </p>
</div>

## 📦 Installation

### Homebrew (Recommended)

```bash
brew tap samzong/tap
brew install mac-music-player
```

### Download DMG

Download the latest `MacMusicPlayer.dmg` from the [Releases](https://github.com/samzong/MacMusicPlayer/releases) page.

> **Security Note**: If you encounter a security warning on first launch, right-click the app and select "Open", or run: `xattr -dr com.apple.quarantine /Applications/MacMusicPlayer.app`

## ✨ Key Features

- 🎵 Lightweight menu bar player for instant music control
- 🎨 Native macOS interface with perfect light/dark theme support
- 🌍 Multi-language support (English, Chinese, Japanese, Korean)
- 🎧 Audio format support (mp3, m4a, wav, flac, aac, aiff, etc.)
- 🔄 Multiple playback modes (Sequential, Single Loop, Random)
- 📥 Download music from online sources (YouTube, SoundCloud, etc.)
- 💾 Smart memory of last music folder location
- 🚀 Launch at login support
- 😴 Prevent system sleep for uninterrupted music
- ⌨️ Media key control support

## 📷 Screenshots

### Menu Items

![](MenuItems.png)

### Download Music

![](DownloadMusic.png)


## 🛠 Development

For detailed development guide, see: [Developer Documentation](docs/developer_guide.md)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit Issues and Pull Requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
