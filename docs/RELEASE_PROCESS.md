# Release Process

OpenScrobbler releases are published by GitHub Actions from version tags.

## Normal Flow

1. Update `MARKETING_VERSION` in `project.yml`.
2. Update `CURRENT_PROJECT_VERSION` in `project.yml` if the build number should advance.
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

## Future Automation

- Add notarization once Apple Developer credentials are available in GitHub secrets.
- Add a version-bump workflow once the project has a stable branching/review policy.
