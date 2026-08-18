import SwiftUI

/// Keşif destesindeki profil kartı. Hem `PremiumDiscoverView` hem de profildeki
/// "kartım nasıl görünüyor" önizlemesi bunu kullanır — önizlemenin gerçekte
/// gösterilen karttan sapmaması için tek bir tanım tutuluyor.
struct DiscoveryCard: View {
    let profile: StudentProfile
    /// Uyum yüzdesi karşı tarafa göre hesaplanır; kendi kartını önizlerken anlamsız olduğu için gizlenir.
    var showsCompatibility = true
    @State private var photoIndex = 0

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
            let photoHeight = height * 0.50
            VStack(spacing: 0) {
                // Fotoğraf katmanındaki her parçaya açık ölçü veriliyor: ZStack'in boyutunu
                // çocuklarından çıkarmaya bırakmak, katmanlar farklı yükseklikler isteyince
                // fotoğrafla bilgi paneli arasında boşluk bırakıyor ya da katmanı kırpıyordu.
                ZStack(alignment: .topLeading) {
                    ProfileMedia(url: currentPhoto, data: nil, assetName: nil)
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
                                .accessibilityLabel("Önceki fotoğraf")
                            Button { step(1) } label: { Color.clear.contentShape(Rectangle()) }
                                .accessibilityLabel("Sonraki fotoğraf")
                        }
                        .buttonStyle(.plain)
                        .frame(width: width, height: photoHeight)
                    }

                    VStack(spacing: 0) {
                        HStack {
                            if showsCompatibility {
                                Label("%\(profile.compatibility) uyum", systemImage: "sparkles")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 11).frame(height: 30)
                                    .background(.black.opacity(0.35), in: Capsule())
                            }
                            Spacer()
                            if profile.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(CampusTheme.acid)
                            }
                        }
                        Spacer()
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text(profile.name).font(.system(size: 34, weight: .bold, design: .rounded))
                            Text("\(profile.age)").font(.title3.weight(.medium))
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(profile.activeLabel.hasPrefix("Yakın") ? Color.green : .white.opacity(0.5))
                                    .frame(width: 7, height: 7)
                                Text(profile.activeLabel)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.82))
                            }
                            Text(profile.relationshipIntent.title)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 9).frame(height: 22)
                                .background(.white.opacity(0.18), in: Capsule())
                            Spacer()
                        }
                        .padding(.top, 6)
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .frame(width: width, height: photoHeight)

                    if photos.count > 1 {
                        HStack(spacing: 4) {
                            ForEach(0..<photos.count, id: \.self) { index in
                                Capsule()
                                    .fill(index == photoIndex ? .white : .white.opacity(0.45))
                                    .frame(width: index == photoIndex ? 16 : 5, height: 5)
                            }
                        }
                        .animation(.snappy(duration: 0.2), value: photoIndex)
                        .padding(.horizontal, 10)
                        .frame(height: 22)
                        .background(.black.opacity(0.3), in: Capsule())
                        .frame(width: width, alignment: .center)
                        .padding(.top, 14)
                    }
                }
                .frame(width: width, height: photoHeight)
                .clipped()

                details
                    .frame(width: width, height: height - photoHeight, alignment: .topLeading)
                    .background(CampusTheme.paper)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
        }
        // SwiftUI kart görünümünü sonraki profil için yeniden kullanıyor; sıfırlamazsak
        // yeni kişinin kartı önceki kişide kalınan fotoğraf numarasından açılır.
        .onChange(of: profile.id) { _, _ in photoIndex = 0 }
    }

    private func step(_ delta: Int) {
        guard photos.count > 1 else { return }
        let next = photoIndex + delta
        guard next >= 0, next < photos.count else { return }
        photoIndex = next
        Haptics.impact(.light)
    }

    /// Kartın alt paneli. `compatibilityReasons`, `prompts` ve `activeLabel` backend'den zaten
    /// geliyordu ama hiçbir yerde gösterilmiyordu — kararı verdiren asıl sinyal bunlar olduğu için
    /// kartın boş kalan alt yarısını bu içerikle değerlendiriyoruz.
    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(profile.department, systemImage: "graduationcap.fill")
                Spacer()
                Text(profile.year)
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(CampusTheme.ink.opacity(0.55))

            Text(profile.bio)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(CampusTheme.ink.opacity(0.72))
                .lineSpacing(2)
                .lineLimit(2)

            if !profile.compatibilityReasons.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(profile.compatibilityReasons.prefix(2), id: \.self) { reason in
                        Label(reason, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(CampusTheme.violet)
                    }
                }
            }

            if let prompt = profile.prompts.first(where: { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(prompt.question.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(CampusTheme.ink.opacity(0.4))
                    Text(prompt.answer)
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(CampusTheme.ink.opacity(0.85))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(CampusTheme.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack(spacing: 7) {
                ForEach(profile.interests.prefix(3), id: \.self) { item in
                    Text(item)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                        .background(CampusTheme.ink.opacity(0.055), in: Capsule())
                }
                Spacer()
            }

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Text("Profilin tamamını gör")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
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
