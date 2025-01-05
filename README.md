# MacMusicPlayer

MacMusicPlayer is an elegant and minimalist music player for macOS, designed as a menu bar application to provide a seamless music playback experience. Built with SwiftUI, it perfectly integrates into the macOS ecosystem, delivering an exceptional user experience.

![Application Screenshot](image.png)

## ✨ Key Features

- 🎵 Lightweight menu bar player for instant music control
- 🎨 Native macOS interface with perfect light/dark theme support
- 🌍 Multi-language support (English, Simplified Chinese, Traditional Chinese, Japanese, Korean)
- 🎧 MP3 audio format playback
- 🔄 Multiple playback modes (Sequential, Single Loop, Random)
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

## 📦 Installation

### Method 1: Direct Download

1. Download the latest `MacMusicPlayer.dmg` from the [Releases](https://github.com/samzong/MacMusicPlayer/releases) page
2. Open the DMG file and drag MacMusicPlayer to your Applications folder
3. If you encounter a security prompt on first launch, go to "System Settings" > "Security & Privacy" to allow the application to run

```bash
sudo xattr -r -d com.apple.quarantine /Applications/MacMusicPlayer.app
```

### Method 2: Command Line Installation (Developers)

```bash
git clone https://github.com/samzong/MacMusicPlayer.git
cd MacMusicPlayer
make install
```

### Uninstallation

```bash
make uninstall
```

## 🚀 Usage Guide

1. On first launch, click the menu bar icon and select "Set Music Source"
2. Choose a folder containing MP3 files
3. Access the following features through the menu bar icon:
   - Play/Pause
   - Previous/Next Track
   - Switch Playback Mode
   - Enable/Disable System Sleep Prevention
   - Configure Launch at Login
   - Reconfigure Music Folder

## 🔨 Development Guide

### Requirements

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

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
│   └── SleepManager    # Sleep Control
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

## 📝 Development Roadmap

- [ ] Support for more audio formats (FLAC, WAV, AAC, etc.)
- [ ] Add audio visualization effects
- [ ] Playlist management support
- [ ] Add audio equalizer
- [ ] Online music service integration
- [ ] Add keyboard shortcut support
- [ ] Audio format conversion support

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

## 🌟 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=samzong/macmusicplayer&type=Timeline)](https://star-history.com/#samzong/macmusicplayer&Timeline)

## 🙏 Acknowledgments

Thanks to all the developers who have contributed to this project!

---

For questions or suggestions, please feel free to open an Issue or Pull Request.
