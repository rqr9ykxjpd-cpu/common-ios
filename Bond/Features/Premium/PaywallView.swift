import SwiftUI

/// Free, Plus ve Pro'yu tek bakışta karşılaştıran abonelik ekranı.
/// Fiyatlar sabit yazılmaz; her zaman StoreKit'in yerelleştirilmiş değeridir.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var quota: QuotaKind?

    private var store: SubscriptionStore { appState.subscriptions }
    private let tiers = SubscriptionTier.allCases
    @State private var selectedTier: SubscriptionTier = .plus
    @Namespace private var tierPill
    /// Kullanıcının bugünkü kademesi. Plus'taki biri paywall'ı açınca Pro
    /// ön-seçili gelir; kendi planını yeniden "satın alamaz" (Apple zaten
    /// reddederdi, kafa karıştırırdı). Aynı abonelik grubundalar: Pro'ya
    /// geçiş Apple'da anında yükseltme, Plus'ın kalanı iade.
    private var currentTier: SubscriptionTier { appState.tier }
    @State private var alertMessage: String?
    @State private var legalDocument: LegalDocumentRoute?

    private var busy: Bool { store.purchasingTier != nil || store.isRestoring }
    private var tierColumnWidth: CGFloat { textSize.isAccessibilitySize ? 64 : 56 }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BondTheme.Space.md) {
                    header
                    comparison
                    pricePicker
                    checkout
                }
                .padding(.horizontal, BondTheme.Space.md)
                .padding(.top, BondTheme.Space.sm)
                .padding(.bottom, BondTheme.Space.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(BondTheme.paper)
            .foregroundStyle(BondTheme.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                        .disabled(busy)
                        .accessibilityIdentifier("paywall.close")
                }
                ToolbarItem(placement: .principal) {
                    Text(L10n.Brand.wordmark)
                        .font(.system(.headline, design: .serif).weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .interactiveDismissDisabled(busy)
        .sheet(item: $legalDocument) { document in
            NavigationStack { LegalTextView(title: document.title, blocks: document.blocks) }
        }
        .task { await store.loadProducts() }
        // Plus'taki kullanıcı için tek anlamlı seçenek Pro; Pro'daki için hiçbiri.
        .onAppear {
            if currentTier >= selectedTier { selectedTier = .pro }
#if DEBUG
            if let plan = appState.debugPaywallPlan { selectedTier = plan }
#endif
        }
        .alert(L10n.Paywall.problem, isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button(L10n.Common.ok, role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(quota?.title ?? L10n.Paywall.headline)
                .font(.system(.largeTitle, design: .serif).weight(.bold))
                .tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)

            Text(quota?.detail ?? L10n.PaywallDesign.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.Paywall.specialNote.replacingOccurrences(of: "\n", with: " "))
                .font(.custom("BradleyHandITCTT-Bold", size: 16, relativeTo: .callout))
                .foregroundStyle(BondTheme.burntOrange)
                .rotationEffect(.degrees(-0.7))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private var comparison: some View {
        VStack(spacing: 0) {
            comparisonHeader
                .padding(.bottom, BondTheme.Space.sm)

            ForEach(Array(PlanFeature.all.enumerated()), id: \.element.id) { index, feature in
                if index > 0 {
                    Divider().overlay(BondTheme.hairline.opacity(0.65))
                }
                featureRow(feature)
            }
        }
        .padding(.horizontal, BondTheme.Space.compact)
        .padding(.vertical, BondTheme.Space.compact)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.PaywallDesign.included)
    }

    private var comparisonHeader: some View {
        HStack(spacing: 4) {
            Text(L10n.PaywallDesign.included)
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(tiers, id: \.self) { tier in
                Text(tier.title.uppercased())
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: tierColumnWidth)
                    .frame(minHeight: 28)
                    .foregroundStyle(tier == selectedTier ? BondTheme.onAccent : .secondary)
                    .background {
                        // Kapsül sütunlar arasında kayar; iki ayrı kapsülün yanıp sönmesi yerine.
                        if tier == selectedTier {
                            Capsule().fill(BondTheme.acid)
                                .matchedGeometryEffect(id: "pill", in: tierPill)
                        }
                    }
            }
        }
        .animation(reduceMotion ? nil : BondTheme.Motion.snappy, value: selectedTier)
    }

    private func featureRow(_ feature: PlanFeature) -> some View {
        HStack(spacing: 4) {
            Label {
                Text(feature.label.replacingOccurrences(of: "\n", with: " "))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            } icon: {
                Image(systemName: featureSymbol(feature.id))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, minHeight: 43, alignment: .leading)

            ForEach(tiers, id: \.self) { tier in
                featureValue(feature.value(tier), tier: tier)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityComparison(for: feature))
    }

    private func featureValue(_ value: String, tier: SubscriptionTier) -> some View {
        Text(value)
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .foregroundStyle(value == L10n.Paywall.no ? BondTheme.muted : BondTheme.ink)
            .frame(width: tierColumnWidth)
            .frame(minHeight: 43)
            .background(
                tier == selectedTier ? BondTheme.burntOrange.opacity(0.09) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
    }

    private var pricePicker: some View {
        // Ücretsiz kartı yok: tablo zaten ücretsizde ne olduğunu gösteriyor,
        // seçilebilecek bir şey değil. İki ödeme kartı genişliği paylaşır.
        HStack(spacing: BondTheme.Space.sm) {
            paidPriceCard(.plus)
            paidPriceCard(.pro)
        }
    }

    private func paidPriceCard(_ tier: SubscriptionTier) -> some View {
        let selected = tier == selectedTier
        let current = tier == currentTier
        // Alt kademe de seçilemez: paywall'dan düşürme yok, Apple aboneliklerde yapılır.
        let locked = tier <= currentTier
        return Button {
            withAnimation(reduceMotion ? nil : BondTheme.Motion.snappy) {
                selectedTier = tier
            }
            Haptics.impact(.light)
        } label: {
            VStack(spacing: 5) {
                HStack(spacing: 3) {
                    Text(tier.title)
                        .font(.caption.weight(.semibold))
                    if current {
                        Text(L10n.Paywall.currentBadge.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(BondTheme.ink.opacity(0.1), in: Capsule())
                    } else {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.caption2)
                            .accessibilityHidden(true)
                    }
                }
                Text(priceText(for: tier))
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(L10n.Paywall.perWeek)
                    .font(.caption2)
                    .opacity(0.72)
            }
            .foregroundStyle(selected ? BondTheme.onAccent : BondTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(
                selected ? BondTheme.acid : BondTheme.surface,
                in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous)
                    .stroke(selected ? Color.clear : BondTheme.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.pressable)
        .disabled(busy || locked)
        .opacity(locked ? 0.55 : 1)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("paywall.plan.\(tier.serverValue)")
    }

    private var checkout: some View {
        VStack(spacing: 7) {
            if let failure = store.productLoadFailure,
               store.displayPrice(for: selectedTier) == nil {
                HStack(spacing: 8) {
                    Text(failure)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Button(L10n.CampusDesign.retryPrices) {
                        Task { await store.loadProducts() }
                    }
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 44)
                    .disabled(busy || store.isLoadingProducts)
                    .accessibilityIdentifier("paywall.retry")
                }
            }

            if currentTier == .pro {
                Text(L10n.Paywall.proAlready)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BondTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(BondTheme.surface, in: Capsule())
            } else {
            Button {
                Task { await purchase() }
            } label: {
                HStack(spacing: 8) {
                    if store.purchasingTier != nil {
                        ProgressView().tint(BondTheme.onAccent)
                    }
                    Text(ctaTitle)
                        .fontWeight(.semibold)
                    Spacer(minLength: 8)
                    if selectedTier > currentTier, let price = store.displayPrice(for: selectedTier) {
                        Text(price).font(.headline)
                    }
                }
                .padding(.horizontal, BondTheme.Space.md)
                .frame(maxWidth: .infinity, minHeight: 54)
                .foregroundStyle(BondTheme.onAccent)
                .background(BondTheme.acid, in: Capsule())
            }
            .buttonStyle(.pressable)
            .disabled(!canPurchaseSelectedTier)
            .opacity(canPurchaseSelectedTier ? 1 : 0.45)
            .accessibilityIdentifier("paywall.purchase")
            }

            Text(L10n.Paywall.legal)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { legalLinks }
                VStack(spacing: 0) { legalLinks }
            }
            .font(.caption)
            .tint(BondTheme.ink)
            .frame(maxWidth: .infinity)
        }
    }

    private var canPurchaseSelectedTier: Bool {
        selectedTier > currentTier
            && store.displayPrice(for: selectedTier) != nil
            && store.canPurchase(selectedTier)
            && !busy
    }

    private var ctaTitle: String {
        if selectedTier <= currentTier { return L10n.Paywall.onCurrentPlan }
        return selectedTier == .plus ? L10n.Paywall.goPlus : L10n.Paywall.goPro
    }

    private func priceText(for tier: SubscriptionTier) -> String {
        if let price = store.displayPrice(for: tier) { return price }
        return store.productLoadFailure == nil
            ? L10n.CampusDesign.priceLoading
            : L10n.PaywallDesign.priceUnavailable
    }

    private func accessibilityComparison(for feature: PlanFeature) -> String {
        let values = tiers.map { "\($0.title): \(feature.value($0))" }.joined(separator: ", ")
        return "\(feature.label.replacingOccurrences(of: "\n", with: " ")), \(values)"
    }

    private func featureSymbol(_ id: Int) -> String {
        switch id {
        case 2: "rectangle.stack"
        case 3: "mappin.and.ellipse"
        case 5: "eye"
        case 7: "pencil"
        case 8: "chart.bar"
        case 9: "eye.slash"
        default: "checkmark"
        }
    }

    @ViewBuilder private var legalLinks: some View {
        Button(store.isRestoring ? L10n.Paywall.restoring : L10n.Paywall.restore) {
            Task { await restore() }
        }
        .disabled(busy)
        .frame(minHeight: 44)
        .accessibilityIdentifier("paywall.restore")

        Button(L10n.Paywall.terms) { legalDocument = .kosullar }
            .frame(minHeight: 44)
            .accessibilityIdentifier("paywall.terms")

        Button(L10n.Paywall.privacy) { legalDocument = .gizlilik }
            .frame(minHeight: 44)
            .accessibilityIdentifier("paywall.privacy")
    }

    private func purchase() async {
        switch await store.purchase(selectedTier) {
        case .success(let kademe):
            Haptics.success()
            dismiss()
            Task { await appState.confirmPlanWithServer(expecting: kademe) }
        case .cancelled:
            break
        case .pending:
            alertMessage = L10n.Paywall.pending
        case .failed(let message):
            alertMessage = message
        }
    }

    private func restore() async {
        let message = await store.restore()
        // Cihazda abonelik yoksa bile sunucu planı biliyor olabilir (kurucu,
        // hediye, başka cihaz). Ona sormadan "abonelik bulunamadı" demiyoruz.
        await appState.refreshServerPlan()
        if appState.tier == .free, let message {
            alertMessage = message
            return
        }
        Haptics.success()
        dismiss()
    }
}
