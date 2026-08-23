import SwiftUI
import UIKit

struct PostCard: View {
    @Environment(AppState.self) private var appState
    let post: SocialPost
    let toggleLike: () -> Void
    let toggleSaved: () -> Void
    let openProfile: () -> Void
    let delete: () -> Void
    @State private var showComments = false
    @State private var showDeleteConfirmation = false
    @State private var showModeratorRemove = false
    @State private var showBlockConfirmation = false

    /// Görselin gösterileceği yükseklik oranı (yükseklik = genişlik × bu değer).
    ///
    /// Fotoğrafın kendi oranı kullanılıyor; yalnızca uç değerler sınırlanıyor:
    /// çok geniş panoramalar şeride, çok uzun ekran görüntüleri de tek gönderiyle
    /// bütün akışı kaplayacak bir sütuna dönüşmesin diye. Sınırlar Instagram'ın
    /// kullandığı aralıkla aynı: 1.91:1 ile 4:5.
    private var displayAspect: CGFloat {
        let enGenis: CGFloat = 0.524   // 1.91:1
        // 1.34: telefonun kendi 4:3 dikey fotoğrafı tam sığsın. Instagram 1.25 (4:5)
        // kullanıyor ama o sınırda standart bir iPhone karesi hâlâ %6 kesiliyordu.
        let enUzun: CGFloat = 1.34
        guard let size = imageSize, size.width > 0 else { return 1 }
        return min(max(size.height / size.width, enGenis), enUzun)
    }

    /// Sunucudan gelen gönderilerde boyut ancak görsel indikten sonra bilinir;
    /// `ProfileMedia` yükleyince buraya yazıyor.
    @State private var remoteImageSize: CGSize?

    /// Başlığın ikinci satırı. Yer varsa yer, yoksa kişinin bölümü ve sınıfı.
    private var altSatir: String {
        if let place = post.place { return "\(place.name) · \(place.area)" }
        let parcalar = [post.author.department, AcademicYear.display(post.author.year)].filter { !$0.isEmpty }
        return parcalar.isEmpty ? post.author.university : parcalar.joined(separator: " · ")
    }

    private var imageSize: CGSize? {
        if let data = post.localImageData, let image = UIImage(data: data) { return image.size }
        if let name = post.imageAssetName, let image = UIImage(named: name) { return image.size }
        return remoteImageSize
    }

