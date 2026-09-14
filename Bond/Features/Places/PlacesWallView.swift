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
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var presenceAccent: Color {
        colorScheme == .dark
            ? Color(red: 0.45, green: 0.76, blue: 0.72)
            : Color(red: 0.12, green: 0.39, blue: 0.37)
    }

    /// The horizontal row has two independent tap targets. Waiting until an
    /// accessibility size before stacking lets ordinary XXL text squeeze the
    /// presence button enough to orphan a letter on the next line.
    private var usesStackedPlaceRows: Bool { typeSize >= .xxLarge }

    /// Bir yer seçilirse akış ona göre süzülür.
    var showsCloseButton = true
    let onFilter: (CampusPlace?) -> Void

    @State private var selectedPeoplePlace: CampusPlace?
    @State private var showClubs = false
    @State private var hasStartedEntrance = false
    @State private var entranceIDs: [UUID] = []
    @State private var entranceVisible = false

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
                    clubsEntry
                    if let error = appState.placesError, !appState.places.isEmpty {
                        ScreenFailureView(message: error, compact: true) { Task { await appState.loadPlaces(silently: true) } }
                    }

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
                                        .font(.caption.weight(.semibold))
                                        .tracking(1.1)
                                        .foregroundStyle(BondTheme.muted)
                                }

                                VStack(spacing: 10) {
                                    ForEach(grup.yerler) { place in
                                        placeRow(place)
                                            .opacity(entranceIsHidden(place) ? 0 : 1)
                                            .offset(y: entranceIsHidden(place) ? 12 : 0)
                                            .animation(reduceMotion ? nil : BondTheme.Motion.smooth.delay(
                                                Double(entranceIDs.firstIndex(of: place.id) ?? 0) * 0.04
                                            ), value: entranceVisible)
                                    }
                                }

                            }
                        }
                    }
                }
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.bottom, BondTheme.Space.xxl)
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .task { await appState.loadPlaces(silently: true) }
            .task(id: appState.places.isEmpty) {
                guard !appState.places.isEmpty, !hasStartedEntrance else { return }
                hasStartedEntrance = true
                entranceIDs = grouped.flatMap { $0.yerler.map(\.id) }
                await Task.yield()
                entranceVisible = true
            }
            .refreshable { await appState.loadPlaces(silently: true) }
            .navigationTitle(L10n.Places.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(L10n.Common.close) { dismiss() }
                    }
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
            .sheet(isPresented: $showClubs) {
                CampusClubsView(showsCloseButton: true)
            }
        }
    }

    @ViewBuilder
    private var placesState: some View {
        if appState.isLoadingPlaces {
            VStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonRow()
                        .padding(12)
                        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
                }
            }
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

    private var clubsEntry: some View {
        Button { showClubs = true } label: {
            HStack(spacing: BondTheme.Space.md) {
                Image(systemName: "person.3")
                    .font(.title3)
                    .frame(width: 28)
                Text(L10n.CampusNavigation.clubs).font(.subheadline.weight(.medium))
                Spacer(minLength: BondTheme.Space.sm)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(BondTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
        .accessibilityLabel(L10n.CampusNavigation.clubs)
    }

    /// Kendi görünürlüğün. Akıştaki kartta bu bilgi küçük bir satırdı ve ne işe
    /// yaradığı anlaşılmıyordu; burada ne olduğu açıkça yazıyor.
    private var visibilityCard: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            Text(L10n.Places.beVisibleHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // Reserve the tallest localized status, including long place names.
            // Changing presence must never change the header's height.
            ZStack(alignment: .leading) {
                ForEach(appState.places) { place in
                    Text(L10n.Places.visibleAt(place.name))
                        .hidden().accessibilityHidden(true)
                }
                if let active = appState.currentVisiblePlace {
                    Text(L10n.Places.visibleAt(active.name))
                        .foregroundStyle(presenceAccent)
                } else {
                    // Ayrılan alan boş kalmasın; durumu söylesin.
                    Text(L10n.Places.notVisible)
                        .foregroundStyle(BondTheme.muted)
                }
            }
            .font(.subheadline.weight(.medium))
            .fixedSize(horizontal: false, vertical: true)
            if let error = appState.presenceError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(BondTheme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func placeRow(_ place: CampusPlace) -> some View {
        let isHere = appState.currentVisiblePlace?.id == place.id
        let isFiltered = appState.selectedPlaceFilter?.id == place.id
        let layout = usesStackedPlaceRows
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            placeLink(place, filtered: isFiltered)
            presenceButton(place, isHere: isHere)
        }
        .padding(12)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    private func entranceIsHidden(_ place: CampusPlace) -> Bool {
        !reduceMotion && !entranceVisible && (!hasStartedEntrance || entranceIDs.contains(place.id))
    }

    private func placeLink(_ place: CampusPlace, filtered: Bool) -> some View {
        Button { selectedPeoplePlace = place } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse").font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name).font(.body.weight(.medium))
                        .lineLimit(usesStackedPlaceRows ? nil : 2)
                        .minimumScaleFactor(0.9)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)
                    // Tıklamadan önce cevap: kaç kişi orada + ilk üç yüz.
                    presenceLine(place)
                    if filtered {
                        Text(L10n.Places.feedFiltered)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .foregroundStyle(BondTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
        .accessibilityHint(L10n.Places.whoIsHere)
        .accessibilityIdentifier("place.open.\(place.id)")
    }

    /// "4 kişi" + üst üste avatarlar; kimse yoksa soluk "kimse yok".
    @ViewBuilder private func presenceLine(_ place: CampusPlace) -> some View {
        let ozet = appState.placePresence[place.id]
        let sayi = ozet?.count ?? 0
        HStack(spacing: 6) {
            if let ozet, sayi > 0 {
                HStack(spacing: -7) {
                    ForEach(Array(ozet.avatarURLs.prefix(3).enumerated()), id: \.offset) { _, url in
                        ProfileMedia(url: url, data: nil)
                            .frame(width: 20, height: 20).clipShape(Circle())
                            .overlay(Circle().stroke(BondTheme.surface, lineWidth: 1.5))
                    }
                    ForEach(Array(ozet.avatarAssetNames.prefix(3).enumerated()), id: \.offset) { _, name in
                        ProfileMedia(url: nil, data: nil, assetName: name)
                            .frame(width: 20, height: 20).clipShape(Circle())
                            .overlay(Circle().stroke(BondTheme.surface, lineWidth: 1.5))
                    }
                }
                Text(L10n.Places.peopleHere(sayi))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BondTheme.ink)
                    .contentTransition(.numericText(value: Double(sayi)))
            } else {
                Text(L10n.Places.nobodyHere)
                    .font(.caption)
                    .foregroundStyle(BondTheme.muted)
            }
        }
        .animation(BondTheme.Motion.snappy, value: sayi)
        .accessibilityLabel(sayi > 0 ? L10n.Places.peopleHere(sayi) : L10n.Places.nobodyHere)
    }

    private func presenceButton(_ place: CampusPlace, isHere: Bool) -> some View {
        let isUpdating = appState.presenceUpdatingPlaceID == place.id
        return Button {
            guard appState.presenceUpdateID == nil else { return }
            Haptics.selection()
            appState.togglePresence(at: place)
        } label: {
            ZStack {
                // Both labels participate in layout, so neither state resizes it.
                Text(L10n.Places.youAreHere).hidden()
                Text(L10n.Places.imHere).hidden()
                Text(isHere ? L10n.Places.youAreHere : L10n.Places.imHere)
                    .opacity(isUpdating ? 0 : 1)
                if isUpdating { ProgressView().controlSize(.small) }
            }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isHere ? L10n.Places.hideVisibility : L10n.Places.imHere)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .frame(width: usesStackedPlaceRows ? nil : 120)
                .frame(minHeight: 44)
                .frame(maxWidth: usesStackedPlaceRows ? .infinity : nil)
                .foregroundStyle(isHere ? BondTheme.paper : BondTheme.ink)
                // Kart surface; kapsül paper ki kartın üstünde okunsun.
                .background(isHere ? BondTheme.ink : BondTheme.paper, in: Capsule())
                .contentTransition(.opacity)
        }
        .buttonStyle(.pressable)
        .tint(isHere ? BondTheme.paper : BondTheme.ink)
        // AppState deliberately disables layout animations. Re-enable only
        // this size-stable control, never its row or the header.
        .transaction(value: isHere) {
            $0.disablesAnimations = reduceMotion
            $0.animation = reduceMotion ? nil : BondTheme.Motion.snappy
        }
        .transaction(value: isUpdating) {
            $0.disablesAnimations = reduceMotion
            $0.animation = reduceMotion ? nil : BondTheme.Motion.snappy
        }
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
        .disabled(isUpdating)
        .accessibilityIdentifier("place.presence.\(place.id)")
    }
}
