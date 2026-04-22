# Settings Native UI Guide

## Use When

- Editing `Clipbook/Settings/*`
- Changing shortcut recorders or toggle/picker interactions
- Fixing focus, hover, border, or highlight behavior in macOS settings UI

## Native UI Rules

- Match existing native macOS control behavior before introducing custom visuals.
- Prefer AppKit-backed behavior when SwiftUI alone produces non-native focus or interaction results.
- Reuse `KeyboardShortcuts`, `Settings`, and existing AppKit wrappers where they fit the behavior.
- Avoid decorative custom borders or fake focus states if the same effect can be achieved with native focus-ring behavior.
- Keep settings controls visually aligned with surrounding controls in size, padding, and interaction feedback.

## Interaction Expectations

- Clicking outside a focused control should clear focus if native controls would do so.
- Focus indication should come from the control itself whenever possible, not from a detached outer overlay.
- Hover, selection, and hit-testing changes should be scoped to the specific row or control being interacted with.

## Verification

- Build and manually test the settings pane after UI changes.
- Check focus gain/loss, hover behavior, disabled/enabled state, clear buttons, and keyboard interactions.
- If behavior intentionally differs from `KeyboardShortcuts.Recorder`, document why.
