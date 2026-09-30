import SwiftUI

/// Destek yazışması. Öğrenci ve destek aynı ekranı görüyor; kendi yazdıkların
/// sağda. Destek tarafında altta "Çözüldü olarak işaretle ve haber ver" var:
/// öğrenciye bildirim ve push gider.
struct SupportThreadView: View {
    let opening: SupportOpening
    let isStaff: Bool

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var messages: [SupportMessage] = []
    @State private var status: SupportThread.Status
    @State private var draft = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var failure: String?
    @State private var limitBump = 0
    @FocusState private var focused: Bool

    init(opening: SupportOpening, isStaff: Bool) {
        self.opening = opening
        self.isStaff = isStaff
        _status = State(initialValue: opening.status)
    }

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !isSending && !trimmed.isEmpty && TextLimit.length(draft) <= TextLimit.message }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: BondTheme.Space.md) {
                        header
                        bubble(opening.message, fromStaff: false, date: opening.createdAt)
                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, BondTheme.Space.md)
                        } else if let failure {
                            ScreenFailureView(message: failure) { Task { await load() } }
                        }
                        ForEach(messages) { mesaj in
                            bubble(mesaj.body, fromStaff: mesaj.fromStaff, date: mesaj.createdAt)
                                .id(mesaj.id)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        if status == .resolved {
                            Label(L10n.Support.resolvedNote, systemImage: "checkmark.circle")
                                .font(.footnote)
                                .foregroundStyle(BondTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                        }
                    }
                    .padding(BondTheme.Space.lg)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    guard let son = messages.last else { return }
                    withAnimation(reduceMotion ? nil : BondTheme.Motion.smooth) { proxy.scrollTo(son.id, anchor: .bottom) }
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(isStaff ? (opening.reporter ?? L10n.Support.threadTitle) : L10n.Support.threadTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .task { await load() }
            .animation(reduceMotion ? nil : BondTheme.Motion.smooth, value: status)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            SupportStatusChip(status: status, staffView: isStaff)
            // Hata kodu ("· email_exists") yalnız desteğe; öğrenci ekranın adını görür.
            if let ekran = isStaff ? opening.screen : opening.screen?.components(separatedBy: " · ").first,
               !ekran.isEmpty {
                Text(ekran)
                    .font(.caption)
                    .foregroundStyle(BondTheme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    /// Kendi yazdıkların sağda ve koyu; karşı taraf solda, adıyla.
    private func bubble(_ text: String, fromStaff: Bool, date: Date) -> some View {
        let benim = fromStaff == isStaff
        let ad = fromStaff ? L10n.Support.staffName : (isStaff ? (opening.reporter ?? L10n.ProblemReport.anonymous) : L10n.Support.you)
        return HStack(alignment: .bottom, spacing: 8) {
            // Karşı taraf solda, fotoğrafıyla: destek için Common işareti,
            // kurucu tarafında şikâyetçinin profil fotoğrafı.
            if !benim {
                if fromStaff {
                    SupportAvatar(url: nil, isStaff: true)
                } else {
                    SupportAvatar(url: opening.reporterAvatarURL)
                }
            }
            VStack(alignment: benim ? .trailing : .leading, spacing: 4) {
            Text(text)
                .font(.body)
                .foregroundStyle(benim ? BondTheme.paper : BondTheme.ink)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(benim ? BondTheme.ink : BondTheme.surface,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text("\(ad) · \(date.relativeTurkish)")
                .font(.caption2)
                .foregroundStyle(BondTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: benim ? .trailing : .leading)
        .padding(benim ? .leading : .trailing, 44)
        .accessibilityElement(children: .combine)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 9) {
                TextField(L10n.Support.placeholder, text: $draft, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...5)
                    .focused($focused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(BondTheme.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .composerLimit(text: $draft, limit: TextLimit.message, bump: $limitBump)
                SendArrowButton(canSend: canSend, accessibilityLabel: L10n.Support.sendA11y) {
                    Task { await send(resolve: false) }
                }
            }
            if isStaff, status != .resolved {
                Button {
                    Task { await send(resolve: true) }
                } label: {
                    Label(L10n.Support.resolveAndNotify, systemImage: "checkmark.circle")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.secondaryCapsuleOnSurface)
                .disabled(isSending)
                .accessibilityIdentifier("support.resolve")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(BondTheme.hairline).frame(height: 0.5) }
    }

    private func load() async {
        failure = nil
        do {
            messages = try await appState.loadSupportMessages(opening.id)
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.Support.loadFailed)
        }
        isLoading = false
    }

    /// Çözüldü işaretlerken yazı isteğe bağlı; kutuda yazı varsa o da gider.
    private func send(resolve: Bool) async {
        guard !isSending, resolve || canSend else { return }
        isSending = true
        defer { isSending = false }
        let metin = trimmed
        guard let yeni = await appState.sendSupportMessage(opening.id, body: metin, resolve: resolve) else { return }
        draft = ""
        status = yeni
        if !metin.isEmpty {
            withAnimation(reduceMotion ? nil : BondTheme.Motion.smooth) {
                messages.append(SupportMessage(id: UUID(), fromStaff: isStaff, body: metin, createdAt: .now))
            }
        }
    }
}

/// Talebin durumu. Öğrenci için "Bekliyor", destek için "Açık".
struct SupportStatusChip: View {
    let status: SupportThread.Status
    var staffView = false

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(renk)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(renk.opacity(0.12), in: Capsule())
            .fixedSize()
    }

    private var title: String {
        switch status {
        case .open: staffView ? L10n.Support.statusOpenStaff : L10n.Support.statusOpen
        case .answered: L10n.Support.statusAnswered
        case .resolved: L10n.Support.statusResolved
        }
    }

    private var renk: Color {
        switch status {
        case .open: BondTheme.burntOrangeText
        case .answered: BondTheme.violet
        case .resolved: BondTheme.muted
        }
    }
}

/// Yazışmadaki küçük fotoğraf: öğrenci için profil fotoğrafı, destek için
/// Common işareti. Fotoğraf yoksa sade bir daire.
struct SupportAvatar: View {
    let url: URL?
    var isStaff = false
    var size: CGFloat = 28

    var body: some View {
        Group {
            if isStaff {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.2)
                    .background(BondTheme.surface, in: Circle())
            } else if let url {
                ProfileMedia(url: url, data: nil, assetName: nil)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(BondTheme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BondTheme.surface, in: Circle())
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
