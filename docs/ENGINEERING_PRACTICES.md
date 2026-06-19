# ListenScrobbler Engineering Practices

This document is the working protocol for future changes in this repository.
Every implementation should keep the codebase easier to understand after the
change than before it.

## Core Principles

- Keep files focused on one primary responsibility.
- Prefer small SwiftUI views with explicit inputs over large monolithic view
  files.
- Keep `ContentView` as app shell and high-level navigation only.
- Put reusable UI in `Sources/UI/Components`.
- Put feature screens in feature folders under `Sources/UI`.
- Keep service and persistence logic out of SwiftUI views unless the view is
  only coordinating calls on an injected service.
- Follow existing product language: ListenBrainz-first, open ecosystem,
  local-first vaults.
- Make changes in narrow, reviewable slices.
- Verify behavior with a build, and run tests when service or data-flow logic
  changes.

## SwiftUI Structure

Use this layout for new or moved UI code:

- `Sources/UI/ContentView.swift`: root shell, tab selection, sheets, top-level
  navigation state, and feature wiring.
- `Sources/UI/AppShell`: app chrome, tab shell, shared shell models.
- `Sources/UI/Components`: reusable controls, image loaders, layout helpers,
  modifiers, and AppKit representables.
- `Sources/UI/Dashboard`: dashboard-only views.
- `Sources/UI/Listens`: recent-listen surfaces and listen row actions.
- `Sources/UI/Charts`: chart and report surfaces.
- `Sources/UI/Social`: ListenBrainz social, recommendations, graph views.
- `Sources/UI/Vaults`: shared music and obsessions vault UI.
- `Sources/UI/Diagnostics`: diagnostics-only UI.

## File Size And Boundaries

- Prefer files under 400 lines.
- A file over 600 lines needs a reason and should be considered for splitting
  before adding more behavior.
- A view with multiple unrelated subviews should move those subviews into
  feature-local files.
- Reusable components should not depend on feature-specific state unless that is
  passed in through small value types or closures.

## State And Dependencies

- Use the narrowest state owner that fits the behavior.
- Keep app-wide services injected through environment objects until the app is
  ready for a broader dependency-injection refactor.
- Keep sheet and inspector state in the shell when it crosses feature
  boundaries.
- Pass user intents upward with closures such as `onShare`, `onOpenTrack`, and
  `onCaptureObsession`.

## Editing Protocol

1. Read the nearest existing code before changing it.
2. Identify the feature boundary before adding new files.
3. Prefer extracting existing behavior unchanged before redesigning it.
4. Avoid unrelated refactors in the same change.
5. Update this document when we intentionally change the architecture.
6. Run `xcodegen generate` after adding, moving, or deleting source files.
7. Run `xcodebuild -scheme ListenScrobbler -project ListenScrobbler.xcodeproj -configuration Debug build`.
8. Run `xcodebuild -scheme ListenScrobbler -project ListenScrobbler.xcodeproj -configuration Debug test` when service logic, models, parsing, persistence, or important user flows change.

## Branch Naming

- Name development branches as `<Product>/<Objective>`.
- Use the product or integration area as the first path component, and a short
  kebab-case objective as the second component.
- Example: `ListenBrainz/localization-foundation`.

## Review Checklist

- Does the changed file still have one clear responsibility?
- Did new behavior land near the feature it belongs to?
- Are shared components generic enough to justify living in `Components`?
- Are actions exposed through visible controls, tooltips, menus, or keyboard
  paths where appropriate?
- Does the app still compile from a clean generated Xcode project?
- Did tests run when the change touched behavior beyond presentation?
