# Feature Guide

Comprehensive guide to all MacMusicPlayer features and capabilities.

## 🎵 Core Music Playback

### Supported Audio Formats

MacMusicPlayer supports all major audio formats:

| Format | Extension | Quality | Notes |
|--------|-----------|---------|-------|
| **MP3** | .mp3 | Good | Universal compatibility |
| **M4A** | .m4a | High | Apple's preferred format |
| **FLAC** | .flac | Lossless | Best quality, larger files |
| **WAV** | .wav | Lossless | Uncompressed audio |
| **AAC** | .aac | High | Efficient compression |
| **AIFF** | .aiff | Lossless | Apple's uncompressed format |

### Playback Controls

Access via menu bar icon or media keys:

```
🎧 Menu Bar Controls
├── ⏯️  Play/Pause     (Space or Media Key)
├── ⏮️  Previous Track  (F7 or Cmd+Left)
├── ⏭️  Next Track      (F9 or Cmd+Right)  
├── 🔊  Volume Control  (F10-F12)
└── 🎛️  Equalizer      (Custom controls)
```

### Playback Modes

**Sequential Mode** (Default)
- Plays tracks in library order
- Stops at end of library

**Single Loop Mode**
- Repeats current track indefinitely
- Perfect for focus music or sleep sounds

**Random Mode**
- Shuffles through entire library
- Each track plays once before reshuffling

**Switch modes**: Menu Bar → Playback Mode → Select mode

## 📚 Music Library Management

### Multiple Libraries

Organize different music collections separately:

**Use Cases**:
- **Work Music**: Focus/productivity playlists
- **Personal**: Full music collection
- **Genres**: Jazz, Rock, Classical libraries
- **Occasions**: Party, Chill, Workout music

**Managing Libraries**:
```
Menu Bar → Music Libraries
├── 🎵 Current Libraries (with ✓ for active)
├── ➕ Add New Library
├── 🔄 Refresh Current Library  
├── ✏️ Rename Current Library
└── 🗑️ Delete Current Library
```

### Library Operations

**Add New Library**:
1. Menu Bar → Music Libraries → Add New Library
2. Choose folder containing music files
3. Enter a descriptive name
4. Library is automatically scanned and activated

**Switch Between Libraries**:
- Click any library name in the menu
- Current library shows checkmark (✓)
- Player automatically loads new library

**Refresh Library**:
- Updates track list with new files
- Removes deleted files from display
- Keyboard shortcut: `Cmd+R`

**Rename Library**:
1. Menu Bar → Music Libraries → Rename Current Library
2. Enter new name in dialog
3. Name change is immediate

**Delete Library**:
- Only removes from app (files remain on disk)
- Cannot delete if only one library exists
- Confirmation dialog prevents accidents

### Smart Library Features

**Automatic Scanning**:
- Recursively scans all subdirectories
- Detects audio metadata (title, artist, duration)
- Ignores hidden files and unsupported formats

**Last Used Memory**:
- App remembers most recently used library
- Automatically loads on next startup
- Switches instantly between sessions

## 🎛️ Audio Enhancement

### 3-Band Equalizer

Professional-grade audio enhancement with three frequency bands:

**Frequency Ranges**:
- **Bass**: Low frequencies (20Hz - 250Hz)
- **Mid**: Mid frequencies (250Hz - 4kHz)  
- **Treble**: High frequencies (4kHz - 20kHz)

**Controls**:
- Range: -12dB to +12dB for each band
- Real-time adjustment with immediate effect
- Settings automatically saved

**Enable Equalizer**:
Menu Bar → Equalizer → Enable Equalizer ✓

### Equalizer Presets

Seven professionally tuned presets for different music styles:

| Preset | Bass | Mid | Treble | Best For |
|--------|------|-----|--------|----------|
| **Flat** | 0dB | 0dB | 0dB | Neutral/Reference |
| **Classical** | 0dB | 0dB | +3dB | Orchestral, acoustic |
| **Rock** | +3dB | 0dB | +3dB | Guitar-heavy music |
| **Pop** | +1dB | +2dB | +2dB | Vocal-focused tracks |
| **Jazz** | +2dB | -1dB | +1dB | Instrumental jazz |
| **Electronic** | +4dB | 0dB | +2dB | EDM, techno |
| **Hip-Hop** | +5dB | -1dB | 0dB | Bass-heavy tracks |

**Apply Preset**:
Menu Bar → Equalizer → Presets → Select preset

**Custom Settings**:
- Adjust individual sliders after selecting preset
- Creates custom EQ curve
- Reset: Menu Bar → Equalizer → Reset Equalizer

## 📥 Online Music Download

### Supported Platforms

Download audio from popular platforms:
- **YouTube**: Videos and playlists
- **SoundCloud**: Tracks and playlists
- **Bandcamp**: Albums and tracks
- **Vimeo**: Video audio tracks
- **Other platforms**: Any site supported by yt-dlp

### Prerequisites

Install required tools via Homebrew:
```bash
brew install yt-dlp ffmpeg
```

**Tool Functions**:
- **yt-dlp**: Extracts audio streams from videos
- **ffmpeg**: Converts audio to desired formats

### Download Interface

Access: Menu Bar → Download Music

**Interface Components**:
```
Download Window
├── URL Input Field
├── 🔍 Detect/Search Button
├── 📋 Format Selection Table
├── 📁 Library Destination Selector
├── 📊 Progress Indicator
└── ℹ️ Tool Version Status
```

### Single Track Download

