# UI/UX Improvement Plan

OpenScrobbler should feel like one product across macOS and iOS while respecting
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

## iOS Plan

### 1. First-Run And Account

- Replace the current account-heavy onboarding with a short setup stack:
  Connect ListenBrainz, grant Music library permission, create baseline.
- Show the user's ListenBrainz name, last refresh, last scan, and pending count
  in one compact Account header.
- Add a "Run Scan" primary action and a "View Pending" secondary action.

### 2. Listens

- Keep the manual `+` action but make it source-aware once source metadata lands.
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
- Keep graph and discovery sections scannable rather than hero-like.

### 4. Queue And Diagnostics

- Unify manual, player, library, and future imported listens under one status
  vocabulary.
- Show source metadata and retry state without exposing raw JSON by default.
- Add a copyable diagnostics payload for release/beta reports.

### 5. Accessibility And Polish

- Audit VoiceOver labels for icon-only buttons.
- Add keyboard shortcuts for refresh, manual submit, queue, and account.
- Confirm text does not overlap at narrow macOS window sizes and iPhone SE
  widths.

## Acceptance Criteria

- iOS and macOS use the same source/status language.
- Account and diagnostics can answer: connected user, last refresh, last scan,
  pending count, last error.
- Manual scrobble, queue, retry, and refresh actions are reachable in two taps
  or fewer on iOS and via menu/keyboard on macOS.
- Icons and brand assets match `docs/ICONOGRAPHY.md`.
- Primary screens pass screenshot review on iPhone SE, iPhone Pro, and a compact
  macOS window.
