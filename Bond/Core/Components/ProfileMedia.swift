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
            if let data {
                image = ImageCompression.imageForDisplay(data, maxDimension: kind.displayDimension)
            } else if let assetName, let loaded = UIImage(named: assetName) {
                image = ImageCompression.capped(loaded, maxDimension: kind.displayDimension)
            }
            failed = image == nil
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
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
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


/// Görsel yüklenirken yüzeyin üstünden geçen yumuşak ışık. Hareket azaltmada durağan.
struct ShimmerPlaceholder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var faz: CGFloat = -1

    var body: some View {
        BondTheme.surface
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.35), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: faz * geo.size.width * 1.4)
                        .blendMode(.plusLighter)
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) { faz = 1 }
            }
    }
}
