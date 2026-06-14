# Scrobbler for ListenBrainz Review

Competitor/complement review for Dominik Gerwing's iOS app.

## App Store Metadata

- App: Scrobbler for ListenBrainz
- Developer: Dominik Gerwing
- Bundle ID: `de.rankwert.ScrobblerForListenBrainz`
- App Store ID: `6762062811`
- App Store URL: https://apps.apple.com/es/app/scrobbler-for-listenbrainz/id6762062811
- Current version observed: `2.2`
- Bundle version observed on device: `7`
- Current version date observed: 2026-06-03
- Original release date observed: 2026-05-27
- Minimum OS observed: iOS `26.0`
- Size observed: ~7.9 MB
- Price: free, with App Store listing showing support-style in-app purchases
- Privacy label observed: developer declares no data collected
- Languages observed: English, French, German, Spanish
- Installed app display name observed on device: `Scrobbler`
- Installed bundle path observed on device:
  `/private/var/containers/Bundle/Application/F925459A-269C-4624-9981-89764B0B97D8/ScrobblerForListenBrainz.app/`
- Widget extension process observed:
  `ScrobblerForListenBrainzWidgets.appex`

## macOS Installation Review

Observed installed path on Apple Silicon Mac:

- `/Applications/Scrobbler.app`
- Wrapped iPhoneOS app:
  `/Applications/Scrobbler.app/Wrapper/ScrobblerForListenBrainz.app`

The app is an iPhoneOS build running on macOS through Apple's iOS-on-Mac app
wrapper rather than a separate native macOS target:

- `CFBundleSupportedPlatforms = ["iPhoneOS"]`
- `DTPlatformName = iphoneos`
- `MinimumOSVersion = 26.0`
- `Format = app bundle with Mach-O thin (arm64)`
- Signing authority: Apple iPhone OS Application Signing
- Team identifier: `ZDA9A99P8G`

Entitlements observed:

- `application-identifier = ZDA9A99P8G.de.rankwert.ScrobblerForListenBrainz`
- `com.apple.security.application-groups =
  ["group.de.rankwert.ScrobblerListenBrainz"]`

Info.plist capability signals:

- `NSAppleMusicUsageDescription`: reads the track currently playing in the
  Music app so it can submit it to ListenBrainz.
- `UIBackgroundModes`: `fetch`, `processing`
- `BGTaskSchedulerPermittedIdentifiers`:
  - `de.rankwert.ScrobblerForListenBrainz.refresh`
  - `de.rankwert.ScrobblerForListenBrainz.listenHistoryImport`
- URL scheme: `listenbrainzapp`
- `LSApplicationQueriesSchemes`: `spotify`

Widget extension:

- Bundle ID: `de.rankwert.ScrobblerForListenBrainz.widgets`
- Extension point: `com.apple.widgetkit-extension`

Privacy manifest:

- No collected data types declared.
- No tracking declared.
- Accessed API categories include UserDefaults and file timestamps.
- Bundled image library observed: Kingfisher, with its own privacy manifest.

Containers created on macOS:

- `~/Library/Containers/de.rankwert.ScrobblerForListenBrainz`
- `~/Library/Group Containers/group.de.rankwert.ScrobblerListenBrainz`

Observed local structure includes StoreKit receipt storage, Kingfisher image
cache, standard preferences/caches/logs directories, and a group container for
shared widget/app state. No user token or private database content was read.

## Visual Notes

- Extracted app icon:
  `tmp/scrobbler-review/scrobbler-icon.png`
- The icon uses a light iOS 26-style glass treatment with blue music notes,
  vertical chart bars, and a rounded translucent background.
- It does not visually use the ListenBrainz/MetaBrainz mark family. That leaves
  room for ListenScrobbler to stay differentiated with explicit MetaBrainz
  ecosystem iconography and cross-platform parity.

## Screen Audit

Captured screen audit folder:

- `tmp/scrobbler-review/screens/`
- Notes: `tmp/scrobbler-review/screens/audit-notes.md`

Captured screens:

- `01-current.png`: welcome screen, "Tu ListenBrainz en el iPhone".
- `02-onboarding-step-2.png`: token/keychain explanation.
- `03-onboarding-step-3.png`: widgets, themes, and quick actions.
- `04-account-question.png`: existing-account versus new-user branch.
- `05-token-login.png`: top of ListenBrainz token login flow.
- `06-token-login-lower.png`: token field, show-token toggle, disabled connect
  button, and ListenBrainz/token-page links.
