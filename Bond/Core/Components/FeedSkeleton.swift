import SwiftUI

/// Akış ilk kez yüklenirken gönderi kartlarının iskeleti.
///
/// Eskiden ortada dönen bir yükleyici vardı; ekranın ne olacağını söylemiyordu
/// ve içerik gelince her şey birden yerine sıçrıyordu. İskelet `PostCard` ile
/// aynı ölçülerde: başlık satırı, metin, görsel alanı, eylem satırı.
struct FeedSkeleton: View {
    var count = 3

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                card(withImage: index != 1)
                if index < count - 1 {
                    Divider().opacity(0.35).padding(.vertical, 14)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Feed.loading)
    }

    private func card(withImage: Bool) -> some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.md) {
            HStack(spacing: BondTheme.Space.compact) {
                Skeleton(height: 40, cornerRadius: 20).frame(width: 40)
                VStack(alignment: .leading, spacing: 6) {
                    Skeleton(height: 13).frame(width: 110)
                    Skeleton(height: 11).frame(width: 160)
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 8) {
                Skeleton(height: 16)
                Skeleton(height: 16).frame(maxWidth: 220, alignment: .leading)
            }
            if withImage {
                Skeleton(height: 220, cornerRadius: BondTheme.Radius.surface)
            }
            HStack(spacing: BondTheme.Space.md) {
                Skeleton(height: 28, cornerRadius: 14).frame(width: 72)
                Skeleton(height: 28, cornerRadius: 14).frame(width: 56)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
    }
}

/// Story şeridindeki yer tutucu daire; gerçek halkayla aynı ölçüde.
struct StoryBubbleSkeleton: View {
    var ring: CGFloat
    var cell: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            Skeleton(height: ring, cornerRadius: ring / 2).frame(width: ring)
            Skeleton(height: 9, cornerRadius: 4.5).frame(width: 40)
        }
        .frame(width: cell)
        .accessibilityHidden(true)
    }
}
