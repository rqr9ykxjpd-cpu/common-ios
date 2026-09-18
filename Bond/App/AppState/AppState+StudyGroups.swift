import Foundation
import UserNotifications

extension AppState {
    /// "Yerimi göster": ev sahibi fotoğrafı çekti; sıkıştır, yükle, karta koy.
    @discardableResult
    func shareStudyGroupSpot(_ groupID: UUID, imageData: Data) async -> Bool {
        guard let i = studyGroups.firstIndex(where: { $0.id == groupID }), studyGroups[i].isMine else { return false }
        guard let hazir = ImageCompression.prepareForUpload(imageData) else {
            showError(L10n.StudyGroup.spotFailed); return false
        }
        do {
            let url = try await service.setStudyGroupSpotPhoto(groupID, imageData: hazir)
            if let j = studyGroups.firstIndex(where: { $0.id == groupID }) {
                studyGroups[j].spotPhotoURL = url
                studyGroups[j].spotPhotoAt = .now
            }
            show(L10n.StudyGroup.spotShared)
            Haptics.success()
            return true
        } catch {
            let ham = String(describing: error) + error.localizedDescription
            if ham.contains("STUDY_GROUP_SPOT_WINDOW") { showError(L10n.StudyGroup.spotWindowClosed) }
            else { showError(error, fallback: L10n.StudyGroup.spotFailed) }
            return false
        }
    }

    /// Ev sahibine başlangıçtan 15 dk önce yerel hatırlatma: "yerini fotoğrafla göster".
    /// Sunucu zamanlayıcısı gerekmiyor; izin yoksa sessizce atlanır.
    func scheduleStudySpotReminder(for group: StudyGroup) {
        let ates = group.startsAt.addingTimeInterval(-15 * 60)
        guard ates > Date() else { return }
        let icerik = UNMutableNotificationContent()
        icerik.title = L10n.StudyGroup.reminderTitle
        icerik.body = L10n.StudyGroup.reminderBody(group.place.name)
        icerik.sound = .default
        let tetik = UNTimeIntervalNotificationTrigger(timeInterval: ates.timeIntervalSinceNow, repeats: false)
        let istek = UNNotificationRequest(identifier: Self.spotReminderID(group.id), content: icerik, trigger: tetik)
        UNUserNotificationCenter.current().add(istek)
    }

    func cancelStudySpotReminder(_ groupID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.spotReminderID(groupID)])
    }

    private static func spotReminderID(_ groupID: UUID) -> String { "study-spot-\(groupID.uuidString)" }

    func loadStudyGroups(silently: Bool = false) async {
        do {
            studyGroups = try await service.fetchStudyGroups()
        } catch {
            guard !isCancellation(error) else { return }
            if !silently { showError(error, fallback: L10n.StudyGroup.loadFailed) }
        }
    }

    /// Sunucu tek açık grup kuralını koyuyor (STUDY_GROUP_ACTIVE_EXISTS).
    @discardableResult
    func createStudyGroup(place: CampusPlace, startsAt: Date, note: String, capacity: Int?) async -> Bool {
        do {
            let group = try await service.createStudyGroup(
                placeID: place.id, startsAt: startsAt,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines), capacity: capacity
            )
            studyGroups.removeAll { $0.id == group.id }
            studyGroups.append(group)
            studyGroups.sort { $0.startsAt < $1.startsAt }
            scheduleStudySpotReminder(for: group)
            show(L10n.StudyGroup.created)
            Haptics.success()
            promptForPushIfNeeded()
            return true
        } catch {
            let ham = String(describing: error) + error.localizedDescription
            if ham.contains("STUDY_GROUP_ACTIVE_EXISTS") {
                showError(L10n.StudyGroup.activeExists)
            } else {
                showError(error, fallback: L10n.StudyGroup.createFailed)
            }
            return false
        }
    }

    func cancelStudyGroup(_ groupID: UUID) {
        let onceki = studyGroups
        studyGroups.removeAll { $0.id == groupID }
        cancelStudySpotReminder(groupID)
        Task {
            do {
                try await service.cancelStudyGroup(groupID)
                show(L10n.StudyGroup.cancelled)
                Haptics.success()
            } catch {
                studyGroups = onceki
                showError(error, fallback: L10n.Errors.title)
            }
        }
    }

    /// Katıl / ayrıl: iyimser; sunucu reddederse (dolu, kapanmış) geri alınır.
    func toggleStudyGroupMembership(_ groupID: UUID) {
        guard let i = studyGroups.firstIndex(where: { $0.id == groupID }),
              !studyGroups[i].isMine else { return }
        let me = currentUserProfile
        let onceki = studyGroups[i]
        let katiliyor = !onceki.joined
        if katiliyor {
            guard !onceki.isFull else { showError(L10n.StudyGroup.full); return }
            studyGroups[i].members.append(me)
        } else {
            studyGroups[i].members.removeAll { $0.id == me.id }
        }
        studyGroups[i].joined = katiliyor
        Haptics.impact(.light)
        Task {
            do {
                if katiliyor {
                    try await service.joinStudyGroup(groupID)
                    show(L10n.StudyGroup.joinedToast)
                    promptForPushIfNeeded()
                } else {
                    try await service.leaveStudyGroup(groupID)
                    show(L10n.StudyGroup.leftToast)
                }
            } catch {
                if let j = studyGroups.firstIndex(where: { $0.id == groupID }) { studyGroups[j] = onceki }
                let ham = String(describing: error) + error.localizedDescription
                if ham.contains("STUDY_GROUP_FULL") { showError(L10n.StudyGroup.full) }
                else if ham.contains("STUDY_GROUP_CLOSED") { showError(L10n.StudyGroup.closed) }
                else { showError(error, fallback: L10n.StudyGroup.joinFailed) }
            }
        }
    }
}
