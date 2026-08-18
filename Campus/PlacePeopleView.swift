import SwiftUI

struct PlacePeopleView: View {
    let place: CampusPlace
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var people: [StudentProfile] = []
    @State private var isLoading = true

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
                                NavigationLink {
                                    SocialPersonDetailView(profile: profile, place: place)
                                } label: {
                                    personRow(profile)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                    .padding(18)
                }
                .refreshable { await reload() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await reload() }
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
            Label("\(people.count + (isHere ? 1 : 0)) kişi görünür", systemImage: "person.2.fill")
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
                .foregroundStyle(isHere ? .white : CampusTheme.ink)
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

    private func personRow(_ profile: StudentProfile) -> some View {
        HStack(spacing: 13) {
            ProfileMedia(url: profile.imageURL, data: nil, assetName: profile.imageAssetName)
                .frame(width: 64, height: 64)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text("\(profile.name), \(profile.age)").font(.headline)
                    if profile.isVerified {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(CampusTheme.violet)
                    }
                }
                Text("\(profile.department) · \(profile.year)")
                    .font(.caption).foregroundStyle(CampusTheme.ink.opacity(0.5))
                Label(place.name, systemImage: "location.fill")
                    .font(.caption.bold()).foregroundStyle(CampusTheme.violet)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(CampusTheme.ink.opacity(0.3))
        }
        .foregroundStyle(CampusTheme.ink)
        .padding(13)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SocialPersonDetailView: View {
    let profile: StudentProfile
    let place: CampusPlace?
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var conversationRoute: ConversationRoute?

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
                            if profile.isVerified {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(CampusTheme.violet)
                            }
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

                        HStack(spacing: 8) {
                            ForEach(profile.interests.prefix(3), id: \.self) { interest in
                                Text(interest.uppercased()).font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 10).frame(height: 28)
                                    .overlay(Capsule().stroke(CampusTheme.ink.opacity(0.18)))
                            }
                        }

                        Button { openConversation() } label: {
                            Label("Mesaj gönder", systemImage: "message.fill")
                                .font(.subheadline.bold()).foregroundStyle(CampusTheme.paper)
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .background(CampusTheme.ink, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(PressableStyle())

                        if visiblePlace != nil {
                            Button { sendRequest() } label: {
                                Label(pendingRequest == nil ? "Buluşma isteği gönder" : "İstek gönderildi", systemImage: pendingRequest == nil ? "cup.and.saucer.fill" : "checkmark")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(pendingRequest == nil ? CampusTheme.ink : CampusTheme.ink.opacity(0.55))
                                    .frame(maxWidth: .infinity).frame(height: 50)
                                    .background(pendingRequest == nil ? CampusTheme.acid : CampusTheme.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(PressableStyle())
                            .disabled(pendingRequest != nil)
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
        .task { appState.recordProfileVisit(profile) }
        .fullScreenCover(item: $conversationRoute) { route in
            NavigationStack { ConversationView(conversationID: route.id) }
        }
    }

    private func openConversation() {
        conversationRoute = ConversationRoute(id: appState.conversationID(for: profile))
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
