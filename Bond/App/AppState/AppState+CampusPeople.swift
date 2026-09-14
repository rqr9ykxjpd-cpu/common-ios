import SwiftUI

// MARK: - AppState+CampusPeople
extension AppState {
    func loadIntroductionRequests() async {
        guard !isLoadingIntroductions else { return }
        let account = currentUserID
        isLoadingIntroductions = true
        defer { isLoadingIntroductions = false }
        do {
            let result = try await service.fetchIntroductionRequests()
            guard account == currentUserID else { return }
            introductionRequests = result
            introductionRequestsError = nil
        } catch {
            guard account == currentUserID, !isCancellation(error) else { return }
            introductionRequestsError = UserFacingError.message(error, fallback: L10n.Errors.title)
        }
    }

    var unreadConnectionNotifications: [AppNotification] {
        notifications.filter { $0.kind == .match && !$0.isRead && $0.conversationID != nil }
    }

    var chatActivityCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
            + pendingMessageRequests.count + introductionRequests.count + unreadConnectionNotifications.count
    }

    func loadCampusPeople(reset: Bool = false, force: Bool = false) async {
        if isLoadingCampusPeople && !force { return }
        if !reset, !campusPeopleHasMore { return }

        campusPeopleLoadGeneration &+= 1
        let generation = campusPeopleLoadGeneration
        isLoadingCampusPeople = true
        campusPeopleError = nil
        defer {
            if campusPeopleLoadGeneration == generation {
                isLoadingCampusPeople = false
            }
        }

        do {
            let offset = reset ? 0 : campusPeople.count
            let page = try await service.fetchCampusPeople(offset: offset, limit: 20)
            guard campusPeopleLoadGeneration == generation else { return }
            if reset {
                campusPeople = page
            } else {
                let existing = Set(campusPeople.map(\.id))
                campusPeople.append(contentsOf: page.filter { !existing.contains($0.id) })
            }
            campusPeopleHasMore = page.count == 20
        } catch is CancellationError {
            return
        } catch {
            guard campusPeopleLoadGeneration == generation else { return }
            if (error as NSError).code == NSURLErrorCancelled { return }
            campusPeopleError = UserFacingError.message(error, fallback: L10n.CampusNavigation.peopleFailed)
            if reset { campusPeople = [] }
        }
    }

    enum RightSwipeResult: Sendable {
        case sent
        case matched(matchID: UUID)
        case already
        case failed
    }

    /// Tek taraf: bildirim. Karşılıklı: `matches` + Sohbet listesinde DM.
    @discardableResult
    /// Sola kaydırma: kart kapanır, kayıt sessizce gider; hata kullanıcıya gösterilmez.
    func recordLeftSwipe(on profile: StudentProfile) {
        guard profile.id != currentUserID else { return }
        Task { try? await service.recordLeftSwipe(on: profile.id) }
    }

    func fetchProfileSwipers() async throws -> [ProfileSwiper] {
        try await service.fetchProfileSwipers()
    }

    func fetchFounderStats() async throws -> FounderStats {
        try await service.fetchFounderStats()
    }

    func sendRightSwipe(to profile: StudentProfile) async -> RightSwipeResult {
        if rightSwipedProfileIDs.contains(profile.id) {
            show(L10n.CampusDesign.alreadySwiped)
            return .already
        }
        do {
            let outcome = try await service.sendRightSwipe(to: profile.id)
            rightSwipedProfileIDs.insert(profile.id)
            if outcome.matched, let matchID = outcome.matchID {
                introductionRequests.removeAll { $0.id == profile.id }
                await loadConversations()
                _ = conversationID(for: profile, matchID: matchID)
                show(L10n.CampusDesign.rightSwipeMatched)
                Haptics.success()
                return .matched(matchID: matchID)
            }
            show(L10n.CampusDesign.rightSwipeSent)
            return .sent
        } catch {
            let ham = String(describing: error) + error.localizedDescription
            if ham.contains("RIGHT_SWIPE_EXISTS") {
                rightSwipedProfileIDs.insert(profile.id)
                show(L10n.CampusDesign.alreadySwiped)
                return .already
            }
            showError(error, fallback: L10n.CampusDesign.rightSwipeFailed)
            return .failed
        }
    }
}
