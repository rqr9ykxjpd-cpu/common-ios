import Foundation

extension AppState {
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
