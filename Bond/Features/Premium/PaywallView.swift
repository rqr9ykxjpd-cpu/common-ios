import SwiftUI

/// Bond Plus ekranı.
///
/// Tasarım kasıtlı olarak uygulamanın karşılama ekranıyla aynı dilde: editoryal
/// serif başlık, bol boşluk, kart yığını yok. Paywall'lar genelde üst üste
/// yuvarlak kutular, degrade balonlar ve büyük harf pazarlama diliyle yapılıyor;
/// burada bilerek hiçbiri yok.
///
/// Zemin her iki modda da koyu: sınıra Tanış ekranında çarpılıyor ve orası da
/// koyu. Renkler sabit, çünkü uyum sağlayan renkler koyu zeminde okunmaz hale
/// geliyordu (bkz. `BondTheme.onAccent`).
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    /// Sınıra takılarak açıldıysa başlık ona göre değişiyor.
    var quota: QuotaKind?

    /// Ürün yüklenene kadar gösterilecek fiyatlar. Gerçek fiyat App Store'dan
    /// geliyor: Apple kullanıcının ülkesine ve para birimine göre biçimlendiriyor,
    /// ayrıca fiyatı biz değiştirsek bile burası kendiliğinden doğru kalıyor.
    var plusFiyat = "₺59,99"
    var proFiyat = "₺299,99"

    private var magaza: SubscriptionStore { appState.subscriptions }

    /// Satın alma sonucuna göre kullanıcıya söylenecek söz.
    @State private var uyari: String?

    /// Hakkı biten ücretsiz kullanıcıya iki seçenek birden sunuluyor; birini
    /// gizlemek "acaba diğeri daha mı iyiydi" sorusunu askıda bırakırdı.
    @State private var secili: SubscriptionTier = .plus

    /// Dipnottaki koşullar/gizlilik bağlantıları için. Apple abonelik
    /// ekranında bu iki metnin okunabilir olmasını şart koşuyor.
    @State private var legalDocument: LegalDocumentRoute?

    var body: some View {
        ZStack {
            BondTheme.canvasDark.ignoresSafeArea()
            GrainOverlay().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    kapat
                    baslik
                    karsilastirma
                    ozelKullaniciNotu
                    planSecimi
                    elYazisiNot
                }
                .padding(.horizontal, 26)
                // Alttaki eylem düğmesi `safeAreaInset` ile duruyor; yasal dipnot
                // ona yapışmasın diye fazladan boşluk.
                .padding(.bottom, 28)
            }
            .safeAreaInset(edge: .bottom) { eylem }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $legalDocument) { belge in
            NavigationStack {
                LegalTextView(title: belge.title, blocks: belge.blocks)
            }
        }
        .task { await magaza.loadProducts() }
        .alert(L10n.Paywall.problem, isPresented: Binding(get: { uyari != nil }, set: { if !$0 { uyari = nil } })) {
            Button(L10n.Common.ok, role: .cancel) { uyari = nil }
        } message: {
            Text(uyari ?? "")
        }
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
            .accessibilityLabel(L10n.Common.close)
        }
        .padding(.top, 8)
    }

    private var baslik: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Paywall.brand)
                .font(.system(size: 11, weight: .black))
                .tracking(2)
                .foregroundStyle(BondTheme.acid)

            // Tek satır ve alt açıklama yok: her şeyin tek ekrana sığması için
            // en pahalı yer başlıktı.
            Text(quota?.title.replacingOccurrences(of: "\n", with: " ") ?? L10n.Paywall.headline)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.bottom, 10)
    }

    /// Üç kademeyi yan yana gösteren tablo. Kart yığını değil, gazete tablosu
    /// gibi: ince ayraçlar, sakin tipografi. Satırlar `PlanFeature.all`'dan
    /// geliyor — kuralı değiştirince tablo kendiliğinden güncelleniyor.
    private var karsilastirma: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(SubscriptionTier.allCases, id: \.self) { kademe in
                    Text(paywallColumnTitle(kademe))
                        .font(.system(size: 9, weight: .black))
                        .tracking(0.6)
                        .foregroundStyle(kademe == .free ? .white.opacity(0.4) : BondTheme.acid)
                        .frame(width: sutunGenisligi)
                }
            }
            .padding(.bottom, 8)

            ForEach(Array(PlanFeature.all.enumerated()), id: \.element.id) { indeks, ozellik in
                if indeks > 0 {
                    Rectangle().fill(.white.opacity(0.09)).frame(height: 1)
                }
                HStack(spacing: 0) {
                    Text(ozellik.label.replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 12.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(SubscriptionTier.allCases, id: \.self) { kademe in
                        hucre(ozellik.value(kademe), kademe: kademe)
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .padding(.bottom, 4)
    }

    private var sutunGenisligi: CGFloat { 62 }

    private func paywallColumnTitle(_ kademe: SubscriptionTier) -> String {
        switch kademe {
        case .free: L10n.Paywall.free
        case .plus: L10n.Paywall.plus
        case .pro: L10n.Paywall.pro
        }
    }

    private func hucre(_ metin: String, kademe: SubscriptionTier) -> some View {
        let bos = metin == "—"
        return Text(metin)
            .font(.system(size: metin == "∞" ? 20 : 15,
                          weight: .bold,
                          design: metin == "✓" || metin == "—" ? .rounded : .serif))
            .foregroundStyle(bos ? .white.opacity(0.22)
                             : (kademe == .free ? .white.opacity(0.62) : BondTheme.acid))
            .frame(width: sutunGenisligi)
    }

    /// Kullanıcının istediği not: veriye erişimin bir karşılığı olduğunu
    /// söylüyor. Turuncu, sayfadaki tek sıcak renk — göz doğrudan buraya gidiyor.
    private var ozelKullaniciNotu: some View {
        Text(L10n.Paywall.specialNote)
            .font(.custom("BradleyHandITCTT-Bold", size: 16))
            .foregroundStyle(BondTheme.coral)
            .lineSpacing(2)
            .rotationEffect(.degrees(-1.2))
            .padding(.top, 6)
            .padding(.bottom, 10)
    }

    /// Plan seçimi. Büyük kartlar yerine iki satır: seçili olan yanıyor.
    private var planSecimi: some View {
        VStack(spacing: 8) {
            planSatiri(.plus, fiyat: magaza.displayPrice(for: .plus) ?? plusFiyat, not: nil)
            planSatiri(.pro, fiyat: magaza.displayPrice(for: .pro) ?? proFiyat, not: L10n.Paywall.unlimited)
        }
        .padding(.bottom, 10)
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
                    .foregroundStyle(aktif ? BondTheme.acid : .white.opacity(0.3))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Paywall.planName(kademe.title))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    if let not {
                        Text(not)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(fiyat)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                    Text(L10n.Paywall.perWeek)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(aktif ? .white.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(aktif ? BondTheme.acid.opacity(0.55) : .white.opacity(0.13), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    /// Sayfanın kenarına elle iliştirilmiş bir not gibi. Apple'ın istediği
    /// zorunlu metinlerin arasında değil, kendi başına duruyor.
    private var elYazisiNot: some View {
        // Tek satıra sıkıştırılıyor: sayfanın tamamı kaydırmadan görünsün diye
        // metni kısaltmak yerine ölçeği düşürüyoruz, cümle aynen kalıyor.
        Text(L10n.Paywall.handNote)
            .font(.custom("BradleyHandITCTT-Bold", size: 16))
            .foregroundStyle(BondTheme.acid.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .rotationEffect(.degrees(-1.5))
            .padding(.top, 2)
            .padding(.bottom, 6)
    }

    /// Apple'ın abonelik ekranlarında zorunlu tuttuğu bilgiler.
    private var yasalDipnot: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Paywall.legal)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .lineSpacing(2)

            HStack(spacing: 12) {
                Button(magaza.isRestoring ? L10n.Paywall.restoring : L10n.Paywall.restore) {
                    Task { await geriYukle() }
                }
                .disabled(magaza.isRestoring)
                Text("·").foregroundStyle(.white.opacity(0.25))
                Button(L10n.Paywall.terms) { legalDocument = .kosullar }
                Text("·").foregroundStyle(.white.opacity(0.25))
                Button(L10n.Paywall.privacy) { legalDocument = .gizlilik }
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var eylem: some View {
        VStack(spacing: 10) {
            // Ürünler gelmediyse sebebini söylüyoruz. Sessizce sönük duran bir
            // düğme, kullanıcıya "uygulama bozuk" dedirtiyor; oysa sorun çoğu
            // zaman geçici ve kendisi çözebiliyor.
            if let hata = magaza.productLoadFailure, magaza.products.isEmpty, !magaza.canPurchase(secili) {
                Text(hata)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BondTheme.coral)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            eylemDugmesi
            yasalDipnot
        }
        .padding(.horizontal, 26)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(BondTheme.canvasDark.opacity(0.97))
    }

    private var eylemDugmesi: some View {
        let calisiyor = magaza.purchasingTier != nil
        // Ürün gelmediyse düğme açılmıyor. Dokununca hiçbir şey olmayan bir
        // düğme, kullanıcıya uygulamanın bozuk olduğunu düşündürür.
        let hazir = magaza.canPurchase(secili) && !calisiyor && !magaza.isRestoring
        return Button {
            Task { await satinAl() }
        } label: {
            ZStack {
                if calisiyor {
                    ProgressView().tint(BondTheme.onAccent)
                } else {
                    Text(secili == .plus ? L10n.Paywall.goPlus : L10n.Paywall.goPro)
                        .font(.system(size: 13, weight: .black))
                        .tracking(1.2)
                }
            }
            .foregroundStyle(BondTheme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(BondTheme.acid.opacity(hazir ? 1 : 0.35), in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(!hazir)
    }

    private func satinAl() async {
        switch await magaza.purchase(secili) {
        case .success:
            Haptics.success()
            dismiss()
        case .cancelled:
            break
        case .pending:
            uyari = L10n.Paywall.pending
        case .failed(let mesaj):
            uyari = mesaj
        }
    }

    private func geriYukle() async {
        if let mesaj = await magaza.restore() {
            uyari = mesaj
        } else {
            Haptics.success()
            dismiss()
        }
    }
}
