# Open Ecosystem References

This document records the external codebases and specs we are using as references while turning `ListenScrobbler` into a ListenBrainz-first macOS app.

The goal is to avoid reinventing solved problems while still shipping a native Swift product with its own codebase and identity.

## Local Mirrors

The following repositories are mirrored locally under `.references/` for inspection:

- `.references/listenbrainz-server`
- `.references/listenbrainz-ts`
- `.references/listenbrainz-client`
- `.references/listenbrainz-content-resolver`

These mirrors are for reading, testing assumptions, and tracing API and UX behavior. They are not product dependencies.

## Usage Rules

1. Use official MetaBrainz projects as product and protocol references.
2. Do not copy GPL code into `ListenScrobbler`.
3. Reuse concepts, payload shapes, user flows, and naming where they improve compatibility.
4. Prefer the OpenAPI spec when deciding field names, optionality, and response structure.
5. Prefer native Swift implementations for app logic, networking, caching, and UI.

## Reference Stack

### `listenbrainz-server`

Role:
- Official product reference for feature behavior and user-facing concepts.
- Best source for understanding how ListenBrainz itself presents compatibility, artist geography, social discovery, and radio prompts.

Most useful files:
- `.references/listenbrainz-server/frontend/js/src/user/stats/components/UserArtistMap.tsx`
- `.references/listenbrainz-server/frontend/js/src/user/stats/components/Choropleth.tsx`
- `.references/listenbrainz-server/frontend/js/src/user/components/follow/SimilarityScore.tsx`
- `.references/listenbrainz-server/frontend/js/src/user/components/follow/CompatibilityCard.tsx`
- `.references/listenbrainz-server/frontend/js/src/user/components/follow/SimilarUsersModal.tsx`
- `.references/listenbrainz-server/frontend/js/src/explore/similar-users/SimilarUsers.tsx`
- `.references/listenbrainz-server/frontend/js/src/utils/APIService.ts`
- `.references/listenbrainz-server/listenbrainz/webserver/views/api.py`
- `.references/listenbrainz-server/listenbrainz/webserver/views/stats_api.py`

How we should use it:
- Mirror the user mental model for `similar users`, `compatibility`, `artist map`, and `LB Radio`.
- Validate endpoint usage and expected edge cases before expanding the Swift client.
- Use it as the reference when designing charts and social affordances in the app.

How we should not use it:
- Do not copy React or Python implementation details into the Swift app.
- Do not inherit web-specific UX patterns that feel wrong on macOS.

### `listenbrainz-ts`

Role:
- Architecture reference for a practical API client.
- Useful for retries, rate-limit awareness, and generic endpoint escape hatches.

Most useful files:
- `.references/listenbrainz-ts/README.md`

Why it matters:
- The README explicitly calls out rate-limit handling and retries.
- It also exposes generic `GET` and `POST` helpers for unsupported endpoints, which is a good pattern for our Swift client while the API surface keeps growing.

How we should use it:
- Add a small reusable request pipeline in `ListenBrainzService` for:
  - common request building
  - token injection
  - 429-aware retry/backoff
  - consistent decoding and error mapping
  - generic fallback requests for newly added endpoints

### `listenbrainz-client`

Role:
- Schema and endpoint coverage reference generated from the ListenBrainz OpenAPI definition.
- Best source for checking operation IDs, response shapes, and optional fields.

Most useful files:
- `.references/listenbrainz-client/api/openapi.yaml`
- `.references/listenbrainz-client/README.md`

High-value operations already relevant to `ListenScrobbler`:
- `similarUsersForUser`
- `similarityOfUserForUser`
- `artistMapForUser`
- `lbRadioRecordingsForArtist`

How we should use it:
- Cross-check every new DTO against the OpenAPI schema before shipping.
- Add fixtures in tests that match the spec instead of ad-hoc payload guesses.
- Consider generating DTOs from the spec later if the manual model count keeps growing.

### `listenbrainz-content-resolver`