**Step-by-step**:
1. **Copy URL** from browser (YouTube, SoundCloud, etc.)
2. **Paste URL** in MacMusicPlayer download window
3. **Click "Detect"** to fetch available formats
4. **Select format** from table:
   - **MP3**: Best compatibility
   - **M4A**: Higher quality, smaller files
   - **WAV**: Uncompressed (very large)
5. **Choose destination library**
6. **Click "Download"**

**Format Selection Tips**:
- **Quality**: Higher bitrate = better quality
- **Size**: Consider available disk space
- **Compatibility**: MP3 works everywhere

### Playlist Download

**Bulk Download Features**:
1. **Paste playlist URL** (YouTube, SoundCloud)
2. **View playlist info**:
   - Title and creator
   - Track count
   - Individual track list
3. **Select tracks** to download (or all)
4. **Choose format and destination**
5. **Monitor batch progress**

**Progress Tracking**:
- Current track being downloaded
- Completed/failed count
- Overall progress percentage

### Download Management

**Download Locations**:
- Files saved to selected music library
- Automatically added to library after download
- Organized by artist/album when metadata available

**Quality Settings**:
- App automatically selects best available audio-only format
- Prioritizes common formats (MP3, M4A)
- Fallback to video conversion if needed

**Error Handling**:
- Retries failed downloads automatically
- Skips unavailable/restricted content
- Detailed error messages for troubleshooting

## 🔧 System Integration

### Menu Bar Operation

**Always Accessible**:
- Persistent menu bar icon
- Quick access to all features
- Minimal system resource usage

**Visual Indicators**:
- **Playing**: Filled headphones icon 🎧
- **Paused**: Outline headphones icon
- **Loading**: Spinning refresh icon

### Media Key Support

**Native macOS Integration**:
- Play/Pause: F8 or dedicated media key
- Previous: F7 or previous track key
- Next: F9 or next track key
- Volume: F10-F12 or volume keys

**Requirements**:
- Grant Accessibility permissions when prompted
- Works with external keyboards and Touch Bar

### Auto-Launch Support

**Configure Launch at Login**:
Menu Bar → Launch at Login ✓

**Features**:
- Starts automatically with macOS
- Resumes last library and playback state
- Silent launch (no startup windows)

### Sleep Prevention

**Prevent System Sleep**:
Menu Bar → Prevent Mac Sleep ✓

**When Enabled**:
- System won't sleep during music playback
- Display can still sleep (screen saver)
- Automatically disabled when app quits

**Use Cases**:
- Long playlists or albums
- Background music during work
- Overnight ambient sounds

## 🌍 Multi-Language Support

### Supported Languages

Full interface localization for:
- **English** (en)
- **简体中文** (zh-Hans) - Simplified Chinese
- **繁體中文** (zh-Hant) - Traditional Chinese
- **日本語** (ja) - Japanese
- **한국어** (ko) - Korean

### Language Selection

**Automatic Detection**:
- Uses macOS system language preference
- Falls back to English if language not supported

**Manual Override**:
1. System Preferences → Language & Region
2. Add preferred language to list
3. Restart MacMusicPlayer

**Localized Elements**:
- All menu items and buttons
- Error messages and alerts
- Download interface text
- Settings and preferences

## ⚙️ Configuration & Settings

### API Configuration

**For Online Search Features**:
Menu Bar → Settings → Configure API

**Required Fields**:
- **API URL**: Your search service endpoint
- **API Key**: Authentication token

**Setup Process**:
1. Obtain YouTube Data API key from Google Cloud Console
2. Deploy compatible search service (or use existing)
3. Enter credentials in MacMusicPlayer settings

### Preferences Storage

**What's Saved**:
- Music library locations and names
- Equalizer settings and presets
- Playback mode preferences
- API configuration
- Window positions and sizes

**Storage Location**:
```
~/Library/Preferences/com.seimotech.MacMusicPlayer.plist
```

**Reset Settings**:
```bash
# Complete reset (loses all preferences)
defaults delete com.seimotech.MacMusicPlayer
```

## 🎯 Pro Tips & Advanced Usage

### Performance Optimization

**Large Libraries (1000+ tracks)**:
- Use SSD storage for music files
- Consider MP3 format for older Macs
- Close other audio applications

**Battery Life**:
- Disable equalizer when on battery
- Use lower bitrate formats
- Enable system sleep when not actively listening

### Workflow Integration

**Productive Music Setup**:
1. Create "Focus" library with instrumental music
2. Enable "Single Loop" for consistent background
3. Use "Prevent Mac Sleep" for long work sessions

**Party/Event Setup**:
1. Create "Party" library with upbeat music
2. Use "Random" mode for variety
3. Connect to external speakers via Audio MIDI Setup

### Keyboard Shortcuts Summary

| Action | Shortcut | Alternative |
|--------|----------|-------------|
| Play/Pause | Space (in menu) | F8, Media Key |
| Next Track | → (in menu) | F9, Media Key |
| Previous Track | ← (in menu) | F7, Media Key |
| Refresh Library | Cmd+R | Menu option |
| Open Downloads | Cmd+D | Menu option |
| Open Settings | Cmd+S | Menu option |

### Integration with Other Apps

**Audio Routing**:
- Use Audio MIDI Setup for complex routing
- Compatible with audio interfaces
- Supports multi-output devices

**Automation**:
- AppleScript support for basic controls
- Shortcuts.app integration (macOS 12+)
- Terminal control via `osascript`

---

🎉 **Master these features** to get the most out of MacMusicPlayer! Each feature is designed to enhance your music listening experience while maintaining simplicity and performance.