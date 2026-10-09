import SwiftUI
import UIKit

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
///
/// Halka Core Animation'da: SwiftUI'daki sonsuz animasyon her karede görünüm
/// ağacını güncelliyordu; Kim nerede boşta beklerken uygulama sürekli işlemci
/// harcıyordu. Artık hareketi sistem yapıyor.
struct LiveDot: View {
    var size: CGFloat = 7
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(IdleMotion.liveGreen)
            .frame(width: size, height: size)
            .background {
                LivePulse(moving: IdleMotion.allowed(reduceMotion: reduceMotion))
                    .frame(width: size, height: size)
            }
            .accessibilityHidden(true)
    }
}

private struct LivePulse: UIViewRepresentable {
    let moving: Bool

    func makeUIView(context: Context) -> LivePulseView { LivePulseView() }
    func updateUIView(_ view: LivePulseView, context: Context) { view.moving = moving }
}

final class LivePulseView: UIView {
    private let halo = CAShapeLayer()

    var moving = true {
        didSet { if moving != oldValue { updateAnimation() } }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = false
        layer.addSublayer(halo)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        halo.frame = bounds
        halo.path = UIBezierPath(ovalIn: bounds).cgPath
        halo.fillColor = UIColor.systemGreen.withAlphaComponent(0.35).resolvedColor(with: traitCollection).cgColor
        CATransaction.commit()
        updateAnimation()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateAnimation()
    }

    private func updateAnimation() {
        guard moving, window != nil, bounds.width > 0 else {
            halo.removeAnimation(forKey: "nabiz")
            halo.opacity = moving ? 1 : 0
            return
        }
        halo.opacity = 0
        guard halo.animation(forKey: "nabiz") == nil else { return }
        let buyume = CABasicAnimation(keyPath: "transform.scale")
        buyume.fromValue = 1
        buyume.toValue = 2.6
        let sonme = CABasicAnimation(keyPath: "opacity")
        sonme.fromValue = 1
        sonme.toValue = 0
        let nabiz = CAAnimationGroup()
        nabiz.animations = [buyume, sonme]
        nabiz.duration = 2.4
        nabiz.timingFunction = CAMediaTimingFunction(name: .easeOut)
        nabiz.repeatCount = .infinity
        nabiz.isRemovedOnCompletion = false
        halo.add(nabiz, forKey: "nabiz")
    }
}

// MARK: - Hikâye halkasındaki ışık

/// İzlenmemiş hikâye halkasının üstünde ~8 saniyede bir tur dönen ince ışık.
/// Dönüş Core Animation'da (bkz. `LiveDot`); akışta birkaç halka aynı anda
/// dönerken uygulama her karede çalışmıyor.
struct RingGlint: View {
    var lineWidth: CGFloat = 3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if IdleMotion.allowed(reduceMotion: reduceMotion) {
            RingGlintLayer(lineWidth: lineWidth)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct RingGlintLayer: UIViewRepresentable {
    let lineWidth: CGFloat

    func makeUIView(context: Context) -> RingGlintView { RingGlintView() }
    func updateUIView(_ view: RingGlintView, context: Context) { view.lineWidth = lineWidth }
}

final class RingGlintView: UIView {
    private let gradient = CAGradientLayer()
    private let ring = CAShapeLayer()

    var lineWidth: CGFloat = 3 {
        didSet { if lineWidth != oldValue { setNeedsLayout() } }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        gradient.type = .conic
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        // 0–70°: saydam → beyaz → saydam; turun geri kalanı boş.
        gradient.colors = [UIColor.white.withAlphaComponent(0), UIColor.white.withAlphaComponent(0.85),
                           UIColor.white.withAlphaComponent(0), UIColor.white.withAlphaComponent(0)].map(\.cgColor)
        gradient.locations = [0, NSNumber(value: 35.0 / 360), NSNumber(value: 70.0 / 360), 1]
        layer.addSublayer(gradient)
        ring.fillColor = nil
        ring.strokeColor = UIColor.black.cgColor
        // Halka dönmez; altındaki ışık döner.
        layer.mask = ring
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        ring.frame = bounds
        ring.lineWidth = lineWidth
        ring.path = UIBezierPath(ovalIn: bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)).cgPath
        CATransaction.commit()
        addSpinIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        addSpinIfNeeded()
    }

    private func addSpinIfNeeded() {
        guard window != nil, gradient.animation(forKey: "donus") == nil else { return }
        let donus = CABasicAnimation(keyPath: "transform.rotation.z")
        donus.fromValue = 0
        donus.toValue = CGFloat.pi * 2
        donus.duration = 8
        donus.repeatCount = .infinity
        donus.isRemovedOnCompletion = false
        gradient.add(donus, forKey: "donus")
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