Role:
- Reference for the open playlist and local-resolution side of the ecosystem.
- Especially useful for JSPF, LB Radio prompt semantics, and local collection matching.

Most useful files:
- `.references/listenbrainz-content-resolver/README.md`
- `.references/listenbrainz-content-resolver/lb_content_resolver/playlist.py`
- `.references/listenbrainz-content-resolver/lb_content_resolver/content_resolver.py`
- `.references/listenbrainz-content-resolver/lb_content_resolver/artist_search.py`
- `.references/listenbrainz-content-resolver/lb_content_resolver/tag_search.py`
- `.references/listenbrainz-content-resolver/lb_content_resolver/unresolved_recording.py`

How we should use it:
- Define playlist export/import around JSPF-compatible concepts.
- Build future "resolve to local library" workflows around MBIDs and unresolved recording tracking.
- Reuse the idea of unresolved-release reporting when local matching fails.

## Product Areas And Their References

### Compatibility And Similar Users

Primary references:
- `SimilarityScore.tsx`
- `CompatibilityCard.tsx`
- `SimilarUsersModal.tsx`
- `api.py` endpoints for `similar-users` and `similar-to`
- OpenAPI operations `similarUsersForUser` and `similarityOfUserForUser`

Adoption decision:
- Implement a native `Compatibility` surface in SwiftUI.
- Use the official compatibility score from ListenBrainz.
- Compute "artists in common" locally by intersecting top artists, because that overlap view is product value even when it is not a first-class API response.

### Artist Geography

Primary references:
- `UserArtistMap.tsx`
- `Choropleth.tsx`
- `stats_api.py` `artist-map`
- OpenAPI operation `artistMapForUser`

Adoption decision:
- Keep the current `Artist Origins` block, but evolve it toward a richer map or regional summary rather than a simple bar list.
- Align naming and empty-state behavior with the official product.

### Radio And Affinity Graphs

Primary references:
- `lb-radio` endpoints in `api.py`
- `LBRadio` routes in the server frontend
- `lbRadioRecordingsForArtist` in the OpenAPI spec
- `listenbrainz-content-resolver` local radio workflows

Adoption decision:
- Keep using `lb-radio` as the source for affinity and discovery.
- Add prompt-based radio generation later, not just artist-seed affinity.
- Use the resolver-inspired model for future local playback/export flows.

### Playlists, JSPF, And Local Resolution

Primary references:
- `listenbrainz-content-resolver/README.md`
- resolver playlist and unresolved recording modules

Adoption decision:
- Add JSPF export/import support rather than inventing a private playlist format.
- Track unresolved MBIDs when we add local library resolution.
- Keep `Shared` and `Obsessions` portable and MBID-friendly.

### Client Hardening

Primary references:
- `listenbrainz-ts/README.md`
- OpenAPI spec

Adoption decision:
- Build a small request core in Swift that supports:
  - explicit request descriptors
  - typed decoding
  - retry and backoff policy
  - reusable error mapping
  - spec-aligned fixtures

## What To Implement Next

1. Add a native compatibility view in `Social` using `similar-to` plus top-artist overlap.
2. Refactor `ListenBrainzService` around a shared request pipeline with retry/backoff and generic endpoint helpers.
3. Add OpenAPI-aligned fixtures for compatibility, similar users, artist map, playlists, pins, and radio.
4. Introduce JSPF export/import groundwork for `Shared` and playlist interoperability.
5. Add a local-resolution design for future MusicBrainz-aware library matching.

## Why This Stack Is The Right One

- `listenbrainz-server` keeps us aligned with the official product and ecosystem behavior.
- `listenbrainz-ts` gives us a clean client architecture pattern without binding us to JavaScript.
- `listenbrainz-client` gives us a stable schema source instead of guesswork.
- `listenbrainz-content-resolver` keeps playlists and local-resolution work open and portable.

Taken together, they let `ListenScrobbler` become a strong native macOS client without drifting away from the ecosystem it is built to serve.
