# Artwork resolution architecture

ListenScrobbler resolves musical artwork once and propagates a typed
`ArtworkResolution` to every surface. Views do not search providers or promote
untyped image URLs. MusicBrainz is the correlation layer, not the only artwork
source.

## Entity policy

The requested entity determines which levels are eligible:

| Surface target | Resolution order |
| --- | --- |
| Artist | Artist portrait only |
| Track | Track, album, EP, artist portrait |
| Album | Album, EP, artist portrait |
| EP | EP, album, artist portrait |

This boundary is intentional. A release cover must never appear as the artist
portrait. Track and release surfaces may use the artist portrait only as their
final fallback.

## Automatic providers

The default application has no artwork API keys, OAuth flows, user tokens, or
credential settings. The runtime catalog contains only sources that can be
queried without credentials:

| Provider | Accepted use | Correlation requirement |
| --- | --- | --- |
| Current player | Track artwork | Artwork belongs to the observed player item |
| Cover Art Archive | Album and EP covers | Resolved release or release-group MBID; the JSON image list must confirm a front image |
| Wikimedia Commons / Wikipedia | Artist portrait | Explicit MusicBrainz Wikidata or Wikipedia relationship |
| ListenBrainz | Typed track/release artwork already present in a validated response | Stable metadata carried by the response; never a URL synthesized from an MBID |
| Deezer | Track, album, or artist artwork | Explicit Deezer URL relationship on the resolved MusicBrainz entity |
| Discogs | Album, EP, or artist artwork | Explicit Discogs URL relationship on the resolved MusicBrainz entity |

Deezer and Discogs requests extract the numeric identifier from the explicit
MusicBrainz relationship. The resolver never searches either service by artist,
track, or release name. Provider requests carry no authorization header, API
key, token, or access-token query item.

## Excluded sources

Providers that require project credentials or user credentials are excluded
from the automatic catalog. This includes the Apple Music web API, Spotify,
Fanart.tv, and any compatibility service configured with private credentials.
TheAudioDB's documented shared/free key is still a credential and is therefore
excluded as well. AllMusic has no supported public artwork API and remains a
link/editorial source only; the application does not scrape or hotlink it.

Legacy provider enum cases remain decodable so existing local data can migrate,
but `automaticArtworkResolution` rejects them before display or propagation.

## Resolver contract

`ScrobbleService.artworkResolution(...)` is the UI-facing entry point. It:

1. normalizes an artist/track/album identity and includes the requested target
   level in the cache key;
2. reuses an allowed typed source result when one is already available;
3. coalesces concurrent requests for the same identity;
4. asks MusicBrainz for correlated entity identifiers and relationships;
5. validates Cover Art Archive JSON instead of constructing a `/front-*` URL;
6. queries correlated Deezer or Discogs references in deterministic order;
7. records provider, level, source relationship, and trace outcome;
8. caches positive results for 24 hours and misses for one hour;
9. returns `nil` after the last eligible level so the UI renders its neutral
   placeholder.

HTTP 404, empty or malformed responses, rate limiting, and transport failures
are misses for the current provider. They do not block the next provider or
fallback level.

## Propagation rules

- Dashboard, listens, track detail, charts, queue, social, explore, profiles,
  artist graphs, shared items, obsessions, menu-bar content, and iOS detail/list
  surfaces consume the typed result.
- Queue resolution updates every backend job for the same track fingerprint and
  persists that result.
- Shared and obsession records preserve provider provenance when exported and
  imported.
- User avatars are outside this musical-artwork pipeline.
- Compatibility accessors may expose a URL only after the typed resolution has
  passed the credential-free allowlist.

## Verification

The test fixtures and URL-protocol doubles cover:

- target-level ordering and artist/release isolation;
- rejection of credentialed and untyped legacy artwork;
- anonymous Deezer and Discogs requests from explicit relationships;
- 404 and rate-limit fallback;
- concurrent request coalescing and cache reuse;
- Cover Art Archive validation and bootleg rejection;
- queue and vault persistence with provider provenance;
- the Peaking Lights portrait regression;
- removal of synthesized Cover Art Archive URLs from ListenBrainz metadata.

Provider behavior can change independently of the app. If a currently anonymous
endpoint begins requiring credentials, remove it from
`ArtworkProviderCatalog.options` and `isCredentialFreeArtworkSource` before
shipping; do not add credentials to this pipeline.
