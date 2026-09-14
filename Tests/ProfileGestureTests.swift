import Foundation

@main
struct ProfileGestureTests {
    static func main() throws {
        var count = 0
        func check(_ condition: Bool, _ name: String) {
            precondition(condition, name); count += 1
        }
        check(!ProfileGestureDecision.requestsMatch(x: 119, y: 0, enabled: true), "short drag cancels")
        check(ProfileGestureDecision.requestsMatch(x: 120, y: 0, enabled: true), "threshold releases")
        check(!ProfileGestureDecision.requestsMatch(x: -220, y: 0, enabled: true), "left swipe never sends")
        check(ProfileGestureDecision.dismissesCard(x: -120, y: 0, enabled: true), "left swipe closes")
        check(!ProfileGestureDecision.dismissesCard(x: -119, y: 0, enabled: true), "short left swipe stays")
        check(!ProfileGestureDecision.dismissesCard(x: 120, y: 0, enabled: true), "right swipe does not close")
        check(!ProfileGestureDecision.requestsMatch(x: 150, y: 140, enabled: true), "diagonal scroll never sends")
        check(!ProfileGestureDecision.requestsMatch(x: 300, y: 0, enabled: false), "disabled state never sends")
        check(!ProfileGestureDecision.requestsMatch(x: 0, y: 300, enabled: true), "vertical scroll never sends")
        check(!ProfileGestureDecision.requestsMatch(x: 10, y: 0, enabled: true), "fast short flick is not a request")
        check(ProfileGestureDecision.photoStep(x: -70, y: 0, count: 3) == 1, "photo next")
        check(ProfileGestureDecision.photoStep(x: 70, y: 0, count: 3) == -1, "photo previous")
        check(ProfileGestureDecision.photoStep(x: 70, y: 80, count: 3) == 0, "photo vertical scroll")
        check(ProfileGestureDecision.photoStep(x: 70, y: 40, count: 3) == -1, "photo mild diagonal still pages")
        check(ProfileGestureDecision.isPhotoPan(x: 12, y: 10), "photo pan begins on slight downward arc")
        check(!ProfileGestureDecision.isPhotoPan(x: 8, y: 14), "photo pan yields when vertical dominates")
        check(ProfileGestureDecision.deckClaimsPan(x: 40, y: 10), "horizontal deck pan claims the photo")
        check(!ProfileGestureDecision.deckClaimsPan(x: 10, y: 40), "vertical pan stays with the page")
        check(!ProfileGestureDecision.deckClaimsPan(x: 0, y: 0), "no movement is not a photo pan")
        check(!ProfileGestureDecision.deckClaimsPan(x: 20, y: 20), "equal axes yield to scroll")
        check(!ProfileGestureDecision.deckClaimsPan(x: 24, y: 20), "slight downward diagonal stays with the page")
        check(ProfileGestureDecision.deckClaimsPan(x: 50, y: 20), "clear horizontal still pages")
        check(ProfileGestureDecision.photoStep(x: 70, y: 0, count: 1) == 0, "single photo")
        check(ProfileGestureDecision.photoStep(x: 40, y: 0, count: 3) == 0, "short photo drag")
        check(ProfileGestureDecision.photoDragCommit(x: 50, count: 3), "held drag commits")
        check(!ProfileGestureDecision.photoDragCommit(x: 49, count: 3), "short held drag snaps back")
        check(ProfileGestureDecision.photoDragCommit(x: 0, y: 50, count: 3), "held vertical drag commits")
        check(!ProfileGestureDecision.photoDragCommit(x: 0, y: 49, count: 3), "short vertical drag snaps back")
        check(!ProfileGestureDecision.photoDragCommit(x: 80, count: 1), "single photo never pages")
        check(ProfileGestureDecision.photoIndex(2, step: 1, count: 3) == 0, "wrap next")
        check(ProfileGestureDecision.photoIndex(0, step: -1, count: 3) == 2, "wrap previous")
        check(ProfileGestureDecision.photoIndex(5, step: 1, count: 0) == 0, "empty gallery safe")
        check(ProfileRequestPreviewPhase.idle.canSubmit, "idle can request")
        check(!ProfileRequestPreviewPhase.sending.canSubmit, "no double submit")
        check(!ProfileRequestPreviewPhase.sent.canSubmit, "sent cannot repeat")
        check(ProfileRequestPreviewPhase.failed.canSubmit, "failed can retry")

        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let deck = try String(contentsOf: root.appendingPathComponent("Bond/Features/Profile/ProfileGalleryStack.swift"), encoding: .utf8)
        check(!deck.contains("sendRightSwipe") && !deck.contains("sendMessageRequest"),
              "photo deck has no request operation")
        check(!deck.contains("swipesPerson") && !deck.contains("onPersonRight") && !deck.contains("onPersonLeft"),
              "photo deck has no person-swipe wiring")
        check(!deck.contains("panGestureRecognizer.require"),
              "deck does not stall the page scroll")
        let profile = try String(contentsOf: root.appendingPathComponent("Bond/Features/Profile/SocialPersonDetailView.swift"), encoding: .utf8)
        check(profile.contains("sendRightSwipe"), "profile can send match request")
        check(profile.contains("allowsMatchRequest"), "match request is gated off the photo deck")
        check(!profile.contains("swipesPerson"), "profile does not enable photo person swipe")
        check(profile.contains("MessageRequestComposer"), "profile opens a written message request")
        check(profile.contains("ProfileGalleryStack(photos:"), "gallery is photo-only")
        let tabs = try String(contentsOf: root.appendingPathComponent("Bond/App/MainTabView.swift"), encoding: .utf8)
        check(!tabs.contains("CampusPeopleView"), "people directory tab is removed")
        print("Profile gestures: \(count) checks passed (photo-only deck, match via button).")
    }
}
