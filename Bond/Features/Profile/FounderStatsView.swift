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
    @State private var days: [FounderDay] = []
    @State private var metric: ChartMetric = .active
    @State private var range: Int = 7
    @State private var announcements: [FounderAnnouncement] = []

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
                            hero(s)
                            if !days.isEmpty { weekSection }
                            broadcastSection
                            usersLink
                            announcementsSection
                            numbers(L10n.Board.statsUsers, [
                                ("usersTotal", s.usersTotal), ("usersVerified", s.usersVerified),
                                ("usersToday", s.usersToday), ("usersWeek", s.usersWeek),
                                ("activeWeek", s.activeWeek), ("reportsOpen", s.reportsOpen),
                            ])
                            numbers(L10n.Board.statsPlans, [
                                ("plus", s.plus), ("pro", s.pro), ("free", max(0, s.usersTotal - s.plus - s.pro)),
                            ])
                            numbers(L10n.Board.statsPeople, [
                                ("matches", s.matches), ("messagesTotal", s.messagesTotal),
                                ("rightSwipes", s.rightSwipes), ("leftSwipes", s.leftSwipes),
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
            VStack(alignment: .leading, spacing: 0) {
                TextField(L10n.Board.broadcastTitleField, text: $broadcastTitle)
                    .font(.body.weight(.semibold))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                Rectangle().fill(BondTheme.hairline).frame(height: 0.5).padding(.horizontal, 14)
                TextField(L10n.Board.broadcastBodyField, text: $broadcastBody, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                VStack(alignment: .leading, spacing: 10) {
                    if let sentMessage {
                        Label(sentMessage, systemImage: sentOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(sentOK ? BondTheme.burntOrange : BondTheme.coral)
                    } else {
                        Text(L10n.Board.broadcastHint)
                            .font(.caption)
                            .foregroundStyle(BondTheme.muted)
                    }
                    Button { confirmSend = true } label: {
                        HStack(spacing: 8) {
                            if isSending { ProgressView().tint(BondTheme.onAccent) }
                            Image(systemName: "megaphone.fill").font(.system(size: 14, weight: .semibold))
                            Text(L10n.Board.broadcastSend(stats?.usersTotal ?? 0)).fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(BondTheme.onAccent)
                        .background(BondTheme.burntOrange, in: Capsule())
                    }
                    .buttonStyle(.pressable)
                    .disabled(isSending || !canSend)
                    .opacity(canSend ? 1 : 0.45)
                    Button(L10n.Board.broadcastTest) { Task { await send(testOnly: true) } }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BondTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .disabled(isSending || !canSend)
                        .opacity(canSend ? 1 : 0.45)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var canSend: Bool {
        !(broadcastTitle.trimmed.isEmpty && broadcastBody.trimmed.isEmpty)
    }

    private func send(testOnly: Bool) async {
        isSending = true
        sentMessage = nil
        defer { isSending = false }
        do {
            // Başlık boşsa uygulama adı; mesaj tek başına yeter.
            let baslik = broadcastTitle.trimmed.isEmpty ? "Common" : broadcastTitle.trimmed
            let adet = try await appState.sendFounderBroadcast(
                title: baslik, body: broadcastBody.trimmed, testOnly: testOnly)
            sentMessage = testOnly ? L10n.Board.broadcastTestDone : L10n.Board.broadcastDone(adet)
            sentOK = true
            Haptics.success()
            if !testOnly { broadcastTitle = ""; broadcastBody = "" }
            announcements = (try? await appState.fetchFounderAnnouncements()) ?? announcements
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

    /// Üstte tek bakışta: şu an çevrimiçi (nabız), yanında üç küçük değer.
    private func hero(_ s: FounderStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(s.onlineNow.formatted())
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(BondTheme.ink)
                    .contentTransition(.numericText())
                HStack(spacing: 6) {
                    PulseDot()
                    Text(L10n.Board.stat("onlineNow"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BondTheme.ink)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                heroChip("activeToday", s.activeToday, "sun.max")
                heroChip("pushDevices", s.pushDevices, "bell.badge")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func heroChip(_ key: String, _ value: Int, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(BondTheme.muted)
                Text(value.formatted())
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .contentTransition(.numericText())
            }
            Text(L10n.Board.chip(key))
                .font(.caption2)
                .foregroundStyle(BondTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(BondTheme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(BondTheme.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Satır listesi: etiket … değer. Kutu ızgarasından kısa, daha az kaydırma.
    private func numbers(_ title: String, _ rows: [(String, Int)]) -> some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(BondTheme.muted)
                .tracking(0.6)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack {
                        Text(L10n.Board.stat(row.0)).font(.subheadline).foregroundStyle(BondTheme.ink)
                        Spacer()
                        Text(row.1.formatted())
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(BondTheme.ink)
                            .contentTransition(.numericText())
                    }
                    .padding(.vertical, 11)
                    .overlay(alignment: .bottom) {
                        if i < rows.count - 1 { Rectangle().fill(BondTheme.hairline).frame(height: 0.5) }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 2)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    enum ChartMetric: String, CaseIterable {
        case active, new, posts, matches
        func value(_ d: FounderDay) -> Int {
            switch self {
            case .active: d.activeUsers
            case .new: d.newUsers
            case .posts: d.posts
            case .matches: d.matches
            }
        }
    }

    /// Tek metrik, tek çubuk/gün, çubuk üstünde sayı; bugün turuncu.
    /// Başlıkta dönem toplamı ve önceki döneme göre değişim.
    private var weekSection: some View {
        let current = Array(days.suffix(range))
        let previous = Array(days.dropLast(range).suffix(range))
        let total = current.reduce(0) { $0 + metric.value($1) }
        let prevTotal = previous.reduce(0) { $0 + metric.value($1) }
        let maxV = max(1, current.map(metric.value).max() ?? 1)
        let peakIndex = current.indices.max { metric.value(current[$0]) < metric.value(current[$1]) }
        return VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            HStack {
                Text((range == 7 ? L10n.Board.week : L10n.Board.month).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BondTheme.muted)
                    .tracking(0.6)
                    .contentTransition(.opacity)
                Spacer()
                rangeToggle
            }
            VStack(alignment: .leading, spacing: 12) {
                // Metrik sekmeleri
                HStack(spacing: 6) {
                    ForEach(ChartMetric.allCases, id: \.self) { m in
                        Button {
                            withAnimation(.snappy) { metric = m }
                            Haptics.selection()
                        } label: {
                            Text(L10n.Board.chart(m.rawValue))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(metric == m ? BondTheme.ink : BondTheme.paper, in: Capsule())
                                .foregroundStyle(metric == m ? BondTheme.paper : BondTheme.ink)
                        }
                        .buttonStyle(.plain)
                    }
                }
                // Özet + eğilim
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(L10n.Board.chart("total"))
                        .font(.footnote)
                        .foregroundStyle(BondTheme.muted)
                    Text(total.formatted())
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(BondTheme.ink)
                        .contentTransition(.numericText())
                    Text(L10n.Board.chart(metric.rawValue).lowercased())
                        .font(.footnote)
                        .foregroundStyle(BondTheme.muted)
                    Spacer(minLength: 4)
                    trend(total, prevTotal)
                }
                // Çubuklar
                HStack(alignment: .bottom, spacing: range == 7 ? 8 : 3) {
                    ForEach(Array(current.enumerated()), id: \.element.id) { i, d in
                        let v = metric.value(d)
                        let isToday = i == current.count - 1
                        let showLabel = range == 7 || isToday || i == peakIndex
                        VStack(spacing: 4) {
                            // Etiketler overlay: sütun genişliğini etkilemez, komşuya taşabilir.
                            Color.clear.frame(height: 12).overlay {
                                Text(v.formatted())
                                    .font(.system(size: range == 7 ? 11 : 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(isToday ? BondTheme.burntOrange : BondTheme.ink)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .opacity(showLabel ? 1 : 0)
                                    .contentTransition(.numericText())
                            }
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isToday ? BondTheme.burntOrange : BondTheme.ink.opacity(0.78))
                                .frame(height: max(3, 84 * CGFloat(v) / CGFloat(maxV)))
                            Color.clear.frame(height: 12).overlay {
                                Text(dayLabel(d.day, index: i))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(isToday ? BondTheme.burntOrange : BondTheme.muted)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .opacity(range == 7 || i % 5 == 0 || isToday ? 1 : 0)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(dayLabel(d.day, index: i)): \(v)")
                    }
                }
                .frame(height: 124)
                .animation(.snappy, value: metric)
                .animation(.snappy, value: range)
            }
            .padding(14)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var rangeToggle: some View {
        HStack(spacing: 2) {
            ForEach([7, 30], id: \.self) { r in
                Button {
                    withAnimation(.snappy) { range = r }
                    Haptics.selection()
                } label: {
                    Text(L10n.Board.chart(r == 7 ? "range7" : "range30"))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(range == r ? BondTheme.surface : Color.clear, in: Capsule())
                        .foregroundStyle(range == r ? BondTheme.ink : BondTheme.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(BondTheme.hairline.opacity(0.6), in: Capsule())
    }

    private func trend(_ now: Int, _ before: Int) -> some View {
        Group {
            if before == 0 {
                Text(L10n.Board.chart("noPrev"))
                    .font(.caption2)
                    .foregroundStyle(BondTheme.muted)
            } else {
                let delta = Int((Double(now - before) / Double(before) * 100).rounded())
                let tone: Color = delta > 0 ? .green : (delta < 0 ? BondTheme.coral : BondTheme.muted)
                HStack(spacing: 3) {
                    if delta != 0 {
                        Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    Text("\(delta > 0 ? "+" : "")\(delta)%")
                        .font(.caption.weight(.bold))
                    Text(L10n.Board.chart(range == 7 ? "vsWeek" : "vs30"))
                        .font(.caption2)
                        .foregroundStyle(BondTheme.muted)
                }
                .foregroundStyle(tone)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func dayLabel(_ day: Date, index: Int) -> String {
        if range == 7 {
            return day.formatted(.dateTime.weekday(.abbreviated).locale(L10n.appLocale))
        }
        return day.formatted(.dateTime.day().locale(L10n.appLocale))
    }

    private var usersLink: some View {
        NavigationLink {
            FounderUsersView()
        } label: {
            HStack(spacing: BondTheme.Space.compact) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(BondTheme.paper, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Board.users).font(.subheadline.weight(.semibold))
                    Text(L10n.Board.usersHint).font(.footnote).foregroundStyle(BondTheme.muted).lineLimit(1)
                }
                Spacer(minLength: BondTheme.Space.sm)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(BondTheme.muted)
            }
            .foregroundStyle(BondTheme.ink)
            .padding(14)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    private var announcementsSection: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            Text(L10n.Board.announcements.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(BondTheme.muted)
                .tracking(0.6)
            if announcements.isEmpty {
                Text(L10n.Board.announcementsEmpty)
                    .font(.footnote)
                    .foregroundStyle(BondTheme.muted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(announcements) { a in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(a.title).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(L10n.Board.announcementRecipients(a.recipients))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BondTheme.burntOrange)
                            }
                            if !a.body.isEmpty {
                                Text(a.body).font(.footnote).foregroundStyle(BondTheme.ink).lineLimit(2)
                            }
                            Text(a.sentAt.relativeTurkish).font(.caption).foregroundStyle(BondTheme.muted)
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if a.id != announcements.last?.id { Rectangle().fill(BondTheme.hairline).frame(height: 0.5) }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func load() async {
        failure = nil
        if stats == nil { isLoading = true }
        do {
            async let a = appState.fetchFounderStats()
            async let b = appState.fetchFounderDaily(days: 60)
            async let c = appState.fetchFounderAnnouncements()
            stats = try await a
            days = (try? await b) ?? []
            announcements = (try? await c) ?? []
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.Board.founderActionFailed)
        }
        isLoading = false
    }
}

/// Yeşil nabız: "canlı" hissi. Reduce Motion açıksa sabit durur.
private struct PulseDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false
    var body: some View {
        ZStack {
            Circle().fill(Color.green.opacity(0.25)).frame(width: 14, height: 14)
                .scaleEffect(on ? 1.5 : 0.8)
                .opacity(on ? 0 : 1)
            Circle().fill(Color.green).frame(width: 8, height: 8)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { on = true }
        }
        .accessibilityHidden(true)
    }
}
