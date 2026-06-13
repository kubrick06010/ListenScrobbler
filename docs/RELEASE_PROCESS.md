# Release Process

OpenScrobbler releases are published by GitHub Actions from version tags.

## Normal Flow

1. Update `MARKETING_VERSION` in `project.yml`.
2. Update `CURRENT_PROJECT_VERSION` in `project.yml` if the build number should advance.
   iOS may override these settings in the `OpenScrobbleriOS` target when its
   first-release version differs from the macOS line.
3. Regenerate the Xcode project if `project.yml` changed:

   ```bash
   xcodegen generate
   ```

4. Add a new section to `CHANGELOG.md` using the version number without `v`:

   ```markdown
   ## 1.0.1 - YYYY-MM-DD
   ```

5. Update public documentation when release behavior, architecture, or supported workflows changed:

   - `README.md`
   - `ROADMAP.md`
   - `docs/ENGINEERING_PRACTICES.md`
   - integration docs under `docs/`

6. Run build and tests locally:

   ```bash
   xcodebuild build \
     -project OpenScrobbler.xcodeproj \
     -scheme OpenScrobbler \
     -destination 'platform=macOS'
   ```

   ```bash
   xcodebuild test \
     -project OpenScrobbler.xcodeproj \
     -scheme OpenScrobbler \
     -destination 'platform=macOS'
   ```

7. Open a release pull request and merge it after review.
8. Create and push the release tag from the validated `main` commit:

   ```bash
   git tag -a v1.0.1 -m "OpenScrobbler 1.0.1"
   git push origin v1.0.1
   ```

GitHub Actions will then test, build, package, and publish the release.

## Manual Re-run

If the tag exists but publishing failed, run the `Release` workflow manually in GitHub and provide the existing tag, such as `v1.0.1`.

## Release Asset

The workflow uploads:

- `OpenScrobbler-<version>-macOS.zip`

The app is locally signed by the workflow. Notarization is not automated yet.

## iOS Release Track

iOS is not published by the current GitHub Actions workflow. Before tagging an
iOS release or TestFlight build:

1. Refresh Apple Developer credentials in Xcode.
2. Run `tools/ios_device_validation.sh` against a paired physical iPhone.
3. Complete the beta gate in `docs/IOS_DEVELOPMENT_PATH.md`.
4. Capture current-build device traces under `tmp/device-traces/`.
5. Archive/sign through Xcode or a future CI workflow with App Store Connect
   credentials.

Do not publish the iOS `1.0.0` release until manual submission, Music library
baseline/delta behavior, duplicate prevention, retry persistence, and current
device traces are verified on hardware.

## Future Automation

- Add notarization once Apple Developer credentials are available in GitHub secrets.
- Add a version-bump workflow once the project has a stable branching/review policy.
