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

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                Button(action: openProfile) {
                    HStack(spacing: 11) {
                        ProfileMedia(url: post.author.imageURL, data: nil, assetName: post.author.imageAssetName)
                            .frame(width: 42, height: 42)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Text(post.author.name).font(.system(size: 14, weight: .bold))
                                // Tik önceden koşulsuzdu: her gönderi yazarı doğrulanmış
                                // görünüyordu ve işaret hiçbir şey ifade etmiyordu.
                                ProfileBadgeLabel(badge: post.author.badge, compact: true)
                            }
                            // İkinci satır eskiden yalnızca gönderide yer varsa
                            // çıkıyordu; yer yokken 42 puntoluk yuvarlağın yanında
                            // tek satır kalıyor ve satır yüksekliği tutmuyordu.
                            // Yer yoksa bölüm ve sınıf yazılıyor, satır hep iki.
                            Text(altSatir)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(CampusTheme.ink.opacity(0.45))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(CampusTheme.ink)
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
                        Button(L10n.Feed.blockUser, role: .destructive) { appState.block(post.author) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(CampusTheme.ink.opacity(0.5))
                        .frame(width: 44, height: 44)
                }
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
                    .foregroundStyle(CampusTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                    .padding(CampusTheme.Space.xl)
                    .background(CampusTheme.acid.opacity(0.3))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if !post.liked { toggleLike() }
                    }
                    .accessibilityAction(named: L10n.Feed.like) {
                        if !post.liked { toggleLike() }
                    }
            }

            HStack(spacing: CampusTheme.Space.sm) {
                Button(action: toggleLike) {
                    Image(systemName: post.liked ? "heart.fill" : "heart")
                        .foregroundStyle(post.liked ? CampusTheme.coral : CampusTheme.ink)
                        .frame(width: 44, height: 44)
                }
                Button { showComments = true } label: { Image(systemName: "bubble.left").frame(width: 44, height: 44) }
                    .accessibilityLabel(L10n.Feed.openComments)
                ShareLink(item: "\(post.author.name): \(post.caption)") { Image(systemName: "paperplane").frame(width: 44, height: 44) }
                Spacer()
                Button(action: toggleSaved) {
                    Image(systemName: post.saved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(post.saved ? CampusTheme.violet : CampusTheme.ink)
                        .frame(width: 44, height: 44)
                }
            }
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(CampusTheme.ink)
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.Feed.likeCount(post.likeCount)).font(.system(size: 12, weight: .bold))
                if !post.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   post.imageURL != nil || post.imageAssetName != nil || post.localImageData != nil {
                    Text("**\(post.author.name)**  \(post.caption)")
                        .font(.system(size: 14)).lineSpacing(3)
                }
                if !post.comments.isEmpty {
                    Button {
                        showComments = true
                    } label: {
                        Text(post.comments.count == 1 ? L10n.Feed.oneComment : L10n.Feed.allComments(post.comments.count))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CampusTheme.muted)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    ForEach(post.comments.suffix(2)) { comment in
                        Text("**\(comment.author)**  \(comment.body)")
                            .font(.system(size: 13)).foregroundStyle(CampusTheme.ink.opacity(0.62))
                    }
                }
                Text(post.createdAt.relativeTurkish)
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(CampusTheme.muted)
            }
            .foregroundStyle(CampusTheme.ink)
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showComments) {
            CommentsView(postID: post.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .confirmationDialog(L10n.Feed.deletePostConfirm, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(L10n.Feed.deletePost, role: .destructive, action: delete)
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Feed.irreversible)
        }
    }
}

