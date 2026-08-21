import SwiftUI
import UIKit

/// Profil fotoğrafını dairesel çerçeveye göre konumlandırma ekranı.
///
/// Önceden seçilen fotoğraf olduğu gibi alınıyor ve gösterildiği her yerde
/// `scaledToFill` ile ortadan kırpılıyordu — kadraja göre yüz kenarda kalıyorsa
/// kullanıcının yapabileceği hiçbir şey yoktu. Burada kaydırıp yakınlaştırarak
/// hangi kısmın görüneceğine kendisi karar veriyor.
/// `fullScreenCover(item:)` için sarmalayıcı: `UIImage` kendisi `Identifiable` değil.
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct AvatarCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onConfirm: (Data) -> Void

    /// Kırpma dairesinin ekrandaki çapı.
    private let cropDiameter: CGFloat = UIScreen.main.bounds.width - 56

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isRendering = false

    /// Görselin daireyi tam dolduracak ölçeği. Tüm hesaplar bunun katı olarak yürüyor,
    /// böylece kullanıcı ne yaparsa yapsın dairede boşluk kalmıyor.
    private var baseScale: CGFloat {
        guard image.size.width > 0, image.size.height > 0 else { return 1 }
        return max(cropDiameter / image.size.width, cropDiameter / image.size.height)
    }

    private var displaySize: CGSize {
        CGSize(width: image.size.width * baseScale * scale,
               height: image.size.height * baseScale * scale)
    }

    var body: some View {
        ZStack {
            BondTheme.canvasDark.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: image.size.width * baseScale, height: image.size.height * baseScale)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: cropDiameter, height: cropDiameter)
                        .clipShape(Circle())

                    Circle()
                        .stroke(.white.opacity(0.9), lineWidth: 2)
                        .frame(width: cropDiameter, height: cropDiameter)
                        .allowsHitTesting(false)
                }
                .frame(width: cropDiameter, height: cropDiameter)
                .contentShape(Circle())
                .gesture(dragGesture)
                .simultaneousGesture(zoomGesture)

                Text(L10n.Crop.hint)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 22)

                Spacer(minLength: 0)
                footer
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Button(L10n.Common.cancel, action: onCancel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
            Text(L10n.Crop.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            // Görünmez denge: başlık gerçekten ortada kalsın.
            Text(L10n.Common.cancel)
                .font(.system(size: 15, weight: .semibold))
                .opacity(0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, BondTheme.Space.lg)
        .frame(height: 56)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.impact(.light)
                withAnimation(.snappy) {
                    scale = 1; lastScale = 1
                    offset = .zero; lastOffset = .zero
                }
            } label: {
                Label(L10n.Crop.reset, systemImage: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(PressableStyle())

            PrimaryEditorialButton(title: isRendering ? L10n.Crop.preparing : L10n.Crop.use, enabled: !isRendering, inverted: true) {
                confirm()
            }
        }
        .padding(.horizontal, BondTheme.Space.lg)
        .padding(.bottom, BondTheme.Space.lg)
    }

    // MARK: Hareketler

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in
                withAnimation(.snappy) { offset = clamped(offset) }
                lastOffset = offset
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, 1), 4)
            }
            .onEnded { _ in
                lastScale = scale
                withAnimation(.snappy) { offset = clamped(offset) }
                lastOffset = offset
            }
    }

    /// Daire her zaman dolu kalsın: görsel kenarından içeri kaydırılamıyor.
    private func clamped(_ value: CGSize) -> CGSize {
        let maxX = max((displaySize.width - cropDiameter) / 2, 0)
        let maxY = max((displaySize.height - cropDiameter) / 2, 0)
        return CGSize(width: min(max(value.width, -maxX), maxX),
                      height: min(max(value.height, -maxY), maxY))
    }

    // MARK: Çıktı

    /// Ekrandaki dönüşümü görsel piksellerine çevirip kare bir çıktı üretir.
    ///
    /// Daire maskesi yalnızca gösterim; kaydedilen kare bir görsel ve her yerde
    /// zaten daire olarak kırpılıyor. Kare kaydetmek, ileride köşeli gösterilmesi
    /// gerekirse elin bağlanmasını da önlüyor.
    private func confirm() {
        isRendering = true
        let safeOffset = clamped(offset)
        let totalScale = baseScale * scale

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropDiameter, height: cropDiameter))
        let cropped = renderer.image { _ in
            let drawSize = CGSize(width: image.size.width * totalScale,
                                  height: image.size.height * totalScale)
            let origin = CGPoint(x: (cropDiameter - drawSize.width) / 2 + safeOffset.width,
                                 y: (cropDiameter - drawSize.height) / 2 + safeOffset.height)
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }

        guard let data = cropped.jpegData(compressionQuality: 0.9).flatMap(ImageCompression.prepareForUpload) else {
            isRendering = false
            return
        }
        onConfirm(data)
    }
}
