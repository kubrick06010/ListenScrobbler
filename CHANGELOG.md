# Changelog

## Unreleased

### Added

- Documented ListenBrainz listen deletion in the user guide and integration
  notes, including the `recording_msid` requirement and ListenBrainz's
  asynchronous cleanup behavior.

## 1.1.0 - 2026-06-13

### Added

- First iOS target with ListenBrainz connection, recent listens, current pin,
  manual scrobble submission, Music library play-count delta scanning, and a
  persistent retry queue for failed mobile submissions.
- Shared mobile core services and tests for ListenBrainz connection, manual
  submission, Music library differ behavior, scan-engine retry behavior, and
  pending queue persistence.
- Official ListenBrainz/MetaBrainz app icon, in-app image assets, and macOS
  menu bar icon parity generated from documented source assets.
- Physical-device validation script for building, installing, launching, and
  tracing the iOS app once Apple Developer provisioning is available.
- iOS source integration, cross-platform UI/UX, and repository release plans.
- Source-aware ListenBrainz submission metadata for future iOS imports,
  including `music_service`, `origin_url`, `spotify_id`, `duration_played`, and
  `original_submission_client`.
- Apple Music and YouTube Music source-metadata fixtures alongside Spotify so
  the iOS import contract is covered before provider UI work begins.
- iOS App Shortcuts for opening ListenScrobbler destinations, opening the manual
  scrobble form with optional draft metadata, and refreshing ListenBrainz
  through the app route.
- iOS direct manual scrobble App Intent for Shortcuts, including title, artist,
  album, duration, listened-at, and ListenScrobbler source metadata.
- iOS repeat recent listen App Intent for Shortcuts, reusing the latest
  ListenBrainz listen with an explicit duration fallback and source metadata.
- iOS WidgetKit extension with status, recent listen, and discovery widgets
  backed by the mobile ListenBrainz snapshot.
- iOS widget refresh App Intent for Shortcuts.
- Shared iOS intent routing so system actions can drive tab selection and
  manual-scrobble presentation without duplicating view logic.
- iOS beta diagnostics export from Account with app/build version, device/OS
  context, ListenBrainz state, Music library scan summary, pending retries, last
  error, and source metadata for queued items.
- iOS ListenBrainz stats on Home with week/month/year/all-time ranges, top
  artists, top releases, top tracks, total listens, and independent stats
  refresh state.
- iOS Discover recommendations backed by the shared ListenBrainz
  recommendation client, with independent loading status and refresh controls.
- iOS Discover social feed backed by ListenBrainz followers, following, similar
  users, and neighbor recent listens.

### Changed

- Bumped macOS to version `1.1.0` build `6`.
- Set the first iOS release target to version `1.0.0` build `1`.
- Documented the physical-device validation path and remaining beta gates.

### Verified

- `xcodebuild test -project ListenScrobbler.xcodeproj -scheme ListenScrobbler -destination 'platform=macOS'`
- `xcodebuild build -project ListenScrobbler.xcodeproj -scheme ListenScrobbleriOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO`
- `xcodebuild build -project ListenScrobbler.xcodeproj -scheme ListenScrobbleriOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath tmp/ios-simulator-verify CODE_SIGNING_ALLOWED=NO`
- `xcodebuild build -project ListenScrobbler.xcodeproj -scheme ListenScrobbleriOS -destination 'platform=iOS,id=00008120-0004388834C3601E' -derivedDataPath tmp/ios-device-derived CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates`
- `xcrun devicectl device install app --device A04FE658-891B-575D-A47B-26424DACB600 tmp/ios-device-derived/Build/Products/Debug-iphoneos/ListenScrobbler.app`
- `xcrun devicectl device process launch --device A04FE658-891B-575D-A47B-26424DACB600 --terminate-existing org.listenscrobbler.app.ios`
- `bash -n tools/ios_device_validation.sh`
- `git diff --check`

## 1.0.0 - 2026-06-12

Official 1.0.0 milestone release.

### Added

- ListenBrainz love/unlove, pin/unpin, and share actions on recent listen rows in the Listens section.
- Matching listen actions on chart recent-activity rows where the same interaction model is useful.
- ListenBrainz feedback support for arbitrary listens, using MBIDs when available and recent-listen MSID lookup as a fallback.
- `docs/ENGINEERING_PRACTICES.md` as the repository protocol for focused files, feature folders, verification, and future refactors.

### Changed

- Restructured the SwiftUI app into feature folders so `ContentView` is the app shell instead of the main implementation container.
- Split dashboard, queue, listens, charts, social, vault, profile, account, and reusable component views into dedicated files.
- Regenerated the Xcode project from `project.yml` after the source layout and version changes.
- Updated public documentation to describe the 1.0.0 product baseline and post-1.0 priorities.

### Verified

- `xcodebuild -scheme ListenScrobbler -project ListenScrobbler.xcodeproj -configuration Debug build`
- `xcodebuild -scheme ListenScrobbler -project ListenScrobbler.xcodeproj -configuration Debug test`

## 0.1.3 - 2026-06-12

### Added

- ListenBrainz love/unlove controls for the current track, using the official recording feedback endpoint.
- `playing_now` submissions now request a `recording_msid` so feedback can work even when MusicBrainz has not resolved a recording MBID yet.

### Fixed

- Reused the existing ListenBrainz recent-listen MSID fallback for feedback, matching the pin flow for tracks without MBIDs.

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
- Preferred the recording artist identity over ambiguous textual artist search results, preventing ListenBrainz enrichment from showing the wrong artist context.
- Loaded enrichment requests in parallel so dashboard metadata and artwork appear sooner.

## 0.1.1 - 2026-05-29

### Added

- ListenBrainz enrichment for the now-playing dashboard and track detail views, including user listen counts, public popularity, top artist recordings, and similar artists.
- Cover Art Archive artwork fallback for MusicBrainz-resolved releases.

### Fixed

- Preserved album context when opening track details so MusicBrainz resolves the intended recording instead of a similarly named entry.
- Loaded ListenBrainz recent listens and account identity from a valid ListenBrainz token without requiring legacy compatibility authentication.
- Resolved ListenBrainz recommendations to readable track and artist names instead of raw recording MBIDs.
- Improved Apple Music and Spotify artwork propagation into ListenScrobbler views.

## 0.1.0 - 2026-05-27

First public development release of ListenScrobbler.

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
