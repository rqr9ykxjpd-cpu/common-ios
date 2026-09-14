import SwiftUI

// MARK: - AppState+Places
extension AppState {
    /// - Parameter silently: bkz. `loadProfileVisits(silently:)`.
    func loadPlaces(silently: Bool = false) async {
        isLoadingPlaces = true
        defer { isLoadingPlaces = false }
        do {
            places = try await service.fetchPlaces()
            placesError = nil
            await loadPlacePresence()
        } catch {
            guard !isCancellation(error) else { return }
            let message = UserFacingError.message(error, fallback: L10n.Places.loadFailed)
            placesError = message
            if !silently && !places.isEmpty { showError(message) }
        }
    }
    /// Sayılar ayrı yüklenir ve hata vermez: sayı gelmezse satır sadece adsız kalır.
    func loadPlacePresence() async {
        guard let ozetler = try? await service.fetchPlacePresence() else { return }
        placePresence = Dictionary(ozetler.map { ($0.placeID, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func togglePresence(at place: CampusPlace) {
        guard presenceUpdateID == nil else { return }
        let operationID = UUID()
        let accountID = currentUserID
        let turningOff = currentVisiblePlace?.id == place.id
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            presenceUpdateID = operationID
            presenceUpdatingPlaceID = place.id
            presenceError = nil
        }
        Task { @MainActor in
            do {
                try await service.setVisiblePlace(turningOff ? nil : place.id)
                guard presenceUpdateID == operationID, accountID == currentUserID else { return }
                withTransaction(transaction) {
                    currentVisiblePlace = turningOff ? nil : place
                    presenceUpdateID = nil
                    presenceUpdatingPlaceID = nil
                }
                Haptics.success()
                await loadPlacePresence()
            } catch {
                guard presenceUpdateID == operationID, accountID == currentUserID else { return }
                withTransaction(transaction) {
                    presenceUpdateID = nil
                    presenceUpdatingPlaceID = nil
                    if !isCancellation(error) {
                        presenceError = UserFacingError.message(error, fallback: L10n.Places.toggleFailed)
                    }
                }
            }
        }
    }

    /// Bir yerde şu an görünen kişiler. Bu liste koda gömülü sabit isimlerdi; herkese
    /// aynı sahte kişiler gösteriliyordu.
    func peopleAtPlace(_ place: CampusPlace) async throws -> [StudentProfile] {
        let digerleri = try await service.fetchPeopleAtPlace(place.id)
        // Sunucu sorgusu kişinin kendisini eliyor. "Buradayım" dedikten sonra
        // listede kendini görmemek, görünür olup olmadığını belirsiz bırakıyor:
        // insan kendi adını görene kadar işe yaradığından emin olamıyor.
        guard currentVisiblePlace?.id == place.id else { return digerleri }
        return [currentUserProfile] + digerleri.filter { $0.id != currentUserID }
    }

    func isJoined(to club: CampusClub) -> Bool {
        joinedClubIDs.contains(club.id)
    }

    /// Kulüpleri ve üyeliklerini sunucudan yükler. Liste eskiden koda gömülüydü ve
    /// katılma bilgisi yalnızca bellekte tutulduğu için uygulama kapanınca kayboluyordu.
    /// - Parameter silently: bkz. `loadProfileVisits(silently:)`.
    func loadClubs(silently: Bool = false) async {
        clubsLoadGeneration += 1
        let generation = clubsLoadGeneration
        let accountID = currentUserID
        isLoadingClubs = true
        defer { if generation == clubsLoadGeneration { isLoadingClubs = false } }
        do {
            let result = try await service.fetchClubs()
            guard generation == clubsLoadGeneration, accountID == currentUserID, !Task.isCancelled else { return }
            clubs = result.clubs
            joinedClubIDs = result.joinedIDs
            clubsError = nil
        } catch {
            guard generation == clubsLoadGeneration, accountID == currentUserID, !isCancellation(error) else { return }
            clubsError = UserFacingError.message(error, fallback: L10n.Places.clubsFailed)
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