- `08-post-login-current.png`: post-login dashboard/panel.
- `09-stats.png`: ListenBrainz statistics.
- `10-feed.png`: social feed/search.
- `11-library.png`: library/pins.
- `12-settings-top.png` and `12-settings.png`: settings top and lower account
  management area.
- `13-settings-scrobble.png`: manual scrobble entry.
- `14-settings-integrations.png` and `15-settings-integrations-lower.png`:
  outbound service open/search integration toggles.
- `17-listen-detail.png` and `18-listen-detail-actions.png`: listen detail and
  feedback/open actions.
- `19-stats-local-history.png`: local-history dependency state.

Screen-level findings:

- The onboarding is visually cohesive and friendly, with one dominant CTA per
  step.
- The product is honest about token login and ListenBrainz web setup.
- The token login screen is useful but dense; the action field falls below the
  fold in the small iOS-on-Mac window.
- The captured token route has no visible back button, and macOS keyboard back
  navigation did not work during the audit.
- Secondary red-on-pink controls and disabled grey controls may have contrast
  risk.
- Post-login dashboard, stats, library, settings, and widgets were not audited
  during the first unauthenticated pass. After the account was connected, the
  dashboard, stats, feed, library, settings, manual scrobble, integrations,
  listen detail, and local-history dependency state were captured.

Post-login findings:

- The product acts primarily as a polished ListenBrainz client with stats,
  recommendations, feed, library, widgets, shortcuts, and manual scrobbling.
- Service integrations are transparent outbound open/search toggles, not native
  Spotify/Deezer/YouTube Music importers.
- Local-history statistics require a full ListenBrainz listen import through
  Data & Export, reinforcing the local cache/database architecture.
- The manual scrobble surface is intentionally minimal: artist, song, optional
  release year, and a disabled submit button until input is present.
- Listen detail surfaces useful ListenBrainz/MusicBrainz actions, love/hate
  feedback, pin, and playlist state.
- The floating tab bar is easy to understand, but it overlaps content at the
  bottom of several long screens.
- Several Spanish labels wrap awkwardly in large circular buttons or dense
  cards, and some secondary text has low contrast.

Post-login limits:

- No token, private database, or app container content was read.
- No ListenBrainz write action was triggered.
- No destructive action was tapped.
- Widgets and network payloads were not verified.

## Publicly Claimed Scope

The App Store listing and MetaBrainz post position the app as a native
ListenBrainz client focused on:

- Listening stats and analytics.
- Shareable visualizations and recaps.
- Social feed, following, discovery, and profile highlights.
- Home Screen widgets.
- Export flow.
- Rebuilt caching/storage backend in the 2.0 line.
- Music service links/integration for opening songs in services such as
  Spotify, YouTube, and Deezer.
- Background/catch-up syncing for scrobbles under iOS constraints.

## Inferred Product Architecture

Bundle strings and App Intents metadata indicate:

- Token login through ListenBrainz user token from
  `https://listenbrainz.org/settings/`.
- Token storage in the iOS Keychain.
- Default ListenBrainz API host: `https://api.listenbrainz.org`.
- Listen submission through `/1/submit-listens`.
- Token validation through `/1/validate-token`.
- Manual scrobble UI and App Intent support.
- Current Music app scrobbling through App Intents and Apple Music access.
- No current-track access for other apps: the localized error explicitly says
  iOS does not expose current playback from other apps to Scrobbler.
- Listen history import, local listen storage, export, and storage limits.
- Background refresh and listen-history import workers.
- MusicBrainz artist lookup and recording links.
- Fanart.tv artist image lookup.
- Open/search actions for Spotify, Deezer, YouTube, and YouTube Music.

App Intents observed:

- `OpenDashboardIntent`
- `OpenStatsIntent`
- `OpenLibraryIntent`
- `RefreshWidgetsIntent`
- `SubmitListenIntent`
- `SubmitCurrentMusicListenIntent`
- `SubmitRecentListenAgainIntent`
- `SubmitFirstLovedTrackIntent`

Shortcut phrases include manual scrobbling, current Music app scrobbling,
repeat latest listen, and loved-track scrobbling.

The MetaBrainz community announcement for 2.0 emphasizes:

