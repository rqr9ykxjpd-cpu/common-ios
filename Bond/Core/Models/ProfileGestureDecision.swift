import Foundation

/// Both gestures use distance and direction, never fling velocity. A short,
/// fast movement must not accidentally submit a request.
enum ProfileGestureDecision {
    static func isHorizontal(x: CGFloat, y: CGFloat) -> Bool {
        abs(x) > abs(y) * 1.5
    }
    /// Photo paging may be a little diagonal. Match requests stay stricter.
    static func isPhotoPan(x: CGFloat, y: CGFloat) -> Bool {
        abs(x) >= abs(y)
    }
    /// The page must keep vertical pans. A downward flick on the photo must
    /// not wait for the deck. Horizontal must clearly win before the card moves.
    static func deckClaimsPan(x: CGFloat, y: CGFloat) -> Bool {
        abs(x) > abs(y) * 1.5
    }
    static func requestsMatch(x: CGFloat, y: CGFloat, enabled: Bool) -> Bool {
        enabled && x >= 100 && isHorizontal(x: x, y: y)
    }
    static func dismissesCard(x: CGFloat, y: CGFloat, enabled: Bool) -> Bool {
        enabled && x <= -100 && isHorizontal(x: x, y: y)
    }
    static func photoStep(x: CGFloat, y: CGFloat, count: Int) -> Int {
        guard count > 1, abs(x) >= 50, isPhotoPan(x: x, y: y) else { return 0 }
        return x < 0 ? 1 : -1
    }
    /// Once the deck owns the pan, distance in any direction cycles the photo.
    static func photoDragCommit(x: CGFloat, y: CGFloat = 0, count: Int) -> Bool {
        count > 1 && hypot(x, y) >= 50
    }
    static func photoIndex(_ current: Int, step: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((current + step) % count + count) % count
    }
}

enum ProfileRequestPreviewPhase {
    case idle, sending, sent, failed
    var canSubmit: Bool { self == .idle || self == .failed }
}
