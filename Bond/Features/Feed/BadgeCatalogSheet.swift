import SwiftUI

/// Rozet kataloğu — Reddit'in "flair" seçicisi gibi: başlık + kapat, arama,
/// altında düz liste: solda seçim dairesi, sağda rozetin kendi rengine boyalı
/// kapsül. Kart yok, açıklama yok, ikon yok; rozetin rengi ve adı yeter.
/// `allowsClear` akış filtresinde "Tümü" satırını gösterir.
struct BadgeCatalogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: PostKind?
    var allowsClear = false
    @State private var query = ""

    private var results: [PostKind] {
        let q = query.trimmed
        guard !q.isEmpty else { return PostKind.catalog }
        return PostKind.catalog.filter { $0.title.localizedStandardContains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.PostKind.pickerTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(BondTheme.ink)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BondTheme.ink)
                        .frame(width: 40, height: 40)
                        .background(BondTheme.surface, in: Circle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(L10n.Common.close)
            }
            .padding(.horizontal, BondTheme.Space.lg)
            .padding(.top, BondTheme.Space.xl)
            .padding(.bottom, BondTheme.Space.md)

            HStack(spacing: BondTheme.Space.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(BondTheme.muted)
                TextField(L10n.PostKind.searchBadges, text: $query)
                    .font(.system(size: 17))
                    .foregroundStyle(BondTheme.ink)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(BondTheme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Common.cancel)
                }
            }
            .padding(.horizontal, BondTheme.Space.md)
            .frame(height: 44)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, BondTheme.Space.lg)
            .padding(.bottom, BondTheme.Space.md)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if allowsClear, query.trimmed.isEmpty {
                        row(title: L10n.PostKind.all, tint: BondTheme.ink, selected: selection == nil) {
                            choose(nil)
                        }
                    }
                    ForEach(results) { kind in
                        row(title: kind.displayTitle, tint: kind.tint, image: kind.image, selected: selection == kind) {
                            choose(kind)
                        }
                    }
                    if results.isEmpty {
                        Text(L10n.PostKind.emptyGeneric(query.trimmed))
                            .font(.subheadline)
                            .foregroundStyle(BondTheme.muted)
                            .padding(.horizontal, BondTheme.Space.lg)
                            .padding(.top, BondTheme.Space.xl)
                    }
                }
                .padding(.bottom, BondTheme.Space.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(BondTheme.paper.ignoresSafeArea())
    }

    private func choose(_ kind: PostKind?) {
        Haptics.selection()
        selection = kind
        dismiss()
    }

    /// Solda seçim dairesi, sağda rozet kapsülü. Satırın tamamı dokunulabilir.
    private func row(title: String, tint: Color, image: UIImage? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: BondTheme.Space.md) {
                ZStack {
                    Circle()
                        .stroke(selected ? BondTheme.ink : BondTheme.hairline, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if selected {
                        Circle()
                            .fill(BondTheme.ink)
                            .frame(width: 12, height: 12)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(BondTheme.Motion.snappy, value: selected)
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(tint, in: Capsule())
                Spacer(minLength: 0)
            }
            .padding(.horizontal, BondTheme.Space.lg)
            .frame(height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableCard)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Çip sırasının sonundaki "Daha fazla…" çipi.
struct MoreBadgesChip: View {
    let action: () -> Void
    var body: some View {
        PostKindChip(title: L10n.PostKind.moreBadges, systemImage: "ellipsis", selected: false, action: action)
    }
}

/// "önce buradan bir rozet seç" — rozetsiz paylaşmaya kalkınca çip sırasının
/// altında beliren el yazısı not; ok yukarıyı, çipleri gösterir.
struct PickBadgeHint: View {
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "arrow.turn.left.up")
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 1)
            Text(L10n.PostKind.pickBadgeHint)
                .font(.custom("BradleyHandITCTT-Bold", size: 17, relativeTo: .callout))
        }
        .foregroundStyle(BondTheme.burntOrange)
        .padding(.horizontal, BondTheme.Space.lg + 4)
        .accessibilityElement(children: .combine)
    }
}
