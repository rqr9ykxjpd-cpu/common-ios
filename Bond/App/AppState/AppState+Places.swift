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

    /// Dokunur dokunmaz sonuç ekranda: yer, sayı ve kendi fotoğrafın anında
    /// değişir; sunucu reddederse eski hâline döner. Eskiden düğmede gösterge
    /// dönüyor, sayı ancak ikinci bir istekten sonra güncelleniyordu.
    func togglePresence(at place: CampusPlace) {
        guard presenceUpdateID == nil else { return }
        let operationID = UUID()
        let accountID = currentUserID
        let turningOff = currentVisiblePlace?.id == place.id
        // Kilitliyken yerini gösteremez; çıkmak her zaman serbest.
        guard turningOff || requireStudent() else { return }
        let oncekiYer = currentVisiblePlace
        let oncekiOzet = placePresence
        withAnimation(BondTheme.Motion.snappy) {
            presenceUpdateID = operationID
            presenceError = nil
            currentVisiblePlace = turningOff ? nil : place
            placePresence = Self.presence(oncekiOzet, leaving: oncekiYer?.id,
                                          joining: turningOff ? nil : place.id, avatar: avatarURL)
        }
        Haptics.success()
        Task { @MainActor in
            do {
                try await service.setVisiblePlace(turningOff ? nil : place.id)
                guard presenceUpdateID == operationID, accountID == currentUserID else { return }
                presenceUpdateID = nil
                // Sunucunun kesin sayısı (aynı anda gelen başkaları dahil).
                await loadPlacePresence()
            } catch {
                guard presenceUpdateID == operationID, accountID == currentUserID else { return }
                withAnimation(BondTheme.Motion.snappy) {
                    currentVisiblePlace = oncekiYer
                    placePresence = oncekiOzet
                    presenceUpdateID = nil
                }
                if !isCancellation(error) {
                    // Ekran hatayı kendi satırında gösteriyor; burada yalnızca oturum kontrolü.
                    presenceError = UserFacingError.message(error, fallback: L10n.Places.toggleFailed)
                    verifySessionIfAuthError(error)
                }
            }
        }
    }

    /// Ayrılınan yerden bir eksilt, gidilen yere bir ekle (fotoğraf başa).
    static func presence(_ ozet: [UUID: PlacePresenceSummary], leaving: UUID?, joining: UUID?,
                         avatar: URL?) -> [UUID: PlacePresenceSummary] {
        var sonuc = ozet
        if let leaving, leaving != joining, let eski = sonuc[leaving] {
            let sayi = max(0, eski.count - 1)
            sonuc[leaving] = sayi == 0 ? nil : PlacePresenceSummary(
                placeID: leaving, count: sayi,
                avatarURLs: eski.avatarURLs.filter { $0 != avatar },
                avatarAssetNames: eski.avatarAssetNames)
        }
        if let joining, joining != leaving {
            let eski = sonuc[joining]
            var fotolar = eski?.avatarURLs ?? []
            if let avatar, !fotolar.contains(avatar) { fotolar.insert(avatar, at: 0) }
            sonuc[joining] = PlacePresenceSummary(
                placeID: joining, count: (eski?.count ?? 0) + 1,
                avatarURLs: Array(fotolar.prefix(3)),
                avatarAssetNames: eski?.avatarAssetNames ?? [])
        }
        return sonuc
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
        guard !willJoin || requireStudent() else { return }
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
