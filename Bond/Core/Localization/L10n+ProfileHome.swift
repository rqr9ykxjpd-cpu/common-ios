import Foundation

extension L10n {
    enum ProfileHome {
        static var features: String { String(localized: "features", table: "ProfileHome") }
        static var photos: String { String(localized: "photos", table: "ProfileHome") }
        static var manage: String { String(localized: "manage", table: "ProfileHome") }
        static var addPhotos: String { String(localized: "addPhotos", table: "ProfileHome") }
        static var publicPreview: String { String(localized: "publicPreview", table: "ProfileHome") }
        static var share: String { String(localized: "share", table: "ProfileHome") }
        static var tools: String { String(localized: "tools", table: "ProfileHome") }
        static var requests: String { String(localized: "requests", table: "ProfileHome") }
        static var noPendingRequests: String { String(localized: "noPendingRequests", table: "ProfileHome") }
        static func pendingRequests(_ count: Int) -> String {
            String(
                format: String(localized: "pendingRequests", table: "ProfileHome"),
                locale: L10n.appLocale,
                Int64(count)
            )
        }
        static var requestsDetail: String { String(localized: "requestsDetail", table: "ProfileHome") }
        static var requiresPlus: String { String(localized: "requiresPlus", table: "ProfileHome") }
        static var requiresPro: String { String(localized: "requiresPro", table: "ProfileHome") }
        static var on: String { String(localized: "on", table: "ProfileHome") }
        static var myPlan: String { String(localized: "myPlan", table: "ProfileHome") }
        static var planPrivate: String { String(localized: "planPrivate", table: "ProfileHome") }
        static var explorePlans: String { String(localized: "explorePlans", table: "ProfileHome") }
        static var planDetails: String { String(localized: "planDetails", table: "ProfileHome") }
        static var requestsIntro: String { String(localized: "requestsIntro", table: "ProfileHome") }
        static var connectionRequests: String { String(localized: "connectionRequests", table: "ProfileHome") }
        static var connectionRequestsDetail: String { String(localized: "connectionRequestsDetail", table: "ProfileHome") }
        static var meetingRequests: String { String(localized: "meetingRequests", table: "ProfileHome") }
        static var meetingRequestsDetail: String { String(localized: "meetingRequestsDetail", table: "ProfileHome") }
    }
}
