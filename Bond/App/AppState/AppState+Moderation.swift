import SwiftUI

// MARK: - AppState+Moderation
extension AppState {
    func loadReports() async {
        guard isModerator else { return }
        isLoadingReports = true
        defer { isLoadingReports = false }
        do {
            reports = try await service.fetchReports()
        } catch {
            showError(error, fallback: L10n.Moderation.loadFailed)
        }
    }

    /// Şikayeti kapatır; istenirse önce içeriği kaldırır ya da hesabı askıya alır.
    func resolveReport(_ report: ModerationReport, resolution: ModerationReport.Resolution) async {
        do {
            if resolution == .accountSuspended {
                try await service.setAccountActive(report.reported.id, active: false)
            }
            try await service.resolveReport(report.id, resolution: resolution.rawValue)
            await loadReports()
            Haptics.success()
        } catch {
            showError(error, fallback: L10n.Moderation.closeFailed)
        }
    }

    /// Askıya alınmış hesabı geri açar.
    func reactivateAccount(_ profileID: UUID) async {
        do {
            try await service.setAccountActive(profileID, active: true)
            await loadReports()
        } catch {
            showError(error, fallback: L10n.Moderation.reopenFailed)
        }
    }

    /// Moderatör olarak gönderi kaldırır.
    /// Moderatör olarak hesabı askıya alır.
    ///
    /// Şikayet ekranındaki askıya almadan farkı: bu, bir şikayete bağlı değil.
    /// Sunucu yine `is_moderator()` kontrolünü yapıyor, buradaki kontrol
    /// yalnızca menüyü gizlemek için.
    func suspendAccount(_ profileID: UUID) async {
        do {
            try await service.setAccountActive(profileID, active: false)
            // Askıya alınan kişi keşiften ve akıştan hemen kalksın.
            profiles.removeAll { $0.id == profileID }
            posts.removeAll { $0.author.id == profileID }
            show(L10n.Moderation.suspended)
            Haptics.success()
        } catch {
            showError(error, fallback: L10n.Moderation.suspendFailed)
        }
    }

    func moderatorRemovePost(_ postID: UUID) async {
        do {
            try await service.moderatorDeletePost(postID)
            posts.removeAll { $0.id == postID }
            show(L10n.Moderation.postRemoved)
        } catch {
            showError(error, fallback: L10n.Moderation.removeFailed)
        }
    }
}
