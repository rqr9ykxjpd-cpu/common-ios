import SwiftUI

/// Kurucu paneli — canlı sayılar, planlar, akış, bağlantılar ve herkese
/// duyuru gönderme. Sunucu rozeti kontrol eder; başka hesap çağırırsa hata alır.
struct FounderStatsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var stats: FounderStats?
    @State private var isLoading = true
    @State private var failure: String?
    // Duyuru
    @State private var broadcastTitle = ""
    @State private var broadcastBody = ""
    @State private var isSending = false
    @State private var confirmSend = false
    @State private var sentMessage: String?
    @State private var sentOK = true

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
                            section(L10n.Board.statsLive, [
                                ("onlineNow", s.onlineNow, true), ("presentNow", s.presentNow, false),
                                ("activeToday", s.activeToday, false), ("pushDevices", s.pushDevices, false),
                            ])
                            broadcastSection
                            section(L10n.Board.statsUsers, [
                                ("usersTotal", s.usersTotal, true), ("usersVerified", s.usersVerified, false),
                                ("usersToday", s.usersToday, false), ("usersWeek", s.usersWeek, false),
                                ("activeWeek", s.activeWeek, false), ("reportsOpen", s.reportsOpen, false),
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
            .scrollDismissesKeyboard(.interactively)
            .alert(L10n.Board.broadcastTitle, isPresented: $confirmSend) {
                Button(L10n.Board.broadcastSend(stats?.usersTotal ?? 0)) { Task { await send(testOnly: false) } }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Board.broadcastConfirm(stats?.usersTotal ?? 0))
            }
            .task { await load() }
        }
    }

    /// Başlık + mesaj; önce kendine test, sonra herkese (onaylı).
    private var broadcastSection: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            Text(L10n.Board.broadcastTitle.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(BondTheme.muted)
                .tracking(0.6)
            VStack(alignment: .leading, spacing: 10) {
                TextField(L10n.Board.broadcastTitleField, text: $broadcastTitle)
                    .font(.body.weight(.semibold))
                    .textFieldStyle(.plain)
                TextField(L10n.Board.broadcastBodyField, text: $broadcastBody, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.plain)
                Text(L10n.Board.broadcastHint)
                    .font(.caption)
                    .foregroundStyle(BondTheme.muted)
                if let sentMessage {
                    Label(sentMessage, systemImage: sentOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(sentOK ? BondTheme.burntOrange : BondTheme.coral)
                }
                HStack(spacing: 10) {
                    Button(L10n.Board.broadcastTest) { Task { await send(testOnly: true) } }
                        .buttonStyle(.bordered)
                    Button(L10n.Board.broadcastSend(stats?.usersTotal ?? 0)) { confirmSend = true }
                        .buttonStyle(.borderedProminent)
                        .tint(BondTheme.burntOrange)
                }
                .disabled(isSending || broadcastTitle.trimmed.isEmpty)
                .font(.footnote.weight(.semibold))
            }
            .padding(14)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func send(testOnly: Bool) async {
        isSending = true
        sentMessage = nil
        defer { isSending = false }
        do {
            let adet = try await appState.sendFounderBroadcast(
                title: broadcastTitle.trimmed, body: broadcastBody.trimmed, testOnly: testOnly)
            sentMessage = testOnly ? L10n.Board.broadcastTestDone : L10n.Board.broadcastDone(adet)
            sentOK = true
            Haptics.success()
            if !testOnly { broadcastTitle = ""; broadcastBody = "" }
        } catch {
            // Kök alert sheet'i kapatıyor; hata panelin içinde kalsın.
            sentMessage = UserFacingError.message(error, fallback: L10n.Board.founderActionFailed)
            sentOK = false
            UINotificationFeedbackGenerator().notificationOccurred(.error)
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
