# ListenScrobbler Roadmap

ListenScrobbler 1.0.0 is the original product baseline: a native macOS client for open listening history with ListenBrainz submission, MusicBrainz-aware enrichment, local-first memory features, and a reorganized SwiftUI codebase.

The roadmap below is maintained from the current `1.1.1` macOS release and the
first `1.0.0` iOS release line. It focuses future work on improving reliability,
depth, maintainability, and polish in small reviewed increments.

Last reviewed: 2026-07-15.

## Current Release State

- macOS `1.1.1` is the current documented release baseline.
- iOS `1.0.0` has a working foundation for connection, recent listens, manual
  submission, Music library delta scanning, retries, stats, recommendations,
  social discovery, widgets, App Intents, diagnostics, and export.
- Simulator and physical-device build, install, and launch paths have been
  exercised. Signing and provisioning remain release-environment concerns, not
  unfinished product architecture.
- ListenBrainz listen deletion, feedback, pins, playlists, sparse decoding, and
  rate-limit retry behavior have focused service tests.

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

## Current Priorities

### 1. ListenBrainz API Contract And Reliability

Make the remote dependency explicit, observable, and safer to evolve.

Targets:

- Record the current integration baseline as ListenBrainz API family `/1`, the
  ListenScrobbler commit reviewed, review date, upstream documentation and
  specification revisions, and the complete endpoint inventory.
- Maintain a machine-readable endpoint manifest covering method, path,
  authentication, request/response model, pagination, and test coverage.
- Pin representative response fixtures and note whether each came from official
  documentation, OpenAPI, or an observed sanitized response.
- Add contract tests for missing, null, additional, and reordered fields without
  making ordinary additive API changes break decoding.
- Add an optional non-mutating live smoke test for public reads and token
  validation; keep submissions, feedback, pins, follows, and deletion out of
  unattended checks.
- Honor ListenBrainz rate-limit reset headers as well as `Retry-After`, and add
  retry policy for safe transient transport failures.
- Define pagination, overlap, and deduplication behavior before expanding from
  recent-listen views into full archive synchronization.

### 2. Domain Cleanup

Reduce migration-era naming and compatibility-provider assumptions in app-facing code.

Targets:

- Continue shrinking `ScrobbleService` into provider-neutral orchestration.
- Move remaining compatibility-provider concepts behind adapters.
- Keep new models centered on listens, recordings, releases, artists, users, pins, playlists, and local archives.
- Add migration tests before changing persisted data paths.

### 3. ListenBrainz Product Depth

Make the ListenBrainz integration feel complete across the app.

Targets:

- Expand playlist support.
- Improve follow and public-user discovery flows.
- Refine ListenBrainz-style artist detail sheets on macOS and iOS, including
  Wikipedia/Wikidata biography highlights when an artist identity can be
  resolved through MusicBrainz.
- Broaden iOS recent-listen parity with macOS where possible, building on
  swipe actions for delete, love/unlove, pin/unpin, and tap-through detail
  routes for the recording, release, and artist.
- Cache recent listens, stats, pins, and recommendations with clear refresh behavior.
- Improve diagnostics for token, network, endpoint, and partial-data failures.
- Continue using MBIDs where available and MSID fallback where needed.

### 4. MusicBrainz And Metadata Quality

Strengthen enrichment without making partial metadata feel broken.

Targets:

- Store artist, recording, and release MBIDs when available.
- Improve album-specific resolution and compilation handling.
- Track metadata provenance where it helps diagnostics.
- Add deduplication rules that prefer stable identifiers over display strings.

### 5. Social Discovery

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

### 6. Vault Evolution

Keep Shared and Obsessions as user-owned memory systems.

Targets:

- Better filtering and tagging.
- Versioned import/export formats.
- Free listen/scrobble export from the iOS Account surface, reinforcing that
  user-owned listening history is a core feature rather than a paid upgrade.
- Playlist-compatible exports.
- Optional flows from pins to obsessions and from vault items to playlists.

### 7. UI And Accessibility Polish

Make the app feel calmer, faster, and more discoverable.

Targets:

- Preserve the completed 2026-07-15 shell cleanup: one grouped macOS sidebar,
  global status strip, actionable Dashboard empty state, platform-appropriate
  compact/regular iOS navigation, and no duplicate bottom navigation.
- Refine empty, loading, error, and partial-data states.
- Expand shared macOS/iOS localization coverage in `Localizable.xcstrings`,
  starting from the English and Spanish foundation, and keep all visible product
  text ready to follow the user's device language automatically.
- Prepare a reviewed expansion path for additional locales after English and
  Spanish, starting with French, German, Italian, and Portuguese.
- Extend the completed primary-control keyboard and VoiceOver audit into
  secondary chart, discovery, vault, and settings flows.
- Keep action icons consistent across dashboard, listens, charts, and vault contexts.
- Continue splitting large cohesive views when new behavior would push them beyond their responsibility.

### 8. Test And Release Automation

Reduce release risk as the app grows.

Targets:

- Keep the macOS and iOS smoke UI suites passing for primary navigation, queue,
  listens, and manual submission reachability.
- Add screenshot regression automation after the current manual iPhone SE,
  iPhone Pro, iPad, and compact macOS baselines are stable enough to version.
- Keep focused tests for ListenBrainz feedback, pins, playlists, deletion,
  sparse payload decoding, and retry behavior aligned with the endpoint manifest.
- Add CI checks that detect endpoint-manifest and fixture drift.
- Add persistence and migration tests before changing storage paths.
- Keep release validation documented in `docs/RELEASE_PROCESS.md`.
- Add notarization once Apple Developer credentials are available in GitHub Actions.

### 9. iOS Release Hardening And Source-Aware Scrobbling

Make iOS a real scrobbling client without overpromising unsupported background
monitoring.

Targets:

- Repeat physical-device validation for release candidates rather than treating
  the already completed first validation as unfinished feature work.
- Treat Apple Developer signing refresh and `tools/ios_device_validation.sh` as
  release gates before tagging or shipping an iOS build.
- Keep Music library delta scanning and manual submission as the first reliable
  mobile scrobbling paths.
- Preserve and extend the source metadata already submitted for Spotify,
  Apple Music, and YouTube Music candidates before adding provider UI or importers.
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
