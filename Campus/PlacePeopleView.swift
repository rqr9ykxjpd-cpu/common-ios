import SwiftUI

struct PlacePeopleView: View {
    let place: CampusPlace
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var people: [StudentProfile] = []
    @State private var isLoading = true
    @State private var selectedPerson: StudentProfile?

    var body: some View {
        NavigationStack {
            ZStack {
                CampusTheme.paper.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        placeHeader
                        if isLoading {
                            ProgressView()
                                .tint(CampusTheme.violet)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else if people.isEmpty {
                            // Kimse görünmüyorsa bunu açıkça söylüyoruz; eskiden sahte
                            // isimlerle dolu olduğu için boş durum hiç görünmüyordu.
                            VStack(spacing: 8) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 26, weight: .light))
                                Text("Şu an burada görünen kimse yok")
                                    .font(.subheadline.bold())
                                Text("\"Buradayım\" diyerek ilk sen görün.")
                                    .font(.caption)
                                    .foregroundStyle(CampusTheme.ink.opacity(0.5))
                            }
                            .foregroundStyle(CampusTheme.ink.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(people) { profile in
                                personRow(profile)
                            }
                        }
                    }
                    .padding(18)
                }
                .refreshable { await reload() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedPerson) { profile in
                SocialPersonDetailView(profile: profile, place: place)
            }
            // Görünürlüğü açıp kapatmak listeyi tazelemiyordu: "buradayım" dedikten
            // sonra liste hâlâ eski halini gösteriyor, kullanıcı kendini göremiyordu.
            .task(id: appState.currentVisiblePlace?.id) { await reload() }
        }
    }

    private func reload() async {
        people = await appState.peopleAtPlace(place)
        isLoading = false
    }

    private var placeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                        .background(CampusTheme.surface, in: Circle())
                        .overlay(Circle().stroke(CampusTheme.hairline))
                }
                .accessibilityLabel("Kapat")
                Spacer()
                Eyebrow(text: "isteğe bağlı görünürlük", color: CampusTheme.ink.opacity(0.42))
            }
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(CampusTheme.violet)
            Text(place.name).editorialTitle(38)
            Text("Şu an burada görünür olan YÜ öğrencileri")
                .font(.subheadline)
                .foregroundStyle(CampusTheme.ink.opacity(0.5))
            // Kendisi artık listenin içinde; elle eklemek iki kez sayardı.
            Label("\(people.count) kişi görünür", systemImage: "person.2.fill")
                .font(.caption.bold())
                .foregroundStyle(CampusTheme.violet)

            Button { appState.togglePresence(at: place) } label: {
                HStack {
                    Image(systemName: isHere ? "checkmark.circle.fill" : "location.circle.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isHere ? "BURADASIN" : "BURADAYIM")
                            .font(.system(size: 11, weight: .black, design: .rounded)).tracking(1)
                        Text(isHere ? "Dokunarak görünürlüğü kapat" : "Bu yerde profilini görünür yap")
                            .font(.caption).opacity(0.65)
                    }
                    Spacer()
                }
                .foregroundStyle(isHere ? .white : CampusTheme.onAccent)
                .padding(.horizontal, 15).frame(height: 58)
                .background(isHere ? CampusTheme.violet : CampusTheme.acid, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressableStyle())
        }
        .foregroundStyle(CampusTheme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    private var isHere: Bool { appState.currentVisiblePlace?.id == place.id }

    /// Satır iki ayrı dokunma alanına bölündü: soldaki profili açıyor, sağdaki
    /// doğrudan buluşma isteği gönderiyor. Eskiden bütün satır tek bir bağlantıydı
    /// ve buluşma isteği ancak profile girip aşağı inince görünüyordu — aynı
    /// kafedeki birine seslenmek için üç dokunuş gerekiyordu.
    private func personRow(_ profile: StudentProfile) -> some View {
        let benMiyim = profile.id == appState.currentUserID
        let bekleyen = appState.meetingRequest(for: profile, at: place)
        return HStack(spacing: 10) {
            Button {
                selectedPerson = profile
            } label: {
                HStack(spacing: 13) {
                    ProfileMedia(url: profile.imageURL, data: nil, assetName: profile.imageAssetName)
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Text("\(profile.name), \(profile.age)").font(.headline)
                            ProfileBadgeLabel(badge: profile.badge, compact: true)
                        }
                        Text("\(profile.department) · \(profile.year)")
                            .font(.caption).foregroundStyle(CampusTheme.ink.opacity(0.5))
                        Label(place.name, systemImage: "location.fill")
                            .font(.caption.bold()).foregroundStyle(CampusTheme.violet)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())

            if benMiyim {
                Text("SEN")
                    .font(.system(size: 10, weight: .black, design: .rounded)).tracking(0.6)
                    .foregroundStyle(CampusTheme.ink.opacity(0.45))
            } else {
                Button {
                    Haptics.impact(.light)
                    appState.sendMeetingRequest(to: profile, at: place)
                } label: {
                    Image(systemName: bekleyen == nil ? "cup.and.saucer.fill" : "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(bekleyen == nil ? CampusTheme.onAccent : CampusTheme.ink.opacity(0.55))
                        .frame(width: 46, height: 46)
                        .background(bekleyen == nil ? CampusTheme.acid : CampusTheme.ink.opacity(0.08), in: Circle())
                }
                .buttonStyle(PressableStyle())
                .disabled(bekleyen != nil)
                .accessibilityLabel(bekleyen == nil ? "\(profile.name) kişisine burada buluşalım mı gönder" : "İstek gönderildi")
            }
        }
        .foregroundStyle(CampusTheme.ink)
        .padding(13)
        .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SocialPersonDetailView: View {
    let profile: StudentProfile
    let place: CampusPlace?
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
    private var pendingRequest: MeetingRequest? {
        guard let visiblePlace else { return nil }
        return appState.meetingRequest(for: profile, at: visiblePlace)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CampusTheme.paper.ignoresSafeArea()
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
                            Text(rozetAlt)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(CampusTheme.ink.opacity(0.5))
                        }
                        HStack {
                        }
                        Text("\(profile.department) · \(profile.university) · \(profile.year)")
                            .font(.subheadline.bold()).foregroundStyle(CampusTheme.ink.opacity(0.5))

                        if let visiblePlace {
                            HStack(spacing: 10) {
                                Image(systemName: "location.fill").foregroundStyle(CampusTheme.violet)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ŞU AN GÖRÜNÜR").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(0.7)
                                    Text(visiblePlace.name).font(.headline)
                                }
                                Spacer()
                                Circle().fill(.green).frame(width: 8, height: 8)
                            }
                            .padding(14)
                            .background(CampusTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        }

                        Text(profile.bio).font(.system(size: 16, design: .serif)).lineSpacing(4)

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
                                Label(reacted ? "Beğenin iletildi" : "Tanış",
                                      systemImage: reacted ? "checkmark" : "heart.fill")
                                    .font(.subheadline.bold()).foregroundStyle(CampusTheme.ink)
                                    .frame(maxWidth: .infinity).frame(height: 50)
                                    .background(reacted ? CampusTheme.ink.opacity(0.08) : CampusTheme.acid,
                                                in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(PressableStyle())
                            .disabled(reacted)

                            Text("Karşı taraf da seni beğenirse eşleşir ve yazışabilirsiniz.")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(CampusTheme.ink.opacity(0.45))
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                        Button { openConversation() } label: {
                            Label("Mesaj gönder", systemImage: "message.fill")
                                .font(.subheadline.bold()).foregroundStyle(CampusTheme.paper)
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .background(CampusTheme.ink, in: RoundedRectangle(cornerRadius: 14))
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
                                    Label(pendingRequest == nil ? "Burada buluşalım mı?" : "İstek gönderildi", systemImage: pendingRequest == nil ? "cup.and.saucer.fill" : "checkmark")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(pendingRequest == nil ? CampusTheme.onAccent : CampusTheme.ink.opacity(0.55))
                                        .frame(maxWidth: .infinity).frame(height: 50)
                                        .background(pendingRequest == nil ? CampusTheme.acid : CampusTheme.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(PressableStyle())
                                .disabled(pendingRequest != nil)

                                if pendingRequest == nil {
                                    Text("Yanıtsız bırakılırsa sana bildirim gitmez.")
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(CampusTheme.ink.opacity(0.45))
                                }
                            }
                        }
                    }
                    .foregroundStyle(CampusTheme.ink)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }

            Button { dismiss() } label: {
                Image(systemName: "arrow.left").foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(.black.opacity(0.55), in: Circle())
            }
            .accessibilityLabel("Geri")
            .padding(16)

            HStack {
                Spacer()
                Menu {
                    Menu {
                        ForEach(ReportReason.allCases) { reason in
                            Button(reason.title) { appState.report(profile, reason: reason) }
                        }
                    } label: {
                        Label("Şikâyet et", systemImage: "flag")
                    }
                    Button("Kullanıcıyı engelle", role: .destructive) {
                        appState.block(profile)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(.white)
                        .frame(width: 44, height: 44).background(.black.opacity(0.55), in: Circle())
                }
            }
            .padding(16)
        }
        .toolbar(.hidden, for: .navigationBar)
        // Ziyaret yalnızca birinin profili kasıtlı olarak açıldığında kaydedilir;
        // keşif destesinde kart çevirmek ziyaret sayılmaz.
        .task {
            appState.recordProfileVisit(profile)
            details = await appState.personDetails(for: profile.id)
        }
        .fullScreenCover(item: $conversationRoute) { route in
            NavigationStack { ConversationView(conversationID: route.id) }
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
                    .padding(.vertical, CampusTheme.Space.md)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Kapat") { selectedPost = nil }
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
                    Text("\(ortak.count) ORTAK İLGİ ALANI")
                        .font(.system(size: 11, weight: .bold, design: .rounded)).tracking(0.7)
                        .foregroundStyle(CampusTheme.violet)
                }
                ProfileFlowLayout(spacing: 7) {
                    ForEach(hepsi, id: \.self) { interest in
                        let paylasilan = benimkiler.contains(interest)
                        Text(interest)
                            .font(.system(size: 12, weight: paylasilan ? .bold : .medium, design: .rounded))
                            .foregroundStyle(CampusTheme.ink)
                            .padding(.horizontal, 11).frame(height: 30)
                            .background(paylasilan ? CampusTheme.acid.opacity(0.5) : CampusTheme.ink.opacity(0.055), in: Capsule())
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
                Text("FOTOĞRAFLARI")
                    .font(.system(size: 11, weight: .bold, design: .rounded)).tracking(0.7)
                    .foregroundStyle(CampusTheme.ink.opacity(0.45))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(fotograflar, id: \.self) { url in
                            ProfileMedia(url: url, data: nil)
                                .frame(width: 132, height: 176)
                                .clipShape(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
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
                Text("PAYLAŞIMLARI")
                    .font(.system(size: 11, weight: .bold, design: .rounded)).tracking(0.7)
                    .foregroundStyle(CampusTheme.ink.opacity(0.45))
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
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(CampusTheme.ink)
                                            .lineLimit(5)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                            .background(CampusTheme.acid.opacity(0.35))
                                    }
                                }
                                .clipped()
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: CampusTheme.Radius.control))
            }
        }
    }

    private func openConversation() {
        guard let id = appState.conversationID(for: profile) else {
            appState.show("Yazışmak için Tanış'ta eşleşmeniz gerekiyor.")
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

private struct ConversationRoute: Identifiable {
    let id: UUID
}