- A caching and data-storage rewrite.
- Faster and more reliable navigation.
- More statistics.
- Data export.
- Improved discovery and following flows.

## Open Questions For Hands-On Review

These need device testing with a ListenBrainz account:

- Authentication:
  - Does it use ListenBrainz user token paste, OAuth-like flow, or another
    method?
  - Where is the token stored?
  - Can the app change ListenBrainz server/base URL?
- Scrobbling mechanism:
  - Does "background scrobbling" rely on Apple Music library play counts,
    MusicKit, MediaPlayer now-playing info, Shortcuts, widgets, or another
    mechanism?
  - Does it submit `playing_now`, `single`, or `import` listens?
  - Does it avoid duplicates on repeat plays and catch-up sync?
  - Does it attach source metadata in `additional_info`?
- Source integrations:
  - Are Spotify, YouTube, and Deezer true import/scrobble sources, or outbound
    links for opening discovered tracks? Bundle strings suggest they are
    primarily open/search integrations, while service connection is delegated
    to ListenBrainz web onboarding.
  - Does the app preserve `origin_url`, `music_service`, `spotify_id`, or
    similar metadata when submitting listens?
- Offline/retry behavior:
  - Are failed scrobbles queued visibly?
  - Can users inspect or retry failures?
  - How does it behave with airplane mode?
- Stats/social UX:
  - Which ListenBrainz endpoints are surfaced?
  - How fast is first load on a large account?
  - What is cached, and how is stale data refreshed?
- Export:
  - What format does export use?
  - Does it export ListenBrainz listens, app-local cache, settings, or all of
    the above?
- Accessibility and polish:
  - VoiceOver labels.
  - Dynamic Type.
  - Dark mode contrast.
  - Reduced Motion.

## Differentiation For ListenScrobbler

Avoid positioning ListenScrobbler as "another generic ListenBrainz iOS app".
Dominik's app appears to own the pure iOS ListenBrainz-client lane already.

ListenScrobbler should emphasize:

- Cross-platform macOS + iOS scrobbling with shared core models.
- macOS player monitoring and local workflow tooling.
- MusicBrainz enrichment surfaces beyond basic ListenBrainz stats.
- Explicit source metadata contracts for future imports.
- Transparent queue, diagnostics, retry, and payload inspection.
- A conservative iOS policy: submit only when timestamp and track identity are
  reliable, with no private scraping or overclaimed background behavior.
- ListenBrainz/MetaBrainz iconography parity across platforms.

Specific lessons to consider:

- Add App Intents early for manual scrobble, current Music app scrobble, repeat
  last listen, dashboard/listens navigation, and widget refresh.
- Be explicit in UI copy that iOS exposes the Music app current track but not
  arbitrary third-party playback.
- Consider BGTaskScheduler identifiers for refresh and import jobs once the
  queue contract is solid.
- Consider a group container only when widgets or extensions actually need
  shared state.
- Keep ListenScrobbler's macOS story native rather than iOS-on-Mac; that is a
  concrete differentiation from Scrobbler for ListenBrainz.

## Hands-On Test Script

1. Install from the App Store.
2. Open once without a ListenBrainz token/account and capture onboarding flow.
3. Connect a ListenBrainz account.
4. Inspect permissions requested by iOS.
5. Submit or trigger one listen if the app supports it directly.
6. Play one Apple Music/library track and observe whether the app detects it.
7. Test airplane mode during a scrobble/catch-up flow.
8. Check ListenBrainz web profile for submitted listen type and
   `additional_info` if visible through API/debug tooling.
9. Try Spotify/YouTube/Deezer flows and record whether they are outbound links
   or actual listen import sources.
10. Review widgets, export, stats, social discovery, and accessibility basics.

## Device Inspection Notes

Local state at review start:

- `xcrun devicectl list devices` saw the paired iPhone but it was
  `unavailable`.
- A later `xcrun devicectl list devices` check saw the paired iPhone as
  `available (paired)`.
- After App Store installation, `xcrun devicectl device info apps --bundle-id
  de.rankwert.ScrobblerForListenBrainz` confirmed `Scrobbler` version `2.2`,
  bundle version `7`.
- `xcrun devicectl device process launch` successfully launched the app.
- Running processes showed both the main app executable and widget extension.
- `ideviceinstaller`, `ipatool`, and `mas` were not installed locally.
- Direct App Store URL was opened from macOS for manual installation.
