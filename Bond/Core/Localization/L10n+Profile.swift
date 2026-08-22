import Foundation

extension L10n {
    enum Profile {
        static var addDepartment: String { String(localized: "profile.addDepartment") }
        static var moreSettings: String { String(localized: "profile.moreSettings") }
        static var signOutConfirm: String { String(localized: "profile.signOutConfirm") }
        static var signOut: String { String(localized: "profile.signOut") }
        static var signOutBody: String { String(localized: "profile.signOutBody") }
        static var deleteConfirm: String { String(localized: "profile.deleteConfirm") }
        static var deleteAccount: String { String(localized: "profile.deleteAccount") }
        static var deleteBody: String { String(localized: "profile.deleteBody") }
        static var zoomPhoto: String { String(localized: "profile.zoomPhoto") }
        static var statPosts: String { String(localized: "profile.statPosts") }
        static var statVisitors: String { String(localized: "profile.statVisitors") }
        static var edit: String { String(localized: "profile.edit") }
        static var editA11y: String { String(localized: "profile.editA11y") }
        static func completion(_ percent: Int) -> String {
            L10n.format("profile.completion", Int64(percent))
        }
        static var completionHint: String { String(localized: "profile.completionHint") }
        static var about: String { String(localized: "profile.about") }
        static var aboutPlaceholder: String { String(localized: "profile.aboutPlaceholder") }
        static var yourAccount: String { String(localized: "profile.yourAccount") }
        static var cardHow: String { String(localized: "profile.cardHow") }
        static var cardHowHint: String { String(localized: "profile.cardHowHint") }
        static var reports: String { String(localized: "profile.reports") }
        static var reportsHint: String { String(localized: "profile.reportsHint") }
        static func reportsWaiting(_ count: Int) -> String {
            L10n.format("profile.reportsWaiting", Int64(count))
        }
        static var saved: String { String(localized: "profile.saved") }
        static var savedHint: String { String(localized: "profile.savedHint") }
        static var visitors: String { String(localized: "profile.visitors") }
        static var visitorsHint: String { String(localized: "profile.visitorsHint") }
        static var meetings: String { String(localized: "profile.meetings") }
        static var meetingsHint: String { String(localized: "profile.meetingsHint") }
        static var appearanceSection: String { String(localized: "profile.appearanceSection") }
        static var appearance: String { String(localized: "profile.appearance") }
        static var privacy: String { String(localized: "profile.privacy") }
        static var ghost: String { String(localized: "profile.ghost") }
        static var ghostOnDetail: String { String(localized: "profile.ghostOnDetail") }
        static var ghostOffDetail: String { String(localized: "profile.ghostOffDetail") }
        static var signOutHint: String { String(localized: "profile.signOutHint") }
        static var deletePermanent: String { String(localized: "profile.deletePermanent") }
        static var irreversible: String { String(localized: "profile.irreversible") }
        static var aboutSection: String { String(localized: "profile.aboutSection") }
        static var termsHint: String { String(localized: "profile.termsHint") }
        static var privacyHint: String { String(localized: "profile.privacyHint") }
        static var blocked: String { String(localized: "profile.blocked") }
        static var blockedHint: String { String(localized: "profile.blockedHint") }
        static var blockedEmpty: String { String(localized: "profile.blockedEmpty") }
        static var blockedEmptyHint: String { String(localized: "profile.blockedEmptyHint") }
        static var blockedUnknown: String { String(localized: "profile.blockedUnknown") }
        static var unblock: String { String(localized: "profile.unblock") }
        static var blockedLoadFailed: String { String(localized: "profile.blockedLoadFailed") }
        static var unblockFailed: String { String(localized: "profile.unblockFailed") }
        static var support: String { String(localized: "profile.support") }
        static var supportHint: String { String(localized: "profile.supportHint") }
        static var accountBusy: String { String(localized: "profile.accountBusy") }
        static func badgeWaiting(_ count: String) -> String {
            L10n.format("profile.badgeWaiting", count)
        }
        static var noVisitors: String { String(localized: "profile.noVisitors") }
        static var noVisitorsBody: String { String(localized: "profile.noVisitorsBody") }
        static var noSaved: String { String(localized: "profile.noSaved") }
        static var noSavedBody: String { String(localized: "profile.noSavedBody") }
        static var unsave: String { String(localized: "profile.unsave") }
        static var myPosts: String { String(localized: "profile.myPosts") }
        static var firstPostHint: String { String(localized: "profile.firstPostHint") }
        static var firstPostBody: String { String(localized: "profile.firstPostBody") }
        static var shareCta: String { String(localized: "profile.shareCta") }
        static var visibleNowCaps: String { String(localized: "profile.visibleNowCaps") }
        static var likeSent: String { String(localized: "profile.likeSent") }
        static var likeHint: String { String(localized: "profile.likeHint") }
        static var sendMessage: String { String(localized: "profile.sendMessage") }
        static var meetHere: String { String(localized: "profile.meetHere") }
        static var requestSent: String { String(localized: "profile.requestSent") }
        static var noNotifyIfIgnored: String { String(localized: "profile.noNotifyIfIgnored") }
        static func sharedInterests(_ count: Int) -> String {
            L10n.format("profile.sharedInterests", Int64(count))
        }
        static var photos: String { String(localized: "profile.photos") }
        static var theirPostsCaps: String { String(localized: "profile.theirPostsCaps") }
        static var needMatchToChat: String { String(localized: "profile.needMatchToChat") }
        static var editTitle: String { String(localized: "profile.editTitle") }
        static var publishNote: String { String(localized: "profile.publishNote") }
        static var discardTitle: String { String(localized: "profile.discardTitle") }
        static var keepEditing: String { String(localized: "profile.keepEditing") }
        static var leaveWithoutSaving: String { String(localized: "profile.leaveWithoutSaving") }
        static var discardBody: String { String(localized: "profile.discardBody") }
        static var allSaved: String { String(localized: "profile.allSaved") }
        static var saveChanges: String { String(localized: "profile.saveChanges") }
        static var savedButton: String { String(localized: "profile.savedButton") }
        static var needName: String { String(localized: "profile.needName") }
        static var needDepartment: String { String(localized: "profile.needDepartment") }
        static var needGender: String { String(localized: "profile.needGender") }
        static func needMoreInterests(_ count: Int) -> String {
            L10n.format("profile.needMoreInterests", Int64(count))
        }
        static var bioTooLong: String { String(localized: "profile.bioTooLong") }
        static var photosSection: String { String(localized: "profile.photosSection") }
        static var addGallery: String { String(localized: "profile.addGallery") }
        static var changeGallery: String { String(localized: "profile.changeGallery") }
        static var mainPhoto: String { String(localized: "profile.mainPhoto") }
        static var mainPhotoHint: String { String(localized: "profile.mainPhotoHint") }
        static var removePhoto: String { String(localized: "profile.removePhoto") }
        static var basics: String { String(localized: "profile.basics") }
        static var birthDate: String { String(localized: "profile.birthDate") }
        static var year: String { String(localized: "profile.year") }
        static var bioPlaceholder: String { String(localized: "profile.bioPlaceholder") }
        static func interestCount(_ count: Int, _ max: Int, _ min: Int) -> String {
            L10n.format("profile.interestCount", Int64(count), Int64(max), Int64(min))
        }
        static var meetPrefs: String { String(localized: "profile.meetPrefs") }
        static var genderRequired: String { String(localized: "profile.genderRequired") }
        static var hideLocation: String { String(localized: "profile.hideLocation") }
        static var visiblePlace: String { String(localized: "profile.visiblePlace") }
        static var accountSection: String { String(localized: "profile.accountSection") }
        static var account: String { String(localized: "profile.account") }
        static var notSignedIn: String { String(localized: "profile.notSignedIn") }
        static var studentStatus: String { String(localized: "profile.studentStatus") }
        static var verified: String { String(localized: "profile.verified") }
        static var lockedFields: String { String(localized: "profile.lockedFields") }
        static var speaksFirst: String { String(localized: "profile.speaksFirst") }
        static var editStory: String { String(localized: "profile.editStory") }
        static var whoToMeet: String { String(localized: "profile.whoToMeet") }
        static var safety: String { String(localized: "profile.safety") }
        static var signOutCaps: String { String(localized: "profile.signOutCaps") }
        static var premiumEyebrow: String { String(localized: "profile.premiumEyebrow") }
        static var activeToday: String { String(localized: "profile.activeToday") }
        static var recentlyActive: String { String(localized: "profile.recentlyActive") }
        static var emptyBio: String { String(localized: "profile.emptyBio") }
        static var saveFailed: String { String(localized: "profile.saveFailed") }
        static var photosPartialFail: String { String(localized: "profile.photosPartialFail") }
        static var updated: String { String(localized: "profile.updated") }
        static var visitorsLoadFailed: String { String(localized: "profile.visitorsLoadFailed") }
        static var matchLabel: String { String(localized: "profile.matchLabel") }
    }
}
