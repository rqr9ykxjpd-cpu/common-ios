import SwiftUI
import UIKit

enum MediaKind {
    case avatar, content
    var emptySymbol: String { self == .avatar ? "person.fill" : "photo" }
    var emptyLabel: String { self == .avatar ? L10n.ScreenStates.photoMissing : L10n.ScreenStates.imageMissing }
    var failureLabel: String { self == .avatar ? L10n.ScreenStates.photoFailed : L10n.ScreenStates.imageFailed }
    var loadingLabel: String { self == .avatar ? L10n.ScreenStates.photoLoading : L10n.ScreenStates.imageLoading }
    var displayDimension: CGFloat {
        self == .avatar ? ImageCompression.avatarDimension : ImageCompression.maxDimension
    }
}

struct ProfileMedia: View {
    let url: URL?
    let data: Data?
    var assetName: String? = nil
    var kind: MediaKind = .avatar
    var showsRetry = false
    var contentMode: ContentMode = .fill
    var onImageSize: (@MainActor @Sendable (CGSize?) -> Void)? = nil

    nonisolated init(url: URL?, data: Data?, assetName: String? = nil,
                     kind: MediaKind = .avatar, showsRetry: Bool = false,
                     contentMode: ContentMode = .fill,
                     onImageSize: (@MainActor @Sendable (CGSize?) -> Void)? = nil) {
        self.url = url; self.data = data; self.assetName = assetName
        self.kind = kind; self.showsRetry = showsRetry
        self.contentMode = contentMode; self.onImageSize = onImageSize
    }

    var body: some View {
        Group {
            if data != nil || assetName != nil {
                DecodedProfileImage(
                    data: data,
                    assetName: assetName,
                    kind: kind,
                    contentMode: contentMode
                )
            } else if let url {
                // Include the signed URL's query: renewed credentials must restart
                // a failed request even when the underlying cache path is identical.
                RemoteProfileImage(url: url, kind: kind, showsRetry: showsRetry, contentMode: contentMode, onImageSize: onImageSize)
                    .id(url)
            } else {
                MediaPlaceholder(kind: kind, failed: false)
            }
        }
        .clipped()
    }
}

private struct DecodedProfileImage: View {
    let data: Data?
    let assetName: String?
    let kind: MediaKind
    let contentMode: ContentMode
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else if failed {
                MediaPlaceholder(kind: kind, failed: true)
            } else {
                BondTheme.surface
            }
        }
        .task(id: identity) {
            // Çözme ve küçültme arka planda: görünümün görevi ana iş parçacığında
            // çalışıyor, kaydırırken yerel fotoğraflı her kart bir kare takıyordu.
            let veri = data, ad = assetName, boyut = kind.displayDimension
            let hazir = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                if let veri {
                    return ImageCompression.imageForDisplay(veri, maxDimension: boyut).map(BondImageLoader.readyForScreen)
                }
                if let ad, let loaded = UIImage(named: ad) {
                    return BondImageLoader.readyForScreen(ImageCompression.capped(loaded, maxDimension: boyut))
                }
                return nil
            }.value
            guard !Task.isCancelled else { return }
            image = hazir
            failed = hazir == nil
        }
    }

    private var identity: String {
        if let data {
            return "d-\(data.count)-\(data.first ?? 0)-\(data.last ?? 0)-\(kind.displayDimension)"
        }
        return "a-\(assetName ?? "")-\(kind.displayDimension)"
    }
}

private struct MediaPlaceholder: View {
    let kind: MediaKind
    var failed = false
    var retry: (() -> Void)?

    var body: some View {
        BondTheme.surface.overlay {
            VStack(spacing: 8) {
                Image(systemName: failed ? "exclamationmark.circle" : kind.emptySymbol)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(failed ? kind.failureLabel : kind.emptyLabel)
                if let retry {
                    Text(kind.failureLabel).font(.callout).multilineTextAlignment(.center)
                    Button(L10n.Common.retry, action: retry)
                        .buttonStyle(.secondaryCapsule)
                }
            }
            .foregroundStyle(BondTheme.ink)
            .padding(8)
        }
    }
}

