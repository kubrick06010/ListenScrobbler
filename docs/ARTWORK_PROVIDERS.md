# Artwork providers and resolution policy

ListenScrobbler keeps identity matching separate from artwork retrieval. MusicBrainz supplies the correlation layer (recording, artist, release and release-group MBIDs); an image is accepted only when it belongs to the resolved entity.

## Resolution order

1. Artist section: an artist portrait only. Prefer a Wikimedia/Wikidata image linked from the MusicBrainz artist; when the compatibility provider is configured, its artist image is the secondary portrait source. Never substitute an album or track cover in this section.
2. Track artwork: player-provided artwork, then the configured compatibility provider's track image, when the source can correlate it to the current artist and title.
3. Album artwork: Cover Art Archive for the resolved MusicBrainz release, then its release group.
4. EP artwork: the same Cover Art Archive release/release-group lookup when MusicBrainz identifies the release group as `EP`.
5. Final fallback: the artist portrait. If no artist portrait exists, the UI keeps its neutral artwork placeholder.

The open MusicBrainz result now exposes `ArtworkResolution` with the resolved level and provider. This prevents a release cover from silently becoming an artist portrait and gives future UI diagnostics enough information to show why an image was selected.

## Candidate providers

| Provider | Best use | Correlation | Decision |
| --- | --- | --- | --- |
| MusicBrainz + Cover Art Archive | Album/EP/release-group covers | Strong: MBID | Primary open provider. CAA documents release and release-group JSON endpoints and thumbnail URLs: [Cover Art Archive API](https://musicbrainz.org/doc/Cover_Art_Archive/API). |
| Wikimedia Commons via Wikidata/Wikipedia | Artist portraits | Strong when the MusicBrainz Wikidata relationship exists | Primary open portrait source; attribution and file-license metadata remain discoverable through Wikimedia. |
| Existing compatibility API | Track/album and artist images | Name/artist or provider response; can be configured by the user | Secondary provider, useful for coverage but never allowed to override a resolved open artist identity. |
| Spotify Web API | Album and artist images | Strong with Spotify IDs, but requires OAuth and attribution | Candidate only. Spotify requires original visual treatment, attribution and a link back to Spotify; it is not enabled in the default open path. See [Get an album](https://developer.spotify.com/documentation/web-api/reference/get-an-album). |
| Deezer API | Album/artist images | Strong with Deezer IDs | Candidate only; licensing, API availability and attribution need product/legal confirmation before enabling. |
| Discogs API | Release/edition covers and artist images | Strong with Discogs release/artist IDs; best reached after resolving the recording/release through a stable identity provider | Ready candidate. It is publicly accessible with a user token, but Discogs requires attribution/link-back, imposes freshness/cache restrictions, and distinguishes CC0 metadata from restricted content. Do not scrape the website or bulk-cache images. [API terms](https://support.discogs.com/hc/es/articles/360009334593-Condiciones-del-uso-del-API). |
| Apple Music API | Song, album and artist catalog artwork | Strong with Apple catalog IDs; the current Apple Music player can also provide local artwork | Candidate. It requires developer tokens and attribution; its artwork URL uses size placeholders and must be treated according to Apple's terms. See [Apple Music API](https://developer.apple.com/documentation/applemusicapi) and [Artwork](https://developer.apple.com/documentation/applemusicapi/artwork). |
| AllMusic | Editorial album, song and artist pages | Potentially strong by page identity, but no stable public developer API was found in this review | Manual/link-only candidate for now. Do not scrape pages or hotlink images without explicit permission. |
| Last.fm | Track/album images where already configured | Name-based unless an MBID is supplied | Candidate/legacy fallback. Do not use its image as an artist portrait unless the response is explicitly correlated to the artist. |
| TheAudioDB | Track, album, EP and artist artwork | Supports MusicBrainz artist/release-group/recording lookups in its free v1 API | Strong free candidate. Free key `123`, 30 requests/minute; use MBID endpoints where available and keep attribution visible. [Free API](https://www.theaudiodb.com/free_music_api). |
| Fanart.tv | Artist portraits, banners, album/CD art | Strong: music artist endpoint is keyed by MusicBrainz artist MBID and album entries expose release-group IDs | Strong candidate for the artist section and album/EP fallback. Requires a project API key; image licensing/attribution must be displayed according to the provider's requirements. [API](https://api.fanart.tv/). |
| Amazon Music | Catalog artwork | Potentially strong with Amazon catalog IDs | Not currently viable: Amazon's official developer portal says its Web API is in closed beta. See [Amazon Music Developer](https://developer.amazon.com/docs/music/landing_home.html). |

## Operational rules

- Store/cache the final image URL together with provider, level, MBID and retrieval time when persistence is added.
- Keep provider URLs unmodified; do not crop, overlay or proxy-rewrite provider artwork without checking that provider's terms.
- A 404, empty image list, malformed URL or rate-limit response is a miss and should advance to the next level/provider.
- Do not perform broad image search by artist name as a fallback: it creates the highest risk of showing the wrong artist or release.

The provider registry in `Sources/Services/ArtworkProviderCatalog.swift` records this inventory, supported entity levels, authentication/attribution requirements and whether a provider is active, a future candidate, or manual-only.
