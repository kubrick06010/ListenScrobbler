# ListenBrainz Integration

This document defines how `ListenScrobbler` integrates with ListenBrainz today and where that integration should go next.

The product position is simple:

- ListenBrainz is the primary account and archive backend.
- MusicBrainz identifiers are the preferred metadata spine.
- Local-first storage, exports, and memory features remain a core differentiator.
- Legacy provider-era code may still exist during migration, but it is not a product goal and should not shape new UX or architecture.

## Official References

Primary references:

- ListenBrainz docs: `https://listenbrainz.readthedocs.io/`
- API index: `https://listenbrainz.readthedocs.io/en/latest/users/api/index.html`
- JSON submission docs: `https://listenbrainz.readthedocs.io/en/latest/users/json.html`
- API usage examples: `https://listenbrainz.readthedocs.io/en/latest/users/api-usage.html`
- Statistics API: `https://listenbrainz.readthedocs.io/en/latest/users/api/statistics.html`
- Core API: `https://listenbrainz.readthedocs.io/en/latest/users/api/core.html`

## Product Scope

ListenBrainz in `ListenScrobbler` should cover:

- token-based account setup
- `playing_now` and completed listen submission
- durable queueing and per-backend diagnostics where applicable
- free, portable listen/scrobble export from Account and local archive surfaces
- recent listens and archive charts
- recent-listen actions for delete, love/unlove, pin/unpin, and detail
  navigation where the row has enough ListenBrainz or MusicBrainz identity
- followers and following
- similar users and compatibility
- recommendations
- iOS Discover search across open music identity and ListenBrainz user surfaces
  where supported by available APIs
- iOS Discover radio backed by ListenBrainz radio, recommendations, or affinity
  data where available
- pins
- love/unlove recording feedback
- playlists
- artist geography
- artist detail sheets with biography highlights sourced through
  MusicBrainz-linked Wikidata/Wikipedia identities when available
- radio and affinity-based discovery
- metadata enrichment hooks that preserve MBIDs wherever possible

## Current State

Already present in the app:

- app-owned local token storage under Application Support
- token validation and username resolution
- native JSON submission for `playing_now` and completed listens
- free Account export for recent ListenBrainz listens and pending local
  scrobbles
- recent listens, top artists, top releases, top recordings, and total listen counts
- ListenBrainz listen deletion for listens with timestamp and `recording_msid`
- iOS recent-listen swipe actions for delete, love/unlove, and pin/unpin when
  the listen has enough identity for the requested action
- iOS tap-through detail routes for recent listens, including recording,
  release, artist, ListenBrainz action, and external-link context
- followers, following, and recommendation flows
- playlist and pin support
- love/unlove support for the current track through recording feedback
- artist origins and artist affinity graph experiments
- iOS Discover Search backed by open ecosystem result sections
- iOS Discover Radio backed by ListenBrainz radio, recommendations, or
  affinity-derived queues
- macOS and iOS artist biography sheets sourced through
  MusicBrainz-linked Wikidata/Wikipedia identities when available
- shared string-catalog localization infrastructure for macOS and iOS, with
  English and Spanish as the first reviewed locales
- deterministic tests for the core ListenBrainz flows already implemented

Still incomplete:

- compatibility view and overlap UX for comparing users
- richer retry and rate-limit handling in the client core
- OpenAPI-aligned fixtures for broader payload coverage
- MusicBrainz enrichment and metadata quality surfacing
- JSPF import/export and local resolution workflows

## Account Model

ListenBrainz settings should remain centered on:

- enablement
- token entry
- validation status
- resolved username
- optional custom base URL for compatible deployments
- toggles for `playing_now` and completed listens when needed

The token is stored in `~/Library/Application Support/ListenScrobbler/Secrets/listenbrainz-token` with user-only file permissions. This avoids repeated macOS Keychain prompts during local development builds. Non-sensitive state such as "token present" is cached separately to keep launch and test flows quiet.

## Submission Model

### `playing_now`

Payload shape:

```json
{
  "listen_type": "playing_now",
  "payload": [
    {
      "track_metadata": {
        "artist_name": "Portishead",
        "track_name": "The Rip",
        "release_name": "Third"
      }
    }
  ]
}
```

### completed listen

Payload shape:

```json
{
  "listen_type": "single",
  "payload": [
    {
      "listened_at": 1779164400,
      "track_metadata": {
        "artist_name": "Portishead",
        "track_name": "The Rip",
        "release_name": "Third",
        "additional_info": {
          "media_player": "ListenScrobbler",
          "submission_client": "ListenScrobbler",
          "submission_client_version": "1.0.0"
        }
      }
    }
  ]
}
```

Mapping from app `Track`:

