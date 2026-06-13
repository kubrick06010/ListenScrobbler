# Repository And Release Plan

This plan turns the iOS foundation and macOS iconography parity work into a
reviewable branch, then into releases only after the physical-device beta gate
is proven.

## Version Bump

- macOS target: `1.1.0` build `6`.
- iOS target: first release `1.0.0` build `1`.
- `project.yml` is the source of truth; regenerate
  `OpenScrobbler.xcodeproj` after version changes.
- `CHANGELOG.md` must include a `1.1.0` section covering macOS changes and iOS
  first-release scope.

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
  -project OpenScrobbler.xcodeproj \
  -scheme OpenScrobbler \
  -destination 'platform=macOS'
```

```bash
xcodebuild build \
  -project OpenScrobbler.xcodeproj \
  -scheme OpenScrobbleriOS \
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

## Commit And Push Plan

1. Stage only tracked release inputs, source, tests, docs, project files, and
   generated assets.
2. Commit as:

   ```bash
   git commit -m "Add iOS scrobbling foundation"
   ```

3. Push the working branch:

   ```bash
   git push -u origin codex/ios-foundation
   ```

4. Open a draft PR until physical-device validation is green.

## Release Tag Plan

After review and merge to `main`:

```bash
git tag -a v1.1.0 -m "OpenScrobbler 1.1.0"
git push origin v1.1.0
```

The existing GitHub Actions release workflow publishes the macOS asset. iOS
distribution still needs a signed archive/TestFlight path once Apple Developer
credentials and App Store Connect metadata are ready.
