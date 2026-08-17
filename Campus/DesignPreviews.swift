import SwiftUI

#Preview("▶ TAM UYGULAMA") {
    RootView()
        .environment(AppState())
}

#Preview("Karşılama") {
    WelcomeView(onContinue: {})
        .preferredColorScheme(.light)
}

#Preview("Onboarding — E-posta") {
    OnboardingFlow(step: .email)
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

#Preview("Eşleşme Anı") {
    MatchMomentView(profile: StudentProfile.samples[1], close: {}, message: {})
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
