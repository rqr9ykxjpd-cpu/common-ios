import SwiftUI

/// "Kartını düzenle": profil kartının rengini seçme ekranı.
///
/// Ortada kaydırılabilen kimlik kartları duruyor; her biri bir renk, yanlarda
/// komşu kartlar görünüyor. Kartı kaydırmak ya da alttaki renk dairesine
/// dokunmak aynı seçimi yapar. Seçilen renk profil kartının zemini olur ve
/// kartı açan herkes onu görür; sunucuya yalnızca "Bu kartı seç" ile gider.
///
/// Zemin bilerek koyu: kart ekranın tek renkli nesnesi, gözü ona çekiyor.
struct CardStudioView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Stüdyonun dışındaki (sistemin) tema; önizleme bununla açılıyor.
    @Environment(\.colorScheme) private var systemScheme
    @State private var selected: CardTheme = .classic
    /// Kaydırma konumu; `selected` ile eşitleniyor.
    @State private var scrolled: CardTheme?
    @State private var didLoad = false
    @State private var saving = false
    @State private var showPreview = false
    @State private var showProfileEditor = false
    /// Seçili kart telefonla birlikte hafifçe döner.
    @State private var tilt = DeviceTilt()

    private var saved: CardTheme { appState.draft.cardTheme }
    private var hasChanges: Bool { selected != saved }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .padding(.top, BondTheme.Space.sm)

                carousel
                    .frame(maxHeight: .infinity)

                editProfileChip
                    .padding(.bottom, BondTheme.Space.lg)

                swatches
                    .padding(.bottom, BondTheme.Space.lg)

                actions
            }
            .padding(.bottom, BondTheme.Space.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(StudioCanvas.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                        .disabled(saving)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .interactiveDismissDisabled(saving)
        .task {
            guard IdleMotion.allowed(reduceMotion: reduceMotion) else { return }
            tilt.start()
        }
        .onDisappear { tilt.stop() }
        .onAppear {
            guard !didLoad else { return }
            selected = saved
            scrolled = saved
            didLoad = true
        }
        .onChange(of: scrolled) { _, yeni in
            guard let yeni, yeni != selected else { return }
            selected = yeni
            Haptics.selection()
        }
        // Başkaları kartı sheet olarak görüyor; önizleme de öyle açılsın ki
        // üst çubuk, düğmeler ve köşeler birebir aynı olsun.
        .sheet(isPresented: $showPreview) {
            NavigationStack {
                SocialPersonDetailView(
                    profile: appState.currentUserProfile,
                    place: nil,
                    showsClose: true,
                    themeOverride: selected
                )
            }
            // Stüdyo koyu olduğu için sayfa (üst çubuk, düğmelerin camı) da koyu
            // açılıyordu; önizleme başkalarının gördüğü gibi sistemin temasında.
            .preferredColorScheme(systemScheme)
        }
        .fullScreenCover(isPresented: $showProfileEditor) {
            NavigationStack { ProfileEditorView() }
        }
    }

    // MARK: - Başlık

    private var header: some View {
        VStack(spacing: 6) {
            Text(L10n.CardStudio.title)
                .font(.system(.title, design: .serif).weight(.bold))
                .tracking(-0.4)
                .accessibilityAddTraits(.isHeader)
            Text(L10n.CardStudio.subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, BondTheme.Space.lg)
    }

    // MARK: - Kartlar

    private var carousel: some View {
        GeometryReader { geo in
            // Kartın yanlarından komşular görünsün; yükseklik ekrana göre.
            let genislik = min(geo.size.width - 104, (geo.size.height - 24) / 1.36)
            ScrollView(.horizontal, showsIndicators: false) {
                // Tembel yığın değil: on kartın yeri baştan bilinmeyince ilk açılışta
                // seçili kart ortalanamıyor, sağa kayık ve eğik duruyordu.
                HStack(spacing: 14) {
                    ForEach(CardTheme.allCases) { theme in
                        StudioIDCard(
                            theme: theme,
                            name: appState.draft.name,
                            handle: appState.draft.username,
                            department: DepartmentCatalog.display(appState.draft.department),
                            year: appState.draft.year,
                            avatarURL: appState.avatarURL,
                            avatarData: appState.avatarData,
                            avatarAsset: appState.currentUserProfile.imageAssetName,
                            glare: theme == selected ? tilt.x : nil
                        )
                        .frame(width: genislik, height: genislik * 1.36)
                        // Yalnızca ortadaki kart eğilir; komşular kaydırmayla dönüyor.
                        .rotation3DEffect(.degrees(theme == selected ? tilt.y * 6 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                        .rotation3DEffect(.degrees(theme == selected ? -tilt.x * 6 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                        .scrollTransition(.interactive, axis: .horizontal) { card, phase in
                            card
                                .scaleEffect(phase.isIdentity ? 1 : 0.88)
                                .rotationEffect(.degrees(reduceMotion ? 0 : phase.value * 5))
                                .opacity(phase.isIdentity ? 1 : 0.55)
                        }
                        .id(theme)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(theme.title)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, (geo.size.width - genislik) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolled, anchor: .center)
            .frame(height: geo.size.height)
        }
    }

    private var editProfileChip: some View {
        Button { showProfileEditor = true } label: {
            Label(L10n.CardStudio.editProfile, systemImage: "pencil")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, BondTheme.Space.md)
                .frame(minHeight: 34)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("cardStudio.editProfile")
    }

    // MARK: - Renkler

    /// Beşerli iki satır: üstte koyu, altta açık tonlar.
    private var swatches: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 4) {
            ForEach(CardTheme.allCases) { theme in
                swatch(theme)
            }
        }
        .padding(.horizontal, BondTheme.Space.xl)
    }

    private func swatch(_ theme: CardTheme) -> some View {
        let secili = theme == selected
        return Button {
            guard !secili else { return }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { scrolled = theme }
        } label: {
            Circle()
                .fill(theme == .classic ? Color(hex: "F5F5F2") : theme.background)
                .overlay { Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1) }
                .frame(width: 32, height: 32)
                .padding(4)
                .overlay {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                        .opacity(secili ? 1 : 0)
                }
                .scaleEffect(secili ? 1 : 0.88)
                .animation(.smooth(duration: 0.2), value: secili)
                .frame(minWidth: 40, minHeight: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.title)
        .accessibilityAddTraits(secili ? .isSelected : [])
        .accessibilityIdentifier("cardStudio.\(theme.rawValue)")
    }

    // MARK: - Düğmeler

    private var actions: some View {
        VStack(spacing: 2) {
            PrimaryActionButton(
                title: L10n.CardStudio.save,
                enabled: hasChanges,
                fill: .white,
                foreground: StudioCanvas.background,
                action: { await save() },
                onDone: { dismiss() }
            )
            .accessibilityIdentifier("cardStudio.save")

            Button(L10n.ProfileHome.publicPreview) { showPreview = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("cardStudio.preview")
        }
        .padding(.horizontal, BondTheme.Space.md)
    }

    private func save() async -> Bool {
        saving = true
        defer { saving = false }
        return await appState.saveCardTheme(selected)
    }
}

private enum StudioCanvas {
    static let background = Color(hex: "111214")
}

// MARK: - Kimlik kartı

/// Düzenleyicideki kart: fotoğraf, ad, kullanıcı adı, bölüm. Zemin seçilen
/// renk; üstünde çok hafif çapraz çizgiler ve kesik çizgili bir iç kenar.
/// Yazı rengi kartın şemasından geliyor (koyu renklerde açık yazı).
private struct StudioIDCard: View {
    let theme: CardTheme
    let name: String
    let handle: String
    let department: String
    let year: String
    let avatarURL: URL?
    let avatarData: Data?
    let avatarAsset: String?
    /// -1…1: telefonun yatay eğimi; ışık buna göre kayar. `nil` = ışık yok.
    var glare: Double? = nil

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 28, style: .continuous) }
    private var scheme: ColorScheme { theme.scheme ?? .light }
    private var zemin: Color { theme == .classic ? Color(hex: "FAFAF7") : theme.background }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.Brand.wordmark)
                        .font(.system(size: w * 0.075, weight: .bold, design: .serif))
                    Spacer()
                    Text("YÜ")
                        .font(.system(size: w * 0.055, weight: .heavy))
                        .tracking(1)
                        .opacity(0.8)
                }

                Spacer(minLength: 0)

                ProfileMedia(url: avatarURL, data: avatarData, assetName: avatarAsset)
                    .frame(width: w * 0.42, height: w * 0.42)
                    .clipShape(Circle())
                    .overlay { Circle().strokeBorder(.white.opacity(0.9), lineWidth: 3) }
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 5)

                Text(name.isEmpty ? "@\(handle)" : name)
                    .font(.system(size: w * 0.12, weight: .bold, design: .serif))
                    .tracking(-0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, w * 0.05)
                if !name.isEmpty, !handle.isEmpty {
                    Text("@\(handle)")
                        .font(.system(size: w * 0.055, weight: .semibold))
                        .opacity(0.72)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.CardStudio.department)
                            .font(.system(size: w * 0.036, weight: .bold))
                            .tracking(0.8)
                            .opacity(0.55)
                        Text(department.isEmpty ? year : "\(department) · \(year)")
                            .font(.system(size: w * 0.045, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 8)
                    Text(theme.title.uppercased())
                        .font(.system(size: w * 0.036, weight: .bold))
                        .tracking(0.8)
                        .opacity(0.55)
                }
            }
            .padding(w * 0.08)
        }
        .foregroundStyle(BondTheme.ink)
        .background {
            ZStack {
                // Klasik düz, renkliler çizgili (bkz. CardThemeSurface).
                if theme == .classic { zemin } else { CardThemeSurface(theme: theme) }
                shape
                    .inset(by: 10)
                    .strokeBorder(BondTheme.ink.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .overlay {
            if let glare {
                GeometryReader { geo in
                    // İnce, hafif bir yansıma: açık kartı beyazlatıp soldurmasın.
                    LinearGradient(
                        colors: [.white.opacity(0), .white.opacity(scheme == .dark ? 0.12 : 0.16), .white.opacity(0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.38, height: geo.size.height * 1.6)
                    .rotationEffect(.degrees(24))
                    .offset(x: geo.size.width * (0.3 + CGFloat(glare) * 0.5), y: -geo.size.height * 0.3)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .clipShape(shape)
        .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
        .environment(\.colorScheme, scheme)
    }
}
