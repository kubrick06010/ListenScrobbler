# Localization

ListenScrobbler localizes first-party app text through the shared resources in
`Resources`. English is the source language and Spanish is the first translated
locale.

## Current Scope

- Shared string catalog: `Resources/Localizable.xcstrings`.
- Info.plist strings: `Resources/en.lproj/InfoPlist.strings` and
  `Resources/es.lproj/InfoPlist.strings`.
- Initial product coverage: iOS tabs, Home, Listens, Discover, Account,
  onboarding/setup, mobile status strings, widgets, App Intents labels, and the
  Music library permission prompt.

MacOS and iOS both include `Resources`, so new first-party user-facing strings
should use the shared catalog unless a target-specific reason requires a
separate table.

## External Content

ListenBrainz and MusicBrainz data should remain as provided by the service.
Wikipedia/Wikidata biographies should prefer the user's language when available,
then fall back to English, then to open metadata without biography text.

## Expansion Path

Keep English and Spanish complete before adding more locales. The next reviewed
batch should be French, German, Italian, and Portuguese. Additional locales
should ship only after checking compact iPhone widths and narrow macOS windows.
