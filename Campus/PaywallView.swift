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

    /// Geçici. Gerçek fiyat App Store Connect'te tanımlanan üründen okunacak;
    /// Apple fiyatı kullanıcının ülkesine göre biçimlendiriyor.
    var haftalikFiyat = "₺49,99"

    var body: some View {
        ZStack {
            CampusTheme.canvasDark.ignoresSafeArea()
            GrainOverlay().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    kapat
                    baslik
                    karsilastirma
                    fiyat
                    elYazisiNot
                    yasalDipnot
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 32)
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
            Text("COMMON PLUS")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(CampusTheme.acid)

            Text("Beş kişi\nyetmiyorsa.")
                .font(.system(size: 42, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .lineSpacing(2)

            Text("Tanış'ta iki günde bir yenilenen hakkın var. Plus ile bu hak iki katına çıkıyor.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .lineSpacing(3)
        }
        .padding(.top, 10)
        .padding(.bottom, 34)
    }

    /// Kart değil, tipografik bir karşılaştırma. İki satır, tek fark.
    private var karsilastirma: some View {
        VStack(spacing: 0) {
            satir(ad: "Ücretsiz", deger: "5 kişi", vurgulu: false)
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
            satir(ad: "Plus", deger: "10 kişi", vurgulu: true)
        }
        .padding(.bottom, 30)
    }

    private func satir(ad: String, deger: String, vurgulu: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(ad)
                .font(.system(size: 16, weight: vurgulu ? .bold : .regular, design: .rounded))
                .foregroundStyle(vurgulu ? .white : .white.opacity(0.55))
            Spacer()
            Text(deger)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(vurgulu ? CampusTheme.acid : .white.opacity(0.55))
            Text("/ 2 gün")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.vertical, 18)
    }

    private var fiyat: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            // Serif yazı tipi ₺ işaretini "Ł"ye benzeyen bir biçimde çiziyor;
            // doğru karakter ama fiyatta yanlış okunuyor. Yuvarlak yüzde
            // alışıldık biçimde görünüyor.
            Text(haftalikFiyat)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("/ hafta")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.bottom, 26)
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
            Text("PLUS'A GEÇ")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(CampusTheme.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(CampusTheme.acid, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, 26)
        .padding(.bottom, 10)
        .background(CampusTheme.canvasDark.opacity(0.94))
    }
}
