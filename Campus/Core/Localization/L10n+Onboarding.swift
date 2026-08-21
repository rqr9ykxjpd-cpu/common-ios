import Foundation

extension L10n {
    enum Onboarding {
        static var identityEyebrow: String { String(localized: "onboarding.identityEyebrow") }
        static var identityTitle: String { String(localized: "onboarding.identityTitle") }
        static var identitySubtitle: String { String(localized: "onboarding.identitySubtitle") }
        static var name: String { String(localized: "onboarding.name") }
        static var namePlaceholder: String { String(localized: "onboarding.namePlaceholder") }
        static var department: String { String(localized: "onboarding.department") }
        static var departmentPlaceholder: String { String(localized: "onboarding.departmentPlaceholder") }
        static var birthDate: String { String(localized: "onboarding.birthDate") }
        static var ageNote: String { String(localized: "onboarding.ageNote") }
        static var preferencesEyebrow: String { String(localized: "onboarding.preferencesEyebrow") }
        static var preferencesTitle: String { String(localized: "onboarding.preferencesTitle") }
        static var preferencesSubtitle: String { String(localized: "onboarding.preferencesSubtitle") }
        static var yourGender: String { String(localized: "onboarding.yourGender") }
        static var interestsEyebrow: String { String(localized: "onboarding.interestsEyebrow") }
        static var interestsTitle: String { String(localized: "onboarding.interestsTitle") }
        static func interestsSubtitle(_ min: Int, _ max: Int) -> String {
            L10n.format("onboarding.interestsSubtitle", Int64(min), Int64(max))
        }
        static func completeProfile(_ count: Int, _ max: Int) -> String {
            L10n.format("onboarding.completeProfile", Int64(count), Int64(max))
        }
        static func maxInterestsHint(_ max: Int) -> String {
            L10n.format("onboarding.maxInterestsHint", Int64(max))
        }
        static var photoEyebrow: String { String(localized: "onboarding.photoEyebrow") }
        static var photoTitle: String { String(localized: "onboarding.photoTitle") }
        static var photoSubtitle: String { String(localized: "onboarding.photoSubtitle") }
        static var photoRequired: String { String(localized: "onboarding.photoRequired") }
        static var pickPhoto: String { String(localized: "onboarding.pickPhoto") }
        static var changePhoto: String { String(localized: "onboarding.changePhoto") }
        static var verified: String { String(localized: "onboarding.verified") }
        static var welcomePlain: String { String(localized: "onboarding.welcomePlain") }
        static func welcomeName(_ name: String) -> String {
            L10n.format("onboarding.welcomeName", name)
        }
        static var readySubtitle: String { String(localized: "onboarding.readySubtitle") }
        static var enter: String { String(localized: "onboarding.enter") }
        static var saveFailed: String { String(localized: "onboarding.saveFailed") }
        static var needPhoto: String { String(localized: "onboarding.needPhoto") }
        static var photoUploadFailed: String { String(localized: "onboarding.photoUploadFailed") }
    }
}
