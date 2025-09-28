# Song Picker Window Enhancement Proposal

## Summary

Provide a minimal search-and-play surface so users can jump to a specific track without fighting the full library. The picker is a floating `NSPanel` invoked from the status-bar menu and relies on filenames only.

## Motivation

Users with large libraries asked for a way to play a known song instantly instead of cycling through sequential or random playback. The existing player offered no quick filtering or direct play control once a track was buried in the list.

## Goals

- Deliver an always-on-top panel that opens fast and stays lightweight.
- Allow immediate filtering by typing, with sane keyboard shortcuts for playback.
- Reuse the current `PlayerManager.playlist` without building new data plumbing.

## Non-Goals

- No playlist management, metadata browsing, or persistent filters.
- No fuzzy search, multi-column table, artwork, or other cosmetic extras.
- No system-wide hotkeys beyond the existing menu item + `⌘F` accelerator.

## Proposal

Implement `SimpleSongPickerWindow` as an `NSPanel` created from the _Browse Songs…_ menu action.

### Activation Flow

1. User clicks **Browse Songs…** or presses `⌘F`.
2. If a picker already exists, bring it forward; otherwise, spawn one and center it.
3. Focus the search box so typing starts filtering immediately.

### Layout

- Fixed 600×400 panel, borderless, floating level, with a plain control-colored background view.
- Contents: search field, table view, bottom status label.
- Currently playing track renders in accent color with semibold font.

### Filtering Behavior

- We snapshot `PlayerManager.playlist` into `allTracks` and maintain a filtered copy.
- A 150 ms debounce keeps filtering off every keystroke; matches use case-insensitive substring on the filename (extension stripped).
- Empty query shows all tracks. Empty result keeps focus in the field and surfaces “No results found”.

### Playback & Shortcuts

- `Return`/`Enter`: play highlighted row without closing the window.
- Double-click mirrors the return behavior.
- `Space`: toggles play/pause when the current track is selected; otherwise, plays the highlighted track and repaints the table while preserving selection.
- `Esc`: closes the panel even if the search field is first responder (handled through the delegate callback).
- Typing alphanumerics while the table has focus hands control back to the search field so filtering never pauses.

### Localization & Status Copy

- Placeholder text, status messages, and operation hints use `NSLocalizedString` keys (`search_songs_placeholder`, `song_count_format`, `operation_hints`).
- Translations live in `Resources/Localization/*/Localizable.strings` alongside the rest of the app.

## Drawbacks

- Filename-only search ignores tags or metadata; users with poorly named files get limited benefit.
- Fixed geometry means long titles truncate; we accept this to keep the panel predictable.

## Alternatives Considered

- Rich playlist UI with multiple columns (rejected: heavy, drifts from menu-bar app vision).
- Spotlight-style overlay with fuzzy matching (rejected for complexity and power key conflicts).
- Global shortcut to summon the picker anywhere (rejected to avoid competing for system-level key bindings).

## Implementation History

- Initial implementation shipped in `SimpleSongPickerWindow.swift`.
- Debounce, selection restore, and localized strings landed in the same file with supporting entries in localization bundles.
