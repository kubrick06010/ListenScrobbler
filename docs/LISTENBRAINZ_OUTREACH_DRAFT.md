# ListenBrainz Outreach Draft

Suggested venue: MetaBrainz Community, ListenBrainz category.

Suggested title:

OpenScrobbler macOS 1.0.0 and iOS beta: native ListenBrainz scrobbling work

## Post Draft

Hi ListenBrainz and MetaBrainz folks,

I wanted to share the current OpenScrobbler work because the project is now
centered on ListenBrainz and MusicBrainz rather than treating them as secondary
compatibility targets.

OpenScrobbler is a native Swift app for scrobbling, listening history, and
ListenBrainz/MusicBrainz exploration:

- Repository: https://github.com/kubrick06010/OpenScrobbler
- Current amended release: https://github.com/kubrick06010/OpenScrobbler/releases/tag/v1.0.0
- macOS branch: `OpenScrobbler-MacOs`
- iOS beta branch: `OpenScrobbler-iOS`

What is already working on macOS:

- ListenBrainz listen submission and now-playing submission.
- ListenBrainz recent listens, stats, pins, recommendations, social discovery,
  love/unlove feedback, and pin/unpin workflows.
- MusicBrainz lookup for recordings, artists, releases, tags, relationships,
  and Cover Art Archive artwork.
- A packaged `OpenScrobbler-1.0.0-macOS.zip` attached to the current release.

What is now working on the iOS beta branch:

- A first native iOS target.
- ListenBrainz account connection.
- Recent listens and current pin display.
- Manual ListenBrainz scrobble submission.
- A Music library play-count delta scanner for supported local library listens.
- A persistent retry queue for failed mobile submissions.
- Source-aware ListenBrainz `additional_info` support for future imports,
  including `music_service`, `music_service_name`, `origin_url`, `spotify_id`,
  `duration_played`, and `original_submission_client`.
- Fixture coverage for plain manual listens plus Spotify, Apple Music, and
  YouTube Music source metadata payloads.
- ListenBrainz/MetaBrainz-aligned app iconography and macOS/iOS visual parity.

We are intentionally not claiming universal iOS background scrobbling. The iOS
implementation follows platform limits: real listens are submitted only when
OpenScrobbler has reliable timestamps and track identity. Spotify and YouTube
Music are treated as explicit import/source-metadata paths rather than hidden
background listeners.

Current verification:

- macOS tests pass locally on the iOS beta branch.
- iOS simulator build succeeds with code signing disabled.
- Physical-device validation is the next gate before treating iOS as a signed
  beta/TestFlight candidate.

The feedback I would especially value:

- Whether our `additional_info` source metadata mapping matches ListenBrainz
  expectations for source-aware imports.
- Whether the iOS source integration plan is aligned with ListenBrainz's view
  of Spotify, Apple Music, YouTube Music, and export-based imports.
- Whether there is an existing ListenBrainz iOS/mobile effort we should align
  with before going further.
- Whether OpenScrobbler should be listed, documented, or coordinated somewhere
  in the ListenBrainz ecosystem once the iOS device gate is green.

Relevant local docs in the repo:

- `docs/IOS_DEVELOPMENT_PATH.md`
- `docs/IOS_SOURCE_INTEGRATIONS_PLAN.md`
- `docs/LISTENBRAINZ_INTEGRATION.md`
- `docs/ICONOGRAPHY.md`
- `docs/RELEASE_PROCESS.md`

Thanks for building ListenBrainz. OpenScrobbler is becoming much better because
the ListenBrainz API is open, documented, and rich enough to build a real native
client around it.

## Short Chat Version

Hi folks. I have been building OpenScrobbler, a native Swift macOS/iOS app
centered on ListenBrainz and MusicBrainz. macOS 1.0.0 is packaged, and the iOS
beta branch now has ListenBrainz connection, manual scrobbling, Music library
delta scanning, retry queue, and source-aware `additional_info` payload coverage
for Spotify, Apple Music, YouTube Music, and manual listens.

Release/repo:

- https://github.com/kubrick06010/OpenScrobbler/releases/tag/v1.0.0
- https://github.com/kubrick06010/OpenScrobbler

I would appreciate feedback on whether the iOS source metadata/import plan
matches ListenBrainz expectations, and whether there is an existing iOS/mobile
effort we should coordinate with.
