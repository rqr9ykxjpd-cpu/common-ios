import SwiftUI
import UIKit
import AuthenticationServices
import CryptoKit
import GoogleSignIn

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppleAccountDeletionNotice.defaultsKey) private var showAppleDeletionNotice = false
    @State private var appeared = false
    @State private var currentAppleNonce: String?
    @State private var isSigningIn = false

    /// E-posta ile giriş App Store sürümünde kapalı. Debug'da da demo hesap
    /// yolu yok — gerçek Apple/Google oturumu kullanılır.
    private static let epostaGirisiAcik = false
    @State private var showingEmailSignIn = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.Brand.wordmark)
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .tracking(-0.8)
                    .foregroundStyle(BondTheme.ink)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                    Text(L10n.Welcome.headline)
                        .editorialTitle(38)
                        .foregroundStyle(BondTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text(L10n.Welcome.handNote)
                        .font(.custom("BradleyHandITCTT-Bold", size: 18, relativeTo: .callout))
                        .foregroundStyle(BondTheme.burntOrange)
                        .rotationEffect(.degrees(-0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, BondTheme.Space.lg)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 10)
                .animation(reduceMotion ? nil : BondTheme.Motion.smooth.delay(0.04), value: appeared)

                VStack(spacing: BondTheme.Space.md) {
                    ForEach(Array(welcomeFeatures.enumerated()), id: \.offset) { index, feature in
                        WelcomeFeatureRow(
                            systemImage: feature.systemImage,
                            title: feature.title,
                            detail: feature.detail
                        )
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared || reduceMotion ? 0 : 12)
                        .animation(
                            reduceMotion ? nil : BondTheme.Motion.smooth.delay(0.10 + Double(index) * 0.06),
                            value: appeared
                        )
                    }
                }
                .padding(.top, BondTheme.Space.xxl)
            }
            .padding(.horizontal, BondTheme.Space.lg)
            .padding(.top, BondTheme.Space.xl)
            .padding(.bottom, BondTheme.Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(BondTheme.paper.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            signInFooter
        }
        .onAppear {
            appeared = true
        }
        .sheet(isPresented: $showingEmailSignIn) {
            EmailSignInSheet()
        }
        .alert(L10n.AccountDeletion.deletedTitle, isPresented: $showAppleDeletionNotice) {
            Button(L10n.AccountDeletion.appleInstructions) {
                openURL(AppleAccountDeletionNotice.instructionsURL)
            }
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(L10n.AccountDeletion.deletedManualBody)
        }
    }

    private var welcomeFeatures: [(systemImage: String, title: String, detail: String)] {
        [
            ("text.below.photo", L10n.Welcome.featureShareTitle, L10n.Welcome.featureShareBody),
            ("person.3", L10n.Welcome.featureClubsTitle, L10n.Welcome.featureClubsBody),
            ("mappin.and.ellipse", L10n.Welcome.featureOfflineTitle, L10n.Welcome.featureOfflineBody),
        ]
    }

    private var signInFooter: some View {
        VStack(spacing: BondTheme.Space.sm) {
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
            .opacity(isSigningIn ? 0.45 : 1)

            Button {
                Haptics.impact(.light)
                signInWithGoogle()
            } label: {
                Text(L10n.Welcome.googleContinue)
                    .font(BondTheme.Typography.body.weight(.semibold))
                    .foregroundStyle(BondTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(BondTheme.surface, in: Capsule())
                    .overlay(Capsule().stroke(BondTheme.hairline, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .disabled(isSigningIn)
            .opacity(isSigningIn ? 0.45 : 1)
            .accessibilityLabel(L10n.Welcome.googleContinue)

            if Self.epostaGirisiAcik {
                Button {
                    Haptics.impact(.light)
                    showingEmailSignIn = true
                } label: {
                    Text(L10n.Welcome.emailContinue)
                        .font(BondTheme.Typography.footnote.weight(.medium))
                        .foregroundStyle(BondTheme.violet)
                        .frame(minHeight: 44)
                }
                .disabled(isSigningIn)
                .opacity(isSigningIn ? 0.45 : 1)
            }

            // Giriş sırasında ekran donmuş görünüyordu: düğmeler devre dışı
            // kalıyordu ama hiçbir görsel işaret yoktu, kullanıcı bir şey
            // olmadığını sanıp tekrar tekrar dokunuyordu.
            if isSigningIn {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(L10n.Welcome.signingIn)
                        .font(BondTheme.Typography.footnote)
                        .foregroundStyle(BondTheme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .transition(.opacity)
            }

            legalConsent
        }
        .animation(.smooth(duration: 0.25), value: isSigningIn)
        .padding(.horizontal, BondTheme.Space.lg)
        .padding(.top, BondTheme.Space.md)
        .padding(.bottom, BondTheme.Space.md)
        .background(BondTheme.paper)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(BondTheme.hairline.opacity(0.7))
                .frame(height: 0.5)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 12)
        .animation(reduceMotion ? nil : BondTheme.Motion.smooth.delay(0.22), value: appeared)
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
            .font(BondTheme.Typography.footnote)
            .foregroundStyle(BondTheme.muted)
            .multilineTextAlignment(.center)
            .tint(BondTheme.violet)
            .padding(.top, BondTheme.Space.md)
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

/// Apple/Google yanına eklenen üçüncü giriş yolu.
/// Debug derlemesinde e-posta + şifre (demo hesaplar). Release'de sihirli bağlantı.
struct EmailSignInSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    enum Step { case email, sent }

    @State private var step: Step = .email
    @State private var email = ""
#if DEBUG
    @State private var password = ""
#endif
    @State private var isBusy = false
    @FocusState private var fieldFocused: Bool

    private var looksLikeEmail: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = value.firstIndex(of: "@") else { return false }
        let local = value[..<at]
        let domain = value[value.index(after: at)...]
        return !local.isEmpty && domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

#if DEBUG
    private var canSubmitEmailSignIn: Bool { !password.isEmpty }
    private var emailSignInSubtitle: String { L10n.Welcome.emailPasswordSubtitle }
    private var emailSignInButtonTitle: String {
        isBusy ? L10n.Welcome.signingIn : L10n.Welcome.signInWithPassword
    }
#else
    private var canSubmitEmailSignIn: Bool { true }
    private var emailSignInSubtitle: String { L10n.Welcome.emailSubtitle }
    private var emailSignInButtonTitle: String {
        isBusy ? L10n.Common.sending : L10n.Welcome.sendLink
    }
#endif

    private func submitEmailSignIn() async {
        Haptics.impact(.light)
        isBusy = true
        defer { isBusy = false }
#if DEBUG
        let signedIn = await appState.signInWithEmail(email, password: password)
        if signedIn {
            Haptics.success()
            dismiss()
        }
#else
        let sent = await appState.requestEmailSignInLink(email)
        if sent {
            Haptics.success()
            withAnimation(.snappy) { step = .sent }
        }
#endif
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BondTheme.Space.xl) {
                switch step {
                case .email:
                    VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                        Text(L10n.Welcome.emailTitle)
                            .font(BondTheme.Typography.title2)
                            .foregroundStyle(BondTheme.ink)
                        Text(emailSignInSubtitle)
                            .font(BondTheme.Typography.footnote)
                            .foregroundStyle(BondTheme.muted)
                    }

                    TextField(L10n.Welcome.emailPlaceholder, text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($fieldFocused)
                        .font(BondTheme.Typography.body)
                        .padding(BondTheme.Space.md)
                        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))

#if DEBUG
                    SecureField(L10n.Welcome.passwordPlaceholder, text: $password)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(BondTheme.Typography.body)
                        .padding(BondTheme.Space.md)
                        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
#endif

                    Spacer(minLength: 0)

                    AppButton(title: emailSignInButtonTitle, enabled: !isBusy && looksLikeEmail && canSubmitEmailSignIn) {
                        Task { await submitEmailSignIn() }
                    }

                case .sent:
                    VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                        Text(L10n.Welcome.checkInbox)
                            .font(BondTheme.Typography.title2)
                            .foregroundStyle(BondTheme.ink)
                        Text(L10n.Welcome.linkSent(email))
                            .font(BondTheme.Typography.footnote)
                            .foregroundStyle(BondTheme.muted)
                    }

                    Spacer(minLength: 0)

                    Button(L10n.Welcome.tryDifferentEmail) {
                        withAnimation(BondTheme.Motion.easing) { step = .email }
                    }
                    .font(BondTheme.Typography.body.weight(.medium))
                    .foregroundStyle(BondTheme.violet)
                    .frame(minHeight: 44)
                }
            }
            .padding(BondTheme.Space.xl)
            .background(BondTheme.paper)
            .dismissesKeyboardOnTap()
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .onAppear { fieldFocused = true }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct WelcomeFeatureRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .center, spacing: BondTheme.Space.md) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(BondTheme.ink)
                .frame(width: 42, height: 42)
                .background(BondTheme.surface, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BondTheme.Typography.headline)
                    .foregroundStyle(BondTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(BondTheme.Typography.footnote)
                    .foregroundStyle(BondTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
    }
}
