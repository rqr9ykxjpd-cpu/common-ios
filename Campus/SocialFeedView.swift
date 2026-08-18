import SwiftUI

struct SocialFeedView: View {
    @Environment(AppState.self) private var appState
    @State private var showStoryComposer = false
    @State private var showPostComposer = false
    @State private var selectedPeoplePlace: CampusPlace?
    @State private var selectedClub: CampusClub?
    @State private var showChats = false
    @State private var showNotifications = false
    @State private var selectedPostAuthor: StudentProfile?

    private var visiblePosts: [SocialPost] {
        guard let place = appState.selectedPlaceFilter else { return appState.posts }
        return appState.posts.filter { $0.place?.id == place.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                feedHeader
                    .frame(height: 56)
                    .background(CampusTheme.paper)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(CampusTheme.ink.opacity(0.08)).frame(height: 0.5)
                    }
                    .zIndex(1)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            Color.clear.frame(height: 1).id("feed-top")
                            storyRail
                            meetingPlaces
                            clubsSection
                            Divider().opacity(0.35).padding(.vertical, 14)
                            if visiblePosts.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "photo.on.rectangle.angled").font(.title2)
                                    Text("Bu noktadan henüz paylaşım yok.").font(.subheadline.bold())
                                    Button("Tüm akışı göster") { appState.selectedPlaceFilter = nil }
                                        .font(.caption.bold()).foregroundStyle(CampusTheme.violet)
                                }
                                .foregroundStyle(CampusTheme.ink.opacity(0.55))
                                .frame(maxWidth: .infinity).padding(.vertical, 48)
                            } else {
                                ForEach(visiblePosts) { post in
                                    PostCard(
                                        post: post,
                                        toggleLike: { appState.toggleLike(postID: post.id) },
                                        toggleSaved: { appState.toggleSaved(postID: post.id) },
                                        openProfile: { selectedPostAuthor = post.author },
                                        delete: { appState.deletePost(post.id) }
                                    )
                                    Divider().opacity(0.35).padding(.vertical, 20)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .scrollContentBackground(.hidden)
                    .refreshable { await appState.loadFeed(); await appState.loadStories() }
                    .onAppear {
                        proxy.scrollTo("feed-top", anchor: .top)
                    }
                }
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showStoryComposer) {
                CreatePostView(initialContentType: 1)
            }
            .sheet(isPresented: $showPostComposer) {
                CreatePostView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
            }
            .sheet(item: $selectedPeoplePlace) { place in
                PlacePeopleView(place: place)
            }
            .sheet(item: $selectedPostAuthor) { profile in
                NavigationStack {
                    SocialPersonDetailView(profile: profile, place: nil)
                }
            }
            .sheet(item: $selectedClub) { club in
                ClubDetailView(club: club)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
            }
            .fullScreenCover(isPresented: $showChats) {
                PremiumMatchesView()
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
            .task { await appState.loadFeed(); await appState.loadStories() }
            .fullScreenCover(item: Binding(get: { appState.selectedStory }, set: { appState.selectedStory = $0 })) { story in
                StoryViewer(
                    stories: appState.stories,
                    initialStoryID: story.id,
                    viewRecords: { storyID in
                        appState.stories.first(where: { $0.id == storyID })?.viewRecords ?? []
                    },
                    onViewed: { viewedStory in appState.markStoryViewed(viewedStory) },
                    onDelete: { storyID in appState.deleteStory(storyID) },
                    close: { appState.selectedStory = nil }
                )
            }
        }
    }

    private var feedHeader: some View {
        HStack(alignment: .center) {
            Wordmark()
            Spacer()
            Button { showNotifications = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(CampusTheme.ink.opacity(0.06), in: Circle())
                    if appState.unreadNotificationCount > 0 {
                        Text("\(min(appState.unreadNotificationCount, 9))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(CampusTheme.coral, in: Circle())
                            .offset(x: 2, y: -2)
                    }
                }
                .accessibilityLabel("Bildirimler, \(appState.unreadNotificationCount) okunmamış")
            }
            .buttonStyle(PressableStyle())

            Button { showChats = true } label: {
                Image(systemName: "message.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CampusTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(CampusTheme.acid, in: Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Sohbetler")

            Button { showPostComposer = true } label: {
                Label("Paylaş", systemImage: "plus")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(CampusTheme.paper)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(CampusTheme.ink, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .foregroundStyle(CampusTheme.ink)
        .padding(.horizontal, 20)
    }

    private var storyRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                AddStoryBubble { showStoryComposer = true }
                ForEach(appState.stories) { story in
                    Button {
                        appState.selectedStory = story
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                ProfileMedia(
                                    url: story.author.imageURL,
                                    data: nil,
                                    assetName: story.author.imageAssetName
                                )
                                    .frame(width: 47, height: 47)
                                    .clipShape(Circle())
                                    .overlay {
                                        Circle().stroke(.white, lineWidth: 1)
                                    }
                                Circle()
                                    .stroke(
                                        story.viewed ? CampusTheme.ink.opacity(0.14) : CampusTheme.violet,
                                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                                    )
                                    .frame(width: 55, height: 55)
                                if let place = story.place {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white, CampusTheme.violet)
                                        .offset(x: 17, y: 17)
                                        .accessibilityLabel(place.name)
                                }
                            }
                            .frame(width: 58, height: 58)
                            .contentShape(Circle())
                            Text(story.author.name)
                                .font(.system(size: 11, weight: story.viewed ? .medium : .bold, design: .rounded))
                                .foregroundStyle(CampusTheme.ink.opacity(story.viewed ? 0.5 : 1))
                                .lineLimit(1)
                                .frame(width: 58)
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }

    private var meetingPlaces: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(CampusTheme.violet)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nerede tanışabiliriz?")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    if let activePlace = appState.currentVisiblePlace {
                        Text("Şu an \(activePlace.name) konumunda görünürsün")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(CampusTheme.violet)
                    }
                }
                Spacer()
                Text(appState.currentVisiblePlace == nil ? "YER SEÇ" : "BURADASIN")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(appState.currentVisiblePlace == nil ? CampusTheme.ink.opacity(0.38) : CampusTheme.violet)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    placeChip(title: "Tümü", icon: "square.grid.2x2", place: nil)
                    ForEach(Array(appState.places.enumerated()), id: \.element.id) { index, place in
                        placeChip(title: place.name, icon: placeIcon(index), place: place)
                    }
                }
            }
        }
        .padding(CampusTheme.Space.lg)
        .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous)
                .stroke(CampusTheme.hairline)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var clubsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("YÜ Kulüpleri", systemImage: "person.3.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(CampusTheme.ink)
                Spacer()
                Text("KATIL · TANIŞ · ÜRET")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(CampusTheme.ink.opacity(0.38))
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(appState.clubs) { club in
                        Button { selectedClub = club } label: {
                            clubCard(club)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 14)
    }

    private func clubCard(_ club: CampusClub) -> some View {
        let joined = appState.isJoined(to: club)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: club.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color(hex: club.accentHex), in: Circle())
                Spacer()
                if joined {
                    Label("ÜYESİN", systemImage: "checkmark")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: club.accentHex))
                }
            }
            Text(club.name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(CampusTheme.ink)
                .lineLimit(2)
            Text(club.nextEvent)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(CampusTheme.ink.opacity(0.48))
                .lineLimit(1)
            HStack {
                Label("\(club.memberCount + (joined ? 1 : 0))", systemImage: "person.2.fill")
                Spacer()
                Text(joined ? "Aç" : "Katıl")
                    .fontWeight(.bold)
            }
            .font(.caption)
            .foregroundStyle(joined ? Color(hex: club.accentHex) : CampusTheme.violet)
        }
        .padding(14)
        .frame(width: 210, height: 166, alignment: .topLeading)
        .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: club.accentHex).opacity(joined ? 0.55 : 0.16), lineWidth: joined ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func placeChip(title: String, icon: String, place: CampusPlace?) -> some View {
        let selected = place == nil ? appState.selectedPlaceFilter == nil : appState.selectedPlaceFilter?.id == place?.id
        return Button {
            if let place {
                selectedPeoplePlace = place
            } else {
                appState.selectedPlaceFilter = nil
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .semibold, design: .rounded)).lineLimit(1)
            }
            .foregroundStyle(selected ? .white : CampusTheme.ink)
            .padding(.horizontal, 11)
            .frame(height: 44)
            .background(selected ? CampusTheme.violet : CampusTheme.ink.opacity(0.055), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private func placeIcon(_ index: Int) -> String {
        ["cup.and.saucer.fill", "mug.fill", "person.3.fill", "building.columns.fill", "books.vertical.fill"][index]
    }
}

