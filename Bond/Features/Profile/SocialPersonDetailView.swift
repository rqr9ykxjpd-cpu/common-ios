import SwiftUI

struct SocialPersonDetailView: View {
    let profile: StudentProfile
    let place: CampusPlace?
    /// Sheet'in kökü olarak açıldığında `true`. İtilerek açıldığında sistem
    /// kendi geri düğmesini koyuyor; buna ek olarak bir tane daha eklemek
    /// yan yana iki geri düğmesi bırakıyordu.
    var showsClose = false
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var conversationRoute: ConversationRoute?
    @State private var selectedPost: SocialPost?
    @State private var details: PersonProfileData?
    @State private var reacted = false

    private var isMe: Bool { profile.id == appState.currentUserID }
    private var isMatched: Bool { conversation(with: profile) != nil }

    private func conversation(with person: StudentProfile) -> Conversation? {
        appState.conversations.first(where: { $0.profile.id == person.id })
    }

    private var visiblePlace: CampusPlace? { place }

    /// Kurucu profili. Rozet tek başına yeterince ayırt edici değildi: ekranın
    /// geri kalanı herkesinkiyle aynı görünüyordu.
    private var kurucu: Bool { (details?.badge ?? profile.badge) == .founder }

    /// İlgi alanı çipinin zemini. Kurucu profilinde vurgu rengi turuncu; ortak
    /// ilgi alanı vurgusu her profilde olduğu gibi duruyor.
    private func cipZemini(paylasilan: Bool) -> Color {
        if paylasilan { return BondTheme.acid.opacity(0.5) }
        return kurucu ? BondTheme.ember.opacity(0.12) : BondTheme.ink.opacity(0.055)
    }
    private var pendingRequest: MeetingRequest? {
        guard let visiblePlace else { return nil }
        return appState.meetingRequest(for: profile, at: visiblePlace)
    }

    /// Durum çubuğu + gezinme çubuğu yüksekliği. Kahraman fotoğraf bunların
    /// altına uzanıyor; yükseklik sabit yazılmıyor, sistemden okunuyor.
    var body: some View {
        ZStack(alignment: .topLeading) {
            BondTheme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ProfileMedia(url: profile.imageURL, data: nil, assetName: profile.imageAssetName)
                        .frame(maxWidth: .infinity)
                        .frame(height: 340)
                        .clipped()

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(profile.name), \(profile.age)").editorialTitle(38)
                            // Çıplak ikon ne anlama geldiğini söylemiyordu.
                            // Gönderi ve story sorguları rozeti getirmiyor; ayrıca
                            // çekilen değer varsa o kullanılıyor.
                            ProfileBadgeLabel(badge: details?.badge ?? profile.badge)
                        }
                        if let rozetAlt = (details?.badge ?? profile.badge).subtitle {
                            // Yuvarlak, yarı saydam gri bir satırdı; ekrandaki
                            // diğer bilgi satırlarından ayrışmıyor, öylece
                            // duruyordu. Serif italik bir künye satırı gibi
                            // okunuyor ve rozetin rengini taşıyor.
                            Text(rozetAlt)
                                .font(.system(size: 14))
                                .italic()
                                .foregroundStyle(BondTheme.ember)
                        }
                        Text("\(DepartmentCatalog.display(profile.department)) · \(profile.university) · \(AcademicYear.display(profile.year))")
                            .font(.subheadline.bold()).foregroundStyle(BondTheme.ink.opacity(0.5))

                        if let visiblePlace {
                            HStack(spacing: 10) {
                                Image(systemName: "location.fill").foregroundStyle(BondTheme.violet)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.Profile.visibleNowCaps).font(.system(size: 11, weight: .bold)).tracking(0.7)
                                    Text(visiblePlace.name).font(.headline)
                                }
                                Spacer()
                                Circle().fill(.green).frame(width: 8, height: 8)
                            }
                            .padding(14)
                            .background(BondTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        }

                        Text(profile.bio).font(.system(size: 16)).lineSpacing(4)

                        interestList

                        gallery

                        personPosts

