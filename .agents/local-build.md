# Local Build Guide

## Use When

- Building the app locally
- Delivering a local `.app` bundle for manual testing
- Cleaning up local build artifacts
- Debugging build-output confusion

## Standard Commands

- Debug build:
  `xcodebuild build -scheme Clipbook -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/clipbook-local-build`
- Optional local test run:
  `xcodebuild test -scheme Clipbook -testPlan Clipbook -destination 'platform=macOS'`
- Stable app delivery path:
  `/Users/opera/Documents/Clipbook-debug.app`

## Output Rules

- Do not create `build/`, `build-local/`, or `build-local-package/` in the repository root for local work.
- Use `/tmp/clipbook-local-build` as the default local derived data path.
- Copy the finished app to `/Users/opera/Documents/Clipbook-debug.app`.
- Do not create timestamped or incrementing app names unless the user explicitly requests multiple copies.

## Replacement And Cleanup

- If `/Users/opera/Documents/Clipbook-debug.app` is running or locked, ask the user to quit it before trying a different output name.
- After verification, clean up accidental repo-root artifacts immediately.
- Keep `git status` clean after local builds.

## Verification

- For manual-test builds, state the exact app path produced.
- If build/test execution is blocked by local machine constraints, report the failure mode precisely.
