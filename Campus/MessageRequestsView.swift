import SwiftUI

/// Eşleşmeden gelen yanıt istekleri.
///
/// Bu ekran olmasaydı istek yalnızca bir bildirim satırı olarak kalırdı ve
/// bildirimi kaçıran kişi kendisine yazıldığını hiç öğrenemezdi.
///
/// Kabul edilmeden mesaj sohbete düşmüyor. Reddetmek kalıcı: karşı taraf bir
/// daha yazamıyor ve reddedildiği kendisine bildirilmiyor.
struct MessageRequestsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Kabul edilince açılacak sohbet.
    @State private var acilacakSohbet: UUID?
    @State private var islemdeki: UUID?

    private var istekler: [MessageRequest] { appState.pendingMessageRequests }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CampusTheme.Space.lg) {
                    baslik
                    if istekler.isEmpty {
                        bosDurum
                    } else {
                        LazyVStack(spacing: CampusTheme.Space.md) {
                            ForEach(istekler) { istek in
                                satir(istek)
                            }
                        }
                    }
                }
                .padding(.horizontal, CampusTheme.Space.lg)
                .padding(.top, CampusTheme.Space.md)
                .padding(.bottom, CampusTheme.Space.xxl)
            }
            .refreshable { await appState.loadMessageRequests() }
            .background(CampusTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $acilacakSohbet) { id in
                ConversationView(conversationID: id)
            }
        }
    }

    private var baslik: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Yanıt istekleri")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Eşleşmediğin kişilerden gelen mesajlar")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
            }
            Spacer()
            AppIconButton(systemName: "xmark") { dismiss() }
        }
    }

    private var bosDurum: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(CampusTheme.muted)
            Text("Bekleyen istek yok")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text("Biri story'ne yazarsa isteği burada göreceksin.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(CampusTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func satir(_ istek: MessageRequest) -> some View {
        let calisiyor = islemdeki == istek.id
        return VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            // Kime ait olduğu profil kartına gitmeden anlaşılmalı: kabul kararı
            // yalnızca mesaja değil, kişiye de bakılarak veriliyor.
            NavigationLink {
                SocialPersonDetailView(profile: istek.profile, place: nil)
            } label: {
                HStack(spacing: 12) {
                    ProfileMedia(url: istek.profile.imageURL, data: nil,
                                 assetName: istek.profile.imageAssetName)
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(istek.profile.name)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(CampusTheme.ink)
                            ProfileBadgeLabel(badge: istek.profile.badge, compact: true)
                        }
                        Text("\(istek.profile.department) · \(istek.profile.year)")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(CampusTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CampusTheme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())

            Text(istek.body)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(CampusTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(CampusTheme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    islemdeki = istek.id
                    Task {
                        await appState.declineMessageRequest(istek.id)
                        islemdeki = nil
                    }
                } label: {
                    Text("Reddet")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(CampusTheme.ink)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(CampusTheme.ink.opacity(0.06), in: Capsule())
                }
                .buttonStyle(PressableStyle())

                Button {
                    islemdeki = istek.id
                    Task {
                        acilacakSohbet = await appState.acceptMessageRequest(istek.id)
                        islemdeki = nil
                    }
                } label: {
                    Text("Kabul et")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(CampusTheme.onAccent)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(CampusTheme.acid, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            .disabled(calisiyor)
            .opacity(calisiyor ? 0.5 : 1)

            // Reddetmenin kalıcı olduğunu önden söylüyoruz: geri alınamayan bir
            // karar, sonucunu söylemeden sunulmamalı.
            Text("Kabul edersen eşleşirsiniz ve mesajı sohbette görürsün. Reddedersen bir daha sana yazamaz.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(CampusTheme.muted)
        }
        .padding(CampusTheme.Space.md)
        .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous).stroke(CampusTheme.hairline))
    }
}
