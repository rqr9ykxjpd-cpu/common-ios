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
    @State private var askiyaAlinacak: ModerationReport?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                    Text(appState.pendingReports.isEmpty
                         ? L10n.Moderation.noneWaiting
                         : L10n.Moderation.waitingCount(appState.pendingReports.count))
                        .font(.system(size: 13))
                        .foregroundStyle(appState.pendingReports.isEmpty ? BondTheme.muted : BondTheme.coral)
                    if appState.reports.isEmpty, appState.isLoadingReports {
                        yukleniyor
                    } else if appState.reports.isEmpty {
                        bosDurum
                    } else {
                        bolum(L10n.Moderation.pending, appState.pendingReports)
                        bolum(L10n.Moderation.closed, appState.reports.filter { $0.handledAt != nil })
                    }
                }
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.top, BondTheme.Space.md)
                .padding(.bottom, BondTheme.Space.xxl)
            }
            .refreshable { await appState.loadReports() }
            .task(id: appState.myBadge) { await appState.loadReports() }
            .background(BondTheme.paper.ignoresSafeArea())
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
            .confirmationDialog(
                L10n.Moderation.suspendConfirm(askiyaAlinacak?.reported.name ?? ""),
                isPresented: Binding(
                    get: { askiyaAlinacak != nil },
                    set: { if !$0 { askiyaAlinacak = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L10n.Moderation.suspend, role: .destructive) {
                    if let kayit = askiyaAlinacak {
                        resolve(kayit, as: .accountSuspended)
                    }
                    askiyaAlinacak = nil
                }
                Button(L10n.Common.cancel, role: .cancel) {
                    askiyaAlinacak = nil
                }
            } message: {
                Text(L10n.Moderation.suspendHint)
            }
        }
    }


    private var yukleniyor: some View {
        VStack(spacing: 12) {
            ProgressView().tint(BondTheme.violet)
            Text(L10n.Moderation.loading)
                .font(.system(size: 13))
                .foregroundStyle(BondTheme.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    private var bosDurum: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(BondTheme.muted)
            Text(L10n.Moderation.empty)
                .font(.system(size: 15, weight: .semibold))
            Text(L10n.Moderation.emptyBody)
                .font(.system(size: 13))
                .foregroundStyle(BondTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    @ViewBuilder private func bolum(_ ad: String, _ kayitlar: [ModerationReport]) -> some View {
        if !kayitlar.isEmpty {
            VStack(alignment: .leading, spacing: BondTheme.Space.md) {
                Text(ad)
                    .font(.system(size: 11, weight: .bold)).tracking(0.7)
                    .foregroundStyle(BondTheme.muted)
                ForEach(kayitlar) { kayit in satir(kayit) }
            }
        }
    }

    private func satir(_ kayit: ModerationReport) -> some View {
        let calisiyor = islemdeki == kayit.id
        let kapali = kayit.handledAt != nil
        return VStack(alignment: .leading, spacing: BondTheme.Space.md) {
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
                                .foregroundStyle(BondTheme.ink)
                            Text(kayit.reason.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(BondTheme.coral)
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
                        .background(BondTheme.coral, in: Capsule())
                }
            }

            if let aciklama = kayit.details, !aciklama.isEmpty {
                Text(aciklama)
                    .font(.system(size: 14))
                    .foregroundStyle(BondTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(BondTheme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Kimin şikayet ettiği görünüyor: aynı kişiden gelen art arda
            // şikayetler ile farklı kişilerden gelenler aynı şey değil.
            HStack(spacing: 6) {
                Text(L10n.Moderation.reporter(kayit.reporter?.name ?? L10n.Moderation.unknown))
                Text("·")
                Text(kayit.createdAt.formatted(.relative(presentation: .named)))
            }
            .font(.system(size: 11))
            .foregroundStyle(BondTheme.muted)

            if kapali {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(BondTheme.violet)
                    Text(sonucMetni(kayit.resolution))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BondTheme.muted)
                    Spacer()
                    if !kayit.reportedActive {
                        Button(L10n.Moderation.reopen) { geriAcilacak = kayit }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(BondTheme.violet)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        eylem(L10n.Moderation.noIssue, .dismissed, kayit, zemin: BondTheme.ink.opacity(0.06),
                              yazi: BondTheme.ink)
                        eylem(L10n.Moderation.removedContent, .contentRemoved, kayit,
                              zemin: BondTheme.ink.opacity(0.06), yazi: BondTheme.ink)
                    }
                    eylem(L10n.Moderation.suspend, .accountSuspended, kayit,
                          zemin: BondTheme.coral, yazi: .white)
                }
                .disabled(calisiyor)
                .opacity(calisiyor ? 0.5 : 1)

                // Askıya almanın ne yaptığını önden söylüyoruz: geri
                // alınabilir ama etkisi geniş.
                Text(L10n.Moderation.suspendHint)
                    .font(.system(size: 11))
                    .foregroundStyle(BondTheme.muted)
            }
        }
        .padding(BondTheme.Space.md)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous).stroke(BondTheme.hairline))
    }

    private func eylem(_ baslik: String, _ sonuc: ModerationReport.Resolution,
                       _ kayit: ModerationReport, zemin: Color, yazi: Color) -> some View {
        Button {
            if sonuc == .accountSuspended {
                askiyaAlinacak = kayit
            } else {
                resolve(kayit, as: sonuc)
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

    private func resolve(_ report: ModerationReport, as resolution: ModerationReport.Resolution) {
        islemdeki = report.id
        Task {
            await appState.resolveReport(report, resolution: resolution)
            islemdeki = nil
        }
    }

    private func sonucMetni(_ raw: String?) -> String {
        switch raw {
        case "content_removed": L10n.Moderation.resultRemoved
        case "account_suspended": L10n.Moderation.resultSuspended
        default: L10n.Moderation.resultClear
        }
    }
}
