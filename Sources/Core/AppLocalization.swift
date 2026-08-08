import Foundation

public enum AppLocalization {
    public static func languageCode(bundle: Bundle = .main) -> String {
        let identifier = bundle.preferredLocalizations.first
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
        return normalizedLanguageCode(identifier)
    }

    public static func locale(
        bundle: Bundle = .main,
        regionLocale: Locale = .current
    ) -> Locale {
        locale(languageCode: languageCode(bundle: bundle), regionLocale: regionLocale)
    }

    public static func locale(languageCode: String, regionLocale: Locale = .current) -> Locale {
        let language = normalizedLanguageCode(languageCode)
        guard let region = regionLocale.region?.identifier, !region.isEmpty else {
            return Locale(identifier: language)
        }
        return Locale(identifier: "\(language)_\(region)")
    }

    public static func integer(
        _ value: Int,
        bundle: Bundle = .main,
        regionLocale: Locale = .current
    ) -> String {
        integer(value, locale: locale(bundle: bundle, regionLocale: regionLocale))
    }

    public static func integer(_ value: Int, locale: Locale) -> String {
        value.formatted(.number.locale(locale))
    }

    public static func date(
        _ value: Date,
        date: Date.FormatStyle.DateStyle,
        time: Date.FormatStyle.TimeStyle,
        bundle: Bundle = .main,
        regionLocale: Locale = .current
    ) -> String {
        AppLocalization.date(
            value,
            date: date,
            time: time,
            locale: locale(bundle: bundle, regionLocale: regionLocale)
        )
    }

    public static func date(
        _ value: Date,
        date: Date.FormatStyle.DateStyle,
        time: Date.FormatStyle.TimeStyle,
        locale: Locale
    ) -> String {
        value.formatted(
            Date.FormatStyle(date: date, time: time)
                .locale(locale)
        )
    }

    private static func normalizedLanguageCode(_ identifier: String) -> String {
        Locale(identifier: identifier).language.languageCode?.identifier.lowercased()
            ?? identifier.split(separator: "-").first.map(String.init)?.lowercased()
            ?? "en"
    }
}
