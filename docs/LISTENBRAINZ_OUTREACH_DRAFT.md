# ListenBrainz Outreach Draft

Suggested venue: MetaBrainz Community, ListenBrainz category.

Suggested title:

ListenScrobbler macOS/iOS: native ListenBrainz scrobbling work

## Post Draft

Hi ListenBrainz and MetaBrainz folks,

I wanted to share the current ListenScrobbler work because the project is now
centered on ListenBrainz and MusicBrainz rather than treating them as secondary
compatibility targets.

ListenScrobbler is a native Swift app for scrobbling, listening history, and
ListenBrainz/MusicBrainz exploration:

- Planned public repository: `https://github.com/kubrick06010/ListenScrobbler`
- Repository shape: one repo for macOS, iOS, widgets, shared services, tests,
  and release documentation.
- Current public release: not republished yet after the rename.
- Development branch policy: `main` plus short-lived review branches.

What is already working on macOS:

- ListenBrainz listen submission and now-playing submission.
- ListenBrainz recent listens, stats, pins, recommendations, social discovery,
  love/unlove feedback, and pin/unpin workflows.
- MusicBrainz lookup for recordings, artists, releases, tags, relationships,
  and Cover Art Archive artwork.

What is now working on iOS:

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
ListenScrobbler has reliable timestamps and track identity. Spotify and YouTube
Music are treated as explicit import/source-metadata paths rather than hidden
background listeners.

Current verification:

- macOS tests pass locally.
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
- Whether ListenScrobbler should be listed, documented, or coordinated somewhere
  in the ListenBrainz ecosystem once the iOS device gate is green.

Relevant docs in the repo:

- `docs/IOS_DEVELOPMENT_PATH.md`
- `docs/IOS_SOURCE_INTEGRATIONS_PLAN.md`
- `docs/LISTENBRAINZ_INTEGRATION.md`
- `docs/ICONOGRAPHY.md`
- `docs/RELEASE_PROCESS.md`

Thanks for building ListenBrainz. ListenScrobbler is becoming much better because
the ListenBrainz API is open, documented, and rich enough to build a real native
client around it.

## Short Chat Version

Hi folks. I have been building ListenScrobbler, a native Swift macOS/iOS app
centered on ListenBrainz and MusicBrainz. The renamed public repository is
planned as `kubrick06010/ListenScrobbler`, and the iOS target now has
ListenBrainz connection, manual scrobbling, Music library
delta scanning, retry queue, and source-aware `additional_info` payload coverage
for Spotify, Apple Music, YouTube Music, and manual listens.

Repo:

- https://github.com/kubrick06010/ListenScrobbler

I would appreciate feedback on whether the iOS source metadata/import plan
matches ListenBrainz expectations, and whether there is an existing iOS/mobile
effort we should coordinate with.
