import SwiftUI

/// Ayarlar → Uygulama simgesi. Renkliler herkese açık; altınlar Plus/Pro'ya
/// özel, ücretsiz planda kilitli ve dokununca abonelik ekranı açılıyor.
/// Dokununca iOS simgeyi değiştirip kendi uyarısını gösteriyor.
struct AppIconPickerView: View {
    @Environment(AppState.self) private var appState
    @State private var selected = AppIconChoice.current
    @State private var showPaywall = false
    @State private var changing = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: BondTheme.Space.md)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BondTheme.Space.md) {
                LazyVGrid(columns: columns, spacing: BondTheme.Space.md) {
                    ForEach(AppIconChoice.allCases) { choice in
                        tile(choice)
                    }
                }

                Text(appState.tier == .free
                     ? L10n.PlanPerks.iconGoldLocked + " " + L10n.PlanPerks.iconFooter
                     : L10n.PlanPerks.iconFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(BondTheme.coral)
                }
            }
            .padding(BondTheme.Space.md)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(L10n.PlanPerks.iconRow)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func locked(_ choice: AppIconChoice) -> Bool {
        choice.isGold && appState.tier == .free
    }

    private func tile(_ choice: AppIconChoice) -> some View {
        let secili = choice == selected
        let kilitli = locked(choice)
        return Button {
            if kilitli {
                showPaywall = true
            } else {
                Task { await select(choice) }
            }
        } label: {
            VStack(spacing: BondTheme.Space.sm) {
                Image(choice.previewAsset)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .padding(4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 21, style: .continuous)
                            .stroke(secili ? BondTheme.ink : .clear, lineWidth: 3)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if kilitli {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(PlusGold.ink)
                                .frame(width: 24, height: 24)
                                .background(PlusGold.light, in: Circle())
                                .overlay(Circle().stroke(Color(uiColor: .systemGroupedBackground), lineWidth: 2))
                                .offset(x: 4, y: 4)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if secili {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, BondTheme.ink)
                                .offset(x: 6, y: -6)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                Text(choice.title)
                    .font(.footnote.weight(secili ? .semibold : .regular))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, BondTheme.Space.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .disabled(changing)
        .accessibilityAddTraits(secili ? .isSelected : [])
        .accessibilityValue(kilitli ? L10n.PlanPerks.iconLocked : "")
        .accessibilityIdentifier("appIcon.\(choice.rawValue)")
    }

    private func select(_ choice: AppIconChoice) async {
        guard choice != selected else { return }
        changing = true
        defer { changing = false }
        do {
            try await choice.apply()
            Haptics.selection()
            withAnimation(BondTheme.Motion.snappy) {
                selected = choice
                errorMessage = nil
            }
        } catch {
            errorMessage = L10n.PlanPerks.iconFailed
        }
    }
}
