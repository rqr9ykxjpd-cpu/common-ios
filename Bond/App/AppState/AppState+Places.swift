import SwiftUI

// MARK: - AppState+Places
extension AppState {
    /// - Parameter silently: bkz. `loadProfileVisits(silently:)`.
    func loadPlaces(silently: Bool = false) async {
        isLoadingPlaces = true
        defer { isLoadingPlaces = false }
        do {
            async let yerler = service.fetchPlaces()
            async let benimYerim = service.fetchMyVisiblePlaceID()
            let (yeniYerler, gorunduguYer) = try await (yerler, benimYerim)
            places = yeniYerler
            // Kullanıcının bekleyen bir dokunuşu varsa onun seçimi geçerli.
            if presenceSyncTask == nil {
                confirmedVisiblePlaceID = .some(gorunduguYer)
                currentVisiblePlace = gorunduguYer.flatMap { id in yeniYerler.first { $0.id == id } }
            }
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
    /// Kullanıcının gönderilmekte olan seçimi varsa dokunulmaz; o bitince yenilenir.
    func loadPlacePresence() async {
        guard let ozetler = try? await service.fetchPlacePresence(), presenceSyncTask == nil else { return }
        applyPlacePresence(ozetler)
    }

    private func applyPlacePresence(_ ozetler: [PlacePresenceSummary]) {
        placePresence = Dictionary(ozetler.map { ($0.placeID, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Dokunur dokunmaz sonuç ekranda: yer, sayı ve kendi fotoğrafın anında
    /// değişir. Eskiden istek sürerken gelen dokunuş sessizce yok sayılıyordu;
    /// artık her dokunuş ekrana yansıyor, sunucuya sırayla yalnızca son seçim gidiyor.
    func togglePresence(at place: CampusPlace) {
        let turningOff = currentVisiblePlace?.id == place.id
        // Kilitliyken yerini gösteremez; çıkmak her zaman serbest.
        guard turningOff || requireStudent() else { return }
        let oncekiYer = currentVisiblePlace
        withAnimation(BondTheme.Motion.snappy) {
            presenceError = nil
            currentVisiblePlace = turningOff ? nil : place
            placePresence = Self.presence(placePresence, leaving: oncekiYer?.id,
                                          joining: turningOff ? nil : place.id, avatar: avatarURL)
        }
        Haptics.success()
        syncPresence()
    }

    /// Ekrandaki seçimi sunucuya taşır. Çalışırken gelen dokunuşları da sırayla
    /// gönderir; sunucu reddederse ekran son onaylanan yere döner.
    private func syncPresence() {
        guard presenceSyncTask == nil else { return }
        let accountID = currentUserID
        presenceSyncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while accountID == currentUserID {
                let hedef = currentVisiblePlace?.id
                if case .some(let onayli) = confirmedVisiblePlaceID, onayli == hedef {
                    // Sunucunun kesin sayısı (aynı anda gelen başkaları dahil).
                    // Beklerken yeni dokunuş geldiyse eski sayı ekrana basılmaz.
                    let ozetler = try? await service.fetchPlacePresence()
                    guard currentVisiblePlace?.id == hedef else { continue }
                    if let ozetler { applyPlacePresence(ozetler) }
                    break
                }
                do {
                    try await service.setVisiblePlace(hedef)
                    confirmedVisiblePlaceID = .some(hedef)
                } catch {
                    guard accountID == currentUserID else { break }
                    let geri = confirmedVisiblePlaceID.flatMap { $0 }.flatMap { id in places.first { $0.id == id } }
                    withAnimation(BondTheme.Motion.snappy) { currentVisiblePlace = geri }
                    if !isCancellation(error) {
                        // Ekran hatayı kendi satırında gösteriyor; burada yalnızca oturum kontrolü.
                        presenceError = UserFacingError.message(error, fallback: L10n.Places.toggleFailed)
                        verifySessionIfAuthError(error)
                    }
                    if let ozetler = try? await service.fetchPlacePresence() { applyPlacePresence(ozetler) }
                    break
                }
            }
            // Çıkış yapıldıysa sıfırlama zaten yapıldı; yeni hesabın işine dokunma.
            if accountID == currentUserID { presenceSyncTask = nil }
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
                avatarURLs: eski.avatarURLs.filter { !Self.sameImage($0, avatar) },
                avatarAssetNames: eski.avatarAssetNames)
        }
        if let joining, joining != leaving {
            let eski = sonuc[joining]
            var fotolar = eski?.avatarURLs ?? []
            if let avatar, !fotolar.contains(where: { Self.sameImage($0, avatar) }) { fotolar.insert(avatar, at: 0) }
            sonuc[joining] = PlacePresenceSummary(
                placeID: joining, count: (eski?.count ?? 0) + 1,
                avatarURLs: Array(fotolar.prefix(3)),
                avatarAssetNames: eski?.avatarAssetNames ?? [])
        }
        return sonuc
    }

    /// İmzalı adresin anahtarı her istekte değişiyor; aynı fotoğraf mı diye yoluna bakılır.
    static func sameImage(_ a: URL, _ b: URL?) -> Bool {
        guard let b else { return false }
        return BondImageLoader.cacheKey(for: a) == BondImageLoader.cacheKey(for: b)
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
