import Foundation
import Supabase

extension SupabaseProductService: ClubAccountManaging {
    func managedClubs(of userID: UUID) async throws -> Set<UUID> {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let ids: [UUID] = try await client
            .rpc("club_manager_clubs", params: ClubAccountTarget(target: userID))
            .execute().value
        return Set(ids)
    }

    func clubAccountStatus(manager: UUID) async throws -> ClubAccountStatus? {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let rows: [ClubAccountStatusRow] = try await client
            .rpc("my_club_account", params: ClubAccountManagerParam(manager: manager))
            .execute().value
        return rows.first.map { ClubAccountStatus(clubID: $0.clubID, managerOK: $0.managerOK) }
    }

    func exportSession() -> Data? {
        guard let session = client.auth.currentSession else { return nil }
        return try? JSONEncoder().encode(session)
    }

    /// Fonksiyon tek kullanımlık bir giriş anahtarı verir; anahtar burada
    /// oturuma çevrilir. Yöneticinin oturumu sunucuda kapanmaz, cihazda
    /// saklanır (bkz. `AppState.switchToClubAccount`).
    func switchToClubAccount(_ clubID: UUID) async throws {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let reply: ClubSwitchReply
        do {
            reply = try await client.functions.invoke(
                "club-account-switch",
                options: .init(body: ClubSwitchRequest(clubID: clubID), timeoutInterval: 30)
            )
        } catch let error as FunctionsError {
            if case .httpError(let status, _) = error, status == 403 {
                throw ClubAccountSwitchError.notManager
            }
            throw ClubAccountSwitchError.unavailable
        }
        try await client.auth.verifyOTP(tokenHash: reply.tokenHash, type: .magiclink)
    }

    func returnToSession(_ stored: Data) async throws {
        guard let session = try? JSONDecoder().decode(Session.self, from: stored) else {
            throw ClubAccountSwitchError.mainSessionLost
        }
        // Yalnızca bu cihazdaki kulüp oturumu kapanır; öbür yöneticiler etkilenmez.
        try? await client.auth.signOut(scope: .local)
        do {
            _ = try await client.auth.setSession(accessToken: session.accessToken, refreshToken: session.refreshToken)
        } catch let error as AuthError {
            let bitmis: [ErrorCode] = [
                .refreshTokenNotFound, .refreshTokenAlreadyUsed,
                .sessionNotFound, .sessionExpired, .userNotFound,
            ]
            throw bitmis.contains(error.errorCode) ? ClubAccountSwitchError.mainSessionLost : error
        }
    }
}

extension SupabaseProductService {
    func clubAccountLinks() async throws -> [ClubAccountLink] {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let rows: [ClubAccountLinkRow] = try await client.rpc("club_account_links").execute().value
        return rows.map { ClubAccountLink(clubID: $0.clubID, profileID: $0.profileID, username: $0.username) }
    }

    func clubAccountProfile(_ profileID: UUID) async throws -> StudentProfile {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let row: SupabaseProfileRow = try await client
            .from("profiles")
            .select("id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified,badge")
            .eq("id", value: profileID)
            .single()
            .execute()
            .value
        let avatar = await signedURLs(bucket: "profile-photos", paths: [row.avatarPath].compactMap { $0 })
        return row.studentProfile(avatarURL: row.avatarPath.flatMap { avatar[$0] })
    }
}

private struct ClubAccountLinkRow: Decodable {
    let clubID: UUID
    let profileID: UUID
    let username: String?

    enum CodingKeys: String, CodingKey {
        case clubID = "club_id"
        case profileID = "profile_id"
        case username
    }
}

private struct ClubAccountTarget: Encodable {
    let target: UUID
}

private struct ClubAccountManagerParam: Encodable {
    let manager: UUID
}

private struct ClubAccountStatusRow: Decodable {
    let clubID: UUID
    let managerOK: Bool

    enum CodingKeys: String, CodingKey {
        case clubID = "club_id"
        case managerOK = "manager_ok"
    }
}

private struct ClubSwitchRequest: Encodable {
    let clubID: UUID

    enum CodingKeys: String, CodingKey {
        case clubID = "club_id"
    }
}

private struct ClubSwitchReply: Decodable {
    let tokenHash: String

    enum CodingKeys: String, CodingKey {
        case tokenHash = "token_hash"
    }
}
