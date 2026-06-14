# Experimental Memory Vault

This document scopes the local-first memory features in `ListenScrobbler`.

The vault is intentionally app-native. It stores portable music memories that can later connect to ListenBrainz, MusicBrainz, playlists, pins, and local library resolution without depending on a private social inbox.

## Product Decision

`Shared` and `Obsessions` are separate product models:

- `Shared` archives music sent, received, or imported between app users.
- `Obsessions` archives tracks the user wants to remember as personal music moments.

Keeping them separate makes filtering, import/export, provenance, and future sync behavior easier to reason about.

## Current Behavior

### Shared

The current sharing flow is file-based:

1. A user creates a share with track, artist, optional album, recipients, and a note.
2. The app stores the share locally.
3. The user exports a `.listenscrobbler-shared.json` bundle or a JSPF playlist where recording MBIDs are available.
4. Another ListenScrobbler user imports the bundle.
5. Imported records keep sender, recipient, note, date, source, and MusicBrainz metadata where present.

The export contains no account token, password, API secret, or local credential.

### Obsessions

The current obsession flow is also local-first:

1. A user captures an obsession from the current track or manual entry.
2. The app stores track, artist, optional album, note, date, source, and identifiers where present.
3. The user can export or import `.listenscrobbler-obsessions.json` bundles.
4. Imported records are marked as manual imports so provenance stays visible.

## Design Principles

- Keep the vault archival rather than feed-like.
- Prefer notes, dates, people, source, and provenance over vanity metrics.
- Preserve MBIDs whenever possible.
- Make import/export a first-class trust feature.
- Avoid silent ingestion of other people's activity.
- Keep private and local-only records fully supported.

## Future Directions

- Add tags and named collections.
- Add richer MusicBrainz enrichment and metadata quality indicators.
- Add share summary cards for exported bundles.
- Add optional ListenBrainz pin import for obsessions.
- Add playlist import/export around JSPF-compatible structures.
- Add local library resolution with unresolved MBID reporting.
- Add privacy controls before any automated friend/activity capture.

## Testing Requirements

- Export/import round trips preserve records and provenance.
- JSPF export carries recording MBIDs where available.
- Imports reject unsupported schema versions cleanly.
- Local vault storage remains account-scoped and migration-safe.
- No vault export contains credentials or tokens.
