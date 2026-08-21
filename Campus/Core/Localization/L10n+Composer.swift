import Foundation

extension L10n {
    enum Composer {
        static var post: String { String(localized: "composer.post") }
        static var story: String { String(localized: "composer.story") }
        static var shareStory: String { String(localized: "composer.shareStory") }
        static var sharePost: String { String(localized: "composer.sharePost") }
        static var cameraUnavailable: String { String(localized: "composer.cameraUnavailable") }
        static var cameraUnavailableBody: String { String(localized: "composer.cameraUnavailableBody") }
        static var pickFromLibrary: String { String(localized: "composer.pickFromLibrary") }
        static var changePhoto: String { String(localized: "composer.changePhoto") }
        static var takePhoto: String { String(localized: "composer.takePhoto") }
        static var storyPlaceholder: String { String(localized: "composer.storyPlaceholder") }
        static var postPlaceholder: String { String(localized: "composer.postPlaceholder") }
        static var noPlace: String { String(localized: "composer.noPlace") }
        static func placeOption(_ name: String, _ area: String) -> String {
            L10n.format("composer.placeOption", name, area)
        }
        static var addPlace: String { String(localized: "composer.addPlace") }
        static var publishStory: String { String(localized: "composer.publishStory") }
        static var publishPost: String { String(localized: "composer.publishPost") }
        static var storyShared: String { String(localized: "composer.storyShared") }
        static var postShared: String { String(localized: "composer.postShared") }
        static var pickStoryPhoto: String { String(localized: "composer.pickStoryPhoto") }
        static var addPhoto: String { String(localized: "composer.addPhoto") }
        static var storyNeedsPhoto: String { String(localized: "composer.storyNeedsPhoto") }
        static var textOnlyOk: String { String(localized: "composer.textOnlyOk") }
    }
}