private struct RemoteProfileImage: View {
    @Environment(AppState.self) private var appState
    let url: URL
    let kind: MediaKind
    let showsRetry: Bool
    let contentMode: ContentMode
    let onImageSize: (@MainActor @Sendable (CGSize?) -> Void)?
    @State private var image: UIImage?
    @State private var finished = false
    @State private var attempt = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else if !finished {
                // Çark yerine ışıltılı iskelet: ekran "donmuş" değil "geliyor" der.
                ShimmerPlaceholder()
                    .accessibilityLabel(kind.loadingLabel)
            } else {
                MediaPlaceholder(kind: kind, failed: true,
                                 retry: showsRetry ? { attempt += 1 } : nil)
            }
        }
        .task(id: attempt) {
            if attempt > 0 {
                image = nil
                finished = false
                onImageSize?(nil)
            }
            let basladi = Date()
            let loaded = await appState.remoteImage(for: url, maxDimension: kind.displayDimension)
            guard !Task.isCancelled else { return }
            // Bellekten anında gelen görsel solarak girmesin: kaydırırken her kart
            // yanıp söner. Yalnızca gerçekten beklenen görsel yumuşakça belirir.
            let beklendi = Date().timeIntervalSince(basladi) > 0.06
            withAnimation(beklendi && !reduceMotion ? .easeOut(duration: 0.28) : nil) {
                image = loaded
                finished = true
            }
            onImageSize?(loaded?.size)
        }
        .onDisappear {
            guard kind == .content else { return }
            image = nil
            finished = false
        }
    }
}


/// Görsel yüklenirken yüzeyin üstünden geçen yumuşak ışık. Hareket azaltmada
/// ve Düşük Güç Modu'nda durağan.
///
/// Önceden SwiftUI'da her karede yeniden çiziliyordu; kaydırırken ekranda
/// birkaç tane olunca ana iş parçacığı her karede bunlarla uğraşıyordu. Artık
/// ışık Core Animation'da kayıyor, uygulama karelerde hiçbir şey yapmıyor.
struct ShimmerPlaceholder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        BondTheme.surface
            .overlay {
                if IdleMotion.allowed(reduceMotion: reduceMotion) {
                    ShimmerSweep()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .clipped()
    }
}

private struct ShimmerSweep: UIViewRepresentable {
    func makeUIView(context: Context) -> ShimmerSweepView { ShimmerSweepView() }
    func updateUIView(_ view: ShimmerSweepView, context: Context) {}
}

final class ShimmerSweepView: UIView {
    private let band = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true
        band.colors = [UIColor.white.withAlphaComponent(0).cgColor,
                       UIColor.white.withAlphaComponent(0.35).cgColor,
                       UIColor.white.withAlphaComponent(0).cgColor]
        band.startPoint = CGPoint(x: 0, y: 0.5)
        band.endPoint = CGPoint(x: 1, y: 0.5)
        band.compositingFilter = "plusL"
        layer.addSublayer(band)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    private var kurulanBoyut: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        // Kaydırırken yerleşim sık çağrılıyor; animasyon yalnızca boyut
        // değişince baştan kurulur.
        guard bounds.size != kurulanBoyut else { return }
        kurulanBoyut = bounds.size
        let genislik = bounds.width * 0.6
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        band.frame = CGRect(x: 0, y: 0, width: genislik, height: bounds.height)
        CATransaction.commit()
        restartAnimation()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Arka plandan dönünce sistem animasyonu kaldırmış olabilir.
        if band.animation(forKey: "kay") == nil { restartAnimation() }
    }

    private func restartAnimation() {
        band.removeAnimation(forKey: "kay")
        guard window != nil, bounds.width > 1 else { return }
        let genislik = bounds.width * 0.6
        let kay = CABasicAnimation(keyPath: "position.x")
        kay.fromValue = -genislik / 2 - bounds.width * 0.4
        kay.toValue = bounds.width * 1.4 + genislik / 2
        kay.duration = 1.25
        kay.repeatCount = .infinity
        kay.isRemovedOnCompletion = false
        band.add(kay, forKey: "kay")
    }
}
