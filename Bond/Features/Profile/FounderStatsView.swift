import SwiftUI

/// Kurucu: "Veriler" — kaç kişi, kaç Plus/Pro, akış ve bağlantı sayıları.
/// Sunucu rozeti kontrol eder; başka hesap çağırırsa hata alır.
struct FounderStatsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var stats: FounderStats?
    @State private var isLoading = true
    @State private var failure: String?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { _ in SkeletonRow() }
                    }
                    .padding(.horizontal, BondTheme.Space.lg)
                } else if let failure {
                    ScreenFailureView(message: failure) { Task { await load() } }
                        .padding(.horizontal, BondTheme.Space.lg)
                } else if let s = stats {
                    ScrollView {
                        VStack(alignment: .leading, spacing: BondTheme.Space.xl) {
                            section(L10n.Board.statsUsers, [
                                ("usersTotal", s.usersTotal, true), ("usersVerified", s.usersVerified, false),
                                ("usersToday", s.usersToday, false), ("usersWeek", s.usersWeek, false),
                                ("activeToday", s.activeToday, false), ("activeWeek", s.activeWeek, false),
                                ("presentNow", s.presentNow, false), ("reportsOpen", s.reportsOpen, false),
                            ])
                            section(L10n.Board.statsPlans, [
                                ("plus", s.plus, true), ("pro", s.pro, true),
                                ("free", max(0, s.usersTotal - s.plus - s.pro), false),
                            ])
                            section(L10n.Board.statsBoard, [
                                ("postsTotal", s.postsTotal, true), ("postsToday", s.postsToday, false),
                                ("commentsTotal", s.commentsTotal, false), ("votesTotal", s.votesTotal, false),
                                ("storiesActive", s.storiesActive, false),
                            ])
                            section(L10n.Board.statsPeople, [
                                ("matches", s.matches, true), ("messagesTotal", s.messagesTotal, false),
                                ("rightSwipes", s.rightSwipes, false), ("leftSwipes", s.leftSwipes, false),
                            ])
                        }
                        .padding(.horizontal, BondTheme.Space.lg)
                        .padding(.vertical, BondTheme.Space.md)
                    }
                    .refreshable { await load() }
                }
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Board.statsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    /// Başlık + iki sütunlu kutular. `accent` olan sayı turuncu: bölümün
    /// bir bakışta okunacak ana rakamı.
    private func section(_ title: String, _ items: [(String, Int, Bool)]) -> some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(BondTheme.muted)
                .tracking(0.6)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items, id: \.0) { key, value, accent in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(value.formatted())
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(accent ? BondTheme.burntOrange : BondTheme.ink)
                            .contentTransition(.numericText())
                        Text(L10n.Board.stat(key))
                            .font(.footnote)
                            .foregroundStyle(BondTheme.muted)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func load() async {
        failure = nil
        if stats == nil { isLoading = true }
        do {
            stats = try await appState.fetchFounderStats()
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.Board.founderActionFailed)
        }
        isLoading = false
    }
}
