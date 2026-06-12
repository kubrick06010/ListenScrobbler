# OpenScrobbler

OpenScrobbler is a macOS SwiftUI app for open listening history, centered on ListenBrainz, MusicBrainz, and local-first music memory.

The current app includes:

- ListenBrainz token-based account setup with local app-owned token storage.
- Now playing and completed listen submission.
- Love/unlove for the current track through ListenBrainz recording feedback.
- Offline queueing with per-backend retry state.
- Charts, listening archive views, and social graph experiments shaped around open data.
- Local-first shared music and obsession vault experiments.
- Menu bar controls, launch-at-login, proxy settings, diagnostics, and player monitoring.

## Direction

ListenBrainz is the primary service. Compatibility code may remain temporarily as an adapter/reference during migration, but product language, onboarding, storage names, and feature work should be ListenBrainz-first.

Charts and social features stay in scope. The goal is not to remove social music discovery, but to rebuild it on ListenBrainz-compatible concepts such as public listens, follows, similar users, MusicBrainz identifiers, playlists, pins, recommendations, and portable local archives.

## Build

Requirements:

- macOS 13 or newer.
- Xcode with the macOS SDK.
- XcodeGen if you want to regenerate the checked-in project from `project.yml`.

Generate the Xcode project:

```bash
xcodegen generate
```

Build from the command line:

```bash
xcodebuild build \
  -project OpenScrobbler.xcodeproj \
  -scheme OpenScrobbler \
  -destination 'platform=macOS'
```

Run tests:

```bash
xcodebuild test \
  -project OpenScrobbler.xcodeproj \
  -scheme OpenScrobbler \
  -destination 'platform=macOS'
```

## Migration Notes

The transplant is intentionally incremental:

- `ListenBrainzService` is the native API surface for validation, now playing, listens, stats, and recent-listen reads.
- `ScrobbleService` still contains some migration-era naming that should be retired behind provider-neutral types.
- Profile, social, charts, vaults, and queue UI should be renamed around listens, people, recordings, releases, and open archives.
- Compatibility-provider-specific account panes, badges, and copy should not return as primary UI.

## Current Shape

- `Sources/App`: app lifecycle and menu bar.
- `Sources/Services`: player monitor, queue, ListenBrainz, proxy, vault, and transitional scrobble coordination.
- `Sources/UI`: SwiftUI app shell and settings.
- `Sources/Domain`: shared domain models.
- `Tests`: inherited tests to keep behavior stable during the migration.

## Reference Strategy

Implementation work should stay aligned with the open ecosystem instead of inventing private semantics. See:

- `docs/OPEN_ECOSYSTEM_REFERENCES.md`
- `docs/LISTENBRAINZ_INTEGRATION.md`
- `docs/RELEASE_PROCESS.md`
- `ROADMAP.md`
