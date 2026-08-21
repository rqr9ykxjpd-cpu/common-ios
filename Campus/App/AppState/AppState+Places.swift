import SwiftUI

// MARK: - AppState+Places
extension AppState {
    /// - Parameter silently: bkz. `loadProfileVisits(silently:)`.
    func loadPlaces(silently: Bool = false) async {
        do {
            let loaded = try await service.fetchPlaces()
            if !loaded.isEmpty { places = loaded }
        } catch {
            if !silently { showError(error, fallback: L10n.Places.loadFailed) }
        }
    }
    func togglePresence(at place: CampusPlace) {
        let previous = currentVisiblePlace
        let turningOff = currentVisiblePlace?.id == place.id
        currentVisiblePlace = turningOff ? nil : place
        show(turningOff ? L10n.Places.hidden : L10n.Places.nowVisible(place.name))
        Haptics.success()
        Task {
            do {
                try await service.setVisiblePlace(turningOff ? nil : place.id)
            } catch {
                currentVisiblePlace = previous
                showError(error, fallback: L10n.Places.toggleFailed)
            }
        }
    }

    /// Bir yerde şu an görünen kişiler. Bu liste koda gömülü sabit isimlerdi; herkese
    /// aynı sahte kişiler gösteriliyordu.
    func peopleAtPlace(_ place: CampusPlace) async -> [StudentProfile] {
        do {
            let digerleri = try await service.fetchPeopleAtPlace(place.id)
            // Sunucu sorgusu kişinin kendisini eliyor. "Buradayım" dedikten sonra
            // listede kendini görmemek, görünür olup olmadığını belirsiz bırakıyor:
            // insan kendi adını görene kadar işe yaradığından emin olamıyor.
            guard currentVisiblePlace?.id == place.id else { return digerleri }
            return [currentUserProfile] + digerleri.filter { $0.id != currentUserID }
        } catch {
            showError(error, fallback: L10n.Places.peopleFailed)
            return []
        }
    }

    func isJoined(to club: CampusClub) -> Bool {
        joinedClubIDs.contains(club.id)
    }

    /// Kulüpleri ve üyeliklerini sunucudan yükler. Liste eskiden koda gömülüydü ve
    /// katılma bilgisi yalnızca bellekte tutulduğu için uygulama kapanınca kayboluyordu.
    /// - Parameter silently: bkz. `loadProfileVisits(silently:)`.
    func loadClubs(silently: Bool = false) async {
        do {
            let result = try await service.fetchClubs()
            clubs = result.clubs
            joinedClubIDs = result.joinedIDs
        } catch {
            if !silently { showError(error, fallback: L10n.Places.clubsFailed) }
        }
    }

    func toggleClubMembership(_ club: CampusClub) {
        let willJoin = !joinedClubIDs.contains(club.id)
        if willJoin {
            joinedClubIDs.insert(club.id)
            show(L10n.Places.joinedClub(club.name))
        } else {
            joinedClubIDs.remove(club.id)
            show(L10n.Places.leftClub(club.name))
        }
        Haptics.success()
        Task {
            do {
                try await service.setClubMembership(club.id, joined: willJoin)
                await loadClubs()
            } catch {
                if willJoin { joinedClubIDs.remove(club.id) } else { joinedClubIDs.insert(club.id) }
                showError(error, fallback: L10n.Places.clubUpdateFailed)
            }
        }
    }
}
