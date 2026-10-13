# MacMusicPlayer agent guide

MacMusicPlayer is a minimal macOS menu bar music player. Run `make help` for targets; `swift test` runs the unit tests and `make build` builds the app bundle.

## Product invariants

These are owner decisions, not implementation details. Do not change them, and do not add a setting, fallback, or "recovery" path that bypasses them. Propose a change to the owner instead.

- **Menu bar only, never a Dock app.** `MacMusicPlayer/Info.plist` keeps `LSUIElement=true`, and no code calls `setActivationPolicy` or `TransformProcessType`. This holds in every state, including when the menu bar icon is hidden: opening the app again from Spotlight or Finder shows the song picker, and that entry point is enough. `make menubar-guard` enforces this, and `make build` runs it.
- **Minimal surface.** Do not add UI, windows, or settings that the owner did not ask for. Playback volume follows the system volume; the app has no volume control.

## Lessons

At task start, read this section and apply the lessons relevant to the affected workflow when choosing the implementation and acceptance checks. Verify their evidence against current code and the owner's requirements before relying on them. Current code establishes behavior; owner requirements establish the target. When either contradicts a lesson, investigate and correct the lesson instead of preserving an obsolete rule.

Keep repository lessons in this repository during the trial; promotion to global agent guidance is a separate owner decision.

### Update procedure

Every retrospective that identifies a confirmed problem must update this section before handoff, whether the problem was fixed or deferred. This applies to debugging, reviews, failed verification, delivery, and owner corrections, including workflows provided by external skills.

- Find the existing lesson for the same cause and update it. Add an entry when the cause is new; do not append duplicate rules or a running session log.
- Record the observed failure and its evidence. If the cause is unknown, say so and name the next check; do not promote a suspected cause into a rule.
- State when the lesson applies, the action that prevents recurrence, and how to verify that action. Separate a proposed action from an implemented and verified correction.
- Keep unresolved problems visible with the consequence and a follow-up issue or concrete next check. Recording a problem does not fix it or authorize deferral.
- Preserve task authority: read-only reviewers return a proposed entry and evidence to the authorized writer. If no authorized writer is available, include the pending update in the handoff. Never write secrets or private conversation content into this file.
- At handoff, link the changed entry. If nothing changed, state that no confirmed problem was found or that an existing lesson already covers it; report any pending update separately.

### Entry format

Use a short, descriptive heading and these fields. Evidence should use repository paths and symbols, commit or issue links, or an executed command with its observed result.

```text
### <Lesson title>

- Applies to: <workflow and triggering condition>
- Problem: <observed failure and consequence>
- Cause: <confirmed cause, or unknown with the next check>
- Action: <concrete prevention or correction; proposed or implemented>
- Evidence: <inspectable source for the failure and correction>
- Verification: <acceptance check and actual result; name anything unverified>
- Follow-up: <unresolved consequence and issue or next check, or none>
```

### Coordinate picker and download window transitions in AppDelegate

- Applies to: Changes that open the song picker or download window.
- Problem: Opening either window without coordinating the other allowed the song picker and download window to remain visible together.
- Cause: The two window entrypoints did not transition the other window's lifecycle or visibility.
- Action: Implemented in `AppDelegate`: `showDownloadWindow()` closes the picker before showing downloads; `showSongPickerWindow()` hides downloads before showing the picker. Preserve this coordination at the shared entrypoints. Hiding the download window preserves its background work; closing the picker lets `windowWillClose` release the picker reference.
- Evidence: [Fix in PR #92](https://github.com/samzong/MacMusicPlayer/pull/92), commit `9b1ec077419dc7e2e72ea92cb68bf3477af0f501`; `MacMusicPlayer/AppDelegate.swift`, `showDownloadWindow()`, `showSongPickerWindow()`, and `windowWillClose(_:)`. The fix and current source were inspected when this entry was added.
- Verification: Open the picker, open downloads, then reopen the picker; check that only the requested window is visible and an active download continues. Current source contains both transitions. This interactive sequence was not rerun for this documentation change.
- Follow-up: Rerun the interactive sequence when changing either window transition; source inspection alone does not verify AppKit runtime behavior.
