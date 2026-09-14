import SwiftUI

/// Kurucu: "Beni kaydıranlar" — kartımı sağa/sola kimin kaydırdığı, en yeni
/// önce. Başka kimse için böyle bir ekran yok; sunucu rozeti kontrol eder.
struct ProfileSwipersView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var swipers: [ProfileSwiper] = []
    @State private var isLoading = true
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { _ in SkeletonRow() }
                    }
                    .padding(.horizontal, BondTheme.Space.lg)
                } else if let failure {
                    ScreenFailureView(message: failure) { Task { await load() } }
                        .padding(.horizontal, BondTheme.Space.lg)
                } else if swipers.isEmpty {
                    ContentUnavailableView(L10n.Board.swipersEmpty, systemImage: "hand.draw")
                } else {
                    List(swipers) { kisi in
                        HStack(spacing: BondTheme.Space.compact) {
                            ProfileMedia(url: kisi.avatarURL, data: nil, assetName: kisi.avatarAssetName)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kisi.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(kisi.isMatched ? L10n.Board.swiperMatched : kisi.swipedAt.relativeTurkish)
                                    .font(.caption)
                                    .foregroundStyle(BondTheme.muted)
                            }
                            Spacer()
                            // Sağ: dolu ok, turuncu. Sol: soluk ok. Kurucu tek bakışta ayırır.
                            Image(systemName: kisi.swipedRight ? "arrow.right.circle.fill" : "arrow.left.circle")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(kisi.swipedRight ? BondTheme.burntOrange : BondTheme.muted)
                                .accessibilityLabel(kisi.swipedRight ? L10n.Board.swipedRight : L10n.Board.swipedLeft)
                        }
                        .foregroundStyle(BondTheme.ink)
                        .listRowBackground(BondTheme.paper)
                    }
                    .listStyle(.plain)
                }
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Board.swipersTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        failure = nil
        do {
            swipers = try await appState.fetchProfileSwipers()
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.Board.founderActionFailed)
        }
        isLoading = false
    }
}
