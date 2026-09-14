import Foundation

extension L10n {
    enum PaywallDesign {
        static var subtitle: String { String(localized: "subtitle", table: "PaywallDesign") }
        static var included: String { String(localized: "included", table: "PaywallDesign") }
        static var priceUnavailable: String { String(localized: "priceUnavailable", table: "PaywallDesign") }
    }
}