    @ViewBuilder
    private var authorBadge: some View {
        if let icon = post.author.badge.systemImage,
           let title = post.author.badge.title {
            Label(title, systemImage: icon)
                .font(BondTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(post.author.badge == .founder ? BondTheme.ember : BondTheme.icon)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            HStack(spacing: BondTheme.Space.compact) {
                Button(action: openProfile) {
                    HStack(spacing: BondTheme.Space.compact) {
                        ProfileMedia(url: post.author.imageURL, data: nil, assetName: post.author.imageAssetName)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: BondTheme.Space.xs) {
                            HStack(spacing: BondTheme.Space.sm) {
                                Text(post.author.name)
                                    .font(BondTheme.Typography.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .layoutPriority(1)
                                authorBadge
                            }
                            // İkinci satır eskiden yalnızca gönderide yer varsa
                            // çıkıyordu; yer yokken 42 puntoluk yuvarlağın yanında
                            // tek satır kalıyor ve satır yüksekliği tutmuyordu.
                            // Yer yoksa bölüm ve sınıf yazılıyor, satır hep iki.
                            Text(altSatir)
                                .font(BondTheme.Typography.caption)
                                .foregroundStyle(BondTheme.muted)
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(BondTheme.ink)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L10n.Feed.openProfile(post.author.name))
                Spacer()
                Menu {
                    ShareLink(item: "\(post.author.name): \(post.caption)") {
                        Label(L10n.Feed.share, systemImage: "square.and.arrow.up")
                    }
                    if post.isMine {
                        Button(L10n.Feed.deletePost, systemImage: "trash", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                    if !post.isMine {
                        Menu {
                            ForEach(ReportReason.allCases) { reason in
                                Button(reason.title) { appState.report(post.author, reason: reason) }
                            }
                        } label: {
                            Label(L10n.Common.report, systemImage: "flag")
                        }
                        Button(L10n.Feed.blockUser, role: .destructive) {
                            showBlockConfirmation = true
                        }
                        // Moderasyon eylemleri yalnızca rozetli hesapta görünür.
                        // Asıl kapı sunucudaki izin kuralı; buradaki kontrol
                        // sadece menüyü kalabalıklaştırmamak için.
                        if appState.isModerator {
                            Divider()
                            Button(L10n.Moderation.removePost, systemImage: "trash.slash", role: .destructive) {
                                showModeratorRemove = true
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(BondTheme.ink.opacity(0.5))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.Common.options)
            }
            .padding(.horizontal, 20)

            if post.imageURL != nil || post.imageAssetName != nil || post.localImageData != nil {
                // Görsel önceden sabit 0.72 orana (geniş format) zorlanıyordu. Dikey
                // çekilmiş bir fotoğraf bu kutuya sığmadığı için üstünden ve altından
                // kesiliyor, yüzün yarısı kayboluyordu. Artık fotoğrafın kendi oranı
                // kullanılıyor; yalnızca aşırı uçlar sınırlanıyor (bkz. displayAspect).
                // Yükseklik artık tek bir kaynaktan, kartın kendi genişliğinden
                // türetiliyor. Eskiden GeometryReader'ın içi kart genişliğini, dış
                // çerçevesi ise ekran genişliğini kullanıyordu; ikisi eşit olmadığı
                // her durumda görsel taşıp altındaki yazının üstüne biniyordu.
                Color.clear
                    .aspectRatio(1 / displayAspect, contentMode: .fit)
                    .overlay {
                        if post.localImageData != nil || post.imageAssetName != nil {
                            ProfileMedia(url: nil, data: post.localImageData,
                                         assetName: post.imageAssetName)
                        } else if let url = post.imageURL {
                            MeasuredRemoteImage(url: url, naturalSize: $remoteImageSize)
                        }
                    }
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if !post.liked { toggleLike() }
                    }
                    .accessibilityAction(named: L10n.Feed.like) {
                        if !post.liked { toggleLike() }
                    }
            } else {
                Text(post.caption)
                    .font(.system(size: 25, weight: .bold))
                    .lineSpacing(5)
                    .foregroundStyle(BondTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                    .padding(BondTheme.Space.xl)
                    .background(BondTheme.acid.opacity(0.3))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if !post.liked { toggleLike() }
                    }
                    .accessibilityAction(named: L10n.Feed.like) {
                        if !post.liked { toggleLike() }
                    }
            }

            HStack(spacing: 0) {
                Button(action: toggleLike) {
                    Image(systemName: post.liked ? "heart.fill" : "heart")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(post.liked ? BondTheme.coral : BondTheme.ink)
                        .frame(width: 24, height: 24)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(post.liked ? L10n.Feed.unlike : L10n.Feed.like)
                .accessibilityAddTraits(post.liked ? .isSelected : [])
                Button { showComments = true } label: {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 21, weight: .regular))
                        .frame(width: 24, height: 24)
                        .frame(width: 44, height: 44)
                }
                    .accessibilityLabel(L10n.Feed.openComments)
                ShareLink(item: "\(post.author.name): \(post.caption)") {
                    Image(systemName: "paperplane")
                        .font(.system(size: 21, weight: .regular))
                        .frame(width: 24, height: 24)
                        .frame(width: 44, height: 44)
                }
                    .accessibilityLabel(L10n.Feed.share)
                Spacer()
                Button(action: toggleSaved) {
                    Image(systemName: post.saved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 21, weight: .regular))
                        .foregroundStyle(post.saved ? BondTheme.violet : BondTheme.ink)
                        .frame(width: 24, height: 24)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(post.saved ? L10n.Feed.removeSaved : L10n.Feed.save)
                .accessibilityAddTraits(post.saved ? .isSelected : [])
            }
            .foregroundStyle(BondTheme.ink)
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: BondTheme.Space.xs) {
                Text(L10n.Feed.likeCount(post.likeCount))
                    .font(BondTheme.Typography.footnote.weight(.semibold))
                if !post.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   post.imageURL != nil || post.imageAssetName != nil || post.localImageData != nil {
                    Text("**\(post.author.name)**  \(post.caption)")
                        .font(BondTheme.Typography.subheadline)
                        .lineSpacing(2)
                }
                if !post.comments.isEmpty {
                    Button {
                        showComments = true
                    } label: {
                        Text(post.comments.count == 1 ? L10n.Feed.oneComment : L10n.Feed.allComments(post.comments.count))
                            .font(BondTheme.Typography.footnote.weight(.semibold))
                            .foregroundStyle(BondTheme.muted)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    ForEach(post.comments.suffix(2)) { comment in
                        Text("**\(comment.author)**  \(comment.body)")
                            .font(BondTheme.Typography.footnote)
                            .foregroundStyle(BondTheme.muted)
                    }
                }
                Text(post.createdAt.relativeTurkish)
                    .font(BondTheme.Typography.caption)
                    .foregroundStyle(BondTheme.muted)
            }
            .foregroundStyle(BondTheme.ink)
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showComments) {
            CommentsView(postID: post.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .confirmationDialog(L10n.Moderation.removePostConfirm, isPresented: $showModeratorRemove, titleVisibility: .visible) {
            Button(L10n.Moderation.removePost, role: .destructive) {
                Task { await appState.moderatorRemovePost(post.id) }
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Moderation.removePostBody)
        }
        .confirmationDialog(L10n.Feed.deletePostConfirm, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(L10n.Feed.deletePost, role: .destructive, action: delete)
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Feed.irreversible)
        }
        .confirmationDialog(
            L10n.Chat.blockConfirm(post.author.name),
            isPresented: $showBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Feed.blockUser, role: .destructive) {
                appState.block(post.author)
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Chat.blockBody)
        }
    }
}

