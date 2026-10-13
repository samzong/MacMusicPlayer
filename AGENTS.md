# MacMusicPlayer agent guide

MacMusicPlayer is a minimal macOS menu bar music player. Run `make help` for targets; `swift test` runs the unit tests and `make build` builds the app bundle.

## Product invariants

These are owner decisions, not implementation details. Do not change them, and do not add a setting, fallback, or "recovery" path that bypasses them. Propose a change to the owner instead.

- **Menu bar only, never a Dock app.** `MacMusicPlayer/Info.plist` keeps `LSUIElement=true`, and no code calls `setActivationPolicy` or `TransformProcessType`. This holds in every state, including when the menu bar icon is hidden: opening the app again from Spotlight or Finder shows the song picker, and that entry point is enough. `make menubar-guard` enforces this, and `make build` runs it.
- **Minimal surface.** Do not add UI, windows, or settings that the owner did not ask for. Playback volume follows the system volume; the app has no volume control.
