# Redundancy Review TODO

## P1 Dependency Detection Is Duplicated And Inconsistent

- `MacMusicPlayer/Controllers/DownloadViewController.swift:476` checks `yt-dlp` and `ffmpeg` in the UI layer.
- `MacMusicPlayer/Managers/DownloadManager.swift:240` and `MacMusicPlayer/Managers/DownloadManager.swift:278` check the same dependencies again in the download layer.
- The UI check adds `/opt/local/bin` to `PATH`, while `DownloadManager` only falls back to `/usr/local/bin` and `/opt/homebrew/bin`.
- Risk: the UI can report a dependency as installed while the actual download path still fails.
- Preferred fix: make `DownloadManager` the single dependency status source and let the UI render that status.

## P2 RefreshMusicLibrary Is Posted Multiple Times

- `MacMusicPlayer/Managers/DownloadManager.swift:638` posts `RefreshMusicLibrary` after a successful audio download.
- `MacMusicPlayer/Controllers/DownloadViewController.swift:1221`, `:1951`, and `:1997` post the same notification again from the UI.
- Risk: single downloads can refresh twice; playlist downloads can refresh once per item and again at the end.
- Preferred fix: choose one notification owner. The download layer is the better owner if every successful write should refresh the library.

## P2 PlayerManager Keeps A Write-Only Legacy currentIndex

- `MacMusicPlayer/Managers/PlayerManager.swift:33` defines a legacy `currentIndex`.
- The field is assigned in many playback paths, but actual reads use `PlaylistStore.currentIndex`.
- Preferred fix: remove `PlayerManager.currentIndex` and the assignments that only mirror `PlaylistStore`.

## P2 loadSavedMusicFolder Is An Empty Compatibility Stub

- `MacMusicPlayer/Managers/PlayerManager.swift:111` defines `loadSavedMusicFolder()` as an empty method.
- It is still called during init and refresh fallback.
- Preferred fix: remove the empty method and replace callers with explicit no-op behavior or a real fallback, depending on the intended migration policy.

## P3 PlaybackControlling Has No Current Abstraction Value

- `MacMusicPlayer/Protocols/PlaybackControlling.swift:11` defines `PlaybackControlling`.
- `QueuePlayerController` is the only implementation.
- `PlayerManager` stores `QueuePlayerController` directly rather than the protocol type.
- Preferred fix: delete the protocol unless a real mock/test/plugin boundary is introduced.

## P3 Unused Private Method

- `MacMusicPlayer/Controllers/DownloadViewController.swift:1249` defines `showAlert(message:)`.
- No call sites were found.
- Preferred fix: delete the method.

## P3 DownloadViewController Has Copy-Paste UI Helpers

- Dependency preflight is duplicated around `MacMusicPlayer/Controllers/DownloadViewController.swift:982` and `:1082`.
- Window expansion frame logic is duplicated around `:819`, `:1024`, and `:1118`.
- Download button restoration is repeated across several success, failure, and stop paths.
- Preferred fix: extract only small helpers for repeated state transitions; do not split the whole controller without a concrete boundary.

## Not Redundant

- `CustomTableRowView`, `SimpleSongPickerWindow`, `Track`, and `MusicLibrary` have real call chains.
- `ConfigManager.resetConfig()` is used by the Settings reset button.
- SwiftLint `unused_import` and `duplicate_imports` checks did not report import-level redundancy.

## Verification Already Run

- `xcodebuild -list -project MacMusicPlayer.xcodeproj`
- `swiftlint lint --only-rule unused_import --only-rule duplicate_imports --quiet --no-cache`
- Symbol/text reference checks for the items above.
- Mechanical duplicate-window scan over Swift sources.

## Not Yet Run

- Full app build.
- Runtime UI verification.
- Behavior tests. No test target was detected.

# Code Quality Review

## Verification Run For This Review

- `xcodebuild -project MacMusicPlayer.xcodeproj -scheme MacMusicPlayer -configuration Debug -destination 'platform=macOS' build -quiet`
  - Result: build succeeded.
  - Xcode warning: scheme/destination metadata is odd; Xcode reports an empty supported platform list and picks one of multiple matching macOS destinations.
- `swiftlint lint --quiet --no-cache --reporter json`
  - Result: failed with 190 violations.
  - Severity: 6 errors, 184 warnings.
  - Top rules: `line_length` 128, `missing_docs` 38, `vertical_whitespace` 7, `file_header` 4.
  - Most affected files: `DownloadManager.swift` 74, `DownloadViewController.swift` 47, `StatusMenuController.swift` 30.

## High-Value Quality Findings

### P1 DownloadViewController Is A God Object

- `MacMusicPlayer/Controllers/DownloadViewController.swift` has 2008 lines.
- SwiftLint reports `file_length` and `type_body_length` errors.
- It owns UI construction, dependency detection, search state, playlist state, table rendering, thumbnail loading, download task state, pagination, error-copy UI, and direct app delegate coordination.
- This is the main maintainability problem. The correct fix is not a huge rewrite; split only the stateful seams that already exist:
  - dependency status owned by `DownloadManager`;
  - download button/progress state helpers;
  - table cell factory helpers;
  - search/playlist mode state.

### P1 Synchronous Work Can Block Threads Or Produce Stale UI

- `DownloadManager.fetchAvailableFormats` uses `Process.launch()`, `waitUntilExit()`, and reads pipes after process exit.
- `DownloadViewController` still has separate synchronous dependency-check `Process` calls.
- `DownloadViewController` loads thumbnails with `Data(contentsOf:)` on a global queue and sets the image later without verifying that the reused table cell still represents the same row.
- Risk: stale thumbnails in reused cells, poor cancellation behavior, and fragile process I/O.
- Preferred fix: centralize process execution through one async helper and use URLSession or an image loader with cell identity checks for thumbnails.

