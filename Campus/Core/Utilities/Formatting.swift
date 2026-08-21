import Foundation

extension Date {
    /// Uygulama diline göre biçimlenir. `Locale.current` değil: telefon Almancayken
    /// arayüz Türkçe kalır, tarihler de Türkçe kalmalı.
    var relativeTurkish: String {
        formatted(.relative(presentation: .named).locale(L10n.appLocale))
    }

    /// Kısa saat. 24 saat TR'de, cihazın İngilizce biçimi EN'de.
    var shortTimeTurkish: String {
        formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(L10n.appLocale))
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
