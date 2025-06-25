# Troubleshooting Guide

Common issues and solutions for MacMusicPlayer.

## 🚨 Installation Issues

### "MacMusicPlayer can't be opened because it is from an unidentified developer"

**Cause**: macOS Gatekeeper security protection

**Solutions**:
1. **Right-click method** (Recommended):
   - Right-click MacMusicPlayer.app
   - Select "Open"
   - Click "Open" in the dialog

2. **Terminal method**:
   ```bash
   xattr -dr com.apple.quarantine /Applications/MacMusicPlayer.app
   ```

3. **System Preferences**:
   - Go to System Preferences → Security & Privacy
   - Look for "MacMusicPlayer was blocked..." message
   - Click "Open Anyway"

### App Won't Install from DMG

**Symptoms**: Drag and drop doesn't work, or app appears corrupted

**Solutions**:
1. **Re-download** the DMG file completely
2. **Check architecture**: Download arm64 for Apple Silicon, x86_64 for Intel
3. **Verify download**:
   ```bash
   # Check if DMG is corrupted
   hdiutil verify ~/Downloads/MacMusicPlayer-arm64.dmg
   ```

### Homebrew Installation Fails

**Error**: `brew install mac-music-player` fails

**Solutions**:
1. **Update Homebrew**:
   ```bash
   brew update
   brew upgrade
   ```

2. **Add tap manually**:
   ```bash
   brew tap samzong/tap
   brew install mac-music-player
   ```

3. **Clear cache**:
   ```bash
   brew cleanup
   rm -rf $(brew --cache)
   ```

## 🎵 Music Playback Issues

### No Music Shows in Library

**Symptoms**: Empty library after selecting music folder

**Causes & Solutions**:

1. **Unsupported formats**:
   - **Supported**: MP3, M4A, WAV, FLAC, AAC, AIFF
   - **Check**: Verify your files are in supported formats

2. **Permission issues**:
   ```bash
   # Check folder permissions
   ls -la ~/Music
   
   # Fix permissions if needed
   chmod -R 755 ~/Music
   ```

3. **Folder structure**:
   - Music files must be directly in the selected folder or subfolders
   - Hidden files (starting with `.`) are ignored

### Music Plays But No Sound

**Diagnostic Steps**:

1. **Check system volume**:
   - macOS volume controls
   - Audio MIDI Setup app

2. **Verify output device**:
   - System Preferences → Sound → Output
   - Try different output devices

3. **Reset audio engine**:
   - Quit MacMusicPlayer
   - Kill any AudioComponentRegistrar processes:
     ```bash
     killall AudioComponentRegistrar
     ```
   - Restart MacMusicPlayer

### Audio Cuts Out or Stutters

**Solutions**:
1. **Disable equalizer** temporarily (Settings → Equalizer → Disable)
2. **Check CPU usage** in Activity Monitor
3. **Close memory-intensive apps**
4. **Try different audio format** (MP3 instead of FLAC)

### Can't Skip Tracks / Controls Don't Work

**Solutions**:
1. **Check media key permissions**:
   - System Preferences → Security & Privacy → Privacy → Accessibility
   - Add MacMusicPlayer if not listed

2. **Restart audio services**:
   ```bash
   sudo killall coreaudiod
   ```

3. **Reset app completely**:
   - Quit app
   - Remove preferences:
     ```bash
     rm ~/Library/Preferences/com.seimotech.MacMusicPlayer.plist
     ```

## 📥 Download Feature Issues

### "yt-dlp not found" Error

**Solutions**:
1. **Install yt-dlp**:
   ```bash
   brew install yt-dlp
   ```

2. **Verify installation**:
   ```bash
   which yt-dlp
   yt-dlp --version
   ```

