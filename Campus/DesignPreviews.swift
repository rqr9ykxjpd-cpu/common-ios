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

#Preview("Sosyal Profil") {
    SocialProfileView()
        .environment(AppState())
        .preferredColorScheme(.light)
}
