# Parity Implementation Plan

This plan converts the Scrobbler for ListenBrainz review and the older Last.fm
desktop/iOS setup pattern into concrete ListenScrobbler work. The goal is product
parity where it makes sense, not a clone: ListenScrobbler should remain native on
macOS, transparent about iOS limits, and visibly grounded in ListenBrainz.

## Baseline From Scrobbler For ListenBrainz

- Account setup is guided, token based, and explicit about Keychain/local
  storage.
- The main screen shows connection state, recent listens, stats, feed, library,
  manual scrobble, integrations, data export, widgets, and shortcuts.
- Integrations mostly open or search external services. They are not hidden
  background listeners for other iOS apps.
- App Intents cover navigation, widget refresh, manual scrobbling, current Music
  app scrobbling, repeating a recent listen, and first loved track submission.
- Local history import gates deeper stats and export features.

## Product Position

- iOS: focused companion for ListenBrainz connection, local Music library scan,
  manual/source-aware listens, queue diagnostics, and future import actions.
- macOS: native desktop control room with menu bar scrobbling, queue/diagnostics,
  ListenBrainz charts/social context, and the same setup language as iOS.
- Shared: official ListenBrainz/MetaBrainz brand assets, source-aware listen
  metadata, honest platform limits, and beta diagnostics.

## Active Parity Goal

Goal: reach competitive iOS parity with Scrobbler for ListenBrainz while keeping
ListenScrobbler native, transparent about platform limits, and shared with the
macOS codebase.

Definition of done:

- A new user can connect ListenBrainz, understand setup, submit a manual listen,
  scan local Music library plays, and export diagnostics.
- A connected user can see recent listens, current pin, stats, recommendations,
  and social feed without leaving the app.
- System surfaces cover navigation, refresh, manual scrobble draft, and direct
  manual scrobble submission.
- Release gates pass on macOS tests, iOS Simulator build, and paired physical
  iPhone build/install/launch.
- Remaining non-parity gaps are explicitly deferred because of platform limits
  or because they need a widget/extension or provider OAuth track.

Current status: beta parity core is implemented. The next parity gaps are
current-Music intent, recommendation actions (pin/share/playlists), provider
imports, and TestFlight release packaging.

## Phase 1: Guided Account Setup

Status: implemented.

- Add a shared `ListenBrainzSetupGuide` model with account, token, enablement,
  verification, and optional import steps.
- Show the guide in macOS Account.
- Show the guide in macOS Preferences > ListenBrainz, where token validation
  actually happens.
- Show the guide in iOS Account before the token connection form.
- Link directly to MusicBrainz registration, ListenBrainz token/profile, and
  ListenBrainz Add Data/import options.
- Add tests that lock the step order and destination hosts.

## Phase 2: iOS Competitive Parity

- Stats:
  - Show a compact ListenBrainz mobile stats panel with selectable week, month,
    year, and all-time ranges.
  - Surface total listens, top artists, top releases, and top tracks from the
    existing core ListenBrainz stats client.
  - Keep stats refresh separate from connection state so stats failures do not
    disconnect the account.

  Status: implemented on iOS Home.

- App Intents:
  - Open dashboard/listens/account/discover.
  - Open manual listen from Shortcuts with optional track, artist, and album
    draft data.
  - Refresh ListenBrainz by opening the app and routing through the shared
    listening store.
  - Submit manual listen from Shortcuts with track, artist, album, duration, and
    listened-at parameters.
  - Repeat the most recent ListenBrainz listen from Shortcuts with an explicit
    duration fallback.
  - Submit current Music app listen when Music APIs expose enough identity.
  - Refresh widgets and recent listens.

  Status: first pass implemented for open destination, open manual scrobble,
  refresh ListenBrainz, direct manual scrobble submission, and repeat recent
  listen. Widget refresh is implemented. Current Music app remains.
- Widgets:
  - Connected account/status widget.
  - Recent listen widget.
  - Current pin or recommendation widget.

  Status: first pass implemented as a WidgetKit extension backed by the mobile
  ListenBrainz snapshot. The app writes connection, latest listen, current pin,
  first recommendation, pending count, and update time; Shortcuts can request a
  widget timeline refresh. Remaining widget work: deeper timeline policy,
  App Group provisioning verification on physical devices, and richer widget
  tap routing once URL/deep-link routing is formalized.
- Recommendations:
  - Load recommended recordings from the shared ListenBrainz recommendation
    client.
  - Show real recommendations in iOS Discover with independent refresh state.
  - Keep sharing, pinning, and playlist creation for a later pass once the
    mobile action surfaces are stable.

  Status: first pass implemented on iOS Discover.
- Social feed:
  - Load followers, following, and similar users from ListenBrainz.
  - Aggregate recent listens from those neighboring users into a compact mobile
    feed.
  - Keep follow/unfollow, compatibility comparison, and graph exploration for a
    later pass.

  Status: first pass implemented on iOS Discover.
- Local history:
  - Promote pending retries into a provider-neutral import queue.
  - Add submitted/duplicate/rejected/failed states.
  - Export diagnostics with source metadata and payload preview.

  Status: first beta diagnostics export is implemented from iOS Account. It
  includes app/build version, OS/device context, ListenBrainz connection state,
  Music library scan status, last scan summary, last error, pending retry count,
  and source metadata for pending items. Payload preview remains part of the
  provider-neutral queue work.
- Integrations:
  - Keep web/service shortcuts honest.
  - Add Spotify recently played only as an explicit user import after OAuth and
    queue dedupe exist.
  - Defer YouTube Music native support; prefer export/import or manual source
    metadata.

## Phase 3: macOS Parity

- Account/setup:
  - Keep the same guide in Account and Preferences.
  - Surface connected username, token validation state, backend, and last
    ListenBrainz error in one place.
- Iconography:
  - Keep app/menu/status icons generated from MetaBrainz ListenBrainz assets.
  - Use SF Symbols only for generic system actions.
- Queue and diagnostics:
  - Show source metadata in queue/detail surfaces.
  - Add copyable diagnostics payloads for beta reports.
- Menu bar:
  - Mirror iOS vocabulary for refresh, manual submit, queue, account, and
    diagnostics.
  - Add keyboard shortcuts for common actions.

## Phase 4: Release Gates

- iOS Simulator build passes.
- macOS unit test suite passes.
- Physical device build, install, and launch pass on the paired iPhone with the
  `org.listenscrobbler.app.ios` bundle.
- Account setup screenshots are captured for macOS compact width and iPhone
  small/Pro widths.
- Release notes mention iOS as beta until physical device and TestFlight gates
  pass.