private struct AddStoryBubble: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack(alignment: .bottomTrailing) {
                    Circle().fill(CampusTheme.ink.opacity(0.08)).frame(width: 52, height: 52)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(CampusTheme.ink.opacity(0.28)))
                        .clipShape(Circle())
                    Image(systemName: "plus")
                        .font(.caption2.bold()).foregroundStyle(CampusTheme.ink)
                        .frame(width: 19, height: 19).background(CampusTheme.acid, in: Circle())
                        .offset(x: -1, y: -1)
                }
                Text("Hikâyen").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(CampusTheme.ink)
            }
        }
        .buttonStyle(PressableStyle())
    }
}

struct PostCard: View {
    @Environment(AppState.self) private var appState
    let post: SocialPost
    let toggleLike: () -> Void
    let toggleSaved: () -> Void
    let openProfile: () -> Void
    let delete: () -> Void
    @State private var showComments = false
    @State private var showDeleteConfirmation = false

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
                                Text(post.author.name).font(.system(size: 14, weight: .bold, design: .rounded))
                                Image(systemName: "checkmark.seal.fill").font(.caption).foregroundStyle(CampusTheme.violet)
                            }
                            if let place = post.place {
                                Text("\(place.name) · \(place.area)")
                                    .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(CampusTheme.ink.opacity(0.45))
                            }
                        }
                    }
                    .foregroundStyle(CampusTheme.ink)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(post.author.name) profilini aç")
                Spacer()
                Menu {
                    ShareLink(item: "\(post.author.name): \(post.caption)") {
                        Label("Paylaş", systemImage: "square.and.arrow.up")
                    }
                    if post.isMine {
                        Button("Gönderiyi sil", systemImage: "trash", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                    if !post.isMine {
                        Menu {
                            ForEach(ReportReason.allCases) { reason in
                                Button(reason.title) { appState.report(post.author, reason: reason) }
                            }
                        } label: {
                            Label("Şikâyet et", systemImage: "flag")
                        }
                        Button("Kullanıcıyı engelle", role: .destructive) { appState.block(post.author) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(CampusTheme.ink.opacity(0.5))
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 20)

            if post.imageURL != nil || post.imageAssetName != nil || post.localImageData != nil {
                GeometryReader { proxy in
                    ProfileMedia(url: post.imageURL, data: post.localImageData, assetName: post.imageAssetName)
                        .frame(width: proxy.size.width, height: proxy.size.width * 0.72)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            if !post.liked { toggleLike() }
                        }
                        .accessibilityAction(named: "Beğen") {
                            if !post.liked { toggleLike() }
                        }
                }
                .frame(height: UIScreen.main.bounds.width * 0.72)
            } else {
                Text(post.caption)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .lineSpacing(5)
                    .foregroundStyle(CampusTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                    .padding(CampusTheme.Space.xl)
                    .background(CampusTheme.acid.opacity(0.3))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if !post.liked { toggleLike() }
                    }
                    .accessibilityAction(named: "Beğen") {
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
                    .accessibilityLabel("Yorumları aç")
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
                Text("\(post.likeCount) beğeni").font(.system(size: 12, weight: .bold, design: .rounded))
                if !post.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   post.imageURL != nil || post.imageAssetName != nil || post.localImageData != nil {
                    Text("**\(post.author.name)**  \(post.caption)")
                        .font(.system(size: 14, design: .rounded)).lineSpacing(3)
                }
                if !post.comments.isEmpty {
                    Button {
                        showComments = true
                    } label: {
                        Text(post.comments.count == 1 ? "1 yorumu gör" : "\(post.comments.count) yorumun tümünü gör")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(CampusTheme.muted)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    ForEach(post.comments.suffix(2)) { comment in
                        Text("**\(comment.author)**  \(comment.body)")
                            .font(.system(size: 13, design: .rounded)).foregroundStyle(CampusTheme.ink.opacity(0.62))
                    }
                }
                Text(post.createdAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(CampusTheme.muted)
            }
            .foregroundStyle(CampusTheme.ink)
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showComments) {
            CommentsView(postID: post.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .confirmationDialog("Gönderiyi sil?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Gönderiyi sil", role: .destructive, action: delete)
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu işlem geri alınamaz.")
        }
    }
}

private struct CommentsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let postID: UUID
    @State private var draft = ""
    @State private var commentToDelete: SocialComment?
    @FocusState private var focused: Bool

    private var post: SocialPost? { appState.posts.first { $0.id == postID } }
    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if let post {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if post.comments.isEmpty {
                                ContentUnavailableView(
                                    "Henüz yorum yok",
                                    systemImage: "bubble.left.and.bubble.right",
                                    description: Text("İlk yorumu sen yazabilirsin.")
                                )
                                .padding(.top, 64)
                            } else {
                                ForEach(post.comments) { comment in
                                    commentRow(comment)
                                }
                            }
                        }
                        .padding(.horizontal, CampusTheme.Space.lg)
                        .padding(.bottom, CampusTheme.Space.xl)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .safeAreaInset(edge: .bottom, spacing: 0) { composer }
                } else {
                    ContentUnavailableView("Gönderi bulunamadı", systemImage: "exclamationmark.bubble")
                }
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .navigationTitle("Yorumlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") { dismiss() }
                }
            }
            .confirmationDialog("Yorumu sil?", isPresented: Binding(
                get: { commentToDelete != nil },
                set: { if !$0 { commentToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Yorumu sil", role: .destructive) {
                    guard let commentToDelete else { return }
                    appState.deleteComment(commentToDelete.id, from: postID)
                    self.commentToDelete = nil
                }
                Button("Vazgeç", role: .cancel) { commentToDelete = nil }
            } message: {
                Text("Bu işlem geri alınamaz.")
            }
        }
    }

    private func commentRow(_ comment: SocialComment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(comment.isMine ? CampusTheme.acid : CampusTheme.violet.opacity(0.14))
                .frame(width: 38, height: 38)
                .overlay {
                    Text(String(comment.author.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(comment.author)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(comment.createdAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(CampusTheme.muted)
                }
                Text(comment.body)
                    .font(.system(size: 14, design: .rounded))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if comment.isMine {
                Menu {
                    Button("Yorumu sil", systemImage: "trash", role: .destructive) {
                        commentToDelete = comment
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Yorum seçenekleri")
            }
        }
        .foregroundStyle(CampusTheme.ink)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(CampusTheme.hairline).frame(height: 0.5) }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 9) {
            TextField("Yorum yaz...", text: $draft, axis: .vertical)
                .font(.system(size: 15, design: .rounded))
                .lineLimit(1...4)
                .focused($focused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(CampusTheme.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Button { send() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(CampusTheme.paper)
                    .frame(width: 44, height: 44)
                    .background(canSend ? CampusTheme.ink : CampusTheme.ink.opacity(0.22), in: Circle())
            }
            .disabled(!canSend)
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Yorumu gönder")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(CampusTheme.hairline).frame(height: 0.5) }
    }

    private func send() {
        guard canSend else { return }
        appState.addComment(draft, to: postID)
        draft = ""
        focused = true
    }
}

struct StoryViewer: View {
    let stories: [CampusStory]
    let viewRecords: (UUID) -> [StoryViewRecord]
    let onViewed: (CampusStory) -> Void
    let onDelete: (UUID) -> Void
    let close: () -> Void
    @State private var currentIndex: Int
    @State private var progress: CGFloat = 0
    @State private var reply = ""
    @State private var replySent = false
    @State private var liked = false
    @State private var showViewers = false
    @State private var showDeleteConfirmation = false
    @State private var selectedStoryAuthor: StudentProfile?
    @FocusState private var replyFocused: Bool

    init(stories: [CampusStory], initialStoryID: UUID, viewRecords: @escaping (UUID) -> [StoryViewRecord], onViewed: @escaping (CampusStory) -> Void, onDelete: @escaping (UUID) -> Void, close: @escaping () -> Void) {
        self.stories = stories
        self.viewRecords = viewRecords
        self.onViewed = onViewed
        self.onDelete = onDelete
        self.close = close
        _currentIndex = State(initialValue: stories.firstIndex(where: { $0.id == initialStoryID }) ?? 0)
    }

    private var story: CampusStory? {
        stories.indices.contains(currentIndex) ? stories[currentIndex] : nil
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()
                if let story {
                    ProfileMedia(url: story.imageURL, data: story.localImageData, assetName: story.imageAssetName)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .ignoresSafeArea()
                    LinearGradient(colors: [.black.opacity(0.64), .clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()

                    HStack(spacing: 0) {
                        Color.clear.contentShape(Rectangle()).onTapGesture { previous() }
                        Color.clear.contentShape(Rectangle()).onTapGesture { next() }
                    }
                    .padding(.top, 90).padding(.bottom, 115)

                    VStack(spacing: 12) {
                        progressBars
                        storyHeader(story)
                        Spacer()
                        storyFooter(story)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                } else {
                    Button("Kapat", action: close).foregroundStyle(.white)
                }
            }
        }
        .task(id: currentIndex) {
            if let story { onViewed(story) }
        }
        .task(id: "\(currentIndex)-\(replyFocused)-\(selectedStoryAuthor != nil)") { await playCurrentStory() }
        .sheet(item: $selectedStoryAuthor) { profile in
            NavigationStack {
                SocialPersonDetailView(profile: profile, place: nil)
            }
        }
        .sheet(isPresented: $showViewers) {
            if let story {
                StoryViewersSheet(story: story, records: viewRecords(story.id))
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .confirmationDialog("Story'yi sil?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            if let story, story.isMine {
                Button("Story'yi sil", role: .destructive) { onDelete(story.id) }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu işlem geri alınamaz.")
        }
    }

    private var progressBars: some View {
        HStack(spacing: 4) {
            ForEach(stories.indices, id: \.self) { index in
                Capsule().fill(.white.opacity(0.3)).frame(height: 3)
                    .overlay(alignment: .leading) {
                        Capsule().fill(.white).frame(maxWidth: .infinity)
                            .scaleEffect(x: index < currentIndex ? 1 : (index == currentIndex ? progress : 0), anchor: .leading)
                    }
            }
        }
    }

    private func storyHeader(_ story: CampusStory) -> some View {
        HStack(spacing: 11) {
            Button { selectedStoryAuthor = story.author } label: {
                HStack(spacing: 11) {
                    ProfileMedia(url: story.author.imageURL, data: nil, assetName: story.author.imageAssetName)
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(story.author.name).font(.subheadline.bold())
                        if let place = story.place {
                            Label(place.name, systemImage: "mappin").font(.caption).opacity(0.72)
                        }
                    }
                }
                .foregroundStyle(.white)
                .contentShape(Rectangle())
                .frame(minHeight: 44)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("\(story.author.name) profilini aç")
            Spacer()
            if story.isMine {
                Button { showViewers = true } label: {
                    Label("\(viewRecords(story.id).reduce(0) { $0 + $1.viewCount })", systemImage: "eye.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(.black.opacity(0.28), in: Capsule())
                }
                Menu {
                    Button("Story'yi sil", systemImage: "trash", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }
            }
            Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
        }
    }

    private func storyFooter(_ story: CampusStory) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(story.caption).font(.system(size: 24, weight: .semibold, design: .rounded))
            if replySent {
                Label("Yanıt gönderildi", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold()).foregroundStyle(CampusTheme.acid)
                    .frame(maxWidth: .infinity, alignment: .center).frame(height: 46)
            } else {
                HStack(spacing: 10) {
                    TextField("\(story.author.name) kişisine yanıtla...", text: $reply)
                        .focused($replyFocused)
                        .padding(.horizontal, 16).frame(height: 46)
                        .background(.black.opacity(0.2), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.55)))
                    Button { sendReply() } label: {
                        Image(systemName: reply.isEmpty ? "heart.fill" : "paperplane.fill")
                            .font(.title3).foregroundStyle(liked ? CampusTheme.coral : .white)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(reply.isEmpty ? "Beğen" : "Yanıtı gönder")
                }
            }
        }
    }

    @MainActor
    private func playCurrentStory() async {
        guard story != nil, !replyFocused, selectedStoryAuthor == nil else { return }

        let tick = Duration.milliseconds(50)
        let increment: CGFloat = 1 / 120
        while progress < 1 {
            do {
                try await Task.sleep(for: tick)
            } catch {
                return
            }
            guard !Task.isCancelled, !replyFocused, selectedStoryAuthor == nil else { return }
            progress = min(1, progress + increment)
        }
        guard !Task.isCancelled else { return }
        next()
    }

    private func prepareForTransition() {
        progress = 0
        reply = ""
        replySent = false
        liked = false
        replyFocused = false
    }

    private func previous() {
        prepareForTransition()
        if currentIndex > 0 { currentIndex -= 1 }
    }

    private func next() {
        prepareForTransition()
        if currentIndex < stories.count - 1 { currentIndex += 1 } else { close() }
    }

    private func sendReply() {
        if reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            liked.toggle()
            Haptics.impact(.light)
        } else {
            replyFocused = false
            withAnimation(.snappy) { replySent = true }
            Haptics.success()
        }
    }
}

private struct StoryViewersSheet: View {
    let story: CampusStory
    let records: [StoryViewRecord]
    @Environment(\.dismiss) private var dismiss

    private var totalViews: Int { records.reduce(0) { $0 + $1.viewCount } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: CampusTheme.Space.lg) {
                        summary(value: "\(records.count)", label: "Kişi")
                        summary(value: "\(totalViews)", label: "Toplam izleme")
                    }
                    .padding(.bottom, CampusTheme.Space.lg)

                    if records.isEmpty {
                        ContentUnavailableView("Henüz izleyen yok", systemImage: "eye.slash", description: Text("Story izlendiğinde kişiler burada görünür."))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, CampusTheme.Space.xxl)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(records.sorted(by: { $0.lastViewedAt > $1.lastViewedAt })) { record in
                                NavigationLink {
                                    SocialPersonDetailView(profile: record.viewer, place: nil)
                                } label: {
                                    HStack(spacing: CampusTheme.Space.md) {
                                        ProfileMedia(url: record.viewer.imageURL, data: nil, assetName: record.viewer.imageAssetName)
                                            .frame(width: 50, height: 50)
                                            .clipShape(Circle())
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(record.viewer.name)
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            Text(record.lastViewedAt.formatted(.relative(presentation: .named)))
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(CampusTheme.muted)
                                        }
                                        Spacer()
                                        Text("\(record.viewCount) kez")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(CampusTheme.violet)
                                            .padding(.horizontal, 10)
                                            .frame(height: 30)
                                            .background(CampusTheme.violet.opacity(0.1), in: Capsule())
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundStyle(CampusTheme.muted)
                                    }
                                    .foregroundStyle(CampusTheme.ink)
                                    .contentShape(Rectangle())
                                    .padding(.vertical, CampusTheme.Space.md)
                                    .overlay(alignment: .bottom) { Rectangle().fill(CampusTheme.hairline).frame(height: 0.5) }
                                }
                                .buttonStyle(PressableStyle())
                                .accessibilityLabel("\(record.viewer.name) profilini aç")
                            }
                        }
                    }
                }
                .padding(.horizontal, CampusTheme.Space.lg)
                .padding(.top, CampusTheme.Space.md)
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .navigationTitle("Görüntüleyenler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") { dismiss() }
                }
            }
        }
    }

    private func summary(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 12, design: .rounded)).foregroundStyle(CampusTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CampusTheme.Space.lg)
        .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.control).stroke(CampusTheme.hairline))
    }
}

struct ProfileMedia: View {
    let url: URL?
    let data: Data?
    var assetName: String? = nil

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let assetName {
                Image(assetName).resizable().scaledToFill()
            } else if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
    }

    private var fallback: some View {
        LinearGradient(colors: [CampusTheme.violet.opacity(0.9), CampusTheme.coral.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Image(systemName: "person.crop.circle.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.35)))
    }
}