- `track.title` -> `track_name`
- `track.artist` -> `artist_name`
- `track.album` -> `release_name`
- scrobble completion time -> `listened_at`
- `track.sourceApp` -> `additional_info.media_player` when useful

When sending `playing_now`, ListenScrobbler requests `return_msid=true`. ListenBrainz can return a `recording_msid` for the now-playing listen, which the app keeps with the current track and reuses for feedback when no MusicBrainz recording MBID is available.

### delete listen

ListenScrobbler uses ListenBrainz's native delete-listen endpoint when a recent
listen has enough identity to be removed:

```json
{
  "listened_at": 1779164400,
  "recording_msid": "d23f4719-9212-49f0-ad08-ddbfbfc50d6f"
}
```

Deletion identity requirements:

1. `listened_at` must be present.
2. `recording_msid` must be present and non-empty.

The app preserves `recording_msid` when converting ListenBrainz listens into
local recent-listen models. macOS exposes deletion from recent listens and chart
recent-activity rows; iOS exposes deletion with a destructive swipe action on
recent listens.

After the ListenBrainz request succeeds, ListenScrobbler removes the row locally
so the interface reflects the user's action immediately. ListenBrainz processes
listen deletions asynchronously, so aggregate counts and remote history may lag
until server cleanup runs.

## Feedback Model

ListenScrobbler uses the native ListenBrainz recording feedback endpoint:

```json
{
  "recording_msid": "d23f4719-9212-49f0-ad08-ddbfbfc50d6f",
  "score": 1
}
```

Feedback scores:

- `1` marks the recording as loved.
- `0` removes the user's feedback, which is the app's unlove action.

Identity resolution order for current-track love/unlove:

1. Prefer the MusicBrainz recording MBID from current open metadata.
2. Use the `recording_msid` returned by the current `playing_now` submission.
3. Refresh recent ListenBrainz listens and match title/artist to recover an MSID.
4. Resolve the recording through MusicBrainz as a final MBID fallback.

## Service Architecture

`ListenBrainzService` should continue evolving toward a small reusable request core:

- shared request building
- token injection
- spec-aligned decoding
- 429-aware retry and backoff
- consistent HTTP and transport error mapping
- generic fallback methods for unsupported endpoints

This keeps the service maintainable as we add more endpoints from the ListenBrainz ecosystem.

## Archive Surfaces

The archive layer should treat ListenBrainz as the main source for:

- recent listens
- top artists, releases, and recordings
- total listen counts
- artist map
- user-to-user compatibility
- similar users
- radio-derived affinity exploration

Where possible, archive entities should preserve MBIDs so later MusicBrainz enrichment and local-resolution features become easier.

## Social And Discovery

The main open-social surface should be built around:

- followers
- following
- similar users
- compatibility score
- artists in common
- recommendation sharing
- pinned recordings
- playlists and recommendation playlists

Important note:

- compatibility should come from ListenBrainz `similar-to`
- "artists in common" is a useful app-level derivation and can be computed by intersecting top artists for both users

## Playlist And Local Ownership Direction

ListenBrainz playlists should not remain an isolated cloud feature inside the app.

The medium-term direction is:

- expand the free Account export from recent ListenBrainz listens and pending
  local scrobbles into an open, documented format that can also include local
  manual submissions and Music library scan results
- export playlist-like content as JSPF-compatible artifacts
- import public ListenBrainz playlists for local use
- track unresolved MBIDs when local files cannot be matched
- evolve `Shared` and `Obsessions` toward open, MusicBrainz-aware artifacts

This aligns `ListenScrobbler` with the broader open ecosystem rather than creating a private side format.

## Testing Requirements

The ListenBrainz test suite should cover:

- token validation
- missing token behavior
- invalid token behavior
- request decoding for charts, social, playlists, pins, artist map, and radio
- feedback submission with MBID and MSID identities
- listen deletion request shape and local removal after successful API response
- `playing_now` `return_msid` decoding
- compatibility and similar users payloads
- partial and sparse payloads
- custom base URL behavior
- retry and error mapping behavior once the request core is refactored
- token-store isolation and quiet startup behavior

Fixtures should prefer payloads cross-checked against the ListenBrainz OpenAPI spec.

## Next Steps

1. Add compatibility UI and "artists in common" to `Social`.
2. Refactor `ListenBrainzService` around a shared request pipeline with retry/backoff.
3. Broaden OpenAPI-aligned fixtures and tests for mobile actions, Search, Radio,
   export, and biography edge cases.
4. Expand free Account export toward versioned local archive artifacts and
   playlist-compatible formats.
5. Add JSPF export/import groundwork.
6. Add MusicBrainz enrichment and provenance surfacing.
