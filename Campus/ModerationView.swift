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
                    baslik
                    if appState.reports.isEmpty, appState.isLoadingReports {
                        yukleniyor
                    } else if appState.reports.isEmpty {
                        bosDurum
                    } else {
                        bolum("BEKLEYEN", appState.pendingReports)
                        bolum("KAPATILAN", appState.reports.filter { $0.handledAt != nil })
                    }
                }
                .padding(.horizontal, CampusTheme.Space.lg)
                .padding(.top, CampusTheme.Space.md)
                .padding(.bottom, CampusTheme.Space.xxl)
            }
            .refreshable { await appState.loadReports() }
            .task(id: appState.myBadge) { await appState.loadReports() }
            .background(CampusTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Hesabı geri aç",
                isPresented: Binding(get: { geriAcilacak != nil }, set: { if !$0 { geriAcilacak = nil } }),
                titleVisibility: .visible
            ) {
                Button("Geri aç") {
                    if let kayit = geriAcilacak {
                        Task { await appState.reactivateAccount(kayit.reported.id) }
                    }
                    geriAcilacak = nil
                }
                Button("Vazgeç", role: .cancel) { geriAcilacak = nil }
            } message: {
                Text("\(geriAcilacak?.reported.name ?? "") tekrar uygulamaya girebilecek ve keşifte görünecek.")
            }
        }
    }

    private var baslik: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Şikayetler")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(appState.pendingReports.isEmpty
                     ? "Bekleyen şikayet yok"
                     : "\(appState.pendingReports.count) şikayet bekliyor")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(appState.pendingReports.isEmpty ? CampusTheme.muted : CampusTheme.coral)
            }
            Spacer()
            AppIconButton(systemName: "xmark") { dismiss() }
        }
    }

    private var yukleniyor: some View {
        VStack(spacing: 12) {
            ProgressView().tint(CampusTheme.violet)
            Text("Şikayetler yükleniyor…")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(CampusTheme.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    private var bosDurum: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(CampusTheme.muted)
            Text("Hiç şikayet yok")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text("Biri bir hesabı şikayet ettiğinde burada göreceksin.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(CampusTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    @ViewBuilder private func bolum(_ ad: String, _ kayitlar: [ModerationReport]) -> some View {
        if !kayitlar.isEmpty {
            VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
                Text(ad)
                    .font(.system(size: 11, weight: .bold, design: .rounded)).tracking(0.7)
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
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(CampusTheme.ink)
                            Text(kayit.reason.title)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(CampusTheme.coral)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                Spacer()
                if !kayit.reportedActive {
                    Text("ASKIDA")
                        .font(.system(size: 10, weight: .black, design: .rounded)).tracking(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).frame(height: 22)
                        .background(CampusTheme.coral, in: Capsule())
                }
            }

            if let aciklama = kayit.details, !aciklama.isEmpty {
                Text(aciklama)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(CampusTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(CampusTheme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Kimin şikayet ettiği görünüyor: aynı kişiden gelen art arda
            // şikayetler ile farklı kişilerden gelenler aynı şey değil.
            HStack(spacing: 6) {
                Text("Şikayet eden: \(kayit.reporter?.name ?? "bilinmiyor")")
                Text("·")
                Text(kayit.createdAt.formatted(.relative(presentation: .named)))
            }
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(CampusTheme.muted)

            if kapali {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(CampusTheme.violet)
                    Text(sonucMetni(kayit.resolution))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(CampusTheme.muted)
                    Spacer()
                    if !kayit.reportedActive {
                        Button("Geri aç") { geriAcilacak = kayit }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(CampusTheme.violet)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        eylem("Sorun yok", .dismissed, kayit, zemin: CampusTheme.ink.opacity(0.06),
                              yazi: CampusTheme.ink)
                        eylem("İçeriği kaldırdım", .contentRemoved, kayit,
                              zemin: CampusTheme.ink.opacity(0.06), yazi: CampusTheme.ink)
                    }
                    eylem("Hesabı askıya al", .accountSuspended, kayit,
                          zemin: CampusTheme.coral, yazi: .white)
                }
                .disabled(calisiyor)
                .opacity(calisiyor ? 0.5 : 1)

                // Askıya almanın ne yaptığını önden söylüyoruz: geri
                // alınabilir ama etkisi geniş.
                Text("Askıya alınan hesap keşifte çıkmaz, profili görünmez ve yeni içerik paylaşamaz. Buradan geri açabilirsin.")
                    .font(.system(size: 11, design: .rounded))
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
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(yazi)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(zemin, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private func sonucMetni(_ raw: String?) -> String {
        switch raw {
        case "content_removed": "İçerik kaldırıldı"
        case "account_suspended": "Hesap askıya alındı"
        default: "Sorun bulunmadı"
        }
    }
}
