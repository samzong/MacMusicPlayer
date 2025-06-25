# Manager Classes API Reference

This document provides comprehensive API documentation for all manager classes in MacMusicPlayer.

## 🎵 PlayerManager

**Location**: `MacMusicPlayer/Managers/PlayerManager.swift`

The core audio playback controller with equalizer support.

### Properties

```swift
@Published var playlist: [Track]          // Current playlist
@Published var currentTrack: Track?       // Currently playing track
@Published var isPlaying: Bool           // Playback state
@Published var bassGain: Float           // Bass EQ level (-12.0 to 12.0)
@Published var midGain: Float            // Mid EQ level (-12.0 to 12.0)  
@Published var trebleGain: Float         // Treble EQ level (-12.0 to 12.0)
@Published var equalizerEnabled: Bool    // Equalizer on/off
@Published var currentPreset: EqualizerPreset // Selected EQ preset
```

### Equalizer Presets

```swift
enum EqualizerPreset: String, CaseIterable {
    case flat        // (0.0, 0.0, 0.0)
    case classical   // (0.0, 0.0, 3.0)
    case rock        // (3.0, 0.0, 3.0)
    case pop         // (1.0, 2.0, 2.0)
    case jazz        // (2.0, -1.0, 1.0)
    case electronic  // (4.0, 0.0, 2.0)
    case hiphop      // (5.0, -1.0, 0.0)
}
```

### Methods

```swift
// Playback Control
func play()                              // Start/resume playback
func pause()                             // Pause playback
func playNext()                          // Skip to next track
func playPrevious()                      // Go to previous track
func loadLibrary(_ library: MusicLibrary) // Load new music library

// Audio Setup
func requestMusicFolderAccess()          // Request folder permissions
```

### Example Usage

```swift
let playerManager = PlayerManager()

// Load a music library
playerManager.loadLibrary(musicLibrary)

// Control playback
playerManager.play()
playerManager.pause()

// Adjust equalizer
playerManager.equalizerEnabled = true
playerManager.currentPreset = .rock
playerManager.bassGain = 5.0
```

---

## 📚 LibraryManager

**Location**: `MacMusicPlayer/Managers/LibraryManager.swift`

Manages multiple music library collections and their metadata.

### Properties

```swift
@Published var libraries: [MusicLibrary]     // All available libraries
@Published var currentLibrary: MusicLibrary? // Active library
```

### Methods

```swift
// Library Management
func addLibrary(name: String, path: String)     // Add new music library
func removeLibrary(id: UUID)                    // Delete library (keeps files)
func switchLibrary(id: UUID)                    // Change active library
func renameLibrary(id: UUID, newName: String)   // Update library name

// Private Methods
private func loadLibraries()                    // Load from UserDefaults
private func saveLibraries()                    // Persist to UserDefaults
private func migrateExistingSingleLibrary()     // Legacy migration
```

### Example Usage

```swift
let libraryManager = LibraryManager()

// Add a new library
libraryManager.addLibrary(name: "Rock Collection", path: "/Users/me/Music/Rock")

// Switch between libraries
libraryManager.switchLibrary(id: libraryId)

// Rename a library
libraryManager.renameLibrary(id: libraryId, newName: "Metal Collection")
```

---

## 📥 DownloadManager

**Location**: `MacMusicPlayer/Managers/DownloadManager.swift`

Handles downloading music from online sources using yt-dlp and ffmpeg.

### Data Structures

```swift
struct DownloadFormat {
    let formatId: String        // Format identifier
    let fileExtension: String   // File extension (.mp3, .m4a, etc.)
    let description: String     // Human-readable description
    let bitrate: String        // Audio bitrate
    let sampleRate: String     // Sample rate
    let channels: String       // Audio channels
    let fileSize: String       // Estimated file size
}

struct PlaylistInfo {
    let id: String             // Playlist identifier
    let title: String          // Playlist title
    let description: String    // Playlist description
    let uploader: String       // Channel/uploader name
    let videoCount: Int        // Number of items
    let items: [PlaylistItem]  // Playlist contents
}
```

### Error Types

```swift
enum DownloadError: Error {
    case formatFetchFailed             // Failed to get available formats
    case downloadFailed(String)        // Download failed with message
    case invalidURL                    // URL validation failed
    case ytDlpNotFound                // yt-dlp not installed
    case ffmpegNotFound               // ffmpeg not installed
    case playlistFetchFailed          // Playlist info fetch failed
    case noFormatsAvailable           // No compatible formats
    case libraryNotFound              // Target library not found
}
```

### Methods

