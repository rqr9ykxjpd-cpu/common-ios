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
        // Sorunlar ayrı yükleniyor: biri başarısız olursa öteki yine gelsin.
        if let sorunlar = try? await service.fetchProblemReports() {
            problemReports = sorunlar
        }
    }

    /// "Sorun bildir". Başarılıysa `true`; hata metni ekranda gösteriliyor.
    func reportProblem(_ message: String, screen: String) async -> Bool {
        do {
            try await service.reportProblem(message, context: ProblemReportContext.current(screen: screen))
            show(L10n.ProblemReport.sent)
            Haptics.success()
            return true
        } catch {
            showError(ProblemReportError.from(error) ?? error, fallback: L10n.ProblemReport.failed)
            return false
        }
    }

    func closeProblemReport(_ id: UUID) async {
        do {
            try await service.closeProblemReport(id)
            if let i = problemReports.firstIndex(where: { $0.id == id }) {
                problemReports[i].handledAt = .now
            }
            Haptics.success()
        } catch {
            showError(error, fallback: L10n.Moderation.closeFailed)
        }
    }

    /// Şikayeti kapatır; istenirse önce içeriği kaldırır ya da hesabı askıya alır.
    func resolveReport(_ report: ModerationReport, resolution: ModerationReport.Resolution) async {
        do {
            try await service.resolveReport(report.id, resolution: resolution.rawValue)
            if resolution == .contentRemoved, let target = report.target {
                removeReportedContentLocally(target)
            }
            await loadReports()
            Haptics.success()
        } catch {
            showError(error, fallback: L10n.Moderation.closeFailed)
        }
    }

    private func removeReportedContentLocally(_ target: ReportTarget) {
        switch target.kind {
        case .post:
            posts.removeAll { $0.id == target.id }
        case .story:
            stories.removeAll { $0.id == target.id }
        case .comment:
            for index in posts.indices { posts[index].comments.removeAll { $0.id == target.id } }
        case .message:
            for index in conversations.indices {
                conversations[index].messages.removeAll { $0.id == target.id }
            }
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
            // Askıya alınan kişi İnsanlar listesinden ve akıştan hemen kalksın.
            campusPeople.removeAll { $0.id == profileID }
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
