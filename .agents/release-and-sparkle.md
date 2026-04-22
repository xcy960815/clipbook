# Release And Sparkle Guide

## Use When

- Bumping app version/build numbers
- Creating commits or tags for a release
- Preparing Sparkle update metadata
- Checking signing-key continuity

## Versioning Rules

- App version metadata lives in `Clipbook.xcodeproj/project.pbxproj`.
- Keep `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in sync with the intended release.
- Use tag format `vX.Y.Z`.

## Git Sequence

- If a task includes commit + tag, create the commit first, then tag that exact commit.
- Do not run commit and tag operations in parallel when the tag must point to the new commit.
- Confirm pushes or remote release changes explicitly before performing them.

## Sparkle Rules

- `Clipbook/Info.plist` contains `SUPublicEDKey`; it must stay paired with the active private key.
- The local private-key backup currently used for this project is:
  `/Users/opera/Documents/Clipbook.sparkle-private-key.txt`
- That file is not needed for normal local builds, but it is still important for future Sparkle-signed releases unless the signing chain is intentionally rotated.
- If rotating Sparkle keys, update both the release secret (`SPARKLE_PRIVATE_KEY`) and `SUPublicEDKey` together.

## Safety

- Never expose private-key contents in normal output.
- Do not delete or rotate signing material without explicit user confirmation.
- When reporting release state, include the exact commit SHA and tag created.
