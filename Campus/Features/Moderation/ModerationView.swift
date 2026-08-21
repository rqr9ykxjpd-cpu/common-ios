import SwiftUI

/// Şikayet kutusu — yalnızca kurucu ve moderatörlere açık.
///
/// Bu ekran olmadan şikayetler hiçbir yere ulaşmıyordu: kayıt tabloya
/// düşüyor ama kimse okuyamıyordu. App Store, kullanıcı içeriği barındıran
/// uygulamalardan şikayeti 24 saat içinde değerlendirip içeriği kaldırmayı ve
/// gerekiyorsa hesabı çıkarmayı istiyor; mağaza notlarımızda bunu yaptığımızı
/// yazıyoruz.
struct ModerationView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var islemdeki: UUID?
    @State private var geriAcilacak: ModerationReport?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CampusTheme.Space.lg) {
                    Text(appState.pendingReports.isEmpty
                         ? L10n.Moderation.noneWaiting
                         : L10n.Moderation.waitingCount(appState.pendingReports.count))
                        .font(.system(size: 13))
                        .foregroundStyle(appState.pendingReports.isEmpty ? CampusTheme.muted : CampusTheme.coral)
                    if appState.reports.isEmpty, appState.isLoadingReports {
                        yukleniyor
                    } else if appState.reports.isEmpty {
                        bosDurum
                    } else {
                        bolum(L10n.Moderation.pending, appState.pendingReports)
                        bolum(L10n.Moderation.closed, appState.reports.filter { $0.handledAt != nil })
                    }
                }
                .padding(.horizontal, CampusTheme.Space.lg)
                .padding(.top, CampusTheme.Space.md)
                .padding(.bottom, CampusTheme.Space.xxl)
            }
            .refreshable { await appState.loadReports() }
            .task(id: appState.myBadge) { await appState.loadReports() }
            .background(CampusTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Moderation.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .confirmationDialog(
                L10n.Moderation.reopenTitle,
                isPresented: Binding(get: { geriAcilacak != nil }, set: { if !$0 { geriAcilacak = nil } }),
                titleVisibility: .visible
            ) {
                Button(L10n.Moderation.reopen) {
                    if let kayit = geriAcilacak {
                        Task { await appState.reactivateAccount(kayit.reported.id) }
                    }
                    geriAcilacak = nil
                }
                Button(L10n.Common.cancel, role: .cancel) { geriAcilacak = nil }
            } message: {
                Text(L10n.Moderation.reopenBody(geriAcilacak?.reported.name ?? ""))
            }
        }
    }


    private var yukleniyor: some View {
        VStack(spacing: 12) {
            ProgressView().tint(CampusTheme.violet)
            Text(L10n.Moderation.loading)
                .font(.system(size: 13))
                .foregroundStyle(CampusTheme.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    private var bosDurum: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(CampusTheme.muted)
            Text(L10n.Moderation.empty)
                .font(.system(size: 15, weight: .semibold))
            Text(L10n.Moderation.emptyBody)
                .font(.system(size: 13))
                .foregroundStyle(CampusTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    @ViewBuilder private func bolum(_ ad: String, _ kayitlar: [ModerationReport]) -> some View {
        if !kayitlar.isEmpty {
            VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
                Text(ad)
                    .font(.system(size: 11, weight: .bold)).tracking(0.7)
                    .foregroundStyle(CampusTheme.ink.opacity(0.45))
                ForEach(kayitlar) { kayit in satir(kayit) }
            }
        }
    }

    private func satir(_ kayit: ModerationReport) -> some View {
        let calisiyor = islemdeki == kayit.id
        let kapali = kayit.handledAt != nil
        return VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            HStack(spacing: 12) {
                NavigationLink {
                    SocialPersonDetailView(profile: kayit.reported, place: nil)
                } label: {
                    HStack(spacing: 12) {
                        ProfileMedia(url: kayit.reported.imageURL, data: nil,
                                     assetName: kayit.reported.imageAssetName)
                            .frame(width: 44, height: 44).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kayit.reported.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(CampusTheme.ink)
                            Text(kayit.reason.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CampusTheme.coral)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                Spacer()
                if !kayit.reportedActive {
                    Text(L10n.Moderation.suspended)
                        .font(.system(size: 10, weight: .black)).tracking(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).frame(height: 22)
                        .background(CampusTheme.coral, in: Capsule())
                }
            }

            if let aciklama = kayit.details, !aciklama.isEmpty {
                Text(aciklama)
                    .font(.system(size: 14))
                    .foregroundStyle(CampusTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(CampusTheme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Kimin şikayet ettiği görünüyor: aynı kişiden gelen art arda
            // şikayetler ile farklı kişilerden gelenler aynı şey değil.
            HStack(spacing: 6) {
                Text(L10n.Moderation.reporter(kayit.reporter?.name ?? L10n.Moderation.unknown))
                Text("·")
                Text(kayit.createdAt.formatted(.relative(presentation: .named)))
            }
            .font(.system(size: 11))
            .foregroundStyle(CampusTheme.muted)

            if kapali {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(CampusTheme.violet)
                    Text(sonucMetni(kayit.resolution))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CampusTheme.muted)
                    Spacer()
                    if !kayit.reportedActive {
                        Button(L10n.Moderation.reopen) { geriAcilacak = kayit }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(CampusTheme.violet)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        eylem(L10n.Moderation.noIssue, .dismissed, kayit, zemin: CampusTheme.ink.opacity(0.06),
                              yazi: CampusTheme.ink)
                        eylem(L10n.Moderation.removedContent, .contentRemoved, kayit,
                              zemin: CampusTheme.ink.opacity(0.06), yazi: CampusTheme.ink)
                    }
                    eylem(L10n.Moderation.suspend, .accountSuspended, kayit,
                          zemin: CampusTheme.coral, yazi: .white)
                }
                .disabled(calisiyor)
                .opacity(calisiyor ? 0.5 : 1)

                // Askıya almanın ne yaptığını önden söylüyoruz: geri
                // alınabilir ama etkisi geniş.
                Text(L10n.Moderation.suspendHint)
                    .font(.system(size: 11))
                    .foregroundStyle(CampusTheme.muted)
            }
        }
        .padding(CampusTheme.Space.md)
        .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous).stroke(CampusTheme.hairline))
    }

    private func eylem(_ baslik: String, _ sonuc: ModerationReport.Resolution,
                       _ kayit: ModerationReport, zemin: Color, yazi: Color) -> some View {
        Button {
            islemdeki = kayit.id
            Task {
                await appState.resolveReport(kayit, resolution: sonuc)
                islemdeki = nil
            }
        } label: {
            Text(baslik)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(yazi)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(zemin, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private func sonucMetni(_ raw: String?) -> String {
        switch raw {
        case "content_removed": L10n.Moderation.resultRemoved
        case "account_suspended": L10n.Moderation.resultSuspended
        default: L10n.Moderation.resultClear
        }
    }
}
