import SwiftUI

/// Keşif destesindeki profil kartı. Hem `PremiumDiscoverView` hem de profildeki
/// "kartım nasıl görünüyor" önizlemesi bunu kullanır — önizlemenin gerçekte
/// gösterilen karttan sapmaması için tek bir tanım tutuluyor.
struct DiscoveryCard: View {
    let profile: StudentProfile
    /// Uyum yüzdesi karşı tarafa göre hesaplanır; kendi kartını önizlerken anlamsız olduğu için gizlenir.
    var showsCompatibility = true
    /// Kullanıcının kendi ilgi alanları. Kesişenler kartta vurgulanır — "neden bu kişi"
    /// sorusunun cevabı listede düz metin olarak kayboluyordu.
    var highlightedInterests: Set<String> = []
    @State private var photoIndex = 0

    private var kurucu: Bool { profile.badge == .founder }

    /// Gösterilecek fotoğraflar. Galeri boşsa ana profil fotoğrafına düşer.
    private var photos: [URL] {
        profile.galleryImageURLs.isEmpty ? [profile.imageURL].compactMap { $0 } : profile.galleryImageURLs
    }

    private var currentPhoto: URL? {
        guard !photos.isEmpty else { return nil }
        return photos[min(photoIndex, photos.count - 1)]
    }

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let width = proxy.size.width
            // Fotoğraf kartın çoğunluğu: yarı yarıya bölünce alttaki açık panel
            // kartı ağırlaştırıyor ve kişiye değil metne bakılıyordu.
            let photoHeight = height * 0.72
            VStack(spacing: 0) {
                // Fotoğraf katmanındaki her parçaya açık ölçü veriliyor: ZStack'in boyutunu
                // çocuklarından çıkarmaya bırakmak, katmanlar farklı yükseklikler isteyince
                // fotoğrafla bilgi paneli arasında boşluk bırakıyor ya da katmanı kırpıyordu.
                ZStack(alignment: .topLeading) {
                    // `assetName` sabit nil'di: pakete gömülü görseller (örnek veri
                    // ve ekran görüntüleri) hiç kullanılmıyor, kart boş degradeye
                    // düşüyordu. Gerçek kullanıcılarda etkisi yok, onların fotoğrafı
                    // adresle geliyor.
                    ProfileMedia(url: currentPhoto, data: nil,
                                 assetName: currentPhoto == nil ? profile.imageAssetName : nil)
                        .frame(width: width, height: photoHeight)
                        .clipped()
                        .id(photoIndex)

                    LinearGradient(colors: [.black.opacity(0.38), .clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                        .frame(width: width, height: photoHeight)

                    // Fotoğraf noktaları "sayfa çevirebilirsin" diyordu ama hiçbir şey
                    // yapmıyordu; diğer fotoğrafları görmek için detay sayfasını açmak
                    // gerekiyordu. Sağ/sol yarıya dokunmak artık gerçekten sayfa çeviriyor.
                    if photos.count > 1 {
                        HStack(spacing: 0) {
                            Button { step(-1) } label: { Color.clear.contentShape(Rectangle()) }
                                .accessibilityLabel(L10n.Discovery.prevPhoto)
                            Button { step(1) } label: { Color.clear.contentShape(Rectangle()) }
                                .accessibilityLabel(L10n.Discovery.nextPhoto)
                        }
                        .buttonStyle(.plain)
                        .frame(width: width, height: photoHeight)

                        // Kaç fotoğraf olduğu ve kaçıncısında olunduğu hiçbir yerde
                        // yazmıyordu; kullanıcı sağa dokununca bir şey değişeceğini
                        // bilmiyordu.
                        HStack(spacing: 4) {
                            ForEach(0..<photos.count, id: \.self) { indeks in
                                Capsule()
                                    .fill(.white.opacity(indeks == photoIndex ? 0.95 : 0.35))
                                    .frame(height: 3)
                            }
                        }
                        .animation(.snappy(duration: 0.2), value: photoIndex)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .frame(width: width, alignment: .top)
                        .allowsHitTesting(false)
                    }

                    VStack(spacing: 0) {
                        HStack {
                            if showsCompatibility {
                                Label(L10n.Discovery.compatibility(profile.compatibility), systemImage: "sparkles")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 11).frame(height: 30)
                                    .background(.black.opacity(0.35), in: Capsule())
                            }
                            Spacer()
                            // Çıplak bir ikon ne anlama geldiğini söylemiyordu.
                            // Rozetler zaten çok az hesapta olduğu için yazılı
                            // etiket kartı kalabalıklaştırmıyor.
                            ProfileBadgeLabel(badge: profile.badge)
                        }
                        Spacer()
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text(profile.name).font(.system(size: 34, weight: .bold))
                            Text("\(profile.age)").font(.title3.weight(.medium))
                            Spacer()
                        }
                        if let rozetAlt = profile.badge.subtitle {
                            // Sarmalayan yığın ortalı; bu satır adla aynı hizada
                            // başlasın diye açıkça sola yaslanıyor.
                            HStack {
                                Text(rozetAlt)
                                    .font(.system(size: 12))
                                    .italic()
                                    .foregroundStyle(CampusTheme.ember)
                                Spacer(minLength: 0)
                            }
                        }
                        HStack(spacing: 8) {
                            // Sunucu, bir aydan uzun süredir girmemiş kişilerde etiketi boş
                            // döndürüyor; boş bir nokta ve boşluk göstermek yerine gizliyoruz.
                            if !profile.activeLabel.isEmpty {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(profile.activeLabel.hasPrefix("Yakın") || profile.activeLabel == L10n.Profile.recentlyActive ? Color.green : .white.opacity(0.5))
                                        .frame(width: 7, height: 7)
                                    Text(profile.activeLabel)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.82))
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, 6)
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .frame(width: width, height: photoHeight)
                }
                .frame(width: width, height: photoHeight)
                .clipped()

                details
                    .frame(width: width, height: height - photoHeight, alignment: .topLeading)
                    .background(CampusTheme.paper)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            // Kurucu kartı bir tık ayrışıyor: fıstık yeşili ince bir çerçeve ve
            // hafif bir hâle. Renk zaten rozetin rengi, yeni bir dil eklemiyor.
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(kurucu ? CampusTheme.ember.opacity(0.85) : .white.opacity(0.16),
                            lineWidth: kurucu ? 2 : 1)
            )
            .shadow(color: kurucu ? CampusTheme.ember.opacity(0.32) : .clear, radius: 18)
            .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
        }
        // SwiftUI kart görünümünü sonraki profil için yeniden kullanıyor; sıfırlamazsak
        // yeni kişinin kartı önceki kişide kalınan fotoğraf numarasından açılır.
        .onChange(of: profile.id) { _, _ in photoIndex = 0 }
    }

    /// Ortak olanlar başa alınır ki ilk üçte mutlaka görünsünler.
    private var sortedInterests: [String] {
        profile.interests.sorted { lhs, rhs in
            let l = highlightedInterests.contains(lhs), r = highlightedInterests.contains(rhs)
            return l == r ? lhs < rhs : l
        }
    }

    private func step(_ delta: Int) {
        guard photos.count > 1 else { return }
        let next = photoIndex + delta
        guard next >= 0, next < photos.count else { return }
        photoIndex = next
        Haptics.impact(.light)
    }

    /// Kartın alt paneli. `compatibilityReasons` ve `activeLabel` backend'den zaten
    /// geliyordu ama hiçbir yerde gösterilmiyordu — kararı verdiren asıl sinyal bunlar olduğu için
    /// kartın boş kalan alt yarısını bu içerikle değerlendiriyoruz.
    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(DepartmentCatalog.display(profile.department), systemImage: "graduationcap.fill")
                Spacer()
                Text(AcademicYear.display(profile.year))
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(CampusTheme.ink.opacity(0.55))

            Text(profile.bio)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(CampusTheme.ink.opacity(0.72))
                .lineSpacing(2)
                .lineLimit(2)

            if !profile.compatibilityReasons.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(profile.compatibilityReasons.prefix(2), id: \.self) { reason in
                        Label(CompatibilityCopy.localize(reason), systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(CampusTheme.violet)
                    }
                }
            }

            HStack(spacing: 7) {
                // Ortak ilgi alanları önce ve vurgulu gösteriliyor; hepsi aynı görünürken
                // hangisinin paylaşıldığı anlaşılmıyordu.
                ForEach(sortedInterests.prefix(3), id: \.self) { item in
                    let shared = highlightedInterests.contains(item)
                    HStack(spacing: 4) {
                        if shared {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .black))
                        }
                        Text(InterestCatalog.displayName(item))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(shared ? CampusTheme.violet : CampusTheme.ink)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(shared ? CampusTheme.violet.opacity(0.12) : CampusTheme.ink.opacity(0.055), in: Capsule())
                    .overlay(Capsule().stroke(shared ? CampusTheme.violet.opacity(0.35) : .clear))
                }
                Spacer()
            }

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Text(L10n.Discovery.seeFullProfile)
                    .font(.system(size: 11, weight: .bold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                Spacer()
            }
            .foregroundStyle(CampusTheme.ink.opacity(0.38))
        }
        .foregroundStyle(CampusTheme.ink)
        .padding(16)
    }
}
