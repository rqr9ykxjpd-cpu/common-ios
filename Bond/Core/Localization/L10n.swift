import Foundation

/// Uygulama dilinin tek giriş noktası.
///
/// Metinler `Localizable.xcstrings` içinde durur. Swift tarafı anahtarları buradan
/// okur; ekranlarda düz Türkçe/İngilizce cümle yazılmaz.
///
/// Dil, telefonun tercih listesinden gelir. Uygulama `tr` ve `en` sunar;
/// ikisi de yoksa `CFBundleDevelopmentRegion` (`tr`) kullanılır.
enum L10n {
    /// Uygulamanın çözülmüş dili. `Locale.current` değil: telefon Almancayken
    /// arayüz Türkçe kalır, tarihler de Türkçe kalmalı.
    static var appLocale: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "tr")
    }

    static var isEnglish: Bool {
        appLocale.language.languageCode?.identifier == "en"
    }

    static func text(_ key: String.LocalizationValue) -> String {
        String(localized: key)
    }

    static func format(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        String(format: String(localized: key), locale: appLocale, arguments: arguments)
    }
}
