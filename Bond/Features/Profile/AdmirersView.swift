import SwiftUI

/// Hesabımı sağa kaydıranlar. Yalnızca kurucu hesapta görünüyor.
///
/// Arayüzdeki `isFounder` kontrolü sadece girişi gizliyor; listeyi döndüren
/// `who_liked_me` fonksiyonu rozeti sunucuda ayrıca doğruluyor. Yani bu ekran
/// bir şekilde açılsa bile kurucu olmayan biri boş/hatalı sonuç alır.
struct AdmirersView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                    if !appState.admirers.isEmpty {
                        Text(L10n.Profile.admirersCount(appState.admirers.count))
                            .font(.system(size: 13))
                            .foregroundStyle(BondTheme.muted)
                    }

                    if appState.admirers.isEmpty, appState.isLoadingAdmirers {
                        yukleniyor
                    } else if appState.admirers.isEmpty {
                        bosDurum
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(appState.admirers) { kisi in
                                NavigationLink {
                                    SocialPersonDetailView(profile: kisi.profile, place: nil)
                                } label: {
                                    satir(kisi)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.top, BondTheme.Space.md)
                .padding(.bottom, BondTheme.Space.xxl)
            }
            .refreshable { await appState.loadAdmirers() }
            .task(id: appState.myBadge) { await appState.loadAdmirers() }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Profile.admirers)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
        }
    }

    private func satir(_ kisi: Admirer) -> some View {
        HStack(spacing: 12) {
            ProfileMedia(url: kisi.profile.imageURL, data: nil,
                         assetName: kisi.profile.imageAssetName)
                .frame(width: 44, height: 44)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(kisi.profile.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(BondTheme.ink)
                    if kisi.isMatched {
                        Text(L10n.Profile.admirersMatched)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(BondTheme.onAccent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(BondTheme.acid, in: Capsule())
                    }
                }
                Text(kisi.profile.department)
                    .font(.system(size: 13))
                    .foregroundStyle(BondTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(kisi.likedAt.formatted(.relative(presentation: .named)))
                .font(.system(size: 12))
                .foregroundStyle(BondTheme.muted)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var yukleniyor: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
    }

    private var bosDurum: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(BondTheme.muted)
            Text(L10n.Profile.admirersEmpty)
                .font(.system(size: 15, weight: .semibold))
            Text(L10n.Profile.admirersEmptyHint)
                .font(.system(size: 13))
                .foregroundStyle(BondTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
