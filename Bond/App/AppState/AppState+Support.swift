import SwiftUI

// MARK: - AppState+Support
extension AppState {
    /// Ayarlar'daki "Destek taleplerim" rozeti: destek yazdı, öğrenci okumadı.
    var supportUnreadCount: Int { supportThreads.filter(\.hasUnread).count }

    /// Sessiz: liste gelmezse rozet çıkmaz; hata şeridi başka ekranları kirletmesin.
    func loadSupportThreads() async {
        guard let masa = service as? any SupportDesk else { return }
        do {
            supportThreads = try await masa.fetchMySupportThreads()
        } catch {
            guard !isCancellation(error) else { return }
        }
    }

    /// Yazışmayı getirir; sunucu okuyan tarafın "okundu" zamanını günceller,
    /// yerelde de rozet hemen düşüyor.
    func loadSupportMessages(_ reportID: UUID) async throws -> [SupportMessage] {
        guard let masa = service as? any SupportDesk else { return [] }
        let mesajlar = try await masa.fetchSupportMessages(reportID)
        if let i = supportThreads.firstIndex(where: { $0.id == reportID }) { supportThreads[i].hasUnread = false }
        if let i = problemReports.firstIndex(where: { $0.id == reportID }) { problemReports[i].staffUnread = false }
        return mesajlar
    }

    /// Öğrenci de destek de aynı yoldan yazar; kim olduğunu sunucu rozetten
    /// anlar. Yeni durumu döndürür, olmazsa `nil` (hata ekranda).
    func sendSupportMessage(_ reportID: UUID, body: String, resolve: Bool = false) async -> SupportThread.Status? {
        guard let masa = service as? any SupportDesk else { return nil }
        do {
            let durum = try await masa.sendSupportMessage(reportID, body: body, resolve: resolve)
            let yazdi = !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if let i = supportThreads.firstIndex(where: { $0.id == reportID }) {
                supportThreads[i].status = durum
                supportThreads[i].lastMessageAt = .now
            }
            if let i = problemReports.firstIndex(where: { $0.id == reportID }) {
                problemReports[i].status = durum
                problemReports[i].handledAt = durum == .resolved ? .now : nil
                if yazdi { problemReports[i].replyCount += 1 }
            }
            Haptics.success()
            return durum
        } catch {
            guard !isCancellation(error) else { return nil }
            showError(ProblemReportError.from(error) ?? error, fallback: L10n.Support.sendFailed)
            return nil
        }
    }

    func fetchEduGate() async throws -> Bool {
        guard let masa = service as? any SupportDesk else { return false }
        return try await masa.fetchEduGate()
    }

    func founderSetEduGate(_ enabled: Bool) async throws -> Bool {
        guard let masa = service as? any SupportDesk else { throw BackendServiceError.missingSession }
        return try await masa.setEduGate(enabled)
    }

    func founderSetStudentVerified(_ userID: UUID, verified: Bool) async throws -> Bool {
        guard let masa = service as? any SupportDesk else { throw BackendServiceError.missingSession }
        return try await masa.setStudentVerified(userID, verified: verified)
    }

    /// Kurucu: öğrenci doğrulamasından muaf tut / muafiyeti kaldır.
    func founderSetEduExempt(_ userID: UUID, exempt: Bool) async throws -> Bool {
        guard let masa = service as? any SupportDesk else { throw BackendServiceError.missingSession }
        return try await masa.setEduExempt(userID, exempt: exempt)
    }
}
