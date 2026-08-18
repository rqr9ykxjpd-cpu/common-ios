import SwiftUI
import UIKit
import AuthenticationServices
import CryptoKit
import GoogleSignIn

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
                WelcomeView()
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
            // Süre metnin uzunluğuna göre: "Gönderi paylaşıldı" ile iki satırlık bir hata
            // açıklaması aynı sürede kaybolunca uzun olan okunamıyordu.
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
        HStack(spacing: CampusTheme.Space.sm) {
            Image(systemName: message.systemImage)
                .foregroundStyle(message.kind == .error ? CampusTheme.coral : CampusTheme.acid)
            Text(message.text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(3)
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
    @Environment(AppState.self) private var appState
    @State private var appeared = false
    @State private var float = false
    @State private var currentAppleNonce: String?
    @State private var isSigningIn = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CampusTheme.paper.ignoresSafeArea()
                Circle().fill(CampusTheme.violet.opacity(0.16)).frame(width: 330).blur(radius: 18)
                    .offset(x: 150, y: float ? -240 : -210)
                Circle().fill(CampusTheme.acid.opacity(0.38)).frame(width: 240).blur(radius: 12)
                    .offset(x: -150, y: float ? 160 : 200)

                VStack(alignment: .leading, spacing: 0) {
                    Wordmark().foregroundStyle(CampusTheme.ink).frame(height: 48)

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

                    VStack(spacing: 12) {
                        SignInWithAppleButton(.continue) { request in
                            let nonce = Self.randomNonceString()
                            currentAppleNonce = nonce
                            request.requestedScopes = [.email, .fullName]
                            request.nonce = Self.sha256(nonce)
                        } onCompletion: { result in
                            handleAppleCompletion(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .disabled(isSigningIn)

                        Button {
                            Haptics.impact(.light)
                            signInWithGoogle()
                        } label: {
                            HStack {
                                Image(systemName: "g.circle.fill").font(.system(size: 18))
                                Text("GOOGLE İLE DEVAM ET").font(.system(size: 11, weight: .black, design: .rounded)).tracking(1.2)
                                Spacer()
                            }
                            .foregroundStyle(CampusTheme.ink).padding(.horizontal, 20).frame(height: 56)
                            .background(CampusTheme.surface).clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(CampusTheme.ink.opacity(0.12)))
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(isSigningIn)
                    }

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
        }
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentAppleNonce else {
                appState.showError("Apple ile giriş tamamlanamadı.")
                return
            }
            isSigningIn = true
            Task {
                await appState.signInWithApple(idToken: idToken, nonce: nonce)
                isSigningIn = false
            }
        case .failure(let error):
            // Kullanıcı iptal ettiğinde de bu dal çalışır; ASAuthorizationError.canceled
            // için sessizce geç, gerçek hatalarda toast göster.
            let nsError = error as NSError
            guard nsError.code != ASAuthorizationError.canceled.rawValue else { return }
            appState.showError(error, fallback: "Apple ile giriş yapılamadı.")
        }
    }

    private func signInWithGoogle() {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else { return }
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do {
                // Apple akışıyla birebir aynı desen: ham nonce bizde kalır, Google'a
                // SHA256'sı gider (id_token'a o yazılır), Supabase'e ham hali gider ve
                // o da hash'leyip token'daki değerle karşılaştırır.
                //
                // Nonce'u kendimiz vermek zorundayız: vermezsek GoogleSignIn'in altındaki
                // AppAuth kendiliğinden bir tane üretiyor, Supabase ise gönderilen nonce'u
                // hash'leyerek karşılaştırdığı için ham değeri geri iletmek de çözmüyordu
                // ("nonces mismatch"). Dışarıdan nonce vermek GoogleSignIn 9'da mümkün.
                let nonce = Self.randomNonceString()
                let result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: rootViewController,
                    hint: nil,
                    additionalScopes: nil,
                    nonce: Self.sha256(nonce)
                )
                guard let idToken = result.user.idToken?.tokenString else {
                    appState.showError("Google ile giriş tamamlanamadı.")
                    return
                }
                await appState.signInWithGoogle(
                    idToken: idToken,
                    accessToken: result.user.accessToken.tokenString,
                    nonce: nonce
                )
            } catch {
                let nsError = error as NSError
                guard nsError.code != GIDSignInError.canceled.rawValue else { return }
                appState.showError(error, fallback: "Google ile giriş yapılamadı.")
            }
        }
    }

    /// Apple'ın kendi örnek koduyla birebir aynı: kriptografik olarak güvenli, URL-safe
    /// karakter kümesinden rastgele bir dize üretir. Bu ham değer nonce olarak Supabase'e
    /// gider; Apple'a giden istekte yalnızca SHA256 hash'i kullanılır.
    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            precondition(status == errSecSuccess)
            for random in randoms {
                if remainingLength == 0 { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
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
