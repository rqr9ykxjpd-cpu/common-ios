import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Karşılama ve kayıt akışı her zaman açık modda kalır. Bu ekranlardaki kullanıcı
    /// henüz bir görünüm tercihi yapmadı — ayara ancak giriş yaptıktan sonra ulaşıyor —
    /// ve telefonu koyu diye uygulamanın ilk izlenimini koyu göstermek onun seçimi değil.
    /// Koyu mod, isteyenin uygulama içinden açtığı bir tercih olarak kalıyor.
    private var resolvedColorScheme: ColorScheme? {
        switch appState.route {
        case .welcome, .onboarding: .light
        case .app: appState.appearance.colorScheme
        }
    }

    var body: some View {
        Group {
            switch appState.route {
            case .welcome:
                WelcomeView()
            case .onboarding(let step):
                OnboardingFlow(step: step)
            case .app:
                MainTabView()
            }
        }
        .preferredColorScheme(resolvedColorScheme)
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        // Sınıra hangi ekranda takılırsan takıl, açılacak yer burası: tek bir
        // sunum noktası, her ekrana ayrı ayrı bağlamaktan güvenli.
        .sheet(isPresented: Binding(
            get: { appState.paywallVisible },
            set: { appState.paywallVisible = $0; if !$0 { appState.quotaHit = nil } }
        )) {
            PaywallView(quota: appState.quotaHit)
        }
        .task { await appState.restoreBackendSession() }
        // Ürünler ve haklar açılışta okunuyor: aboneliği başka cihazda alan ya
        // da uygulamayı silip kuran kullanıcı, paywall'a hiç uğramadan
        // hakkına kavuşmalı.
        .task { await appState.refreshSubscriptions() }
        .onChange(of: scenePhase) { previous, phase in
            // Arka planda anlık kanal kopuyor; dönüşte kaçan mesajları getiriyoruz.
            guard phase == .active, previous != .active else { return }
            Task { await appState.refreshAfterForeground() }
        }
        .alert(
            L10n.Errors.title,
            isPresented: Binding(
                get: { appState.toast?.kind == .error },
                set: { isPresented in
                    if !isPresented, appState.toast?.kind == .error {
                        appState.toast = nil
                    }
                }
            )
        ) {
            Button(L10n.Common.ok) { appState.toast = nil }
        } message: {
            if let error = appState.toast, error.kind == .error {
                Text(error.text)
            }
        }
        .overlay(alignment: .top) {
            if let toast = appState.toast, toast.kind == .info {
                AppToast(message: toast)
                    .padding(.horizontal, BondTheme.Space.lg)
                    // Alttaki ekranlar zemini `ignoresSafeArea` ile çizdiği için bilgi
                    // mesajını durum çubuğunun ve çentiğin altında tutuyoruz.
                    .safeAreaPadding(.top)
                    .padding(.top, BondTheme.Space.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .task(id: appState.toast) {
            guard let toast = appState.toast, toast.kind == .info else { return }
            // Kısa bilgi mesajlarının süresini metnin okunma uzunluğuna göre ayarlıyoruz.
            // Hatalar native alert içinde kullanıcı kapatana kadar görünür kalıyor.
            let readingTime = 1.6 + Double(toast.text.count) * 0.045
            try? await Task.sleep(for: .seconds(min(max(readingTime, 2.4), 6)))
            guard !Task.isCancelled, appState.toast == toast else { return }
            withAnimation(.snappy) { appState.toast = nil }
        }
    }
}

private struct AppToast: View {
    let message: AppToastMessage

    var body: some View {
        HStack(spacing: BondTheme.Space.sm) {
            Image(systemName: message.systemImage)
                .foregroundStyle(message.kind == .error ? BondTheme.coral : BondTheme.acid)
            Text(message.text)
                .font(BondTheme.Typography.footnote.weight(.medium))
                .lineLimit(6)
            Spacer(minLength: 0)
        }
        .foregroundStyle(BondTheme.ink)
        .padding(.horizontal, BondTheme.Space.lg)
        .frame(minHeight: 48)
        .background(BondTheme.surface, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
