import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

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
                WelcomeView(
                    onContinue: { appState.beginOnboarding() },
                    onRequestCode: { email in
                        await appState.requestLoginCode(email: email)
                    },
                    onLogin: { email, code in
                        await appState.signIn(email: email, code: code)
                    }
                )
            case .onboarding(let step):
                OnboardingFlow(step: step)
            case .app:
                MainTabView()
            }
        }
        .preferredColorScheme(resolvedColorScheme)
        .task { await appState.restoreBackendSession() }
        .overlay(alignment: .top) {
            if let toast = appState.toast {
                AppToast(message: toast)
                    .padding(.horizontal, CampusTheme.Space.lg)
                    .padding(.top, CampusTheme.Space.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .task(id: appState.toast) {
            guard let toast = appState.toast else { return }
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled, appState.toast == toast else { return }
            withAnimation(.snappy) { appState.toast = nil }
        }
    }
}

private struct AppToast: View {
    let message: String

    var body: some View {
        HStack(spacing: CampusTheme.Space.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CampusTheme.acid)
            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .foregroundStyle(CampusTheme.paper)
        .padding(.horizontal, CampusTheme.Space.lg)
        .frame(minHeight: 48)
        .background(CampusTheme.ink, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.control, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 7)
        .accessibilityElement(children: .combine)
    }
}

struct WelcomeView: View {
    let onContinue: () -> Void
    var onRequestCode: (String) async -> Bool = { _ in false }
    var onLogin: (String, String) async -> Bool = { _, _ in false }
    @State private var appeared = false
    @State private var float = false
    @State private var loginGlow = false
    @State private var showLogin = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CampusTheme.paper.ignoresSafeArea()
                Circle().fill(CampusTheme.violet.opacity(0.16)).frame(width: 330).blur(radius: 18)
                    .offset(x: 150, y: float ? -240 : -210)
                Circle().fill(CampusTheme.acid.opacity(0.38)).frame(width: 240).blur(radius: 12)
                    .offset(x: -150, y: float ? 160 : 200)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Wordmark().foregroundStyle(CampusTheme.ink)
                        Spacer()
                        Button { showLogin = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .symbolEffect(.pulse, options: .repeating)
                                Text("GİRİŞ")
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .tracking(1.1)
                            }
                            .foregroundStyle(CampusTheme.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(CampusTheme.acid.opacity(loginGlow ? 1 : 0.68), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1))
                            .shadow(color: CampusTheme.acid.opacity(loginGlow ? 0.75 : 0.2), radius: loginGlow ? 14 : 4)
                            .scaleEffect(loginGlow ? 1.035 : 1)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    .frame(height: 48)

                    Spacer(minLength: 20)

                    Text("Kampüste olup\nbitenlere **dahil ol.**")
                        .editorialTitle(min(48, proxy.size.width * 0.117))
                        .foregroundStyle(CampusTheme.ink).lineSpacing(-4)

                    Text("Anlarını paylaş. Yeni insanlarla tanış. Sohbeti gerçek hayata taşı.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(CampusTheme.ink.opacity(0.52)).lineSpacing(4)
                        .frame(maxWidth: 310, alignment: .leading).padding(.top, 14)

                    WelcomeSocialCanvas()
                        .frame(height: min(315, proxy.size.height * 0.38))
                        .padding(.top, 22)

                    Spacer(minLength: 18)

                    Button {
                        Haptics.impact(.light)
                        onContinue()
                    } label: {
                        HStack {
                            Text("COMMON'A KATIL").font(.system(size: 11, weight: .black, design: .rounded)).tracking(1.2)
                            Spacer()
                            Image(systemName: "arrow.right").font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(CampusTheme.paper).padding(.horizontal, 20).frame(height: 58)
                        .background(CampusTheme.ink).clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
                .frame(width: proxy.size.width - 44, height: proxy.size.height, alignment: .top)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .padding(.bottom, 10)
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { appeared = true }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { float = true }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { loginGlow = true }
        }
        .sheet(isPresented: $showLogin) {
            LoginView(
                requestCode: onRequestCode,
                login: { email, code in
                    let success = await onLogin(email, code)
                    if success { showLogin = false }
                    return success
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    let requestCode: (String) async -> Bool
    let login: (String, String) async -> Bool
    @State private var email = ""
    @State private var code = ""
    @State private var codeRequested = false
    @State private var isRequestingCode = false
    @State private var isLoggingIn = false
    @State private var resendCooldown = 0

    private func startResendCooldown() { resendCooldown = 30 }

    private var usernameIsValid: Bool {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return UniversityDomain.isValid(normalized)
    }
    private var isValid: Bool {
        codeRequested && usernameIsValid && code.count == 6
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "tekrar hoş geldin", color: CampusTheme.ink.opacity(0.45))
                    Text("Giriş yap").editorialTitle(38)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                        .background(CampusTheme.ink.opacity(0.07), in: Circle())
                }
                .accessibilityLabel("Kapat")
            }

            VStack(spacing: 14) {
                EditorialLoginField(title: "ÜNİVERSİTE E-POSTASI", text: $email, keyboard: .emailAddress)
                    .disabled(codeRequested)
                if codeRequested {
                    EditorialLoginField(title: "GİRİŞ KODU", text: $code, keyboard: .numberPad)
                        .onChange(of: code) { _, newValue in
                            code = String(newValue.filter(\.isNumber).prefix(6))
                        }
                }
            }

            Text(codeRequested
                 ? "E-postana gelen altı haneli kodu gir."
                 : "Üniversite e-postana tek kullanımlık kod göndereceğiz.")
                .font(.caption).foregroundStyle(CampusTheme.ink.opacity(0.48))

            if codeRequested {
                PrimaryEditorialButton(title: isLoggingIn ? "GİRİŞ YAPILIYOR…" : "GİRİŞ YAP", enabled: isValid && !isLoggingIn) {
                    guard !isLoggingIn else { return }
                    isLoggingIn = true
                    Task {
                        let success = await login(email, code)
                        await MainActor.run { if !success { isLoggingIn = false } }
                    }
                }
                // Kod istendikten sonra e-posta alanı kilitleniyor. Kod gelmezse ya da adres
                // yanlış yazıldıysa bu iki çıkış olmadan kullanıcının tek seçeneği ekranı
                // kapatmak oluyordu.
                HStack(spacing: 18) {
                    Button(resendCooldown > 0 ? "Tekrar gönder (\(resendCooldown))" : "Kodu tekrar gönder") {
                        guard resendCooldown == 0, !isRequestingCode else { return }
                        isRequestingCode = true
                        Task {
                            let sent = await requestCode(email)
                            await MainActor.run {
                                isRequestingCode = false
                                if sent { startResendCooldown() }
                            }
                        }
                    }
                    .disabled(resendCooldown > 0 || isRequestingCode)
                    .foregroundStyle(resendCooldown > 0 || isRequestingCode ? CampusTheme.ink.opacity(0.32) : CampusTheme.violet)

                    Button("E-postayı değiştir") {
                        codeRequested = false
                        code = ""
                        resendCooldown = 0
                    }
                    .foregroundStyle(CampusTheme.violet)

                    Spacer()
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            } else {
                PrimaryEditorialButton(title: isRequestingCode ? "GÖNDERİLİYOR…" : "KODU GÖNDER", enabled: usernameIsValid && !isRequestingCode) {
                    guard !isRequestingCode else { return }
                    isRequestingCode = true
                    Task {
                        let sent = await requestCode(email)
                        await MainActor.run {
                            isRequestingCode = false
                            if sent {
                                codeRequested = true
                                startResendCooldown()
                            }
                        }
                    }
                }
            }
        }
        .task(id: resendCooldown) {
            guard resendCooldown > 0 else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            resendCooldown -= 1
        }
        .foregroundStyle(CampusTheme.ink)
        .padding(24)
        .background(CampusTheme.paper.ignoresSafeArea())
    }
}

private struct EditorialLoginField: View {
    let title: String
    @Binding var text: String
    let keyboard: UIKeyboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Eyebrow(text: title, color: CampusTheme.ink.opacity(0.4))
            TextField("", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct WelcomeSocialCanvas: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28).fill(CampusTheme.ink).rotationEffect(.degrees(-3))
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack { Circle().fill(CampusTheme.coral).frame(width: 34, height: 34); Text("Ece bir an paylaştı").font(.caption.bold()); Spacer(); Image(systemName: "heart") }
                        Text("Ders sonrası planı:\nkendimizi dışarı atmak.").font(.system(size: 23, weight: .medium, design: .serif))
                        HStack { Label("Hazırlık Kantini", systemImage: "mappin"); Spacer(); Text("12 dk") }.font(.caption).opacity(0.6)
                    }.foregroundStyle(CampusTheme.paper).padding(22)
                }
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Circle().fill(CampusTheme.acid).frame(width: 46, height: 46).overlay(Image(systemName: "message.fill").foregroundStyle(CampusTheme.ink))
                    VStack(alignment: .leading, spacing: 3) { Text("Yeni bir sohbet başladı").font(.caption.bold()); Text("“Kahve için hâlâ geç değil.”").font(.caption).opacity(0.55) }
                    Spacer()
                }
                .foregroundStyle(CampusTheme.ink).padding(14).background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.12), radius: 20, y: 10).padding(.horizontal, 18).offset(y: 18)
            }
        }
        .padding(10)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r, g, b: UInt64
        (r, g, b) = ((value >> 16) & 255, (value >> 8) & 255, value & 255)
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}