### P1 Playback Queue State Has Conflicting Sources Of Truth

- `PlayerManager` mirrors state across `playlist`, `currentTrack`, `isPlaying`, `currentIndex`, `PlaylistStore`, and `QueuePlayerController`.
- `currentIndex` is already marked legacy and is write-only.
- `currentTrack` is updated manually in several paths and also from queue callbacks.
- Risk: UI and Now Playing metadata can drift from the actual `AVQueuePlayer` item after automatic transitions or queue rebuilds.
- Preferred fix: remove the dead `currentIndex` first, then define whether `PlaylistStore` or `QueuePlayerController` owns current-track truth.

### P2 Stringly-Typed Notifications Are A Low-Grade Architecture

- Notification names are raw string literals such as `TrackChanged`, `PlaybackStateChanged`, `PlaylistUpdated`, `RefreshMusicLibrary`, `ConfigUpdated`, and `AddNewLibrary`.
- These are spread across app delegate, managers, and controllers.
- Risk: typo-prone, no discoverable contract, hard to audit payloads.
- Preferred fix: introduce typed `Notification.Name` constants in one small namespace, not a new event bus.

### P2 Public API Is Overused Inside An App Target

- `DownloadManager` and nested DTOs are declared `public` even though this is a single app target, not a framework boundary.
- SwiftLint's 38 `missing_docs` warnings mostly come from that unnecessary `public` surface.
- Preferred fix: make these declarations internal unless there is a real module boundary.

### P2 Old-Style KVO In QueuePlayerController

- `QueuePlayerController` uses string key-path KVO for `rate` and `currentItem`.
- SwiftLint reports `block_based_kvo`.
- Preferred fix: use block-based key-path observation and store `NSKeyValueObservation` tokens.

### P2 Logging Is Mostly Print Statements

- `DownloadManager` has 26 `print` calls; `YTSearchManager` logs full URLs and raw JSON on parse errors.
- Risk: noisy production logs and accidental leakage of URLs/API behavior.
- Preferred fix: use `Logger` with subsystem/category and avoid dumping raw server responses unless behind debug-only logic.

### P2 Localization Is Broad But Slightly Inconsistent

- Swift sources contain 140 unique `NSLocalizedString` keys.
- Each `Localizable.strings` file has 149 keys, but each locale is missing 5 keys used by Swift and has 14 extra keys.
- Missing keys include `🎵 Best Quality (Auto Select)`, `Failed to get playlist info: %@`, `Error getting playlist info: %@`, `Dev: %@`, and `Version %@`.
- Preferred fix: reconcile keys per locale; avoid emoji in localization keys.

### P3 Force Unwraps In Table Cell Construction

- `SimpleSongPickerWindow` and `DownloadViewController` use `cellView!` / `cell!` while constructing table cells.
- These are probably safe in the current local branch because the cell is just allocated above, but the style is brittle and unnecessary.
- Preferred fix: bind the newly created cell to a non-optional local before installing constraints.

### P3 Info.plist Has Suspicious Residual Keys

- `UIBackgroundModes` is an iOS-style key in a macOS app.
- `CFBundleDocumentTypes` contains an almost empty document type.
- `NSServices` contains an empty dictionary.
- `SMPrivilegedExecutables` references the app bundle id itself.
- These may be harmless, but they look like copied template residue unless a packaging/signing workflow requires them.

## Low-Level / Garbage-Code Smells

- Obvious narration comments repeat the next line, especially in `DownloadViewController`, `PlayerManager`, and `LibraryManager`.
- Multiple comments say `legacy`, `new architecture`, `transition`, or `Do nothing`; the transition was never finished.
- Manual UI layout creates the same `NSTextField` and container boilerplate repeatedly.
- Error handling often collapses detailed failures into generic user messages, while still printing raw details.
- The app uses singleton/global access (`DownloadManager.shared`, `ConfigManager.shared`, `NSApp.delegate`) in places where explicit dependencies already exist.
- `URL(string:) != nil` is used as validation for downloader URLs; that is too weak for user-facing URL validation.

## AI-Authorship Heuristic

- Probability this codebase has substantial AI-assisted generation: high, roughly 75-85%.
- This is not proof and cannot identify the author. It is a style heuristic.
- Evidence raising the probability:
  - excessive explanatory comments for obvious code;
  - generic phase comments such as "New queue-based architecture", "Legacy update", "Use Task to execute asynchronous operations";
  - large controller with many features appended sequentially instead of cohesive boundaries;
  - repetitive localized strings, button styling, and dispatch-to-main blocks;
  - broad `public` access in an app target;
  - template-like file headers with `Created by X`;
  - multiple unfinished migration markers.
- Evidence lowering the probability:
  - the app builds;
  - core playback/download flows are real, not mock placeholders;
  - there are domain-specific integrations with `yt-dlp`, `ffmpeg`, `AVQueuePlayer`, status menu, sleep assertions, and localization files.
- Best read: likely human-directed code with significant AI-assisted expansion and insufficient cleanup.

## Suggested Cleanup Order

1. Make `DownloadManager` the single dependency/status source and delete UI-side duplicate dependency probing.
2. Remove duplicate `RefreshMusicLibrary` posts from UI after `DownloadManager.downloadAudio`.
3. Delete `PlayerManager.currentIndex`, `loadSavedMusicFolder()`, `showAlert(message:)`, and `PlaybackControlling` if no test boundary is planned.
4. Replace raw notification strings with centralized `Notification.Name` constants.
5. Convert `QueuePlayerController` to block-based KVO.
6. Extract only small `DownloadViewController` helpers for repeated progress/button/window/table-cell logic.
7. Reconcile localization keys and remove suspicious Info.plist residue only after confirming packaging requirements.
