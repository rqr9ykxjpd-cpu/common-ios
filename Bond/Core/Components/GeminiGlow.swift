import SwiftUI
import UIKit
import CoreImage

/// Gemini / Siri ışığı: şeklin çevresinde mavi, mor, kırmızı ve sarı arasında
/// dönen yumuşak ışık; ışık nefes alır. Common'un gönderisi
/// (`OfficialPostFrame`) ve Kim nerede'deki Kulüpler düğmesi.
/// Kartın arkasına konur; kartın kendi zemini üstte olmalı.
///
/// Önceki sürüm SwiftUI'da saniyede 30 kez baştan çiziliyordu (iki büyük
/// bulanıklaştırma dahil); ekranda dururken uygulama işlemcinin üçte birini
/// yiyordu, telefon kasıyordu. Artık bulanık halka boyut başına bir kez
/// çiziliyor, dönme ve nefes Core Animation'da: uygulama her karede hiçbir
/// şey yapmıyor. Hareketi Azalt ya da Düşük Güç Modu'nda ışık durur.
struct GeminiGlow: UIViewRepresentable {
    let cornerRadius: CGFloat
    /// Işığın yayıldığı mesafe: gönderide 1, küçük düğmede daha az.
    var spread: CGFloat = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    func makeUIView(context: Context) -> GeminiGlowView { GeminiGlowView() }

    func updateUIView(_ view: GeminiGlowView, context: Context) {
        view.configure(
            cornerRadius: cornerRadius,
            spread: spread,
            dark: colorScheme == .dark,
            moving: IdleMotion.allowed(reduceMotion: reduceMotion)
        )
    }
}

final class GeminiGlowView: UIView {
    /// Renklerin şeklin etrafında bir tur dönmesi.
    private static let spin: CFTimeInterval = 6
    /// Nefesin yarısı (sönme ya da parlama).
    private static let breath: CFTimeInterval = 2

    private static let colors: [CGColor] = ["4285F4", "9B72CB", "EA4335", "FBBC04", "4285F4"]
        .map { UIColor(Color(hex: $0)).cgColor }

    private let gradient = CAGradientLayer()
    private let ring = CALayer()
    private var cornerRadius: CGFloat = 22
    private var spread: CGFloat = 1
    private var dark = false
    private var moving = true
    private var ringKey = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        clipsToBounds = false
        gradient.type = .conic
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        gradient.colors = Self.colors
        layer.addSublayer(gradient)
        // Maske dönmez; yalnızca altındaki renkler döner.
        layer.mask = ring
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    func configure(cornerRadius: CGFloat, spread: CGFloat, dark: Bool, moving: Bool) {
        let degisti = cornerRadius != self.cornerRadius || spread != self.spread || dark != self.dark
        self.cornerRadius = cornerRadius
        self.spread = spread
        self.dark = dark
        if moving != self.moving {
            self.moving = moving
            updateAnimations()
        }
        if degisti { setNeedsLayout() }
    }

    /// Işığın kartın dışına taştığı pay (bulanıklığın kuyruğu dahil).
    private var margin: CGFloat { 56 * spread }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 1, bounds.height > 1 else { return }
        let alan = bounds.insetBy(dx: -margin, dy: -margin)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let kenar = hypot(alan.width, alan.height)
        gradient.bounds = CGRect(x: 0, y: 0, width: kenar, height: kenar)
        gradient.position = CGPoint(x: bounds.midX, y: bounds.midY)
        ring.frame = alan
        let anahtar = "\(Int(bounds.width))x\(Int(bounds.height))-\(cornerRadius)-\(spread)-\(dark)"
        if anahtar != ringKey {
            ringKey = anahtar
            ring.contents = Self.ringImage(size: bounds.size, margin: margin, cornerRadius: cornerRadius,
                                           spread: spread, dark: dark, key: anahtar)
        }
        CATransaction.commit()
        updateAnimations()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Uygulama arka plana gidip dönünce sistem animasyonları kaldırabiliyor.
        updateAnimations()
    }

    private func updateAnimations() {
        guard moving, window != nil else {
            gradient.removeAnimation(forKey: "donus")
            layer.removeAnimation(forKey: "nefes")
            layer.opacity = 1
            return
        }
        if gradient.animation(forKey: "donus") == nil {
            let donus = CABasicAnimation(keyPath: "transform.rotation.z")
            donus.fromValue = 0
            donus.toValue = CGFloat.pi * 2
            donus.duration = Self.spin
            donus.repeatCount = .infinity
            donus.isRemovedOnCompletion = false
            gradient.add(donus, forKey: "donus")
        }
        if layer.animation(forKey: "nefes") == nil {
            let nefes = CABasicAnimation(keyPath: "opacity")
            nefes.fromValue = 0.72
            nefes.toValue = 1
            nefes.duration = Self.breath
            nefes.autoreverses = true
            nefes.repeatCount = .infinity
            nefes.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            nefes.isRemovedOnCompletion = false
            layer.add(nefes, forKey: "nefes")
        }
    }

    // MARK: - Bulanık halka (maske)

    private static let context = CIContext(options: [.cacheIntermediates: false])
    private static let cache = NSCache<NSString, CGImage>()

    /// Kartın çevresindeki ışığın biçimi: geniş, dağınık bir hâle ve kenara
    /// yakın daha canlı bir çizgi. Ekran ölçeğinde değil 1×'te çiziliyor;
    /// zaten bulanık, keskinliğe gerek yok.
    private static func ringImage(size: CGSize, margin: CGFloat, cornerRadius: CGFloat,
                                  spread: CGFloat, dark: Bool, key: String) -> CGImage? {
        if let hazir = cache.object(forKey: key as NSString) { return hazir }
        let tuval = CGSize(width: size.width + margin * 2, height: size.height + margin * 2)
        let kart = CGRect(origin: CGPoint(x: margin, y: margin), size: size)

        let genis = katman(tuval: tuval, blur: 24 * spread) {
            let alan = kart.insetBy(dx: -10 * spread, dy: -10 * spread)
            let yol = UIBezierPath(roundedRect: alan, cornerRadius: cornerRadius + 8 * spread)
            UIColor(white: 1, alpha: dark ? 0.65 : 0.6).setFill()
            yol.fill()
        }
        let kenar = katman(tuval: tuval, blur: 8 * spread) {
            let cizgi = 8 * spread
            let alan = kart.insetBy(dx: cizgi / 2, dy: cizgi / 2)
            let yol = UIBezierPath(roundedRect: alan, cornerRadius: max(0, cornerRadius - cizgi / 2))
            yol.lineWidth = cizgi
            UIColor(white: 1, alpha: dark ? 0.8 : 0.7).setStroke()
            yol.stroke()
        }
        guard let genis, let kenar else { return nil }
        let birlesik = kenar.composited(over: genis)
        guard let sonuc = context.createCGImage(birlesik, from: CGRect(origin: .zero, size: tuval)) else { return nil }
        cache.setObject(sonuc, forKey: key as NSString)
        return sonuc
    }

    private static func katman(tuval: CGSize, blur: CGFloat, ciz: () -> Void) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let resim = UIGraphicsImageRenderer(size: tuval, format: format).image { _ in ciz() }
        guard let cg = resim.cgImage else { return nil }
        let kaynak = CIImage(cgImage: cg)
        return kaynak
            .clampedToExtent()
            // SwiftUI'daki `.blur(radius:)` ile aynı yayılım: sigma yarıçapın yarısı.
            .applyingGaussianBlur(sigma: Double(blur) / 2)
            .cropped(to: kaynak.extent)
    }
}
