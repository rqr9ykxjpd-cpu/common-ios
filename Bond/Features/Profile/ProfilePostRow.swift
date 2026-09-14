import SwiftUI

/// Profil kartlarının altındaki paylaşım satırı. Akış kartı değil: List/Scroll
/// içinde caption, tarih ve varsa küçük kare.
struct ProfilePostRow: View {
    let post: SocialPost

    var body: some View {
        HStack(alignment: .top, spacing: BondTheme.Space.md) {
            if post.hasPhoto {
                ProfileMedia(
                    url: post.imageURL,
                    data: post.localImageData,
                    assetName: post.imageAssetName,
                    kind: .content
                )
                .frame(width: 56, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 4) {
                if !post.caption.isEmpty {
                    Text(post.caption)
                        .font(.body)
                }
                Text(post.createdAt.relativeTurkish)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
