# iOS Source Integrations Plan

OpenScrobbler iOS should support ListenBrainz's source-aware listen model
without pretending that iOS allows global background scrobbling for every music
app. The product rule is: submit real listens when OpenScrobbler has reliable
timestamps and track identity, and attach source metadata when it can be proven.

## Current Ground Truth

- ListenBrainz accepts `single`, `playing_now`, and `import` submissions through
  `/1/submit-listens`.
- ListenBrainz asks clients to submit completed listens only after half the
  track or four minutes, whichever is lower.
- ListenBrainz `additional_info` supports source fields such as
  `media_player`, `submission_client`, `submission_client_version`,
  `original_submission_client`, `music_service`, `music_service_name`,
  `origin_url`, `spotify_id`, `duration`, `duration_ms`, and
  `duration_played`.
- ListenBrainz documents canonical service domains including `spotify.com`,
  `youtube.com`, `music.youtube.com`, `music.apple.com`, `bandcamp.com`,
  `soundcloud.com`, `deezer.com`, and `tidal.com`.
- Spotify's official iOS SDK is an App Remote integration that requires user
  authorization and is not a universal background listener.
- Spotify Web API exposes recently played tracks for the current user, but that
  is a polling/import source, not a proof of real-time iOS playback by another
  app.
- YouTube Music has no supported first-party iOS playback-history API suitable
  for app-store-safe background scrobbling. ListenBrainz server-side YouTube
  import work exists, but it is based on user exports and remains a separate
  server/importer concern.

References:

- https://listenbrainz.readthedocs.io/en/latest/users/api/core.html
- https://listenbrainz.readthedocs.io/en/latest/users/json.html
- https://developer.spotify.com/documentation/ios
- https://developer.spotify.com/documentation/web-api/reference/get-recently-played
- https://github.com/metabrainz/listenbrainz-server/pull/3498

## Feasibility Matrix

| Source | iOS feasibility | Product decision |
| --- | --- | --- |
| Local Music library | High | Keep current delta scanner as the first automatic path. |
| Manual listen | High | Keep as the reliable fallback and QA tool. |
| Apple Music / MusicKit | Medium | Add after scanner beta; use supported MusicKit permissions and avoid duplicate submissions against library scan. |
| Spotify recent plays | Medium | Add as opt-in account import/polling, with explicit limits and dedupe. Do not market as background Spotify scrobbling. |
| Spotify App Remote | Low to medium | Only consider if OpenScrobbler adds a Spotify control surface. It should not be required for core scrobbling. |
| YouTube / YouTube Music | Low | Defer native integration. Prefer user-export import if ListenBrainz server support stabilizes, or manual scrobble with `origin_url`. |
| Bandcamp / SoundCloud / web sources | Low | Use manual/import flows with source metadata; do not scrape apps or webviews. |

## Implementation Slices

### Slice 1: Source Metadata In Core

- Extend `MobileScrobbleCandidate` with optional source identity:
  `mediaPlayer`, `musicService`, `musicServiceName`, `originURL`,
  `spotifyID`, `durationPlayed`, and `originalSubmissionClient`.
- Extend `Track` or the ListenBrainz submission mapper so source metadata is
  serialized into `additional_info` only when present.
- Preserve existing manual and Music library behavior with defaults:
  `submission_client = OpenScrobbler`, source app from candidate, and no
  fabricated `music_service`.
- Add tests for Spotify, YouTube Music, Apple Music, and plain manual metadata
  payloads.

Status: implemented for the core contract. The mobile candidate, internal track
model, and ListenBrainz encoder preserve source metadata, with fixture coverage
for plain manual listens plus Spotify, Apple Music, and YouTube Music source
payloads. Remaining work: expose source selection/import UI after the queue
contract is promoted.

### Slice 2: Import Queue Contract

- Promote the iOS pending queue into a provider-neutral import queue:
  `pending`, `submitted`, `duplicate`, `rejected`, `failed`.
- Add stable dedupe keys using MBID/MSID when available and otherwise a
  normalized tuple of source, origin URL, title, artist, album, and timestamp.
- Add an Account diagnostics screen that can show source, timestamp, attempts,
  last error, and ListenBrainz payload preview.

### Slice 3: Apple Music / MusicKit

- Add a MusicKit capability check and authorization state separate from
  `MPMediaLibrary`.
- Use MusicKit only where it provides better metadata or playback context than
  the current library scanner.
- Make duplicate prevention explicit between MusicKit events and library
  play-count increments.

### Slice 4: Spotify Recent Plays Import

- Add Spotify OAuth only if the app has a clear user-facing import screen and a
  privacy explanation.
- Fetch recent plays as an explicit import action or foreground refresh.
- Map Spotify track URL to `spotify_id`, `origin_url`, and
  `music_service = spotify.com`.
- Never poll aggressively in background; rely on user action or allowed
  foreground refresh.

### Slice 5: Export-Based Imports

- Add document importers for service exports only after the queue/dedupe layer
  is solid.
- Start with JSON fixtures and local parsing tests before adding UI.
- Treat YouTube Music exports as experimental until ListenBrainz's own importer
  stabilizes and skip detection is good enough to avoid bad history.

## Non-Goals

- No private scraping of iOS app sandboxes.
- No accessibility/notification scraping.
- No hidden background polling that violates platform or API rules.
- No unsupported YouTube Music API emulation in the App Store build.
- No source labels unless we can prove the source.

## Beta Exit Criteria

- Existing Music library and manual listens still submit correctly.
- Source metadata is covered by unit tests and visible in diagnostics.
- Import queue dedupe prevents duplicate submissions across at least Music
  library, manual, and one source-enriched fixture.
- Spotify or YouTube work does not start until the source metadata and queue
  contract are merged.
