import Foundation
import Supabase

extension SupabaseProductService {
    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    /// `nonce` ham (hash'lenmemiş) değer olmalı — Apple ile aynı kural. Google'a giden
    /// istekte SHA256'sı kullanılır, Supabase de gönderdiğimiz ham değeri hash'leyip
    /// id_token'daki nonce ile karşılaştırır.
    ///
    /// Nonce'u kendimiz üretmek zorundayız: vermezsek GoogleSignIn'in altındaki AppAuth
    /// kendiliğinden üretiyor ve ne gönderirsek gönderelim karşılaştırma tutmuyordu.
    func signInWithGoogle(idToken: String, accessToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken,
                nonce: nonce
            )
        )
    }

    /// Bağlantının gerçekten gönderilip gönderilmeyeceğine sunucu karar veriyor: Auth
    /// "Before User Created" hook'u e-posta `.edu.tr` ile bitmiyorsa hesabı oluşturmadan
    /// reddediyor, GoTrue de bu hatayı olduğu gibi buraya taşıyor. `redirectTo` olmadan
    /// bağlantı Supabase'in kendi web sayfasını açar, uygulamaya hiç dönmez — bu yüzden
    /// uygulamanın kayıtlı özel URL şemasına (bkz. Info.plist, CampusApp.swift) gidiyor.
    /// Bu şemanın Supabase Dashboard > Authentication > URL Configuration > Redirect URLs
    /// listesinde de olması gerekiyor, yoksa GoTrue yönlendirmeyi reddeder.
    func requestEmailSignInLink(email: String) async throws {
        try await client.auth.signInWithOTP(
            email: email,
            redirectTo: URL(string: "common://login-callback")
        )
    }

    /// Kullanıcı maildeki bağlantıya dokununca iOS'un `.onOpenURL` ile ilettiği URL.
    /// Başarılıysa Apple/Google ile aynı şekilde oturum açılmış olur (`client.auth`ın
    /// kendi session'ı güncellenir).
    func completeEmailSignIn(url: URL) async throws {
        try await client.auth.session(from: url)
    }

    func restoreSession() async throws -> UUID? {
        // Yerel oturum `emitLocalSessionAsInitialSession` ile hemen gelir; süresi
        // dolmuş olabilir. Kullanıcıyı içeri almak için yenilenmiş `session`'ı bekleriz
        // — o getter süresi dolmuşsa refresh dener, başaramazsa hata atar.
        guard let local = client.auth.currentSession else { return nil }
        if local.isExpired {
            return try await client.auth.session.user.id
        }
        return local.user.id
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Önce depolamadaki dosyalar, sonra hesap.
    ///
    /// `delete_my_account` eskiden `storage.objects`'ten de siliyordu; Supabase
    /// doğrudan silmeyi engellediği için hesap silme de kırıktı (bkz. 20260819210000).
    /// Dosyalar artık burada, Storage API üzerinden temizleniyor.
    func deleteAccount() async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        await removeAllFiles(ownedBy: userID)
        try await client.rpc("delete_my_account").execute()
        try? await client.auth.signOut()
    }

    /// Süresi dolmuş kendi story'lerini siler (satır + dosya).
    func purgeMyExpiredStories() async {
        guard let userID = currentUserID else { return }
        let rows: [ExpiredStoryRow]? = try? await client
            .from("stories")
            .select("id,media_path")
            .eq("author_id", value: userID)
            .lt("expires_at", value: Date())
            .execute()
            .value
        guard let rows, !rows.isEmpty else { return }

        let paths = rows.compactMap(\.mediaPath)
        if !paths.isEmpty {
            _ = try? await client.storage.from("story-media").remove(paths: paths)
        }
        _ = try? await client
            .from("stories")
            .delete(returning: .minimal)
            .`in`("id", values: rows.map(\.id))
            .execute()
    }
}
