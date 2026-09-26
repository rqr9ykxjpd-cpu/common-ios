import SwiftUI

/// Ayarlar → Uygulama simgesi (Plus/Pro). Üç kutucuk; dokununca iOS simgeyi
/// değiştirip kendi uyarısını gösteriyor.
struct AppIconPickerView: View {
    @State private var selected = AppIconChoice.current
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

                Text(L10n.PlanPerks.iconFooter)
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
    }

    private func tile(_ choice: AppIconChoice) -> some View {
        let secili = choice == selected
        return Button {
            Task { await select(choice) }
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
                            .stroke(secili ? PlusGold.deep : .clear, lineWidth: 3)
                    }
                    .overlay(alignment: .topTrailing) {
                        if secili {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(PlusGold.ink, PlusGold.light)
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
