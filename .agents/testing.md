# Testing Guide

## Use When

- Deciding how to verify a change
- Running unit tests or UI tests
- Writing or updating tests
- Reporting test limitations or manual verification steps

## Test Strategy

- Match the verification depth to the change.
- Prefer unit tests for logic changes that can be validated deterministically.
- Prefer manual verification for native macOS behavior that depends on focus, permissions, event taps, pasteboard content, or system integration.
- For user-visible behavior changes, do not stop at “build succeeded” if a realistic manual check is practical.

## Standard Commands

- Full test plan:
  `xcodebuild test -scheme Clipbook -testPlan Clipbook -destination 'platform=macOS'`
- Local debug build for manual verification:
  `xcodebuild build -scheme Clipbook -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/clipbook-local-build`

## Test Scope Guidance

- History model, thumbnail detection, sorting, or data-state changes:
  prefer adding/updating unit tests in `ClipbookTests/`
- Settings-window interaction, focus rings, shortcut recorder behavior, hover behavior, or visual/native-control regressions:
  prefer a local build plus manual smoke testing
- Release/version/tag/Sparkle changes:
  verify metadata, file paths, versions, tags, and signing-key continuity; these changes may not need normal unit tests

## Current Repository Notes

- The shared plan is `Clipbook.xctestplan`.
- The test plan injects the `enable-testing` launch argument automatically.
- Some tests are intentionally skipped in the plan; check the plan before treating skipped coverage as accidental.
- UI behavior in this app often depends on native macOS services and permissions, so manual verification remains important even when tests pass.

## Reporting Expectations

- State exactly what was verified:
  build only, unit tests, UI tests, or manual smoke test
- If tests were not run, say so directly.
- If tests failed because of local environment limitations, describe the blocker precisely.
- For manual verification, mention the concrete behavior checked, such as focus loss, hover targeting, thumbnail display, or settings persistence.
