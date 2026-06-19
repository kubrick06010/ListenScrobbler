# ListenScrobbler Roadmap

ListenScrobbler 1.0.0 is the official baseline for the app: a native macOS client for open listening history with ListenBrainz submission, MusicBrainz-aware enrichment, local-first memory features, and a reorganized SwiftUI codebase.

The roadmap below is intentionally post-1.0. It treats the current release as the product foundation and focuses future work on improving depth, maintainability, and polish in small reviewed increments.

The current release track adds an iOS foundation. macOS moves toward `1.1.0`;
iOS is prepared for its first `1.0.0` release after physical-device validation.

## 1.0.0 Baseline

The release includes:

- Native macOS SwiftUI app shell with sidebar navigation, settings, menu bar controls, launch-at-login, proxy support, diagnostics, and player monitoring.
- ListenBrainz token validation, now-playing submission, completed listen submission, recent listens, stats, feedback, and pin workflows.
- Love/unlove, pin/unpin, and share actions on listen rows where those actions are meaningful.
- Offline queueing with retry state and local persistence.
- Charts, reports, listening clock, archive views, social discovery surfaces, and graph experiments built around open listening data.
- Shared and Obsessions vaults with local persistence, import/export, and ListenBrainz pin integration.
- A feature-folder SwiftUI structure backed by `docs/ENGINEERING_PRACTICES.md`.
- A passing build and unit test suite for the release branch.

## Product Direction

ListenScrobbler should remain:

- ListenBrainz-first for identity, submission, listens, charts, pins, recommendations, and social discovery.
- MusicBrainz-aware for portable identifiers, cleaner metadata, and open ecosystem compatibility.
- Local-first for queue resilience, user-owned memories, exports, and future archive portability.
- Native to macOS in interaction quality, keyboard/mouse ergonomics, and menu bar workflows.

## Engineering Rules

Every roadmap item should follow `docs/ENGINEERING_PRACTICES.md`.

- Keep `ContentView` as shell and wiring only.
- Place feature UI in feature folders.
- Move reusable controls into `Sources/UI/Components`.
- Keep service, persistence, and parsing logic outside SwiftUI presentation code.
- Run `xcodegen generate` after source layout or project changes.
- Run build and tests for service, model, persistence, or release-critical UI work.

## Post-1.0 Priorities

### 1. Domain Cleanup

Reduce migration-era naming and compatibility-provider assumptions in app-facing code.

Targets:

- Continue shrinking `ScrobbleService` into provider-neutral orchestration.
- Move remaining compatibility-provider concepts behind adapters.
- Keep new models centered on listens, recordings, releases, artists, users, pins, playlists, and local archives.
- Add migration tests before changing persisted data paths.

### 2. ListenBrainz Depth

Make the ListenBrainz integration feel complete across the app.

Targets:

- Expand playlist support.
- Improve follow and public-user discovery flows.
- Add ListenBrainz-style artist detail sheets on macOS and iOS, including
  Wikipedia/Wikidata biography highlights when an artist identity can be
  resolved through MusicBrainz.
- Bring iOS recent-listen interactions to parity with macOS where possible:
  swipe actions for delete, love/unlove, pin/unpin, and tap-through detail
  routes for the recording, release, and artist.
- Cache recent listens, stats, pins, and recommendations with clear refresh behavior.
- Improve diagnostics for token, network, endpoint, and partial-data failures.
- Continue using MBIDs where available and MSID fallback where needed.

### 3. MusicBrainz And Metadata Quality

Strengthen enrichment without making partial metadata feel broken.

Targets:

- Store artist, recording, and release MBIDs when available.
- Improve album-specific resolution and compilation handling.
- Track metadata provenance where it helps diagnostics.
- Add deduplication rules that prefer stable identifiers over display strings.

### 4. Social Discovery

Grow discovery around open listening behavior rather than closed social assumptions.

Targets:

- Public listening overlap.
- Similar users and related artists.
- Refine the iOS Discover Search entry point now that the placeholder is gone,
  covering useful open-ecosystem searches for artists, recordings, and releases.
- Refine the iOS Discover Radio entry point now that the placeholder is gone,
  using ListenBrainz radio, recommendations, or affinity data to build playable
  discovery queues where supported.
- Recommendation-driven exploration.
- Graph views that explain why a connection exists.
- Local-first social analysis that still works when remote data is incomplete.

### 5. Vault Evolution

Keep Shared and Obsessions as user-owned memory systems.

Targets:

- Better filtering and tagging.
- Versioned import/export formats.
- Free listen/scrobble export from the iOS Account surface, reinforcing that
  user-owned listening history is a core feature rather than a paid upgrade.
- Playlist-compatible exports.
- Optional flows from pins to obsessions and from vault items to playlists.

### 6. UI And Accessibility Polish

Make the app feel calmer, faster, and more discoverable.

Targets:

- Refine empty, loading, error, and partial-data states.
- Add shared macOS/iOS localization infrastructure with `Localizable.xcstrings`,
  starting with English and Spanish, and keep all visible product text ready to
  follow the user's device language automatically.
- Prepare a reviewed expansion path for additional locales after English and
  Spanish, starting with French, German, Italian, and Portuguese.
- Audit keyboard navigation and VoiceOver labels for primary controls.
- Keep action icons consistent across dashboard, listens, charts, and vault contexts.
- Continue splitting large cohesive views when new behavior would push them beyond their responsibility.

### 7. Test And Release Automation

Reduce release risk as the app grows.

Targets:

- Add focused tests for ListenBrainz feedback, pins, playlists, and sparse payload decoding.
- Add persistence and migration tests before changing storage paths.
- Keep release validation documented in `docs/RELEASE_PROCESS.md`.
- Add notarization once Apple Developer credentials are available in GitHub Actions.

### 8. iOS Beta And Source-Aware Scrobbling

Make iOS a real scrobbling client without overpromising unsupported background
monitoring.

Targets:

- Finish physical-device validation for the current iOS scanner build.
- Treat Apple Developer signing refresh and `tools/ios_device_validation.sh` as
  the next release gate before tagging or shipping the iOS beta.
- Keep Music library delta scanning and manual submission as the first reliable
  mobile scrobbling paths.
- Add source metadata to ListenBrainz submissions before adding Spotify,
  YouTube, Apple Music, or export importers.
- Treat Spotify recent plays as opt-in import/polling, not universal background
  scrobbling.
- Defer YouTube Music native integration unless a supported, app-store-safe API
  path exists.
- Keep cross-platform UI/UX language aligned through
  `docs/UI_UX_IMPROVEMENT_PLAN.md`.

## Release Policy

Patch releases should fix defects or low-risk polish. Minor releases should introduce focused user-facing capabilities. Major releases should be reserved for durable product or storage-contract changes.

Release branches should update:

- `project.yml`
- `CHANGELOG.md`
- public docs affected by the change
- generated Xcode project files

Do not tag a release until the release branch is merged and validated on `main`.
