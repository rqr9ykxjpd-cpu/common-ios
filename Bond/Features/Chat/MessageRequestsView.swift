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
    /// Satırdaki "…" menüsünden şikayet edilecek ya da engellenecek istek.
    /// Tanımadığın biri yazdığında bunun için profiline girmek gerekmesin.
    @State private var sikayetEdilecek: MessageRequest?
    @State private var engellenecek: MessageRequest?

    private var istekler: [MessageRequest] { appState.pendingMessageRequests }

    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                    Text(L10n.Chat.requestsIntro)
                        .font(BondTheme.Typography.footnote)
                        .foregroundStyle(BondTheme.muted)
                    if istekler.isEmpty {
                        requestState
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
            .task { await appState.loadMessageRequests() }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Chat.requestsTitle)
            .navigationDestination(item: $acilacakSohbet) { id in
                ConversationView(conversationID: id)
            }
            .confirmationDialog(
                L10n.Common.report,
                isPresented: Binding(get: { sikayetEdilecek != nil }, set: { if !$0 { sikayetEdilecek = nil } }),
                titleVisibility: .visible,
                presenting: sikayetEdilecek
            ) { istek in
                ForEach(ReportReason.allCases) { reason in
                    Button(reason.title) {
                        appState.report(istek.profile, reason: reason)
                        sikayetEdilecek = nil
                    }
                }
                Button(L10n.Common.cancel, role: .cancel) { sikayetEdilecek = nil }
            }
            .confirmationDialog(
                L10n.Chat.blockConfirm(engellenecek?.profile.name ?? L10n.Common.someone),
                isPresented: Binding(get: { engellenecek != nil }, set: { if !$0 { engellenecek = nil } }),
                titleVisibility: .visible,
                presenting: engellenecek
            ) { istek in
                Button(L10n.Common.block, role: .destructive) {
                    engellenecek = nil
                    appState.block(istek.profile)
                    // Engellemek istekleri temizlemiyor; istek de kalıcı olarak reddedilsin
                    // ki liste yenilenince geri gelmesin.
                    Task { await appState.declineMessageRequest(istek.id) }
                }
                Button(L10n.Common.cancel, role: .cancel) { engellenecek = nil }
            } message: { _ in
                Text(L10n.Chat.blockBody)
            }
    }

    @ViewBuilder
    private var requestState: some View {
        if appState.isLoadingMessageRequests {
            VStack(spacing: 0) { ForEach(0..<3, id: \.self) { _ in SkeletonRow() } }
                .padding(.horizontal, BondTheme.Space.lg)
        } else if let error = appState.messageRequestsError {
            ContentUnavailableView {
                Label(L10n.Errors.title, systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button(L10n.Common.retry) {
                    Task { await appState.loadMessageRequests() }
                }
                .buttonStyle(.borderedProminent)
                .tint(BondTheme.acid)
            }
        } else {
            bosDurum
        }
    }


    private var bosDurum: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(BondTheme.muted)
                .idleFloat()
            Text(L10n.Chat.noRequests)
                .font(BondTheme.Typography.headline)
            Text(L10n.Chat.noRequestsBody)
                .font(BondTheme.Typography.footnote)
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
            HStack(spacing: 4) {
            NavigationLink {
                SocialPersonDetailView(profile: istek.profile, place: nil)
            } label: {
                HStack(spacing: BondTheme.Space.compact) {
                    ProfileMedia(url: istek.profile.imageURL, data: nil,
                                 assetName: istek.profile.imageAssetName)
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(istek.profile.name)
                                .font(BondTheme.Typography.subheadline.weight(.bold))
                                .foregroundStyle(BondTheme.ink)
                            ProfileBadgeLabel(badge: istek.profile.badge, compact: true)
                        }
                        Text("\(istek.profile.department) · \(AcademicYear.display(istek.profile.year))")
                            .font(BondTheme.Typography.caption)
                            .foregroundStyle(BondTheme.muted)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BondTheme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())

                Menu {
                    Button(L10n.Common.report, systemImage: "flag") { sikayetEdilecek = istek }
                    Button(L10n.Common.block, systemImage: "hand.raised", role: .destructive) { engellenecek = istek }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BondTheme.muted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(L10n.Common.options)
            }

            Text(istek.body)
                .font(BondTheme.Typography.body)
                .foregroundStyle(BondTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BondTheme.Space.compact)
                .background(BondTheme.paper, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: BondTheme.Space.compact) {
                    declineButton(for: istek)
                    acceptButton(for: istek)
                }
                VStack(spacing: BondTheme.Space.sm) {
                    declineButton(for: istek)
                    acceptButton(for: istek)
                }
            }
            .disabled(calisiyor)
            .opacity(calisiyor ? 0.5 : 1)

            // Reddetmenin kalıcı olduğunu önden söylüyoruz: geri alınamayan bir
            // karar, sonucunu söylemeden sunulmamalı.
            Text(L10n.Chat.requestFootnote)
                .font(BondTheme.Typography.caption)
                .foregroundStyle(BondTheme.muted)
        }
        .padding(BondTheme.Space.md)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous).stroke(BondTheme.hairline))
    }

    private func declineButton(for request: MessageRequest) -> some View {
        Button {
            islemdeki = request.id
            Task {
                await appState.declineMessageRequest(request.id)
                islemdeki = nil
            }
        } label: {
            Text(L10n.Chat.decline)
                .font(BondTheme.Typography.footnote.weight(.semibold))
                .foregroundStyle(BondTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(BondTheme.ink.opacity(0.06), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private func acceptButton(for request: MessageRequest) -> some View {
        Button {
            islemdeki = request.id
            Task {
                acilacakSohbet = await appState.acceptMessageRequest(request.id)
                islemdeki = nil
            }
        } label: {
            Text(L10n.Chat.accept)
                .font(BondTheme.Typography.footnote.weight(.semibold))
                .foregroundStyle(BondTheme.onAccent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(BondTheme.acid, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}
