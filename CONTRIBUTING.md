# Contributing

Thanks for helping make OpenScrobbler better. The project is a macOS SwiftUI app centered on ListenBrainz, MusicBrainz, Cover Art Archive, and local-first listening archives.

## Project Direction

- Keep ListenBrainz as the primary account, submission, archive, and social data source.
- Preserve MusicBrainz identifiers when available; they are the metadata spine for enrichment.
- Prefer open ecosystem sources over private scraping or provider-specific assumptions.
- Keep local-first vault and export behavior portable.
- Treat legacy compatibility code as transitional unless a change explicitly needs it.

## Local Setup

Requirements:

- macOS 13 or newer.
- Xcode with the macOS SDK.
- XcodeGen when regenerating `OpenScrobbler.xcodeproj` from `project.yml`.

Generate the project:

```bash
xcodegen generate
```

Run tests:

```bash
xcodebuild test \
  -project OpenScrobbler.xcodeproj \
  -scheme OpenScrobbler \
  -destination 'platform=macOS'
```

## Pull Requests

Before opening a pull request:

- Keep changes focused on one behavior or feature area.
- Add or update tests for service parsing, queue behavior, metadata enrichment, or migration-sensitive logic.
- Run the macOS test suite locally.
- Update `CHANGELOG.md` for user-facing changes when preparing a release.
- Avoid committing local account tokens, generated DerivedData, or user-specific app state.

## Code Style

- Follow the existing Swift and SwiftUI structure.
- Prefer small service methods with explicit request and response models.
- Keep UI copy ListenBrainz-first and provider-neutral.
- Use structured JSON decoding when response shapes are stable.
- When parsing loose OpenAPI or JSPF payloads, keep fallback behavior deterministic and covered by tests.

## Release Work

Release steps live in `docs/RELEASE_PROCESS.md`. Version bumps should update `project.yml`, regenerate the Xcode project, update `CHANGELOG.md`, run tests, and publish from an annotated `v*` tag.
