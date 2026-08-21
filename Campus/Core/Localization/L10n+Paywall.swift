import Foundation

extension L10n {
    enum Paywall {
        static var brand: String { String(localized: "paywall.brand") }
        static var headline: String { String(localized: "paywall.headline") }
        static var free: String { String(localized: "paywall.free") }
        static var plus: String { String(localized: "paywall.plus") }
        static var pro: String { String(localized: "paywall.pro") }
        static var specialNote: String { String(localized: "paywall.specialNote") }
        static func planName(_ tier: String) -> String {
            L10n.format("paywall.planName", tier)
        }
        static var unlimited: String { String(localized: "paywall.unlimited") }
        static var perWeek: String { String(localized: "paywall.perWeek") }
        static var handNote: String { String(localized: "paywall.handNote") }
        static var legal: String { String(localized: "paywall.legal") }
        static var restoring: String { String(localized: "paywall.restoring") }
        static var restore: String { String(localized: "paywall.restore") }
        static var terms: String { String(localized: "paywall.terms") }
        static var privacy: String { String(localized: "paywall.privacy") }
        static var problem: String { String(localized: "paywall.problem") }
        static var goPlus: String { String(localized: "paywall.goPlus") }
        static var goPro: String { String(localized: "paywall.goPro") }
        static var pending: String { String(localized: "paywall.pending") }
        static var featureLikes: String { String(localized: "paywall.featureLikes") }
        static var featureRequests: String { String(localized: "paywall.featureRequests") }
        static var featureAccepts: String { String(localized: "paywall.featureAccepts") }
        static var featureVisitors: String { String(localized: "paywall.featureVisitors") }
        static var featurePause: String { String(localized: "paywall.featurePause") }
        static var featureEdit: String { String(localized: "paywall.featureEdit") }
        static var featureViewCounts: String { String(localized: "paywall.featureViewCounts") }
        static var featureGhost: String { String(localized: "paywall.featureGhost") }
        static var infinity: String { String(localized: "paywall.infinity") }
        static var yes: String { String(localized: "paywall.yes") }
        static var no: String { String(localized: "paywall.no") }
        static var productsFailed: String { String(localized: "paywall.productsFailed") }
        static var unavailable: String { String(localized: "paywall.unavailable") }
        static var verifyFailed: String { String(localized: "paywall.verifyFailed") }
        static var purchaseFailed: String { String(localized: "paywall.purchaseFailed") }
        static var noSubscription: String { String(localized: "paywall.noSubscription") }
        static var restoreFailed: String { String(localized: "paywall.restoreFailed") }
        static var unverified: String { String(localized: "paywall.unverified") }
    }
}
