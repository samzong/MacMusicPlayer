# System Architecture Overview

## 🏗️ High-Level Architecture

MacMusicPlayer follows a **Manager-based MVVM architecture** that cleanly separates business logic, data management, and user interface concerns.

```
┌─────────────────────────────────────────┐
│              AppDelegate                │
│         (Application Coordinator)       │
└─────────────────┬───────────────────────┘
                  │
    ┌─────────────┼─────────────┐
    │             │             │
    ▼             ▼             ▼
┌─────────┐  ┌─────────┐  ┌─────────┐
│ Manager │  │ Manager │  │ Manager │
│ Layer   │  │ Layer   │  │ Layer   │
└─────────┘  └─────────┘  └─────────┘
    │             │             │
    └─────────────┼─────────────┘
                  │
         ┌────────┼────────┐
         │                 │
         ▼                 ▼
    ┌─────────┐      ┌─────────┐
    │ SwiftUI │      │ AppKit  │
    │ Views   │      │ Views   │
    └─────────┘      └─────────┘
```

## 🔧 Core Components

### 1. **AppDelegate** - Application Coordinator
- **Role**: Central coordinator and entry point
- **Responsibilities**:
  - Initialize all manager instances
  - Handle system integration (status bar, media keys)
  - Manage application lifecycle
  - Coordinate between managers and UI

### 2. **Manager Layer** - Business Logic
Seven specialized managers handle distinct concerns:

- **PlayerManager**: Audio playback and controls
- **LibraryManager**: Music library CRUD operations
- **DownloadManager**: External tool integration (yt-dlp)
- **ConfigManager**: Settings persistence
- **SleepManager**: System sleep prevention
- **LaunchManager**: Login item management
- **YTSearchManager**: Online search API integration

### 3. **Model Layer** - Data Structures
- **Track**: Individual music file representation
- **MusicLibrary**: Collection metadata and paths

### 4. **View Layer** - User Interface
- **SwiftUI Views**: Modern reactive UI components
- **AppKit Controllers**: System integration and complex forms

## 🔄 Data Flow Patterns

### Reactive Updates
```swift
Manager (@Published property) 
    → NotificationCenter.post() 
    → UI automatically updates
```

### Manager Communication
```swift
Manager A → NotificationCenter → Manager B
    ↓
AppDelegate coordinates cross-manager operations
```

## 🎯 Design Principles

### 1. **Separation of Concerns**
- Each manager has a single, well-defined responsibility
- UI components are lightweight and reactive
- Business logic is isolated from presentation

### 2. **Reactive Architecture**
- `@Published` properties for automatic UI updates
- `NotificationCenter` for loose coupling between components
- SwiftUI's declarative paradigm for responsive interfaces

### 3. **System Integration**
- Hybrid UI approach: SwiftUI for modern views, AppKit for system features
- macOS-native patterns for menu bar applications
- Proper handling of system permissions and entitlements

### 4. **Extensibility**
- Manager-based design allows easy addition of new features
- Protocol-oriented approach enables testing and mocking
- Clear boundaries enable independent component development

## 🔒 Security Architecture

### Sandboxing Strategy
- **Disabled App Sandbox**: Required for external tool execution
- **Controlled Process Execution**: Limited to specific tools (yt-dlp, ffmpeg)
- **Path Validation**: Strict validation of executable locations

### Data Protection
- **Local Storage**: Music metadata only, no sensitive content
- **API Credentials**: Currently UserDefaults (⚠️ recommendation: migrate to Keychain)
- **External Communication**: HTTPS-only for API calls

## 📊 Technology Stack

### Core Technologies
- **Swift 5.9+**: Modern Swift features and patterns
- **SwiftUI**: Declarative UI framework
- **AppKit**: System integration and complex views
- **AVFoundation**: Audio playback and processing
- **Foundation**: Core system services

### External Dependencies
- **yt-dlp**: Media extraction from online sources
- **ffmpeg**: Audio format conversion and processing

### Development Tools
- **Xcode 15.0+**: Primary development environment
- **Swift Package Manager**: Dependency management
- **Make**: Build automation and distribution

## 🚀 Performance Characteristics

### Strengths
- **Lightweight**: Minimal memory footprint for menu bar app
- **Responsive**: Reactive updates prevent UI blocking
- **Efficient**: Lazy loading and on-demand resource allocation

### Considerations
- **Menu Rebuilding**: Full reconstruction on updates (optimization opportunity)
- **Process Execution**: Synchronous tool execution may block UI
- **Audio Engine**: Dual-engine setup for EQ functionality

---

This architecture provides a solid foundation for a maintainable, extensible macOS music player while following platform conventions and best practices.