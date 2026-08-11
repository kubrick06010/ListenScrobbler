# Localization

ListenScrobbler uses one shared, runtime-selectable localization system across
the macOS app, iOS app, and iOS widgets. English is the development language,
but the implementation does not contain a closed enum of supported languages.
Adding a complete localization to the string catalogs makes it discoverable by
the language picker without a code change.

## Published Languages

The initial published set matches the historical Last.fm Desktop application:

- English (`en`)
- German (`de`)
- Spanish (`es`)
- French (`fr`)
- Italian (`it`)
- Japanese (`ja`)
- Polish (`pl`)
- Portuguese (`pt`)
- Russian (`ru`)
- Swedish (`sv`)
- Turkish (`tr`)
- Simplified Chinese (`zh-Hans`)

Language identifiers are normalized BCP 47 identifiers. Regional or script
variants can be added later without changing the preference model.

## Resources

- First-party app text: `Resources/Localizable.xcstrings`.
- App Shortcut phrases: `Resources/AppShortcuts.xcstrings`.
- System-owned bundle text and permission prompts:
  `Resources/<language>.lproj/InfoPlist.strings`.

All application targets include the shared resources. The App Shortcut catalog
is included only where App Intents requires it.

## Selection and Fallback

Users can select **System Language** or any localization bundled with the app.
The stable BCP 47 identifier is persisted in the shared app-group defaults; an
empty or invalid value falls back safely to the system preference.

A language change is deliberately atomic: the preference is saved immediately,
but the running process keeps its launch language until ListenScrobbler is
reopened. macOS offers to restart the app at once; iOS applies the choice on the
next launch. This prevents long-lived status, error, menu, and accessibility
text from mixing two languages in one session.

System-language resolution walks the user's preferred languages and the
available bundle localizations. Resolution removes specificity one component at
a time before falling back to the development language. For example:

```text
zh-Hans-CN -> zh-Hans -> zh -> en
pt-BR      -> pt -> en
```

The interface language and formatting region are deliberately separate. A user
can select French while retaining Canadian regional number and date conventions.

## SwiftUI and Programmatic Strings

SwiftUI views receive the effective locale at each app entry point. Literal
labels such as `Text("Settings")` therefore resolve through the selected app
language.

Strings created outside a SwiftUI environment must use `AppLocalization`:

```swift
AppLocalization.string("Authenticated")
AppLocalization.string("Signed in as \(username)")
AppLocalization.integer(playCount)
AppLocalization.date(date, date: .abbreviated, time: .shortened)
AppLocalization.localizedStringWithFormat(
    AppLocalization.string("%d recommendations loaded"), count
)
```

Do not introduce new bare `String(localized:)` calls in services, models,
exports, diagnostics, or other long-lived state. Those calls use bundle-default
selection and can disagree with the in-app language override. System-owned
surfaces use `AppLocalization.systemString` explicitly.

## Widgets and Other Processes

The iOS app and WidgetKit extension share the selected identifier through
`group.org.listenscrobbler.app`. Widgets render semantic snapshot data in their
own process using that locale. Avoid persisting already-localized display text
when a stable state or value can be persisted instead.

Siri, App Shortcut discovery text, Info.plist permission prompts, and some other
system-owned surfaces continue to follow the device language. Apple does not
provide a supported per-app runtime override for those surfaces, so every
published language must still be present in their dedicated catalogs.

## External Content

Artist, release, recording, tag, and user-provided text remains exactly as the
service returns it. MusicBrainz/Wikidata/Wikipedia enrichment prefers the
selected app language, progressively falls back to a less-specific language,
and finally falls back to English. Biography prose is shown only when its
language matches the selected language.

## Adding a Language

1. Add complete translations to `Localizable.xcstrings`.
2. Add equivalent App Shortcut phrase sets while preserving every `${...}`
   token.
3. Add the localized `InfoPlist.strings` permission text.
4. Regenerate the Xcode project so its known regions include the locale.
5. Run the localization tests. They verify catalog coverage, placeholders,
   shortcut tokens, locale resolution, and bundle loading.
6. Check compact iPhone widths, widgets, the macOS settings window, the menu bar
   extra, and long error/diagnostic text before publishing.

Never expose a partially translated language in a release. Brand names,
protocol identifiers, URLs, and user content should remain unchanged unless a
specific localized product term is documented.
