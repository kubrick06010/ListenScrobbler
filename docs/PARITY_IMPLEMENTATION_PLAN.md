# Parity Implementation Plan

This plan converts the Scrobbler for ListenBrainz review and the older Last.fm
desktop/iOS setup pattern into concrete OpenScrobbler work. The goal is product
parity where it makes sense, not a clone: OpenScrobbler should remain native on
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

## Phase 1: Guided Account Setup

Status: implemented.

- Add a shared `ListenBrainzSetupGuide` model with account, token, source, and
  verification steps.
- Show the guide in macOS Account.
- Show the guide in macOS Preferences > ListenBrainz, where token validation
  actually happens.
- Show the guide in iOS Account before the token connection form.
- Link directly to MusicBrainz registration, ListenBrainz token/profile, and
  ListenBrainz music-service settings.
- Add tests that lock the step order and destination hosts.

## Phase 2: iOS Competitive Parity

- App Intents:
  - Open dashboard/listens/account/discover.
  - Open manual listen from Shortcuts with optional track, artist, and album
    draft data.
  - Refresh ListenBrainz by opening the app and routing through the shared
    listening store.
  - Submit manual listen from Shortcuts after the provider-neutral queue/dedupe
    layer exists.
  - Submit current Music app listen when Music APIs expose enough identity.
  - Repeat a recent ListenBrainz listen.
  - Refresh widgets and recent listens.

  Status: first pass implemented for open destination, open manual scrobble,
  and refresh ListenBrainz routes. Inline submission, current Music app
  submission, and repeat-last-listen remain gated on queue/dedupe and Music API
  validation.
- Widgets:
  - Connected account/status widget.
  - Recent listen widget.
  - Current pin or recommendation widget.
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
- Physical device install and first-run validation pass once provisioning is
  fixed.
- Account setup screenshots are captured for macOS compact width and iPhone
  small/Pro widths.
- Release notes mention iOS as beta until physical device and TestFlight gates
  pass.
