import SwiftUI

#Preview("▶ TAM UYGULAMA") {
    RootView()
        .environment(AppState())
}

#Preview("Karşılama") {
    WelcomeView()
        .environment(AppState())
        .preferredColorScheme(.light)
}

#Preview("Onboarding — Kimlik") {
    OnboardingFlow(step: .identity)
        .environment(AppState())
        .preferredColorScheme(.light)
}

#Preview("Onboarding — İlgi Alanları") {
    OnboardingFlow(step: .interests)
        .environment(AppState())
        .preferredColorScheme(.light)
}

#Preview("Sosyal Akış") {
    MainTabView()
        .environment(AppState())
        .preferredColorScheme(.light)
}

#Preview("İçerik Oluştur") {
    CreatePostView()
        .environment(AppState())
}

#Preview("Keşfet — Dating") {
    PremiumDiscoverView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Bağlantılar — Premium") {
    PremiumMatchesView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Sistem — Düğmeler") {
    VStack(spacing: 20) {
        AppButton(title: L10n.Common.continue_, role: .primary, action: {})
        AppButton(title: L10n.Common.secondary, role: .secondary, action: {})
        AppButton(title: L10n.Common.disabled, enabled: false, action: {})
        AppTextLink(title: L10n.Common.learnMore, action: {})
        AppLoadingView()
        AppEmptyState(systemImage: "photo.on.rectangle.angled", title: L10n.Common.emptyContent, message: L10n.Feed.emptyMessage, actionTitle: L10n.Feed.share, action: {})
    }
    .padding(20)
    .background(BondTheme.paper)
    .preferredColorScheme(.light)
}

#Preview("Sistem — Koyu") {
    VStack(spacing: 20) {
        AppButton(title: L10n.Common.continue_, role: .primary, action: {})
        AppButton(title: L10n.Common.secondary, role: .secondary, action: {})
        AppEmptyState(systemImage: "tray", title: L10n.Common.empty)
    }
    .padding(20)
    .background(BondTheme.paper)
    .preferredColorScheme(.dark)
}

#Preview("Onboarding — Hazır") {
    OnboardingFlow(step: .ready)
        .environment(AppState())
        .preferredColorScheme(.light)
}
