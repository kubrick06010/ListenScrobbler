# Repository And Release Plan

This document records the completed single-repository decision and the current
cross-platform release policy.

## Repository Decision

Use the existing GitHub repository named `ListenScrobbler`.

Do not split the codebase into separate macOS and iOS repositories yet. The app
currently shares ListenBrainz services, domain models, tests, iconography,
release workflow, WidgetKit support, and documentation across targets. Keeping
those pieces together avoids duplicate release process and keeps source-aware
iOS work aligned with the macOS client.

Repository shape:

- GitHub repository: `kubrick06010/ListenScrobbler`
- Default branch: `main`
- Feature/review branches: short-lived product/platform branches.
- Long-lived platform branches: avoid unless App Store/TestFlight operations
  force one later.
- Release tags: `v<version>`, created from validated `main` commits.

The deleted `OpenScrobbler` GitHub repository should not be reused in docs,
release notes, or outreach. If historical context is needed, mention only that
local migration code can read old `OpenScrobbler` app-support data.

The configured remote is:

```bash
git remote get-url origin
# https://github.com/kubrick06010/ListenScrobbler.git
```

## Version Bump

- macOS target: `1.1.1` build `7`.
- iOS target: first release `1.0.0` build `2`.
- `project.yml` is the source of truth; regenerate
  `ListenScrobbler.xcodeproj` after version changes.
- `CHANGELOG.md` must include a section for each published macOS version.

## Repository Hygiene

- Ignore local traces, DerivedData, and `.DS_Store` files.
- Do not commit `.references/`, `tmp/`, local device traces, or provisioning
  artifacts.
- Keep generated ListenBrainz icon assets committed because they are release
  inputs.
- Keep scripts committed when they are part of validation:
  `tools/generate_iconography.py` and `tools/ios_device_validation.sh`.

## Documentation Checklist

- `README.md`: mention iOS target and first-release status.
- `ROADMAP.md`: add iOS beta/release track and source integration policy.
- `docs/IOS_DEVELOPMENT_PATH.md`: keep physical-device gate current.
- `docs/IOS_SOURCE_INTEGRATIONS_PLAN.md`: maintain source feasibility and
  sequencing.
- `docs/UI_UX_IMPROVEMENT_PLAN.md`: maintain cross-platform UI/UX priorities.
- `docs/ICONOGRAPHY.md`: keep official asset provenance and generation steps.
- `docs/RELEASE_PROCESS.md`: describe macOS release, iOS beta/release, and
  device-validation requirements.

## Local Verification Before Commit

```bash
xcodegen generate
```

```bash
xcodebuild test \
  -project ListenScrobbler.xcodeproj \
  -scheme ListenScrobbler \
  -destination 'platform=macOS'
```

```bash
xcodebuild build \
  -project ListenScrobbler.xcodeproj \
  -scheme ListenScrobbleriOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO
```

```bash
bash -n tools/ios_device_validation.sh
git diff --check
```

## Physical iOS Gate

Before tagging an iOS release:

- Refresh Apple Developer credentials in Xcode.
- Run `tools/ios_device_validation.sh` against the paired iPhone.
- Connect ListenBrainz on device.
- Submit a manual scrobble and confirm it appears after refresh.
- Run first Music library scan and confirm it creates a baseline only.
- Play one track, rerun scan, confirm exactly one ListenBrainz submission.
- Rerun scan without another play and confirm no duplicate.
- Capture a current-build trace under `tmp/device-traces/`.

## Commit And Push Policy

1. Stage only tracked release inputs, source, tests, docs, project files, and
   generated assets.
2. Commit with a terse description of the complete release diff.
3. Push a short-lived review branch and open a pull request against `main`.
4. Merge only after macOS tests, platform builds, and required UI checks pass.

## Release Tag Plan

After review and merge to `main`:

```bash
git tag -a v1.1.1 -m "ListenScrobbler 1.1.1"
git push origin v1.1.1
```

The existing GitHub Actions release workflow publishes the macOS asset. iOS
distribution still needs a signed archive/TestFlight path once Apple Developer
credentials and App Store Connect metadata are ready.