                        // Kendi profilinde eylem düğmesi çıkıyordu: kendine mesaj
                        // gönderme ve kendinle buluşma isteği.
                        if isMe {
                            EmptyView()
                        } else if !isMatched {
                            // Eşleşmemişken tek düğme "Mesaj gönder"di, ama mesajlaşma
                            // eşleşmeye bağlı olduğu için hiçbir yere çıkmıyordu:
                            // birini beğenip tanışmanın profilden bir yolu yoktu.
                            Button {
                                Haptics.impact(.light)
                                reacted = true
                                Task { await appState.react(to: profile, liked: true) }
                            } label: {
                                Label(reacted ? L10n.Profile.likeSent : L10n.Discovery.meet,
                                      systemImage: reacted ? "checkmark" : "heart.fill")
                                    .font(.subheadline.bold()).foregroundStyle(BondTheme.ink)
                                    .frame(maxWidth: .infinity).frame(height: 50)
                                    .background(reacted ? BondTheme.ink.opacity(0.08) : BondTheme.acid,
                                                in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(PressableStyle())
                            .disabled(reacted)

                            Text(L10n.Profile.likeHint)
                                .font(.system(size: 11))
                                .foregroundStyle(BondTheme.ink.opacity(0.45))
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                        Button { openConversation() } label: {
                            Label(L10n.Profile.sendMessage, systemImage: "message.fill")
                                .font(.subheadline.bold()).foregroundStyle(BondTheme.paper)
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .background(BondTheme.ink, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(PressableStyle())

                        }

                        if visiblePlace != nil, !isMe {
                            // Metin eskiden "Buluşma isteği gönder"di ve kulağa çıkma
                            // teklifi gibi geliyordu. Özellik aslında bunu yapmıyor:
                            // ikisi de o an aynı yerde, bu yalnızca "buradayım, gelsene"
                            // demek. Altındaki satır da atma eşiğini düşürüyor —
                            // reddedilme gerçekten sessiz, ama bunu kimse bilmiyordu.
                            VStack(spacing: 7) {
                                Button { sendRequest() } label: {
                                    Label(pendingRequest == nil ? L10n.Profile.meetHere : L10n.Profile.requestSent, systemImage: pendingRequest == nil ? "cup.and.saucer.fill" : "checkmark")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(pendingRequest == nil ? BondTheme.onAccent : BondTheme.ink.opacity(0.55))
                                        .frame(maxWidth: .infinity).frame(height: 50)
                                        .background(pendingRequest == nil ? BondTheme.acid : BondTheme.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(PressableStyle())
                                .disabled(pendingRequest != nil)

                                if pendingRequest == nil {
                                    Text(L10n.Profile.noNotifyIfIgnored)
                                        .font(.system(size: 11))
                                        .foregroundStyle(BondTheme.ink.opacity(0.45))
                                }
                            }
                        }
                    }
                    .foregroundStyle(BondTheme.ink)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }

        }
        .ignoresSafeArea(edges: .top)
        // Kahraman fotoğrafın üstünde iki düğme yüzüyordu: elle çizilmiş siyah
        // daireler, elle verilmiş 16pt kenar boşluğu, safe area'yı taklit eden
        // konumlar. Aynı iş sistemin bar'ında yapılıyor; bar fotoğrafın üstünde
        // şeffaf duruyor ve kaydırınca kendi materyalini getiriyor.
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsClose {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(L10n.Common.close)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Menu {
                        ForEach(ReportReason.allCases) { reason in
                            Button(reason.title) { appState.report(profile, reason: reason) }
                        }
                    } label: {
                        Label(L10n.Common.report, systemImage: "flag")
                    }
                    Button(L10n.Feed.blockUser, role: .destructive) {
                        appState.block(profile)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        // Ziyaret yalnızca birinin profili kasıtlı olarak açıldığında kaydedilir;
        // keşif destesinde kart çevirmek ziyaret sayılmaz.
        .task {
            appState.recordProfileVisit(profile)
            details = await appState.personDetails(for: profile.id)
        }
        .fullScreenCover(item: $conversationRoute) { route in
            NavigationStack { ConversationView(conversationID: route.id, showsClose: true) }
        }
        .sheet(item: $selectedPost) { secili in
            let guncel = appState.posts.first(where: { $0.id == secili.id }) ?? secili
            NavigationStack {
                ScrollView {
                    PostCard(
                        post: guncel,
                        toggleLike: { appState.toggleLike(postID: guncel.id) },
                        toggleSaved: { appState.toggleSaved(postID: guncel.id) },
                        openProfile: {},
                        delete: {
                            appState.deletePost(guncel.id)
                            selectedPost = nil
                        }
                    )
                    .padding(.vertical, BondTheme.Space.md)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.Common.close) { selectedPost = nil }
                    }
                }
            }
        }
    }

    /// İlgi alanları eskiden üçle sınırlıydı ve hangilerinin ortak olduğu
    /// görünmüyordu. Ortak olanlar öne çıkarılıyor: tanışma sebebi zaten orada.
    @ViewBuilder private var interestList: some View {
        let hepsi = details?.interests ?? profile.interests
        if !hepsi.isEmpty {
            let benimkiler = isMe ? [] : appState.draft.interests
            let ortak = hepsi.filter { benimkiler.contains($0) }
            VStack(alignment: .leading, spacing: 8) {
                if !ortak.isEmpty {
                    Text(L10n.Profile.sharedInterests(ortak.count))
                        .font(.system(size: 11, weight: .bold)).tracking(0.7)
                        .foregroundStyle(BondTheme.violet)
                }
                FlowLayout(spacing: 7) {
                    ForEach(hepsi, id: \.self) { interest in
                        let paylasilan = benimkiler.contains(interest)
                        Text(InterestCatalog.displayName(interest))
                            .font(.system(size: 12, weight: paylasilan ? .bold : .medium))
                            .foregroundStyle(BondTheme.ink)
                            .padding(.horizontal, 11).frame(height: 30)
                            .background(cipZemini(paylasilan: paylasilan), in: Capsule())
                    }
                }
            }
        }
    }

    /// Galeri fotoğrafları. Kart tek bir fotoğraf gösteriyordu; kişi hakkında
    /// fikir edinmek için en çok işe yarayan şey diğer fotoğraflarıydı.
    @ViewBuilder private var gallery: some View {
        let fotograflar = details?.galleryURLs ?? profile.galleryImageURLs
        if !fotograflar.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.Profile.photos)
                    .font(.system(size: 11, weight: .bold)).tracking(0.7)
                    .foregroundStyle(kurucu ? BondTheme.ember : BondTheme.ink.opacity(0.45))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(fotograflar, id: \.self) { url in
                            ProfileMedia(url: url, data: nil)
                                .frame(width: 132, height: 176)
                                .clipShape(RoundedRectangle(cornerRadius: BondTheme.Radius.card, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    /// Kişinin paylaşımları. Profil ekranı yalnızca kartı gösteriyordu; kimin ne
    /// paylaştığını görmeden o kişi hakkında fikir edinmek zor. Sunucuda tek bir
    /// kişinin gönderilerini çeken bir yol yok, o yüzden yüklü akıştan süzülüyor —
    /// yeni bir sorgu ve yeni bir izin kuralı gerektirmiyor.
    @ViewBuilder private var personPosts: some View {
        let gonderiler = details?.posts ?? []
        if !gonderiler.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.Profile.theirPostsCaps)
                    .font(.system(size: 11, weight: .bold)).tracking(0.7)
                    .foregroundStyle(kurucu ? BondTheme.ember : BondTheme.ink.opacity(0.45))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                    ForEach(gonderiler) { post in
                        Button {
                            Haptics.impact(.light)
                            selectedPost = post
                        } label: {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    if post.imageURL != nil || post.imageAssetName != nil || post.localImageData != nil {
                                        ProfileMedia(url: post.imageURL, data: post.localImageData, assetName: post.imageAssetName)
                                    } else {
                                        Text(post.caption)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(BondTheme.ink)
                                            .lineLimit(5)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                            .background(BondTheme.acid.opacity(0.35))
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    private func openConversation() {
        guard let id = appState.conversationID(for: profile) else {
            appState.show(L10n.Profile.needMatchToChat)
            return
        }
        conversationRoute = ConversationRoute(id: id)
    }

    private func sendRequest() {
        guard let visiblePlace else { return }
        withAnimation(.snappy) {
            appState.sendMeetingRequest(to: profile, at: visiblePlace)
        }
    }
}

struct ConversationRoute: Identifiable {
    let id: UUID
}
