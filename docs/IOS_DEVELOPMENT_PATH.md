# iOS Development Path

ListenScrobbler's iOS version should live in this repository while the product
shape is still settling. The current structure keeps the macOS app stable and
adds a small iOS foundation without copying the desktop UI.

## Targets

- `ListenScrobbler`: the existing macOS app.
- `ListenScrobblerCore`: an iOS framework target that exposes a narrow mobile
  facade over shared ListenBrainz/domain code.
- `ListenScrobbleriOS`: the first native iOS app target.

`project.yml` remains the source of truth. Run `xcodegen generate` after target
or source layout changes.

## Current iOS Scope

The first iOS target is intentionally modest:

- ListenBrainz token connection and validation.
- Recent ListenBrainz listens.
- Current ListenBrainz pin.
- Manual listen submission from the iOS Listens tab.
- Music library delta scanning with `MPMediaLibrary` / `MPMediaQuery`.
- Persistent retry storage for Music library scrobbles that fail submission.
- Account-visible scan status: last scan, detected, submitted, failed, and
  pending retry counts.
- Account-visible pending queue details for failed Music library submissions,
  including attempts, timestamps, last error, and a clear action for beta tests.
- Tab-based SwiftUI shell with `NavigationStack` per tab.

This gives iOS the real open-ecosystem client path before adding platform
specific playback adapters.

## Last.fm iPhone Reference

The historical `lastfm/lastfm-iphone` repository is mirrored locally under
`.references/lastfm-iphone` for product reference only. It is Objective-C,
GPL-licensed, and built on old UIKit-era dependencies, so do not copy code or
assets into ListenScrobbler.

Ideas worth carrying forward:

- A persistent mobile mental model: Profile, Recommendations, Search, and Radio
  live as first-class tabs rather than hidden desktop panels.
- A global Now Playing affordance appears in navigation stacks while playback is
  active.
- Track, artist, and album detail screens are compact grouped sections with
  obvious actions: love, share, tag/pin, play radio, inspect artist, and open
  related content.
- Network and cache behavior is explicit: user-facing lists should tolerate
  stale data, refresh quickly, and clean old temporary state.
- Scrobbling is modeled separately from playback UI, with a queue saved on app
  termination.

ListenScrobbler's translation:

- Keep the iOS shell tab-first, but map the old Last.fm tabs to open ecosystem
  concepts: ListenBrainz profile, recommendations, search, playlists, pins, and
  LB Radio prompts.
- Keep a global Now Playing route, but implement it through iOS-specific
  adapters rather than macOS notification or AppleScript behavior.
- Prefer detail routes that explain open identity: MusicBrainz IDs, ListenBrainz
  MSIDs, listener counts, tags, pins, and playlist/export actions.
- Reuse the existing queue and ListenBrainz client path before adding playback
  integrations.

## Scrobbling Strategy

Do not port macOS player monitoring directly to iOS. The macOS app relies on
distributed player notifications and AppleScript fallbacks, neither of which is
an iOS product model.

iOS work should add adapters in this order:

1. Music library delta scanning with user permission.
2. Manual listen submission and queue management.
3. Apple Music / MusicKit-assisted workflows where user permissions allow them.
4. Spotify or other service-specific integrations only through supported APIs.
5. Background behavior only where Apple platform rules explicitly support it.

The shared rule stays the same: adapters emit normalized listening events, and
submission policy lives above them.

The current scanner creates a local baseline on first run and only submits
future increments in Music library play counts. This avoids importing the user's
old listening history by accident.

## Build Commands

Build the iOS target in this environment with the simulator SDK:

```bash
xcodebuild build \
  -project ListenScrobbler.xcodeproj \
  -scheme ListenScrobbleriOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO
```

For a physical iPhone, use Xcode's normal signing flow or a `devicectl` install
of an already signed `.app`. Device tracing is available with `xcrun xctrace`
once Developer Mode and pairing are enabled.

The reproducible physical-device path is captured in:

```bash
tools/ios_device_validation.sh
```

Current known device:

- Device name: `haa`
- Device model: `iPhone 15`
- Device app identifier: `A04FE658-891B-575D-A47B-26424DACB600`
- Xcode destination id: `00008120-0004388834C3601E`
- Installed bundle id: `org.listenscrobbler.app.ios`

The current local blocker is signing, not app code. Command-line signing reaches
the device, but Xcode cannot load the Apple account credentials for team
`7K778AG29F` and therefore cannot create or find a provisioning profile for
`org.listenscrobbler.app.ios`. After refreshing the Apple ID in Xcode Settings,
rerun `tools/ios_device_validation.sh`; it builds, installs, verifies the
installed bundle, launches the app, and prints the trace command to run while
exercising connect, refresh, and Music library scan.

A trace of the already-installed device build exists at
`tmp/device-traces/ListenScrobbler-installed-build.trace`. That build is bundle
version `5` and its executable name is `ListenScrobbler`, so it proves the
device-launch and trace path but does not validate the latest scanner changes.

Keep validating macOS:

```bash
xcodebuild build \
  -project ListenScrobbler.xcodeproj \
  -scheme ListenScrobbler \
  -destination 'platform=macOS'

xcodebuild test \
  -project ListenScrobbler.xcodeproj \
  -scheme ListenScrobbler \
  -destination 'platform=macOS'
```

## Next Slices

- Move more Foundation-only services into `ListenScrobblerCore` behind focused
  public facades.
- Add device-level trace evidence for the current scanner build after installing
  it on a physical iPhone.
- Promote the pending queue from beta diagnostics to a fuller offline queue
  screen shared by manual submission and library scanning.
- Replace remaining placeholder copy with beta-ready user-facing states.

## Beta Gate

The iOS app is beta-ready when this checklist is true on a physical device:

- First launch can connect a ListenBrainz token and refresh recent listens.
- A manual scrobble can be submitted from iOS and appears after refresh.
- First Music library scan creates a baseline and does not submit old history.
- A later Music library play count increment creates exactly one scrobble.
- Re-running scan without another play does not duplicate the scrobble.
- Failed candidate submissions are persisted for retry instead of dropped.
- Account shows last scan time, detected count, submitted count, and failures.
- Account can inspect pending retries with track metadata, attempts, timestamps,
  and last error.
- Mobile ListenBrainz connection, refresh, manual submit, and disconnected
  submit behavior are covered by focused tests.
- Music library baseline, new-play submit, failed-submit persistence, retry
  success, and retry failure summaries are covered by the shared scan engine
  tests.
- Device traces include ListenScrobbler `Logger` events for connect, refresh,
  permission status, scan start, baseline, candidates, submissions, and errors.
- App icon, in-app image assets, and macOS menu bar icon are generated from
  official ListenBrainz assets documented in `docs/ICONOGRAPHY.md`.
- macOS build/tests and iOS simulator build pass from the command line.
