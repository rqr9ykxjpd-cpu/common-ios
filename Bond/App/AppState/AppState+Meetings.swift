import SwiftUI

// MARK: - AppState+Meetings
extension AppState {
    func meetingRequest(for profile: StudentProfile, at place: CampusPlace) -> MeetingRequest? {
        meetingRequests.first {
            $0.profile.id == profile.id && $0.place.id == place.id && $0.direction == .outgoing && $0.status == .pending
        }
    }

    /// Buluşma isteklerini sunucudan yükler. Bu liste şimdiye kadar yalnızca bellekte
    /// yaşıyordu; uygulama kapanınca gönderilen ve gelen istekler kayboluyordu.
    func loadMeetingRequests() async {
        do {
            meetingRequests = try await service.fetchMeetingRequests()
        } catch {
            showError(error, fallback: L10n.Meetings.loadFailed)
        }
    }
    func sendMeetingRequest(to profile: StudentProfile, at place: CampusPlace) {
        guard meetingRequest(for: profile, at: place) == nil else { return }
        let optimistic = MeetingRequest(profile: profile, place: place, direction: .outgoing)
        meetingRequests.insert(optimistic, at: 0)
        Task {
            do {
                try await service.sendMeetingRequest(to: profile.id, placeID: place.id)
                await loadMeetingRequests()
                show(L10n.Meetings.sent(profile.name, place.name))
                Haptics.success()
            } catch {
                meetingRequests.removeAll { $0.id == optimistic.id }
                showError(error, fallback: L10n.Meetings.sendFailed)
            }
        }
    }

    func respondToMeetingRequest(_ requestID: UUID, accept: Bool) {
        guard let index = meetingRequests.firstIndex(where: { $0.id == requestID && $0.direction == .incoming && $0.status == .pending }) else { return }
        let previous = meetingRequests[index].status
        meetingRequests[index].status = accept ? .accepted : .declined
        notifications.removeAll { $0.meetingRequestID == requestID }
        show(accept ? L10n.Meetings.accepted : L10n.Meetings.declined)
        Haptics.success()
        Task {
            do {
                try await service.respondToMeetingRequest(requestID, accept: accept)
            } catch {
                if let refreshed = meetingRequests.firstIndex(where: { $0.id == requestID }) {
                    meetingRequests[refreshed].status = previous
                }
                showError(error, fallback: L10n.Meetings.respondFailed)
            }
        }
    }

    var pendingIncomingMeetingRequestCount: Int {
        meetingRequests.filter { $0.direction == .incoming && $0.status == .pending }.count
    }
}
