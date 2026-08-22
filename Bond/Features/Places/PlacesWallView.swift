import SwiftUI

/// Kampüs yerleri duvarı.
///
/// Önceden akışın tepesinde bir kart vardı: başlık, "YER SEÇ" yazısı ve yatay
/// kaydırılan çipler. Yerlerin çoğu ekrana sığmıyordu, hangisinde kim olduğu
/// görünmüyordu ve kartın kendisi akışta yer kaplıyordu. Artık akışta tek satır
/// duruyor, dokununca burası açılıyor.
struct PlacesWallView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Bir yer seçilirse akış ona göre süzülür.
    let onFilter: (CampusPlace?) -> Void

    @State private var selectedPeoplePlace: CampusPlace?

    private var grouped: [(alan: String, yerler: [CampusPlace])] {
        // Sıra `CampusPlaceOrder`dan geliyor: en çok buluşulan yerler başta.
        // Burası kendi alfabetik sırasını kuruyordu ve iki sorun çıkarıyordu —
        // akıştaki şeritle bu liste birbirini tutmuyordu, ayrıca ham `<`
        // karşılaştırması Türkçe harfleri Unicode sırasına göre diziyor:
        // "Şamdan Kafe" en çok gidilen yer olmasına rağmen "Yemekhane"nin de
        // altına, listenin en dibine düşüyordu.
        Dictionary(grouping: CampusPlaceOrder.sorted(appState.places), by: \.area)
            .map { (alan: $0.key, yerler: CampusPlaceOrder.sorted($0.value)) }
            .sorted { grupSirasi($0) < grupSirasi($1) }
    }

    /// Grubun sırası, içindeki en öncelikli yere göre. Alanları alfabetik
    /// dizmek, öne çıkardığımız yeri yine dibe gömüyordu.
    private func grupSirasi(_ grup: (alan: String, yerler: [CampusPlace])) -> Int {
        grup.yerler
            .compactMap { CampusPlaceOrder.pinned.firstIndex(of: $0.name) }
            .min() ?? CampusPlaceOrder.pinned.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.xl) {
                    visibilityCard

                    if appState.places.isEmpty {
                        placesState
                    } else {
                        ForEach(grouped, id: \.alan) { grup in
                            VStack(alignment: .leading, spacing: BondTheme.Space.md) {
                                // Tek grup varsa başlık bir şey anlatmıyor, sadece yer
                                // kaplıyor. Yalnızca gerçekten birden fazla alan olduğunda
                                // gösteriliyor.
                                if grouped.count > 1 {
                                    Text(grup.alan.uppercased())
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1.1)
                                        .foregroundStyle(BondTheme.muted)
                                }

                                VStack(spacing: 0) {
                                    ForEach(Array(grup.yerler.enumerated()), id: \.element.id) { index, place in
                                        if index > 0 {
                                            Divider().overlay(BondTheme.hairline).padding(.leading, 54)
                                        }
                                        placeRow(place)
                                    }
                                }
                                .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous).stroke(BondTheme.hairline))
                            }
                        }
                    }
                }
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.bottom, BondTheme.Space.xxl)
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .task {
                if appState.places.isEmpty { await appState.loadPlaces() }
            }
            .navigationTitle(L10n.Places.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if appState.selectedPlaceFilter != nil {
                        Button(L10n.Places.clearFilter) {
                            onFilter(nil)
                            dismiss()
                        }
                    }
                }
            }
            .sheet(item: $selectedPeoplePlace) { place in
                PlacePeopleView(place: place)
            }
        }
    }

    @ViewBuilder
    private var placesState: some View {
        if appState.isLoadingPlaces {
            AppLoadingView()
        } else if let error = appState.placesError {
            ContentUnavailableView {
                Label(L10n.Places.loadFailedTitle, systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button(L10n.Common.retry) {
                    Task { await appState.loadPlaces() }
                }
                .buttonStyle(.borderedProminent)
                .tint(BondTheme.acid)
            }
        } else {
            ContentUnavailableView(
                L10n.Places.emptyTitle,
                systemImage: "mappin.slash",
                description: Text(L10n.Places.emptyBody)
            )
        }
    }

    /// Kendi görünürlüğün. Akıştaki kartta bu bilgi küçük bir satırdı ve ne işe
    /// yaradığı anlaşılmıyordu; burada ne olduğu açıkça yazıyor.
    private var visibilityCard: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            if let active = appState.currentVisiblePlace {
                Label(L10n.Places.visibleAt(active.name), systemImage: "dot.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BondTheme.violet)
                Text(L10n.Places.visibleHint)
                    .font(.system(size: 12))
                    .foregroundStyle(BondTheme.muted)
                Button(L10n.Places.hideVisibility) { appState.togglePresence(at: active) }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BondTheme.coral)
                    .padding(.top, 2)
            } else {
                Text(L10n.Places.beVisible)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(BondTheme.ink)
                Text(L10n.Places.beVisibleHint)
                    .font(.system(size: 12))
                    .foregroundStyle(BondTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BondTheme.Space.lg)
        .background(BondTheme.violet.opacity(0.07), in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
    }

    private func placeRow(_ place: CampusPlace) -> some View {
        let isHere = appState.currentVisiblePlace?.id == place.id
        let isFiltered = appState.selectedPlaceFilter?.id == place.id

        return HStack(spacing: BondTheme.Space.md) {
            Image(systemName: isHere ? "mappin.circle.fill" : "mappin.circle")
                .font(.system(size: 19))
                .foregroundStyle(isHere ? BondTheme.violet : BondTheme.ink.opacity(0.35))
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BondTheme.ink)
                Text(isFiltered ? L10n.Places.feedFiltered : L10n.Places.whoIsHere)
                    .font(.system(size: 12))
                    .foregroundStyle(isFiltered ? BondTheme.violet : BondTheme.muted)
            }
            Spacer(minLength: 0)

            Button {
                Haptics.impact(.light)
                appState.togglePresence(at: place)
            } label: {
                Text(isHere ? L10n.Places.imHere : L10n.Places.imHereQuestion)
                    .font(.system(size: 10, weight: .black))
                    .tracking(0.6)
                    .foregroundStyle(isHere ? BondTheme.paper : BondTheme.ink)
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(isHere ? BondTheme.violet : BondTheme.ink.opacity(0.06), in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, BondTheme.Space.md)
        .frame(minHeight: 62)
        .contentShape(Rectangle())
        .onTapGesture { selectedPeoplePlace = place }
    }
}
