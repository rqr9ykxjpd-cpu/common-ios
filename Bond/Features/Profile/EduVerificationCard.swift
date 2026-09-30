import SwiftUI

/// Profil sekmesindeki "öğrenci e-postanı doğrula" kartı. Doğrulanmış ya da
/// muaf hesapta hiç görünmez; bağlantı gönderilmişse bekleyen adresi gösterir.
struct EduVerificationCard: View {
    @Environment(AppState.self) private var appState
    @State private var showSheet = false

    private var status: EduVerificationStatus { appState.eduStatus ?? .unknown }

    var body: some View {
        Button { showSheet = true } label: {
            HStack(spacing: BondTheme.Space.compact) {
                Image(systemName: status.isPending ? "envelope.badge.fill" : "graduationcap.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(status.isPending ? BondTheme.ink : BondTheme.onAccent)
                    .frame(width: 40, height: 40)
                    .background(status.isPending ? BondTheme.paper : BondTheme.burntOrange, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    // Bölünmez tire: büyük yazıda satır "e-" / "postanı" diye kırılmasın.
                    Text((status.isPending ? L10n.Edu.pendingTitle : L10n.Edu.cardTitle)
                        .replacingOccurrences(of: "-", with: "\u{2011}"))
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(status.isPending ? L10n.Edu.pendingBody(status.pendingEmail ?? "") : L10n.Edu.cardBody)
                        .font(.footnote)
                        .foregroundStyle(BondTheme.muted)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: BondTheme.Space.sm)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BondTheme.muted)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(BondTheme.ink)
            .padding(.horizontal, BondTheme.Space.md)
            // Büyük yazıda kart yazıyla birlikte uzar; kenara yapışmaz.
            .padding(.vertical, BondTheme.Space.compact)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(
                status.isPending ? BondTheme.surface : BondTheme.burntOrange.opacity(0.10),
                in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("profile.edu")
        .sheet(isPresented: $showSheet) { EduVerificationSheet() }
    }
}

/// Adres gir → bağlantı gönderildi → "dokundum, kontrol et". Bağlantı Safari'de
/// açılıp tasarımlı sayfaya düşer; oradan `bond://edu-verified` ile döner ya da
/// kullanıcı buradan elle kontrol ettirir.
struct EduVerificationSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var email = ""
    @State private var isSending = false
    @State private var isChecking = false
    @State private var cooldown = 0
    @State private var showStillPending = false
    @State private var didLoadDomains = false
    @State private var isLoadingDomains = false
    @State private var showProblemReport = false
    @FocusState private var fieldFocused: Bool

    private var status: EduVerificationStatus { appState.eduStatus ?? .unknown }
    private var trimmed: String { email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    private var canSend: Bool {
        !isSending && EduEmailCheck.looksLikeEmail(trimmed)
            && !appState.eduDomains.isEmpty
            && EduEmailCheck.isAllowed(trimmed, domains: appState.eduDomains)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                    if status.isVerified {
                        verified
                    } else if let bekleyen = status.pendingEmail {
                        sent(to: bekleyen)
                    } else {
                        entry
                    }
                    if !status.isVerified { problemLink }
                }
                .padding(BondTheme.Space.lg)
            }
            .sheet(isPresented: $showProblemReport) {
                // Son hata kodu da gider (email_exists…): destek neyin takıldığını görür.
                ProblemReportView(screen: ["Öğrenci e-postası", appState.lastEduErrorCode]
                    .compactMap { $0 }.joined(separator: " · "))
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Edu.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Kısa ve diğer pencerelerle aynı: "Şimdi değil" başlığı ortadan itiyordu.
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .task {
                await loadDomainsIfNeeded()
                if !status.isPending { fieldFocused = true }
            }
            .animation(reduceMotion ? nil : BondTheme.Motion.smooth, value: status)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Adım 1: adres

    private var entry: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.md) {
            Text(L10n.Edu.sheetHint)
                .font(BondTheme.Typography.footnote)
                .foregroundStyle(BondTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            TextField(L10n.Edu.placeholder, text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($fieldFocused)
                .submitLabel(.send)
                .onSubmit { if canSend { Task { await send() } } }
                .font(BondTheme.Typography.body)
                .padding(BondTheme.Space.md)
                .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))

            if isLoadingDomains {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(L10n.Edu.loadingDomains)
                }
                .font(.footnote)
                .foregroundStyle(BondTheme.muted)
            } else if didLoadDomains, appState.eduDomains.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Edu.domainsUnavailable)
                        .font(.footnote)
                        .foregroundStyle(BondTheme.burntOrangeText)
                    Button(L10n.Common.retry) { Task { await loadDomainsIfNeeded(force: true) } }
                        .font(.footnote.weight(.semibold))
                }
            }

            if !trimmed.isEmpty, EduEmailCheck.looksLikeEmail(trimmed),
               !appState.eduDomains.isEmpty, !EduEmailCheck.isAllowed(trimmed, domains: appState.eduDomains) {
                Text(L10n.Edu.notAllowedDomain)
                    .font(.footnote)
                    .foregroundStyle(BondTheme.burntOrangeText)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }

            Button { Task { await send() } } label: {
                HStack(spacing: 8) {
                    if isSending { ProgressView().tint(BondTheme.paper) }
                    Text(L10n.Edu.send).font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(BondTheme.paper)
                .background(canSend ? BondTheme.ink : BondTheme.muted.opacity(0.5), in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .disabled(!canSend)
        }
    }

    // MARK: - Adım 2: gönderildi

    private func sent(to address: String) -> some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.md) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(BondTheme.acid)
                    .symbolEffect(.bounce, options: .nonRepeating, value: status.pendingEmail)
                Text(L10n.Edu.sentTitle)
                    .font(BondTheme.Typography.title2)
                    .foregroundStyle(BondTheme.ink)
            }
            Text(L10n.Edu.sentBody(address))
                .font(BondTheme.Typography.footnote)
                .foregroundStyle(BondTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button { Task { await check() } } label: {
                HStack(spacing: 8) {
                    if isChecking { ProgressView().tint(BondTheme.paper) }
                    Text(L10n.Edu.checkNow).font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(BondTheme.paper)
                .background(BondTheme.ink, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .disabled(isChecking)

            if showStillPending {
                Text(L10n.Edu.stillPending)
                    .font(.footnote)
                    .foregroundStyle(BondTheme.burntOrangeText)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }

            HStack(spacing: BondTheme.Space.md) {
                Button {
                    email = address
                    Task { await send() }
                } label: {
                    Text(cooldown > 0 ? L10n.Edu.resendIn(cooldown) : L10n.Edu.resend)
                        .font(.subheadline.weight(.medium))
                        .contentTransition(.numericText())
                }
                .disabled(cooldown > 0 || isSending)
                Spacer()
                Button {
                    email = address
                    appState.eduStatus?.pendingEmail = nil
                    fieldFocused = true
                } label: {
                    Text(L10n.Edu.changeAddress).font(.subheadline.weight(.medium))
                }
            }
            .foregroundStyle(BondTheme.ink)
            .padding(.top, 4)
        }
        .task(id: cooldown) {
            guard cooldown > 0 else { return }
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled { cooldown -= 1 }
        }
    }

    /// Adres kabul edilmedi, e-posta gelmedi…: öğrenci takılırsa doğrudan bize
    /// yazsın. Kurucu Sorunlar'da "Öğrenci e-postası" ekranından geldiğini görür.
    private var problemLink: some View {
        Button { showProblemReport = true } label: {
            Label(L10n.ProblemReport.eduHelp, systemImage: "exclamationmark.bubble")
                .font(.footnote.weight(.medium))
                .foregroundStyle(BondTheme.muted)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityIdentifier("edu.problem")
    }

    // MARK: - Doğrulandı

    private var verified: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.md) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(BondTheme.violet)
                Text(L10n.Edu.verifiedLine)
                    .font(BondTheme.Typography.title2)
                    .foregroundStyle(BondTheme.ink)
            }
            if let adres = status.email {
                Text(adres).font(BondTheme.Typography.footnote).foregroundStyle(BondTheme.muted)
            }
        }
    }

    private func send() async {
        guard canSend else { return }
        isSending = true
        defer { isSending = false }
        if await appState.requestEduVerification(trimmed) {
            cooldown = 60
            showStillPending = false
            fieldFocused = false
        }
    }

    private func loadDomainsIfNeeded(force: Bool = false) async {
        guard force || appState.eduDomains.isEmpty else {
            didLoadDomains = true
            return
        }
        isLoadingDomains = true
        _ = await appState.loadEduDomains()
        isLoadingDomains = false
        didLoadDomains = true
    }

    private func check() async {
        isChecking = true
        defer { isChecking = false }
        let oldu = await appState.syncEduVerification()
        if oldu {
            try? await Task.sleep(for: .seconds(1.2))
            dismiss()
        } else {
            withAnimation(reduceMotion ? nil : BondTheme.Motion.smooth) { showStillPending = true }
        }
    }
}
