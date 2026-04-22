# Repository Instructions

## Agent Workflow

- Treat this file as the root contract for working in this repository.
- Before starting a task, read this file first, then load only the smallest relevant task guide from `.agents/`.
- Prefer declarative execution: follow repository rules and task guides instead of improvising one-off workflows.
- Keep context tight. Use the root rules plus one or two relevant task guides rather than dragging the whole repository into every task.
- For larger tasks, separate planning, implementation, verification, and delivery clearly.

## Task Routing

- Use `.agents/local-build.md` for local builds, app bundle delivery, and cleanup.
- Use `.agents/settings-native-ui.md` for macOS settings UI, focus handling, shortcuts, and native control behavior.
- Use `.agents/release-and-sparkle.md` for version bumps, commits, tags, release prep, and Sparkle-related work.

## Project Overview

- Clipbook is a native macOS clipboard manager built with SwiftUI and AppKit interop.
- The app targets macOS 14+ and focuses on clipboard history, search, pinning, previews, keyboard-first navigation, and optional double-click modifier-key wakeup.
- Main app code lives in `Clipbook/`.
- Unit tests live in `ClipbookTests/`.
- UI tests live in `ClipbookUITests/`.
- Release automation and Sparkle update packaging live in `.github/workflows/build-macos.yml` and related docs/scripts.

## Build And Test Commands

- Local debug build:
  `xcodebuild build -scheme Clipbook -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/clipbook-local-build`
- Local test run with the shared test plan:
  `xcodebuild test -scheme Clipbook -testPlan Clipbook -destination 'platform=macOS'`
- If a user wants a local app bundle to try manually, copy the built app to:
  `/Users/opera/Documents/Clipbook-debug.app`
- CI/release packaging is defined in:
  `.github/workflows/build-macos.yml`

## Safety And Communication

- Ask for confirmation before destructive actions outside normal local cleanup, especially deleting user files, changing release state, pushing commits/tags, or altering signing material.
- Do not run release-oriented git operations in parallel with commit/tag operations if ordering matters.
- For tasks that touch user-visible behavior, explain the intended verification path before or while making changes.
- When a task spans multiple concerns, keep write scopes separated and avoid mixing unrelated cleanup into the same change.

## Local Build And Artifact Rules

- Keep the repository root clean. Do not create or reuse `build/`, `build-local/`, or `build-local-package/` in the repo root for local work.
- Use `/tmp/clipbook-local-build` as the default local `xcodebuild -derivedDataPath` unless the user explicitly asks for a different path.
- When the user wants a local app bundle to test, copy it to a stable path: `/Users/opera/Documents/Clipbook-debug.app`.
- Do not create timestamped or incrementing app bundle names such as `Clipbook-debug-2.app` unless the user explicitly asks for multiple copies.
- If `/Users/opera/Documents/Clipbook-debug.app` cannot be replaced because it is running or locked, ask the user to quit the old app instead of creating a new output name by default.
- Clean up temporary repo-root artifacts after local verification if any were created accidentally.

## Code Style Guidelines

- Follow the existing repository style and keep diffs narrow.
- Use 2-space indentation in Swift files.
- Prefer native SwiftUI/AppKit patterns that match the existing macOS UI instead of introducing custom-looking controls without a reason.
- Keep import lists explicit and minimal, following the style already used in nearby files.
- Reuse existing app architecture and types such as `Defaults`, `KeyboardShortcuts`, `Settings`, SwiftData models, and current observable/view patterns before adding new abstractions.
- Preserve localization patterns. User-facing strings in settings and UI should continue to use the existing localized string approach where the surrounding code already does so.
- Add comments only when they explain non-obvious behavior, platform quirks, or intent. Do not add obvious commentary.
- Respect the current SwiftLint config in `.swiftlint.yml`. In particular, avoid unnecessary disables and keep long lines under control unless comments require otherwise.

## Testing Notes

- Use the shared `Clipbook.xctestplan` for normal test runs.
- The test plan injects the `enable-testing` launch argument automatically for tests.
- Some tests are intentionally skipped in `Clipbook.xctestplan`; check the plan before assuming the full suite should run.
- For logic changes in history handling, thumbnails, settings state, shortcuts, or pasteboard behavior, add or update unit tests in `ClipbookTests/` when practical.
- For settings and interaction changes, also do a manual smoke test in the built app because many behaviors depend on native macOS focus, permissions, pasteboard, or event monitoring.
- If local tests are blocked by machine-specific signing, permission, or UI environment issues, report the limitation clearly instead of silently skipping verification.

## Reflection Checklist

- Before finishing, verify what changed, what was built or tested, and whether any temporary artifacts were left behind.
- Prefer surfacing concrete residual risks over vague reassurance.
- If a task changed user-facing UI or release metadata, mention the exact app path, version, commit, or tag that was produced.

## Git Hygiene

- Never add local build artifacts or cache directories to git.
- Prefer keeping `git status` clean after local builds.
