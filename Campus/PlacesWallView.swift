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
        Dictionary(grouping: appState.places, by: \.area)
            .map { (alan: $0.key, yerler: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.alan < $1.alan }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CampusTheme.Space.xl) {
                    visibilityCard

                    if appState.places.isEmpty {
                        ContentUnavailableView(
                            "Kampüs yerleri yüklenemedi",
                            systemImage: "mappin.slash",
                            description: Text("Bağlantını kontrol edip tekrar dene.")
                        )
                        .padding(.top, CampusTheme.Space.xxl)
                    } else {
                        ForEach(grouped, id: \.alan) { grup in
                            VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
                                Text(grup.alan.uppercased())
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .tracking(1.1)
                                    .foregroundStyle(CampusTheme.muted)

                                VStack(spacing: 0) {
                                    ForEach(Array(grup.yerler.enumerated()), id: \.element.id) { index, place in
                                        if index > 0 {
                                            Divider().overlay(CampusTheme.hairline).padding(.leading, 54)
                                        }
                                        placeRow(place)
                                    }
                                }
                                .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous).stroke(CampusTheme.hairline))
                            }
                        }
                    }
                }
                .padding(.horizontal, CampusTheme.Space.lg)
                .padding(.bottom, CampusTheme.Space.xxl)
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .navigationTitle("Nerede tanışabiliriz?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if appState.selectedPlaceFilter != nil {
                        Button("Filtreyi kaldır") {
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

    /// Kendi görünürlüğün. Akıştaki kartta bu bilgi küçük bir satırdı ve ne işe
    /// yaradığı anlaşılmıyordu; burada ne olduğu açıkça yazıyor.
    private var visibilityCard: some View {
        VStack(alignment: .leading, spacing: CampusTheme.Space.sm) {
            if let active = appState.currentVisiblePlace {
                Label("Şu an \(active.name) konumunda görünürsün", systemImage: "dot.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CampusTheme.violet)
                Text("Buradaki diğer öğrenciler seni görebilir. İstediğin an kapatabilirsin.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
                Button("Görünürlüğü kapat") { appState.togglePresence(at: active) }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(CampusTheme.coral)
                    .padding(.top, 2)
            } else {
                Text("Bir yerde görünür ol")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(CampusTheme.ink)
                Text("Bulunduğun yeri seçersen orada olan öğrenciler seni görür. Seçmezsen kimse konumunu bilmez.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CampusTheme.Space.lg)
        .background(CampusTheme.violet.opacity(0.07), in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
    }

    private func placeRow(_ place: CampusPlace) -> some View {
        let isHere = appState.currentVisiblePlace?.id == place.id
        let isFiltered = appState.selectedPlaceFilter?.id == place.id

        return HStack(spacing: CampusTheme.Space.md) {
            Image(systemName: isHere ? "mappin.circle.fill" : "mappin.circle")
                .font(.system(size: 19))
                .foregroundStyle(isHere ? CampusTheme.violet : CampusTheme.ink.opacity(0.35))
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(CampusTheme.ink)
                Text(isFiltered ? "Akış bu yere göre süzülüyor" : "Kimler burada, bak")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(isFiltered ? CampusTheme.violet : CampusTheme.muted)
            }
            Spacer(minLength: 0)

            Button {
                Haptics.impact(.light)
                appState.togglePresence(at: place)
            } label: {
                Text(isHere ? "BURADAYIM" : "BURADAYIM?")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(isHere ? CampusTheme.paper : CampusTheme.ink)
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(isHere ? CampusTheme.violet : CampusTheme.ink.opacity(0.06), in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, CampusTheme.Space.md)
        .frame(minHeight: 62)
        .contentShape(Rectangle())
        .onTapGesture { selectedPeoplePlace = place }
    }
}
