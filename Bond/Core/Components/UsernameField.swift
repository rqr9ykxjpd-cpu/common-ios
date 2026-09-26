import SwiftUI

/// Kullanıcı adının kontrol durumu. Kayıt ve profil düzenleme ekranı "Devam" /
/// "Kaydet" düğmesini buna göre açıyor.
enum UsernameStatus: Equatable {
    case idle
    case checking
    case available
    case taken
    case invalid
    /// Ağ yüzünden kontrol edilemedi. Kural uyuyorsa ilerlemeye izin veriliyor;
    /// sunucu kaydederken yine kontrol ediyor.
    case failed

    /// Kaydetmeye izin var mı.
    var allowsSave: Bool { self == .available || self == .failed }
}

/// "@" ile başlayan kullanıcı adı alanı. Yazılanı kurala yaklaştırır (küçük harf,
/// Türkçe harfler Latin, izinsiz karakterler atılır) ve kısa bir beklemeden
/// sonra sunucuya "uygun mu" diye sorar. Etiketi çağıran çiziyor.
struct UsernameField: View {
    @Binding var text: String
    @Binding var status: UsernameStatus
    /// Sunucu kontrolü; `true` uygun.
    let check: (String) async throws -> Bool
    var font: Font = BondTheme.Typography.body

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text("@")
                    .font(font)
                    .foregroundStyle(BondTheme.muted)
                    .accessibilityHidden(true)
                TextField(L10n.Username.title, text: $text)
                    .font(font)
                    .foregroundStyle(BondTheme.ink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .accessibilityLabel(L10n.Username.title)
                statusIcon
            }
            .frame(minHeight: 32)

            Text(statusText)
                .font(BondTheme.Typography.caption)
                .foregroundStyle(statusColor)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.smooth(duration: 0.2), value: status)
        }
        .onChange(of: text) { _, yeni in
            // Yalnızca kural dışı bir şey yazıldığında düzeltiyoruz; aksi halde
            // alanın içeriğine dokunmak imleci oynatıyordu.
            let duzgun = Username.normalize(yeni)
            if duzgun != yeni { text = duzgun }
        }
        .task(id: text) { await verify(text) }
    }

    private func verify(_ aday: String) async {
        guard !aday.isEmpty else { status = .idle; return }
        guard Username.isValid(aday) else { status = .invalid; return }
        status = .checking
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        do {
            let uygun = try await check(aday)
            guard !Task.isCancelled else { return }
            status = uygun ? .available : .taken
        } catch {
            guard !Task.isCancelled else { return }
            status = .failed
        }
    }

    @ViewBuilder private var statusIcon: some View {
        switch status {
        case .checking:
            ProgressView().controlSize(.small)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(uiColor: .systemGreen))
                .transition(.scale.combined(with: .opacity))
        case .taken, .invalid:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(BondTheme.coral)
                .transition(.scale.combined(with: .opacity))
        case .idle, .failed:
            EmptyView()
        }
    }

    private var statusText: String {
        switch status {
        case .idle: L10n.Username.hint
        case .checking: L10n.Username.checking
        case .available: L10n.Username.available
        case .taken: L10n.Username.taken
        case .invalid: L10n.Username.invalid
        case .failed: L10n.Username.checkFailed
        }
    }

    private var statusColor: Color {
        switch status {
        case .taken, .invalid: BondTheme.coral
        case .available: Color(uiColor: .systemGreen)
        default: BondTheme.muted
        }
    }
}
