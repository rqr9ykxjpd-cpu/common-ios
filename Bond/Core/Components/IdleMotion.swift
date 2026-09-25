import SwiftUI

/// Kullanıcı ekrana dokunmazken çalışan hafif hareketlerin ortak kuralı.
///
/// Hepsi yalnızca ekrandayken çalışıyor (`.task` görünüm kaybolunca iptal
/// oluyor), yalnızca dönüşüm ve opaklık kullanıyor; bütün ekranı yeniden
/// çizmiyor. "Hareketi Azalt" ya da Düşük Güç Modu açıkken hiç başlamıyor.
enum IdleMotion {
    static func allowed(reduceMotion: Bool) -> Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    /// "Şu an burada" yeşili. Tasarım dosyası başka bir işte düzenlendiği için
    /// burada; sistem yeşili iki modda da okunuyor.
    static let liveGreen = Color(uiColor: .systemGreen)
}

// MARK: - Süzülme

/// Boş ekrandaki simge çok yavaşça yukarı aşağı süzülür (±3 pt, ~3,5 sn).
private struct IdleFloat: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var running = false
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: running ? (up ? -3 : 3) : 0)
            .task {
                guard IdleMotion.allowed(reduceMotion: reduceMotion) else { return }
                running = true
                withAnimation(.easeInOut(duration: 1.75).repeatForever(autoreverses: true)) { up = true }
            }
    }
}

extension View {
    func idleFloat() -> some View { modifier(IdleFloat()) }
}

// MARK: - Canlı nokta

/// Şu an bir yerde kişi varken yanında duran yeşil nokta; etrafından yavaşça
/// genişleyip sönen bir halka yayılır (~2,4 sn).
struct LiveDot: View {
    var size: CGFloat = 7
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(IdleMotion.liveGreen)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(IdleMotion.liveGreen.opacity(0.35))
                    .scaleEffect(pulse ? 2.6 : 1)
                    .opacity(pulse ? 0 : 1)
            }
            .task {
                guard IdleMotion.allowed(reduceMotion: reduceMotion) else { return }
                withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) { pulse = true }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Hikâye halkasındaki ışık

/// İzlenmemiş hikâye halkasının üstünde ~8 saniyede bir tur dönen ince ışık.
struct RingGlint: View {
    var lineWidth: CGFloat = 3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var running = false
    @State private var spin = false

    var body: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [.white.opacity(0), .white.opacity(0.85), .white.opacity(0)],
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(70)
                ),
                lineWidth: lineWidth
            )
            .rotationEffect(.degrees(spin ? 360 : 0))
            .opacity(running ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                guard IdleMotion.allowed(reduceMotion: reduceMotion) else { return }
                running = true
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { spin = true }
            }
    }
}

// MARK: - Yaklaşan başlangıç halkası

/// Çalışma grubunun başlamasına 60 dakikadan az kalınca ev sahibinin
/// fotoğrafının etrafında zamanla dolan halka; son 10 dakikada hafifçe atar.
/// 30 saniyede bir güncelleniyor, saniye saniye değil.
struct StartCountdownRing: View {
    let startsAt: Date
    var diameter: CGFloat = 48
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beat = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let kalan = startsAt.timeIntervalSince(context.date)
            if kalan > 0, kalan <= 3600 {
                let dolu = 1 - kalan / 3600
                let sonDakikalar = kalan <= 600
                ZStack {
                    // Çizgi dairenin içinde kalsın; dışa taşan yarısı kesiliyordu.
                    Circle().inset(by: 1.25).stroke(BondTheme.burntOrange.opacity(0.18), lineWidth: 2.5)
                    Circle()
                        .inset(by: 1.25)
                        .trim(from: 0, to: dolu)
                        .stroke(BondTheme.burntOrange, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .smooth(duration: 0.8), value: dolu)
                }
                .frame(width: diameter, height: diameter)
                .scaleEffect(sonDakikalar && beat ? 1.07 : 1)
                .task(id: sonDakikalar) {
                    guard sonDakikalar, IdleMotion.allowed(reduceMotion: reduceMotion) else {
                        beat = false
                        return
                    }
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { beat = true }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
