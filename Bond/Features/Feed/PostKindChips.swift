import SwiftUI

/// Rozetin küçük işareti: resim varsa resim (yuvarlak), yoksa emoji, o da
/// yoksa SF ikon. Çip, rozet ve katalog aynı sırayı kullanır.
struct BadgeGlyph: View {
    let kind: PostKind
    var size: CGFloat = 16
    var weight: Font.Weight = .semibold

    var body: some View {
        if let image = kind.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let emoji = kind.emoji {
            Text(emoji).font(.system(size: size * 0.85))
        } else {
            Image(systemName: kind.systemImage)
                .font(.system(size: size * 0.75, weight: weight))
        }
    }
}

/// Tür çipi. Composer'da "ne paylaşıyorsun", akışta "neyi göreyim" için aynı
/// parça; seçili "Tümü" mürekkep, seçili tür kendi rengi, diğerleri yüzey.
struct PostKindChip: View {
    let title: String
    var systemImage: String? = nil
    /// Rozetin kendisi: işaret (resim/emoji/ikon) buradan çizilir.
    var kind: PostKind? = nil
    let selected: Bool
    var selectedColor: Color = BondTheme.ink
    /// Verilirse seçili zemin çipler arasında kayar (sıradaki tek kapsül).
    var pillNamespace: Namespace.ID? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let kind {
                    BadgeGlyph(kind: kind, size: 16)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 13)
            .frame(height: 34)
            .foregroundStyle(selected ? BondTheme.onAccent : BondTheme.ink)
            .background {
                ZStack {
                    Capsule().fill(BondTheme.surface)
                    if selected {
                        if let pillNamespace {
                            Capsule().fill(selectedColor)
                                .matchedGeometryEffect(id: "seciliCip", in: pillNamespace)
                        } else {
                            Capsule().fill(selectedColor)
                        }
                    }
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Yatay kayan çip sırası. `allTitle` verilirse başa bir "Tümü" çipi koyar
/// (akış filtresi); verilmezse yalnızca türler (composer).
struct PostKindChipRow<Trailing: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pill
    @Binding var selection: PostKind?
    var allTitle: String? = nil
    var kinds: [PostKind] = PostKind.allCases
    /// Sıranın sonuna eklenen parça (akışta sıralama çipi). Ayrı satır
    /// açmamak için buraya girer.
    var trailing: () -> Trailing

    init(selection: Binding<PostKind?>, allTitle: String? = nil, kinds: [PostKind] = PostKind.allCases,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        _selection = selection
        self.allTitle = allTitle
        self.kinds = kinds
        self.trailing = trailing
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BondTheme.Space.sm) {
                    if let allTitle {
                        PostKindChip(title: allTitle, selected: selection == nil, pillNamespace: pill) {
                            select(nil)
                        }
                        .id("all")
                    }
                    // Seçili rozet öne çıkanlarda yoksa (katalogdan seçildi) sıranın
                    // başında görünür; yoksa kullanıcı neyi seçtiğini göremiyor.
                    ForEach(visibleKinds) { kind in
                        PostKindChip(
                            title: kind.title,
                            kind: kind,
                            selected: selection == kind,
                            // Seçili tür kendi rengini giyer; rozetle aynı ton.
                            selectedColor: kind.tint,
                            pillNamespace: pill
                        ) {
                            select(kind)
                        }
                        .id(kind.id)
                    }
                    trailing()
                }
                .padding(.horizontal, BondTheme.Space.lg)
            }
            .onChange(of: selection) { _, kind in
                // Seçilen çip kenarda kalmasın; kısmen görünür bir seçim
                // "seçildi mi" şüphesi bırakıyor.
                if reduceMotion {
                    proxy.scrollTo(kind?.id ?? "all", anchor: .center)
                } else {
                    withAnimation(BondTheme.Motion.smooth) {
                        proxy.scrollTo(kind?.id ?? "all", anchor: .center)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var visibleKinds: [PostKind] {
        guard let selection, !kinds.contains(selection) else { return kinds }
        return [selection] + kinds
    }

    private func select(_ kind: PostKind?) {
        withAnimation(reduceMotion ? nil : BondTheme.Motion.snappy) { selection = kind }
    }
}

/// Akış kartındaki tür rozeti; düz paylaşımda çizilmez.
struct PostKindBadge: View {
    let kind: PostKind

    var body: some View {
        if kind != .moment {
            HStack(spacing: 4) {
                BadgeGlyph(kind: kind, size: 14)
                Text(kind.title)
            }
                .font(.caption.weight(.semibold))
                .foregroundStyle(kind.tint)
                .padding(.horizontal, 10)
                .frame(height: 26)
                // Türün rengi, %12 zemin: kâğıtta da yüzeyde de okunur, bağırmaz.
                .background(kind.tint.opacity(0.12), in: Capsule())
        }
    }
}

/// ▲ puan ▼ — Reddit'teki oy kapsülü. Etkin ok mürekkep daireyle işaretlenir,
/// puan hep okunur kalır. Gönderide de cevapta da aynı parça.
struct VoteControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let score: Int
    /// +1, -1, 0
    let myVote: Int
    var disabled: Bool = false
    let onUp: () -> Void
    let onDown: () -> Void
    /// Oy verildiği an artar: ok zıplar, yukarı oyda turuncu halka yayılır.
    /// Oyu geri alırken tetiklenmez; geri almak kutlanacak bir şey değil.
    @State private var upPulse = 0
    @State private var downPulse = 0

    var body: some View {
        HStack(spacing: 2) {
            arrow(up: true, active: myVote == 1, action: onUp)
            Text(String(score))
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(score)))
                .frame(minWidth: 18)
                .foregroundStyle(myVote == 1 ? BondTheme.upvote : (score < 0 ? BondTheme.muted : BondTheme.ink))
            arrow(up: false, active: myVote == -1, action: onDown)
        }
        .padding(.horizontal, 2)
        .frame(height: 36)
        .background(BondTheme.surface, in: Capsule())
        .opacity(disabled ? 0.45 : 1)
        .animation(reduceMotion ? nil : BondTheme.Motion.snappy, value: myVote)
        .animation(reduceMotion ? nil : BondTheme.Motion.snappy, value: score)
        .accessibilityElement(children: .contain)
        .accessibilityValue(L10n.Board.voteCount(score))
    }

    private func arrow(up: Bool, active: Bool, action: @escaping () -> Void) -> some View {
        let fill = up ? BondTheme.upvote : BondTheme.ink
        // Dokunma alanı 36pt (HIG'e yakın), görünen daire 28pt.
        return Button {
            if !active, !reduceMotion {
                if up { upPulse += 1 } else { downPulse += 1 }
            }
            action()
        } label: {
            Image(systemName: up ? "arrow.up" : "arrow.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(active ? BondTheme.paper : BondTheme.ink)
                // Ok oyun yönüne kısa bir sıçrayış yapıp yerine oturuyor.
                .keyframeAnimator(initialValue: VoteHop(), trigger: up ? upPulse : downPulse) { icon, hop in
                    icon.offset(y: hop.y)
                } keyframes: { _ in
                    KeyframeTrack(\.y) {
                        CubicKeyframe(up ? -6 : 6, duration: 0.1)
                        SpringKeyframe(0, duration: 0.35, spring: .bouncy)
                    }
                }
                .frame(width: 28, height: 28)
                // Dolgu merkezden büyüyerek geliyor; eskiden renk bir anda değişiyordu.
                .background {
                    Circle()
                        .fill(fill)
                        .scaleEffect(active ? 1 : 0.4)
                        .opacity(active ? 1 : 0)
                }
                .overlay {
                    if up {
                        // Yukarı oyda daireden dışa yayılıp sönen ince turuncu halka.
                        Circle()
                            .strokeBorder(BondTheme.upvote, lineWidth: 2)
                            .keyframeAnimator(initialValue: VoteRing(), trigger: upPulse) { ring, frame in
                                ring.scaleEffect(frame.scale).opacity(frame.opacity)
                            } keyframes: { _ in
                                KeyframeTrack(\.scale) {
                                    MoveKeyframe(1)
                                    CubicKeyframe(2.1, duration: 0.5)
                                }
                                KeyframeTrack(\.opacity) {
                                    MoveKeyframe(0.7)
                                    CubicKeyframe(0, duration: 0.5)
                                }
                            }
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .disabled(disabled)
        .animation(reduceMotion ? nil : BondTheme.Motion.bouncy, value: active)
        .accessibilityLabel(up ? (active ? L10n.Board.unvote : L10n.Board.vote)
                               : (active ? L10n.Board.undoDownvote : L10n.Board.downvote))
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// Oy okunun sıçrama karesi.
private struct VoteHop {
    var y: CGFloat = 0
}

/// Yukarı oy halkasının karesi; başlangıçta görünmez.
private struct VoteRing {
    var scale: CGFloat = 1
    var opacity: Double = 0
}
