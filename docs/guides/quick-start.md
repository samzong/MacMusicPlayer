# Quick Start Guide

Get up and running with MacMusicPlayer in minutes!

## 📦 Installation

### Option 1: Homebrew (Recommended)
```bash
# Add the tap
brew tap samzong/tap

# Install MacMusicPlayer
brew install mac-music-player
```

### Option 2: Direct Download
1. Visit the [Releases page](https://github.com/samzong/MacMusicPlayer/releases)
2. Download the latest `MacMusicPlayer-{architecture}.dmg`
3. Open the DMG and drag MacMusicPlayer to Applications

### 🛡️ Security Note
If you see "MacMusicPlayer can't be opened because it is from an unidentified developer":

1. **Right-click** the app → **Open** → **Open** (bypass Gatekeeper)
2. Or run in Terminal:
   ```bash
   xattr -dr com.apple.quarantine /Applications/MacMusicPlayer.app
   ```

## 🚀 First Launch

### 1. Launch the App
- Open MacMusicPlayer from Applications or Launchpad
- Look for the headphones icon in your menu bar

### 2. Add Your Music Library
On first launch, you'll be prompted to select your music folder:

1. Click the **headphones icon** in menu bar
2. Select **"Add New Library"**
3. Navigate to your music folder (e.g., `~/Music`)
4. Click **"Choose"**

### 3. Start Playing
- Click the menu bar icon to see your music library
- Select any track to start playback
- Use playback controls in the menu

## 🎵 Basic Usage

### Menu Bar Controls
```
🎧 MacMusicPlayer Menu
├── Current Track Info
├── ⏯️ Play/Pause
├── ⏮️ Previous Track  
├── ⏭️ Next Track
├── 🔀 Playback Mode
├── 🎛️ Equalizer
├── 📚 Music Libraries
├── 📥 Download Music
└── ⚙️ Settings
```

### Keyboard Shortcuts
- **Play/Pause**: Media keys or F8
- **Next Track**: F9
- **Previous Track**: F7
- **Volume**: F10-F12

### Playback Modes
- **Sequential**: Play tracks in order
- **Single Loop**: Repeat current track
- **Random**: Shuffle through library

## 🎛️ Essential Features

### Multiple Music Libraries
Organize different music collections:
1. **Music Libraries** → **Add New Library**
2. Choose folder and give it a name
3. Switch between libraries from the menu

### Download Online Music
Set up online downloading (requires external tools):

1. Install dependencies:
   ```bash
   brew install yt-dlp ffmpeg
   ```

2. **Download Music** from menu bar
3. Configure API settings if using search features

### Equalizer
Enhance your audio experience:
1. **Equalizer** → **Enable Equalizer**
2. Choose from presets or adjust Bass/Mid/Treble manually
3. Settings are automatically saved

## ⚙️ Configuration

### Auto-Launch at Login
**Settings** → **Launch at Login** ✓

### Prevent System Sleep
**Prevent Mac Sleep** ✓ (useful for long playlists)

### API Configuration
For online search features:
1. **Settings** → Configure API URL and Key
2. Enter your YouTube API credentials (optional)

## 🌍 Language Support

MacMusicPlayer supports 5 languages:
- English
- 简体中文 (Simplified Chinese)
- 繁體中文 (Traditional Chinese)  
- 日本語 (Japanese)
- 한국어 (Korean)

Language is automatically detected from system preferences.

## 🎧 Supported Audio Formats

- **MP3** (.mp3)
- **M4A** (.m4a)
- **WAV** (.wav)
- **FLAC** (.flac)
- **AAC** (.aac)
- **AIFF** (.aiff)

## 🔧 Troubleshooting

### Music Not Playing?
1. Check file format is supported
2. Verify file permissions in music folder
3. Try refreshing the current library

### Menu Bar Icon Missing?
1. Look in **System Preferences** → **Dock & Menu Bar**
2. Restart MacMusicPlayer
3. Check if app is running in Activity Monitor

### Download Features Not Working?
1. Install required tools:
   ```bash
   brew install yt-dlp ffmpeg
   ```
2. Verify installation in Download window

## 📞 Getting Help

- **Issues**: [GitHub Issues](https://github.com/samzong/MacMusicPlayer/issues)
- **Documentation**: [Full Documentation](../index.md)
- **Troubleshooting**: [Detailed Troubleshooting Guide](troubleshooting.md)

---

🎉 **Congratulations!** You're now ready to enjoy your music with MacMusicPlayer. For advanced features and customization, explore the [Feature Guide](features.md).