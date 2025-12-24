# MacMusicPlayer

<div align="center">
  <img src="./MacMusicPlayer/Assets.xcassets/AppIcon.appiconset/icon_256x256_2x.png" alt="MacMusicPlayer" width="128" />
  <br />
  <div id="download-section" style="margin: 20px 0;">
    <a href="#" onclick="downloadLatest(); return false;" style="text-decoration: none;">
      <img src="https://img.shields.io/badge/⬇%20Download%20for%20Your%20System-28a745?style=for-the-badge&labelColor=28a745" alt="Download" />
    </a>
  </div>
  <p>An elegant and minimalist menu bar music player for macOS (no Dock icon), providing a seamless music playback experience.</p>
  <p>
    <a href="https://github.com/samzong/MacMusicPlayer/releases"><img src="https://img.shields.io/github/v/release/samzong/MacMusicPlayer" alt="Release" /></a>
    <a href="https://github.com/samzong/MacMusicPlayer/blob/main/LICENSE"><img src="https://img.shields.io/github/license/samzong/MacMusicPlayer" alt="License" /></a>
    <a href="https://deepwiki.com/samzong/MacMusicPlayer"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>
  </p>
</div>

## Requirements

- macOS 12.0 (Monterey) or later

## Installation

### Homebrew (Recommended)

```bash
brew install samzong/tap/mac-music-player
```

### DMG

Download the latest `MacMusicPlayer.dmg` from the [Releases](https://github.com/samzong/MacMusicPlayer/releases) page.

> **Security Note**: If you encounter a security warning on first launch, right-click the app and select "Open", or run: `xattr -dr com.apple.quarantine /Applications/MacMusicPlayer.app`

## Features

- 🎵 Lightweight menu bar player for instant music control
- 🎨 Native macOS interface with perfect light/dark theme support
- 🌍 Multi-language support (English, Simplified Chinese, Traditional Chinese, Japanese, Korean)
- 🔎 Song picker (⌘F in menu) with instant filename filtering
- 🎧 Audio format support (mp3, m4a, wav, flac, aac, ogg, aiff)
- 🔄 Multiple playback modes (Sequential, Single Loop, Random)
- 📚 Multiple music libraries with quick switch (⌘R to refresh)
- 📥 Built-in YouTube/SoundCloud search & playlist downloads with format selection (requires yt-dlp + ffmpeg)
- 💾 Smart memory of last music folder location and volume
- 🚀 Launch at login (enabled by default)
- 🌙 Prevent-sleep toggle (enabled by default) and configurable song picker on launch
- ⌨️ Media key control and keyboard shortcuts (⌘D Download, ⌘S Settings)

## Configuration & Tips

- Download dependencies (yt-dlp, ffmpeg) are installed automatically via Homebrew; manual install (`brew install yt-dlp ffmpeg`) is required for DMG users.
- Configure API URL and API Key in **Settings** to enable YouTube search (requires a custom search proxy service).
- Pick the destination library in the Download window; use **Download All** button to download entire playlists, or **Refresh Current Library** to rescan music quickly.
- For best metadata display, name your files as `Artist - Title.mp3` format.

## Screenshots

### Menu Items

![](MenuItems.png)

### Download Music

![](DownloadMusic.png)

## Contributing

Contributions are welcome! Please feel free to submit Issues and Pull Requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
