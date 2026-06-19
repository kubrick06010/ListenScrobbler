# UI/UX Improvement Plan

ListenScrobbler should feel like one product across macOS and iOS while respecting
each platform. macOS remains a dense desktop control room; iOS should be a
focused listening companion with fast account, listens, scan, and discovery
flows.

## Shared Principles

- ListenBrainz identity and current listening state should be visible without
  digging through settings.
- Source and submission status should be understandable: manual, Music library,
  future Spotify import, future MusicKit, pending, failed, submitted.
- Empty states should offer one useful action, not explanatory walls of text.
- Icons should come from official ListenBrainz/MetaBrainz assets for brand
  surfaces and SF Symbols for system actions.
- Diagnostics must be accessible from Account on both platforms.
- Destructive or duplicate-prone actions need clear confirmation.
- Visible app text should be localizable across macOS and iOS, with English and
  Spanish as the first complete locales and later locales added only with review.

## iOS Plan

### 1. First-Run And Account

- Replace the current account-heavy onboarding with a short setup stack:
  Connect ListenBrainz, grant Music library permission, create baseline.
- Show the user's ListenBrainz name, last refresh, last scan, and pending count
  in one compact Account header.
- Add a "Run Scan" primary action and a "View Pending" secondary action.
- Add a free "Export Listening History" action in Account for portable
  scrobble/listen export, with progress, success, and failure states.

### 2. Listens

- Keep the manual `+` action but make it source-aware once source metadata lands.
- Add iOS swipe actions for recent listens: delete, love/unlove, and pin/unpin,
  using clear destructive/positive roles and showing unavailable actions only
  when identity can be resolved safely.
- Navigate from a tapped listen row into a track detail screen with sections for
  recording metadata, release context, artist context, ListenBrainz actions, and
  MusicBrainz/ListenBrainz links.
- Add visible states for submitting, queued, failed, and refreshed.
- Add pull-to-refresh and a last-updated timestamp.
- Add detail rows for MBID/MSID/source where available.

### 3. Library Scan

- Turn scan status into a timeline: baseline created, candidates detected,
  submitted, queued, retry succeeded, retry failed.
- Show why the first scan does not submit history.
- Add a beta diagnostics export text view for device testing.

### 4. Discover

- Replace placeholder cards with real ListenBrainz entry points:
  recommendations, similar users/artists, playlists, and LB Radio prompts.
- Implement the Search option in Discover with a real search field, scoped
  result sections, loading/empty/error states, and navigation into matching
  artist, track, release, or user detail routes.
- Implement the Radio option in Discover with selectable seeds or prompts,
  generated recommendation queues, loading/empty/error states, and clear links
  into track, artist, release, and ListenBrainz context.
- Add artist detail sheets from artist rows and recommendations, with biography
  highlights, MusicBrainz identity, ListenBrainz context, and source links.
- Disable unavailable integrations with honest status, not marketing copy.

### 5. Visual System

- Use the generated ListenBrainz image assets only where brand context matters.
- Use SF Symbols for actions: refresh, retry, scan, queue, plus, link, warning,
  checkmark, and info.
- Keep compact cards at 8px radius or less and avoid nested cards.

## macOS Plan

### 1. Navigation And Density

- Keep the sidebar but reduce repeated status copy inside panels.
- Add a compact global status strip for account, queue, current source, and last
  submission.
- Make source labels visible in queue and listen detail surfaces.

### 2. Menu Bar Parity

- Continue using the official monochrome ListenBrainz icon as a template image.
- Add tooltip/status text that matches iOS account wording.
- Ensure menu actions mirror iOS concepts: refresh, submit/manual, queue, open
  diagnostics.

### 3. Dashboard

- Separate currently playing, ListenBrainz context, and MusicBrainz enrichment
  into stable panels with consistent loading/error states.
- Open artist detail sheets from now-playing, recent-listen, chart, and
  discovery contexts, matching iOS content while using macOS-native sheet or
  inspector presentation.
- Keep graph and discovery sections scannable rather than hero-like.

### 4. Queue And Diagnostics

- Unify manual, player, library, and future imported listens under one status
  vocabulary.
- Show source metadata and retry state without exposing raw JSON by default.
- Add a copyable diagnostics payload for release/beta reports.

### 5. Accessibility And Polish

- Move visible macOS and iOS text into shared string catalogs and verify English
  and Spanish in primary flows.
- Keep localized labels short enough for compact iPhone widths and narrow macOS
  windows.
- Audit VoiceOver labels for icon-only buttons.
- Add keyboard shortcuts for refresh, manual submit, queue, and account.
- Confirm text does not overlap at narrow macOS window sizes and iPhone SE
  widths.

## Acceptance Criteria

- iOS and macOS use the same source/status language.
- iOS and macOS follow the user's device language for visible app text, with
  complete English and Spanish localizations in the first localization pass.
- Account and diagnostics can answer: connected user, last refresh, last scan,
  pending count, last error.
- iOS Account exposes free listening-history export; exporting scrobbles is not
  gated behind a paid feature.
- Manual scrobble, queue, retry, and refresh actions are reachable in two taps
  or fewer on iOS and via menu/keyboard on macOS.
- iOS recent listen rows support delete, love/unlove, and pin/unpin from swipe
  actions, and the same actions remain available from the detail screen.
- Tapping an iOS listen row opens a Last.fm-style detail route that lets the
  user inspect the song, release, and artist without losing list position.
- iOS Discover Search is implemented and no longer shows an "available in a
  later build" placeholder.
- iOS Discover Radio is implemented and no longer shows an "available in a
  later build" placeholder.
- Artist detail sheets reach feature parity on macOS and iOS: biography
  highlight, MusicBrainz/Wikidata/Wikipedia attribution, ListenBrainz context,
  loading/empty/error states, and external links.
- Icons and brand assets match `docs/ICONOGRAPHY.md`.
- Primary screens pass screenshot review on iPhone SE, iPhone Pro, and a compact
  macOS window.
