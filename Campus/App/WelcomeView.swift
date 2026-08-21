import SwiftUI
import UIKit
import AuthenticationServices
import CryptoKit
import GoogleSignIn

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var appeared = false
    @State private var currentAppleNonce: String?
    @State private var isSigningIn = false

    /// E-posta ile giriş girişinin görünürlüğü. bkz. aşağıdaki açıklama.
    private static let epostaGirisiAcik = false
    @State private var showingEmailSignIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Wordmark()
                .frame(height: 44)

            Spacer(minLength: CampusTheme.Space.lg)

            Text(L10n.Welcome.headline)
                .campusDisplay(34)
                .foregroundStyle(CampusTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.Welcome.subtitle)
                .font(CampusTheme.Typography.body)
                .foregroundStyle(CampusTheme.muted)
                .padding(.top, CampusTheme.Space.sm)

            WelcomeSocialCanvas()
                .frame(maxHeight: 220)
                .padding(.top, CampusTheme.Space.xl)

            Spacer(minLength: CampusTheme.Space.lg)

            VStack(spacing: CampusTheme.Space.sm) {
                SignInWithAppleButton(.continue) { request in
                    let nonce = Self.randomNonceString()
                    currentAppleNonce = nonce
                    request.requestedScopes = [.email, .fullName]
                    request.nonce = Self.sha256(nonce)
                } onCompletion: { result in
                    handleAppleCompletion(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(Capsule())
                .disabled(isSigningIn)

                Button {
                    Haptics.impact(.light)
                    signInWithGoogle()
                } label: {
                    Text(L10n.Welcome.googleContinue)
                        .font(CampusTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(CampusTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .background(CampusTheme.surface, in: Capsule())
                        .overlay(Capsule().stroke(CampusTheme.hairline, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                .disabled(isSigningIn)
                .accessibilityLabel(L10n.Welcome.googleContinue)

                if Self.epostaGirisiAcik {
                    Button {
                        Haptics.impact(.light)
                        showingEmailSignIn = true
                    } label: {
                        Text(L10n.Welcome.emailContinue)
                            .font(CampusTheme.Typography.footnote.weight(.medium))
                            .foregroundStyle(CampusTheme.violet)
                            .frame(minHeight: 44)
                    }
                    .disabled(isSigningIn)
                }
            }

            legalConsent
        }
        .padding(.horizontal, CampusTheme.Space.lg)
        .padding(.vertical, CampusTheme.Space.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(CampusTheme.paper.ignoresSafeArea())
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(CampusTheme.Motion.easing) { appeared = true }
        }
        .sheet(isPresented: $showingEmailSignIn) {
            EmailSignInSheet()
        }
    }

    /// Kullanıcı içeriği barındıran uygulamalarda Apple, koşulların kayıt sırasında
    /// kabul edilmesini ve metinlerin uygulamadan okunabilmesini şart koşuyor. Ayrı
    /// bir onay kutusu yerine giriş eylemine bağlıyoruz; yerleşik ve kabul gören
    /// biçim bu.
    @State private var legalDocument: LegalDocumentRoute?

    private var legalConsent: some View {
        // Tek bir cümle: parçalara bölünce satırlar ortalanınca tırtıklı duruyordu
        // ve bağlantılar düz metinden ayırt edilemiyordu. Markdown bağlantıları
        // `tint` rengini alıyor, dolayısıyla tıklanabilir oldukları belli oluyor.
        Text(LocalizedStringKey(L10n.Welcome.legalConsent(Self.kosullarURL.absoluteString, Self.gizlilikURL.absoluteString)))
            .font(CampusTheme.Typography.footnote)
            .foregroundStyle(CampusTheme.muted)
            .multilineTextAlignment(.center)
            .tint(CampusTheme.violet)
            .padding(.top, CampusTheme.Space.md)
            // Bağlantılar tarayıcı yerine uygulama içindeki metni açıyor: aynı
            // metin, internet gerektirmeden ve barındırmaya bağlı kalmadan.
            .environment(\.openURL, OpenURLAction { url in
                legalDocument = url == Self.gizlilikURL ? .gizlilik : .kosullar
                return .handled
            })
            .sheet(item: $legalDocument) { belge in
                NavigationStack {
                    LegalTextView(title: belge.title, blocks: belge.blocks)
                }
            }
    }

    private static let kosullarURL = URL(string: "https://rqr9ykxjpd-cpu.github.io/common-ios/kosullar.html")!
    private static let gizlilikURL = URL(string: "https://rqr9ykxjpd-cpu.github.io/common-ios/gizlilik.html")!

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentAppleNonce else {
                appState.showError(L10n.Welcome.appleIncomplete)
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
            appState.showError(error, fallback: L10n.Auth.appleFailed)
        }
    }

    private func signInWithGoogle() {
        let clientID = AppSecrets.googleClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let serverClientID = AppSecrets.googleServerClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty, !serverClientID.isEmpty else {
            appState.showError(L10n.Errors.googleNotConfigured)
            return
        }
        // SDK Info.plist'teki GIDClientID'den de okur; AppSecrets aynı derlemede güncel
        // kalır (xcconfig bir build geriden gelebilir), o yüzden burada da basıyoruz.
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientID,
            serverClientID: serverClientID
        )
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
                    appState.showError(L10n.Welcome.googleIncomplete)
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
                appState.showError(error, fallback: L10n.Auth.googleFailed)
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

/// Apple/Google yanına eklenen üçüncü giriş yolu: üniversite e-postasına giriş
/// bağlantısı gönderip mailden dönüşü bekleme. Kod yerine link kullanıyoruz çünkü
/// Supabase'in "Confirm signup" şablonu Free planda özelleştirilemiyor (kodu göstermek
/// için Pro'ya geçmek ya da custom SMTP kurmak gerekiyordu, ikincisinin bu üniversite
/// sunucusuna teslimat sorunu vardı) — varsayılan şablondaki link zaten çalışıyordu.
/// Kabul kriteri istemcide değil sunucuda (Before User Created hook) — buradaki
/// `.edu.tr` biçim kontrolü yalnızca erken geri bildirim için, güvenlik sınırı değil.
struct EmailSignInSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    enum Step { case email, sent }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var isBusy = false
    @FocusState private var fieldFocused: Bool

    private var looksLikeEduEmail: Bool {
        email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(".edu.tr")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: CampusTheme.Space.xl) {
                switch step {
                case .email:
                    VStack(alignment: .leading, spacing: CampusTheme.Space.sm) {
                        Text(L10n.Welcome.emailTitle)
                            .font(CampusTheme.Typography.title2)
                            .foregroundStyle(CampusTheme.ink)
                        Text(L10n.Welcome.emailSubtitle)
                            .font(CampusTheme.Typography.footnote)
                            .foregroundStyle(CampusTheme.muted)
                    }

                    TextField(L10n.Welcome.emailPlaceholder, text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($fieldFocused)
                        .font(CampusTheme.Typography.body)
                        .padding(CampusTheme.Space.md)
                        .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))

                    Spacer(minLength: 0)

                    AppButton(title: isBusy ? L10n.Common.sending : L10n.Welcome.sendLink, enabled: !isBusy && looksLikeEduEmail) {
                        Task {
                            Haptics.impact(.light)
                            isBusy = true
                            let sent = await appState.requestEmailSignInLink(email)
                            isBusy = false
                            if sent {
                                Haptics.success()
                                withAnimation(.snappy) { step = .sent }
                            }
                        }
                    }

                case .sent:
                    VStack(alignment: .leading, spacing: CampusTheme.Space.sm) {
                        Text(L10n.Welcome.checkInbox)
                            .font(CampusTheme.Typography.title2)
                            .foregroundStyle(CampusTheme.ink)
                        Text(L10n.Welcome.linkSent(email))
                            .font(CampusTheme.Typography.footnote)
                            .foregroundStyle(CampusTheme.muted)
                    }

                    Spacer(minLength: 0)

                    Button(L10n.Welcome.tryDifferentEmail) {
                        withAnimation(CampusTheme.Motion.easing) { step = .email }
                    }
                    .font(CampusTheme.Typography.body.weight(.medium))
                    .foregroundStyle(CampusTheme.violet)
                    .frame(minHeight: 44)
                }
            }
            .padding(CampusTheme.Space.xl)
            .background(CampusTheme.paper)
            .dismissesKeyboardOnTap()
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .onAppear { fieldFocused = true }
        }
        .presentationDetents([.medium])
    }
}

struct WelcomeSocialCanvas: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            VStack(alignment: .leading, spacing: CampusTheme.Space.sm) {
                Text(L10n.Welcome.canvasPostMeta)
                    .font(CampusTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(CampusTheme.muted)
                Text(L10n.Welcome.canvasCaption)
                    .font(CampusTheme.Typography.title3)
                    .foregroundStyle(CampusTheme.ink)
                Text(L10n.Welcome.canvasPlace)
                    .font(CampusTheme.Typography.caption)
                    .foregroundStyle(CampusTheme.muted)
            }
            .padding(CampusTheme.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))

            HStack(spacing: CampusTheme.Space.sm) {
                Image(systemName: "message.fill")
                    .font(.body)
                    .foregroundStyle(CampusTheme.acid)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Welcome.canvasChatMeta)
                        .font(CampusTheme.Typography.footnote.weight(.medium))
                    Text(L10n.Welcome.canvasQuote)
                        .font(CampusTheme.Typography.caption)
                        .foregroundStyle(CampusTheme.muted)
                }
                Spacer()
            }
            .foregroundStyle(CampusTheme.ink)
        }
    }
}

