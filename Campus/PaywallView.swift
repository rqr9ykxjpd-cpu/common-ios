import SwiftUI

/// Common Plus ekranı.
///
/// Tasarım kasıtlı olarak uygulamanın karşılama ekranıyla aynı dilde: editoryal
/// serif başlık, bol boşluk, kart yığını yok. Paywall'lar genelde üst üste
/// yuvarlak kutular, degrade balonlar ve büyük harf pazarlama diliyle yapılıyor;
/// burada bilerek hiçbiri yok.
///
/// Zemin her iki modda da koyu: sınıra Tanış ekranında çarpılıyor ve orası da
/// koyu. Renkler sabit, çünkü uyum sağlayan renkler koyu zeminde okunmaz hale
/// geliyordu (bkz. `CampusTheme.onAccent`).
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    /// Sınıra takılarak açıldıysa başlık ona göre değişiyor.
    var quota: QuotaKind?

    /// Geçici fiyatlar. Gerçekleri App Store Connect'te tanımlanan üründen
    /// okunacak; Apple fiyatı kullanıcının ülkesine göre biçimlendiriyor.
    var plusFiyat = "₺49,99"
    var proFiyat = "₺89,99"

    /// Hakkı biten ücretsiz kullanıcıya iki seçenek birden sunuluyor; birini
    /// gizlemek "acaba diğeri daha mı iyiydi" sorusunu askıda bırakırdı.
    @State private var secili: SubscriptionTier = .plus

    var body: some View {
        ZStack {
            CampusTheme.canvasDark.ignoresSafeArea()
            GrainOverlay().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    kapat
                    baslik
                    karsilastirma
                    ozelKullaniciNotu
                    planSecimi
                    elYazisiNot
                    yasalDipnot
                }
                .padding(.horizontal, 26)
                // Alttaki eylem düğmesi `safeAreaInset` ile duruyor; yasal dipnot
                // ona yapışmasın diye fazladan boşluk.
                .padding(.bottom, 28)
            }
            .safeAreaInset(edge: .bottom) { eylem }
        }
        .preferredColorScheme(.dark)
    }

    private var kapat: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Kapat")
        }
        .padding(.top, 8)
    }

    private var baslik: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("COMMON")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(CampusTheme.acid)

            Text(quota?.title ?? "Kampüs daha\nbüyük olsun.")
                .font(.system(size: 42, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .lineSpacing(2)

            Text(quota?.detail ?? "Ücretsiz kullanmaya devam edebilirsin. Plus ve Pro yalnızca sınırları kaldırıyor.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .lineSpacing(3)
        }
        .padding(.top, 10)
        .padding(.bottom, 34)
    }

    /// Kart değil, tipografik bir karşılaştırma. İki satır, tek fark.
    /// Özellikler ızgara değil, satır satır okunuyor: üstte özelliğin adı,
    /// altında üç kademenin değeri yan yana. Izgara elektronik tablo gibi
    /// duruyordu; bu düzen bir dergi künyesi gibi okunuyor.
    private var karsilastirma: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(PlanFeature.all.enumerated()), id: \.element.id) { indeks, ozellik in
                if indeks > 0 {
                    Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                }
                VStack(alignment: .leading, spacing: 9) {
                    Text(ozellik.label.replacingOccurrences(of: "\n", with: " · "))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(spacing: 18) {
                        ForEach(SubscriptionTier.allCases, id: \.self) { kademe in
                            kademeDegeri(kademe, deger: ozellik.value(kademe))
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .padding(.bottom, 6)
    }

    private func kademeDegeri(_ kademe: SubscriptionTier, deger: String) -> some View {
        let kapali = deger == "—"
        return HStack(spacing: 6) {
            Text(kademe == .free ? "ÜCRETSİZ" : kademe.title.uppercased())
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.35))
            Text(deger)
                .font(.system(size: deger == "∞" ? 17 : 14, weight: .bold, design: .rounded))
                .foregroundStyle(kapali ? .white.opacity(0.25)
                                 : (kademe == .free ? .white.opacity(0.7) : CampusTheme.acid))
        }
    }

    /// Kullanıcının istediği not: veriye erişimin bir karşılığı olduğunu
    /// söylüyor. Turuncu, sayfadaki tek sıcak renk.
    private var ozelKullaniciNotu: some View {
        Text("bu verilere erişmek için özel kullanıcılarımızdan olmalısın")
            .font(.custom("BradleyHandITCTT-Bold", size: 18))
            .foregroundStyle(CampusTheme.coral)
            .rotationEffect(.degrees(-1.2))
            .padding(.top, 18)
            .padding(.bottom, 26)
    }

    /// Plan seçimi. Büyük kartlar yerine iki satır: seçili olan yanıyor.
    private var planSecimi: some View {
        VStack(spacing: 10) {
            planSatiri(.plus, fiyat: plusFiyat, not: nil)
            planSatiri(.pro, fiyat: proFiyat, not: "sınırsız")
        }
        .padding(.bottom, 26)
    }

    private func planSatiri(_ kademe: SubscriptionTier, fiyat: String, not: String?) -> some View {
        let aktif = secili == kademe
        return Button {
            withAnimation(.snappy(duration: 0.18)) { secili = kademe }
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: aktif ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(aktif ? CampusTheme.acid : .white.opacity(0.3))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Common \(kademe.title)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if let not {
                        Text(not)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(fiyat)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ hafta")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .background(aktif ? .white.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(aktif ? CampusTheme.acid.opacity(0.55) : .white.opacity(0.13), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    /// Sayfanın kenarına elle iliştirilmiş bir not gibi. Apple'ın istediği
    /// zorunlu metinlerin arasında değil, kendi başına duruyor.
    private var elYazisiNot: some View {
        Text("merak etme, kimse senin Plus olduğunu bilmeyecek ☺")
            .font(.custom("BradleyHandITCTT-Bold", size: 19))
            .foregroundStyle(CampusTheme.acid.opacity(0.85))
            .rotationEffect(.degrees(-1.5))
            .padding(.bottom, 28)
    }

    /// Apple'ın abonelik ekranlarında zorunlu tuttuğu bilgiler.
    private var yasalDipnot: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Abonelik otomatik yenilenir. Dönem bitmeden en az 24 saat önce iptal etmezsen her hafta yeniden ücretlendirilirsin. İptali App Store hesap ayarlarından yapabilirsin.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .lineSpacing(2)

            HStack(spacing: 14) {
                Button("Satın alımları geri yükle") {}
                Text("·").foregroundStyle(.white.opacity(0.25))
                Button("Koşullar") {}
                Text("·").foregroundStyle(.white.opacity(0.25))
                Button("Gizlilik") {}
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var eylem: some View {
        Button {} label: {
            Text("\(secili.title.uppercased())'A GEÇ")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(CampusTheme.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(CampusTheme.acid, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, 26)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(CampusTheme.canvasDark.opacity(0.94))
    }
}
