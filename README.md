# ListenScrobbler

ListenScrobbler is a macOS SwiftUI app for open listening history, centered on ListenBrainz, MusicBrainz, and local-first music memory.

Version `1.1.0` is the current macOS release line. The iOS target is being
prepared as its first `1.0.0` release after physical-device beta validation.

## Repository Plan

ListenScrobbler should be published as one new GitHub repository, not split into
separate macOS and iOS repos. The single-repo shape keeps shared ListenBrainz
services, domain models, tests, release docs, icon assets, and WidgetKit support
reviewable in one place while the product is still settling.

Recommended GitHub target:

- Repository name: `ListenScrobbler`
- Default branch: `main`
- Working branches: short-lived branches such as `codex/ios-foundation`
- Release tags: `v<version>`, for example `v1.1.0`

After creating the new repository, point this local checkout at it:

```bash
git remote add origin git@github.com:kubrick06010/ListenScrobbler.git
git push -u origin main
```

The current app includes:

- ListenBrainz token-based account setup with local app-owned token storage.
- Now playing and completed listen submission.
- Love/unlove for the current track and recent listens through ListenBrainz recording feedback.
- Pin/unpin and share actions for ListenBrainz listen rows.
- Offline queueing with per-backend retry state.
- Charts, listening archive views, and social discovery surfaces shaped around open data.
- Local-first shared music and obsession vaults.
- Menu bar controls, launch-at-login, proxy settings, diagnostics, and player monitoring.
- iOS foundation work for ListenBrainz connection, manual submission, recent
  listens, Music library scan baseline/delta behavior, and pending retries.

## Direction

ListenBrainz is the primary service. Compatibility code may remain temporarily as an adapter/reference during migration, but product language, onboarding, storage names, and feature work should be ListenBrainz-first.

Charts and social features stay in scope. The goal is not to remove social music discovery, but to rebuild it on ListenBrainz-compatible concepts such as public listens, follows, similar users, MusicBrainz identifiers, playlists, pins, recommendations, and portable local archives.

## Architecture

The app now follows the repository protocol in `docs/ENGINEERING_PRACTICES.md`. In short:

- `Sources/UI/ContentView.swift` is the high-level app shell.
- Feature screens live in focused folders under `Sources/UI`, such as `Dashboard`, `Listens`, `Charts`, `Social`, `Vaults`, `Queue`, `Profile`, `Explore`, and `Account`.
- Reusable SwiftUI controls and AppKit bridges live in `Sources/UI/Components`.
- Services and persistence stay out of view files unless a view is only coordinating calls on an injected service.
- `project.yml` is the source of truth for the generated Xcode project.

## Build And Test

Requirements:

- macOS 13 or newer.
- Xcode with the macOS SDK.
- XcodeGen if you want to regenerate the checked-in project from `project.yml`.

Generate the Xcode project:

```bash
xcodegen generate
```

Build from the command line:

```bash
xcodebuild build \
  -project ListenScrobbler.xcodeproj \
  -scheme ListenScrobbler \
  -destination 'platform=macOS'
```

Build the iOS target in the simulator:

```bash
xcodebuild build \
  -project ListenScrobbler.xcodeproj \
  -scheme ListenScrobbleriOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO
```

Build, install, and launch on a paired iPhone:

```bash
DEVELOPMENT_TEAM=YOURTEAMID ./tools/ios_device_validation.sh
```

The iOS app and WidgetKit extension share their latest ListenBrainz snapshot
through the App Group `group.org.listenscrobbler.app`, so physical-device signing
must enable that capability for both bundle identifiers.

Run tests:

```bash
xcodebuild test \
  -project ListenScrobbler.xcodeproj \
  -scheme ListenScrobbler \
  -destination 'platform=macOS'
```

## Current Shape

- `Sources/App`: app lifecycle and menu bar.
- `Sources/Services`: player monitor, queue, ListenBrainz, proxy, vault, and transitional scrobble coordination.
- `Sources/UI`: SwiftUI app shell, feature screens, and reusable components.
- `Sources/Domain`: shared domain models.
- `Tests`: deterministic coverage for services, queues, parsing, vault behavior, and release-critical regressions.

## Post-1.0 Maintenance

ListenScrobbler 1.0.0 is a stable milestone, not the end of the architecture work. Remaining cleanup should happen in narrow, tested slices:

- Reduce migration-era naming in orchestration and storage.
- Keep expanding ListenBrainz, MusicBrainz, and local archive behavior behind focused services.
- Keep large SwiftUI views moving toward feature-local components before adding major new behavior.

## Reference Strategy

Implementation work should stay aligned with the open ecosystem instead of inventing private semantics. See:

- `docs/OPEN_ECOSYSTEM_REFERENCES.md`
- `docs/LISTENBRAINZ_INTEGRATION.md`
- `docs/ENGINEERING_PRACTICES.md`
- `docs/ICONOGRAPHY.md`
- `docs/IOS_DEVELOPMENT_PATH.md`
- `docs/IOS_SOURCE_INTEGRATIONS_PLAN.md`
- `docs/UI_UX_IMPROVEMENT_PLAN.md`
- `docs/REPOSITORY_RELEASE_PLAN.md`
- `docs/RELEASE_PROCESS.md`
- `ROADMAP.md`
