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
                VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                    Text(L10n.Chat.requestsIntro)
                        .font(.system(size: 13))
                        .foregroundStyle(BondTheme.muted)
                    if istekler.isEmpty {
                        bosDurum
                    } else {
                        LazyVStack(spacing: BondTheme.Space.md) {
                            ForEach(istekler) { istek in
                                satir(istek)
                            }
                        }
                    }
                }
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.top, BondTheme.Space.md)
                .padding(.bottom, BondTheme.Space.xxl)
            }
            .refreshable { await appState.loadMessageRequests() }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Chat.requestsTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .navigationDestination(item: $acilacakSohbet) { id in
                ConversationView(conversationID: id)
            }
        }
    }


    private var bosDurum: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(BondTheme.muted)
            Text(L10n.Chat.noRequests)
                .font(.system(size: 15, weight: .semibold))
            Text(L10n.Chat.noRequestsBody)
                .font(.system(size: 13))
                .foregroundStyle(BondTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func satir(_ istek: MessageRequest) -> some View {
        let calisiyor = islemdeki == istek.id
        return VStack(alignment: .leading, spacing: BondTheme.Space.md) {
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
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(BondTheme.ink)
                            ProfileBadgeLabel(badge: istek.profile.badge, compact: true)
                        }
                        Text("\(istek.profile.department) · \(AcademicYear.display(istek.profile.year))")
                            .font(.system(size: 12))
                            .foregroundStyle(BondTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BondTheme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())

            Text(istek.body)
                .font(.system(size: 15))
                .foregroundStyle(BondTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(BondTheme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    islemdeki = istek.id
                    Task {
                        await appState.declineMessageRequest(istek.id)
                        islemdeki = nil
                    }
                } label: {
                    Text(L10n.Chat.decline)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(BondTheme.ink)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(BondTheme.ink.opacity(0.06), in: Capsule())
                }
                .buttonStyle(PressableStyle())

                Button {
                    islemdeki = istek.id
                    Task {
                        acilacakSohbet = await appState.acceptMessageRequest(istek.id)
                        islemdeki = nil
                    }
                } label: {
                    Text(L10n.Chat.accept)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(BondTheme.onAccent)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(BondTheme.acid, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            .disabled(calisiyor)
            .opacity(calisiyor ? 0.5 : 1)

            // Reddetmenin kalıcı olduğunu önden söylüyoruz: geri alınamayan bir
            // karar, sonucunu söylemeden sunulmamalı.
            Text(L10n.Chat.requestFootnote)
                .font(.system(size: 11))
                .foregroundStyle(BondTheme.muted)
        }
        .padding(BondTheme.Space.md)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BondTheme.Radius.card, style: .continuous).stroke(BondTheme.hairline))
    }
}
