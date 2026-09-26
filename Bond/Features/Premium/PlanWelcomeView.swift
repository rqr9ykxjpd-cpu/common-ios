import SwiftUI

/// Satın alma bitince paywall'ın yerini alan ekran. Eskiden paywall sessizce
/// kapanıyordu; parayı veren bir şeyin değiştiğini görmüyordu.
///
/// Uygulamanın kendi dili: kâğıt zemin, serif başlık, el yazısı not. Altın
/// yalnızca Plus/Pro anlamına ayrıldığı için yalnızca üyelik kartında; kart
/// profildeki plan kutucuğuyla aynı yüzey ve aynı ışık. Tek hareket kartın
/// yerine oturup üstünden bir kez ışık geçmesi.
///
/// Paywall dört ayrı sheet'ten açılıyor; bu yüzden ayrı bir tam ekran değil,
/// paywall'ın kendi içeriği.
struct PlanWelcomeView: View {
    let tier: SubscriptionTier
    /// Satın almadan önceki kademe; listede yalnızca farkı gösteriyoruz.
    let previous: SubscriptionTier
    let onDone: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cardIn = false
    @State private var detailsIn = false
    @State private var sweep: CGFloat = -1
    @State private var iconIsGold = AppIconChoice.current.isGold
    @State private var iconError: String?

    /// Paywall tablosuyla aynı kaynak: yeni kademede değeri değişen satırlar.
    private var unlocked: [PlanFeature] {
        PlanFeature.all.filter { $0.value(tier) != $0.value(previous) }
    }

    private var handle: String {
        let ad = appState.draft.username
        return ad.isEmpty ? appState.draft.name : "@\(ad)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                card
                    .padding(.top, BondTheme.Space.xl)

                VStack(alignment: .leading, spacing: 7) {
                    Text(tier == .pro ? L10n.PlanPerks.welcomePro : L10n.PlanPerks.welcomePlus)
                        .font(.system(.largeTitle, design: .serif).weight(.bold))
                        .tracking(-0.7)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(L10n.ProfileHome.planPrivate)
                        .font(.subheadline)
                        .foregroundStyle(BondTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(detailsIn ? 1 : 0)
                .offset(y: detailsIn ? 0 : 8)

                if !unlocked.isEmpty {
                    unlockedList
                        .opacity(detailsIn ? 1 : 0)
                        .offset(y: detailsIn ? 0 : 8)
                }
            }
            .padding(.horizontal, BondTheme.Space.md)
            .padding(.bottom, BondTheme.Space.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { actions }
        .background(BondTheme.paper.ignoresSafeArea())
        .foregroundStyle(BondTheme.ink)
        .task { await play() }
    }

    // MARK: - Kart

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Brand.wordmark)
                    .font(.system(.title2, design: .serif).weight(.bold))
                Spacer()
                Text(tier.title.uppercased())
                    .font(.caption.weight(.heavy))
                    .tracking(1.4)
            }
            Spacer(minLength: BondTheme.Space.lg)
            HStack(alignment: .bottom) {
                cardField(L10n.PlanPerks.cardMember, handle, alignment: .leading)
                Spacer(minLength: BondTheme.Space.md)
                cardField(
                    L10n.PlanPerks.cardSince,
                    Date.now.formatted(.dateTime.month(.abbreviated).year()),
                    alignment: .trailing
                )
            }
        }
        .foregroundStyle(PlusGold.ink)
        .padding(BondTheme.Space.lg)
        .frame(maxWidth: .infinity)
        .aspectRatio(1.586, contentMode: .fit)
        .background(PlusGold.gradient, in: shape)
        .overlay { GoldSheen(progress: sweep, shape: shape) }
        .overlay { shape.strokeBorder(.white.opacity(0.35), lineWidth: 0.5) }
        .shadow(color: PlusGold.deep.opacity(0.22), radius: 18, y: 10)
        .scaleEffect(cardIn ? 1 : 0.96)
        .offset(y: cardIn ? 0 : 18)
        .opacity(cardIn ? 1 : 0)
        .accessibilityElement(children: .combine)
    }

    private func cardField(_ label: String, _ value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .opacity(0.6)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Açılanlar

    /// Paywall karşılaştırma tablosunun satır biçimi.
    private var unlockedList: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            Text(L10n.PlanPerks.subtitle)
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(unlocked.enumerated()), id: \.element.id) { index, feature in
                    if index > 0 {
                        Divider().overlay(BondTheme.hairline.opacity(0.65))
                    }
                    featureRow(feature)
                }
            }
            .padding(.horizontal, BondTheme.Space.compact)
            .padding(.vertical, BondTheme.Space.xs)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        }
    }

    private func featureRow(_ feature: PlanFeature) -> some View {
        let deger = feature.value(tier)
        return HStack(spacing: 10) {
            Image(systemName: feature.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(feature.label.replacingOccurrences(of: "\n", with: " "))
                .font(.footnote)
                .lineLimit(2)
            Spacer(minLength: BondTheme.Space.sm)
            if deger == L10n.Paywall.yes {
                Image(systemName: "checkmark")
                    .font(.footnote.weight(.bold))
                    .accessibilityLabel(deger)
            } else {
                Text(deger)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
            }
        }
        .frame(minHeight: 43)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Düğmeler

    private var actions: some View {
        VStack(spacing: 2) {
            Button(action: onDone) {
                Text(L10n.PlanPerks.start)
                    .fontWeight(.semibold)
                    .foregroundStyle(BondTheme.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(BondTheme.acid, in: Capsule())
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("planWelcome.start")

            if !iconIsGold {
                Button {
                    Task { await tryGoldIcon() }
                } label: {
                    HStack(spacing: 8) {
                        Image(AppIconChoice.goldNight.previewAsset)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                        Text(L10n.PlanPerks.tryIcon)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("planWelcome.tryIcon")
            }

            if let iconError {
                Text(iconError)
                    .font(.caption)
                    .foregroundStyle(BondTheme.coral)
            }
        }
        .padding(.horizontal, BondTheme.Space.md)
        .padding(.vertical, BondTheme.Space.sm)
        .background(BondTheme.paper.ignoresSafeArea())
        .opacity(detailsIn ? 1 : 0)
    }

    private func tryGoldIcon() async {
        do {
            try await AppIconChoice.goldNight.apply()
            Haptics.selection()
            withAnimation(.smooth(duration: 0.25)) {
                iconIsGold = true
                iconError = nil
            }
        } catch {
            iconError = L10n.PlanPerks.iconFailed
        }
    }

    // MARK: - Açılış

    private func play() async {
        guard IdleMotion.allowed(reduceMotion: reduceMotion) else {
            withAnimation(.easeOut(duration: 0.25)) {
                cardIn = true
                detailsIn = true
            }
            return
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { cardIn = true }
        withAnimation(.easeOut(duration: 0.4).delay(0.15)) { detailsIn = true }
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.easeInOut(duration: 1.1)) { sweep = 1 }
    }
}