3. **Add to PATH** (if homebrew isn't in PATH):
   ```bash
   echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

### "ffmpeg not found" Error

**Solutions**:
1. **Install ffmpeg**:
   ```bash
   brew install ffmpeg
   ```

2. **Verify installation**:
   ```bash
   which ffmpeg
   ffmpeg -version
   ```

### Download Fails with "Format not available"

**Solutions**:
1. **Update yt-dlp**:
   ```bash
   brew upgrade yt-dlp
   ```

2. **Try different format**:
   - Choose MP3 instead of M4A
   - Select lower quality option

3. **Check URL validity**:
   - Test URL in browser
   - Some content may be region-restricted

### Download Stuck at 0%

**Solutions**:
1. **Check internet connection**
2. **Verify URL format**:
   - Full YouTube URLs work best
   - Avoid shortened (youtu.be) links

3. **Clear app cache**:
   ```bash
   rm -rf ~/Library/Caches/com.seimotech.MacMusicPlayer
   ```

## ⚙️ Application Issues

### App Doesn't Start / Crashes on Launch

**Diagnostic Steps**:
1. **Check Console logs**:
   - Open Console.app
   - Search for "MacMusicPlayer"
   - Look for error messages

2. **Reset preferences**:
   ```bash
   defaults delete com.seimotech.MacMusicPlayer
   rm ~/Library/Preferences/com.seimotech.MacMusicPlayer.plist
   ```

3. **Check system requirements**:
   - macOS 13.0+ required
   - 64-bit Intel or Apple Silicon

### Menu Bar Icon Missing

**Solutions**:
1. **Check if app is running**:
   ```bash
   ps aux | grep MacMusicPlayer
   ```

2. **Restart the app**:
   - Force quit in Activity Monitor
   - Relaunch from Applications

3. **Reset menu bar**:
   ```bash
   killall SystemUIServer
   ```

### Settings Don't Save

**Solutions**:
1. **Check permissions**:
   ```bash
   ls -la ~/Library/Preferences/com.seimotech.MacMusicPlayer.plist
   ```

2. **Reset UserDefaults**:
   ```bash
   defaults delete com.seimotech.MacMusicPlayer
   ```

3. **Recreate preference file**:
   - Launch app and reconfigure settings

### High CPU Usage

**Solutions**:
1. **Check audio format**: FLAC files use more CPU than MP3
2. **Disable equalizer** if not needed
3. **Close other audio apps** to prevent conflicts
4. **Update macOS** for better audio optimization

## 🌐 API/Search Issues

### "API configuration not completed"

**Solutions**:
1. **Configure API settings**:
   - Settings → Enter API URL and Key
   - Get YouTube API key from Google Cloud Console

2. **Verify API endpoint**:
   - Test URL in browser
   - Ensure HTTPS is used

### Search Returns No Results

**Solutions**:
1. **Check API quotas** in Google Cloud Console
2. **Verify API key permissions**
3. **Try different search terms**

## 🔧 Advanced Troubleshooting

### Reset Everything

**Complete reset** (loses all settings and libraries):
```bash
# Quit the app first
killall MacMusicPlayer

# Remove all app data
rm -rf ~/Library/Preferences/com.seimotech.MacMusicPlayer.plist
rm -rf ~/Library/Caches/com.seimotech.MacMusicPlayer
rm -rf ~/Library/Application\ Support/MacMusicPlayer

# Restart the app
open /Applications/MacMusicPlayer.app
```

### Enable Debug Logging

For detailed troubleshooting:
```bash
# Run from terminal to see debug output
/Applications/MacMusicPlayer.app/Contents/MacOS/MacMusicPlayer
```

### Check System Compatibility

**Verify system meets requirements**:
```bash
# Check macOS version
sw_vers

# Check architecture
uname -m

# Check available disk space
df -h ~
```

### Force Permissions Reset

If permission dialogs don't appear:
```bash
# Reset privacy permissions
tccutil reset All com.seimotech.MacMusicPlayer

# Restart and re-grant permissions
```

## 📞 Getting Help

### Before Reporting Issues

1. **Check this troubleshooting guide**
2. **Search existing issues**: [GitHub Issues](https://github.com/samzong/MacMusicPlayer/issues)
3. **Try the solutions above**
4. **Gather system information**:
   ```bash
   system_profiler SPSoftwareDataType SPHardwareDataType
   ```

### Report a Bug

**Include in your report**:
- macOS version and architecture (Intel/Apple Silicon)
- MacMusicPlayer version
- Steps to reproduce the issue
- Console logs if available
- Screenshots for UI issues

**Create issue**: [New Issue](https://github.com/samzong/MacMusicPlayer/issues/new)

### Community Support

- **Documentation**: [Full Documentation](../index.md)
- **Feature Requests**: GitHub Issues with "enhancement" label
- **Questions**: GitHub Discussions (if available)

---

💡 **Tip**: Most issues are resolved by updating macOS, reinstalling external tools (yt-dlp/ffmpeg), or resetting app preferences. Try the simple solutions first!