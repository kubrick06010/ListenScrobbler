# Localization QA Plan

This plan is the handoff from catalog repair to native-speaker review. The
published set contains eleven non-English locales: `de`, `es`, `fr`, `it`,
`ja`, `pl`, `pt`, `ru`, `sv`, `tr`, and `zh-Hans`.

## Baseline already checked

- `Resources/Localizable.xcstrings` and `Resources/AppShortcuts.xcstrings`
  parse as valid Xcode string catalogs.
- Every published locale has a value for every catalog entry and every App
  Shortcut variant.
- Format arguments, `${...}` shortcut parameters, product names, meaningful
  edge whitespace, stale-entry policy, and known machine-translation terms
  are covered by `Tests/LocalizationTests.swift`.
- The per-locale audit proposals are kept in `.codex-l10n/*.json`; they are
  keyed by source string and locale so a reviewer can trace every change.
- The glossary, voice, context comments, and release rules live in
  `docs/LOCALIZATION.md`.

## Review sequence

1. **Native linguistic pass** — review every changed mapping in the locale's
   audit file, then scan the complete catalog for grammar, register, gender,
   punctuation, terminology, and natural UI phrasing.
2. **Context pass** — exercise the key in its screen (navigation, settings,
   history, social, queue, errors, onboarding, widgets, and permissions).
   Confirm that nouns and commands use the intended meaning from the glossary.
3. **Layout pass** — check compact macOS windows, menus, accessibility labels,
   iOS widths, widgets, and App Shortcut discovery. Record any truncation or
   ambiguous wrap as a key-specific issue.
4. **Release gate** — rerun the localization tests and the full macOS test
   suite, inspect the final diff, and obtain native-speaker sign-off for each
   locale before publishing.

## Handoff matrix

| Locale | Primary linguistic focus | Automated baseline |
| --- | --- | --- |
| `de` | Inflection, compound nouns, concise commands | Catalog + shortcuts + InfoPlist covered |
| `es` | Neutral/informal voice, gender and imperative consistency | Catalog + shortcuts + InfoPlist covered |
| `fr` | Menu infinitives, `vous` instructions, spacing before punctuation | Catalog + shortcuts + InfoPlist covered |
| `it` | Infinitive commands, articles, technical loanwords | Catalog + shortcuts + InfoPlist covered |
| `ja` | Natural UI register, counters, kanji choices, no machine terms | Catalog + shortcuts + InfoPlist covered |
| `pl` | Case endings, aspect, formal/informal consistency | Catalog + shortcuts + InfoPlist covered |
| `pt` | European Portuguese vocabulary and agreement | Catalog + shortcuts + InfoPlist covered |
| `ru` | Cases, aspect, plural variations, quotation marks | Catalog + shortcuts + InfoPlist covered |
| `sv` | Imperative labels, definite forms, capitalization | Catalog + shortcuts + InfoPlist covered |
| `tr` | Agglutination, duplicated-word cleanup, command mood | Catalog + shortcuts + InfoPlist covered |
| `zh-Hans` | Simplified terminology, measure words, natural UI syntax | Catalog + shortcuts + InfoPlist covered |

## Sign-off record

The code change is ready for final linguistic QA when the automated baseline is
green. Native reviewers should record the reviewer, date, and any approved
follow-up directly in the project issue or pull request; this document should
not be treated as native-speaker approval by itself.
