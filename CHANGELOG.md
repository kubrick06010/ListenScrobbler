# Changelog

## 0.1.2 - 2026-06-10

### Added

- ListenBrainz pin controls for local obsessions, including visual pinned state and mixed local/remote pin history.
- Artist context in the now-playing dashboard, with ListenBrainz popularity, MusicBrainz metadata, tags, links, and artwork fallbacks.
- Test readability guidelines for future behavioral coverage.

### Fixed

- Replaced the current ListenBrainz pin before posting a new one, matching ListenBrainz's single-active-pin model.
- Pinned tracks without MusicBrainz recording MBIDs by falling back to recent ListenBrainz recording MSIDs.
- Deleted ListenBrainz pin history entries by row ID.
- Resolved MusicBrainz recordings when album-specific searches miss, and found compilation artwork when releases are not credited to the track artist.
- Loaded enrichment requests in parallel so dashboard metadata and artwork appear sooner.

## 0.1.1 - 2026-05-29

### Added

- ListenBrainz enrichment for the now-playing dashboard and track detail views, including user listen counts, public popularity, top artist recordings, and similar artists.
- Cover Art Archive artwork fallback for MusicBrainz-resolved releases.

### Fixed

- Preserved album context when opening track details so MusicBrainz resolves the intended recording instead of a similarly named entry.
- Loaded ListenBrainz recent listens and account identity from a valid ListenBrainz token without requiring legacy compatibility authentication.
- Resolved ListenBrainz recommendations to readable track and artist names instead of raw recording MBIDs.
- Improved Apple Music and Spotify artwork propagation into OpenScrobbler views.

## 0.1.0 - 2026-05-27

First public development release of OpenScrobbler.

### Added

- Native macOS SwiftUI app shell with menu bar controls, settings, diagnostics, launch-at-login, and proxy configuration.
- ListenBrainz account setup, token validation, now-playing submission, and completed listen submission.
- Offline queueing with retry state across submission backends.
- ListenBrainz archive surfaces for recent listens, top artists, top releases, top recordings, listening activity, and social discovery experiments.
- MusicBrainz metadata lookup for recordings, artists, releases, MBIDs, tags, and related links.
- Local-first shared music and obsession vaults with portable import/export.
- App icon and menu bar artwork refresh.
- Deterministic tests for core submission, queue, ListenBrainz, MusicBrainz, and vault behavior.

### Changed

- Removed product-facing legacy service naming in favor of ListenBrainz, MusicBrainz, listens, people, and compatibility-provider terminology.
- Replaced Keychain-based ListenBrainz token storage with app-owned local token storage to avoid repeated macOS permission prompts during development builds.
- Regenerated the Xcode project from `project.yml`.

### Known Gaps

- Some orchestration still uses migration-era names such as `ScrobbleService`.
- Compatibility-provider adapter code remains transitional and should continue shrinking behind provider-neutral domain models.
- Social and profile surfaces need further ListenBrainz and MusicBrainz hardening before a stable release.