```swift
// Tool Verification
func checkYTDlpAvailability() throws -> String    // Verify yt-dlp installation
func checkFFmpegAvailability() throws -> String   // Verify ffmpeg installation

// Format Discovery
func fetchAvailableFormats(for url: String) async throws -> [DownloadFormat]

// Single Downloads
func download(url: String, format: DownloadFormat, libraryId: UUID, 
             progress: @escaping (Double) -> Void) async throws

// Playlist Operations
func fetchPlaylistInfo(for url: String) async throws -> PlaylistInfo
func downloadPlaylist(playlist: PlaylistInfo, format: DownloadFormat, 
                     libraryId: UUID, selectedItems: [PlaylistItem],
                     progress: @escaping (PlaylistDownloadProgress) -> Void) async throws
```

### Example Usage

```swift
let downloadManager = DownloadManager.shared

// Check if tools are installed
do {
    let ytDlpPath = try downloadManager.checkYTDlpAvailability()
    let ffmpegPath = try downloadManager.checkFFmpegAvailability()
    print("Tools ready: yt-dlp at \(ytDlpPath), ffmpeg at \(ffmpegPath)")
} catch {
    print("Missing tools: \(error)")
}

// Download a single track
Task {
    do {
        let formats = try await downloadManager.fetchAvailableFormats(for: youtubeURL)
        let mp3Format = formats.first { $0.fileExtension == "mp3" }
        
        try await downloadManager.download(
            url: youtubeURL,
            format: mp3Format!,
            libraryId: libraryId
        ) { progress in
            print("Download progress: \(progress * 100)%")
        }
    } catch {
        print("Download failed: \(error)")
    }
}
```

---

## ⚙️ ConfigManager

**Location**: `MacMusicPlayer/Managers/ConfigManager.swift`

Manages application configuration and API settings.

### Properties

```swift
var apiKey: String          // YouTube API key
var apiUrl: String          // API endpoint URL
var isConfigValid: Bool     // Configuration validation status
```

### Methods

```swift
func saveConfig(apiKey: String, apiUrl: String)  // Save API configuration
func resetConfig()                               // Clear all settings
```

### Example Usage

```swift
let configManager = ConfigManager.shared

// Configure API settings
configManager.saveConfig(
    apiKey: "your-youtube-api-key",
    apiUrl: "https://your-api-server.com"
)

// Check if configuration is valid
if configManager.isConfigValid {
    // Proceed with API calls
} else {
    // Prompt user for configuration
}
```

---

## 🔍 YTSearchManager

**Location**: `MacMusicPlayer/Managers/YTSearchManager.swift`

Handles online music search functionality.

### Data Structures

```swift
struct SearchResult: Codable {
    struct VideoItem: Codable {
        let videoId: String        // Video identifier
        let videoUrl: String       // Full URL
        let title: String          // Video title
        let thumbnailUrl: String   // Thumbnail image URL
        let platform: String       // Source platform
    }
    
    let items: [VideoItem]         // Search results
    let nextPageToken: String?     // Pagination token
    let totalResults: Int          // Total result count
}
```

### Methods

```swift
func search(keyword: String, pageToken: String? = nil, 
           completion: @escaping (Result<SearchResult, Error>) -> Void)
```

### Example Usage

```swift
let searchManager = YTSearchManager.shared

searchManager.search(keyword: "jazz music") { result in
    switch result {
    case .success(let searchResult):
        for item in searchResult.items {
            print("Found: \(item.title) - \(item.videoUrl)")
        }
    case .failure(let error):
        print("Search failed: \(error)")
    }
}
```

---

## 💤 SleepManager

**Location**: `MacMusicPlayer/Managers/SleepManager.swift`

Controls system sleep prevention during music playback.

### Properties

```swift
@Published var preventSleep: Bool    // Sleep prevention state
```

### Methods

```swift
// Implementation uses IOKit for power assertion management
// Automatically prevents system sleep when enabled
```

---

## 🚀 LaunchManager

**Location**: `MacMusicPlayer/Managers/LaunchManager.swift`

Manages launch-at-login functionality.

### Properties

```swift
@Published var launchAtLogin: Bool   // Auto-launch state
```

### Methods

```swift
// Uses ServiceManagement framework for login item management
// Automatically registers/unregisters app for auto-launch
```

---

## 🔄 Notification System

All managers use `NotificationCenter` for loose coupling:

### Standard Notifications

```swift
// Posted by PlayerManager
"TrackChanged"           // When currentTrack changes
"PlaybackStateChanged"   // When isPlaying changes

// Posted by LibraryManager/AppDelegate  
"RefreshMusicLibrary"    // When library needs refresh
"AddNewLibrary"          // When new library is added

// Posted by ConfigViewController
"ConfigUpdated"          // When settings change
```

### Listening to Notifications

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleTrackChange),
    name: NSNotification.Name("TrackChanged"),
    object: nil
)
```

---

This API documentation provides the foundation for understanding and extending MacMusicPlayer's manager architecture. Each manager is designed to be independent and communicate through well-defined interfaces.