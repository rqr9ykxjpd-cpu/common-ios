#if DEBUG
import Foundation

/// Örnek modda destek talepleri: biri yanıtlanmış ve okunmamış (öğrenci
/// e-postası), biri çözülmüş. Yazılanlar bu açılış boyunca kalıyor.
extension SampleProductService: SupportDesk {
    func fetchMySupportThreads() async throws -> [SupportThread] {
        await SampleSupportStore.shared.threads
    }

    func fetchSupportMessages(_ reportID: UUID) async throws -> [SupportMessage] {
        await SampleSupportStore.shared.read(reportID)
    }

    func sendSupportMessage(_ reportID: UUID, body: String, resolve: Bool) async throws -> SupportThread.Status {
        await SampleSupportStore.shared.send(reportID, body: body, resolve: resolve)
    }

    func setEduExempt(_ userID: UUID, exempt: Bool) async throws -> Bool { exempt }

    func fetchEduGate() async throws -> Bool { await SampleSupportStore.shared.eduGate }

    func setEduGate(_ enabled: Bool) async throws -> Bool {
        await SampleSupportStore.shared.setEduGate(enabled)
        return enabled
    }

    func setStudentVerified(_ userID: UUID, verified: Bool) async throws -> Bool { verified }
}

private actor SampleSupportStore {
    static let shared = SampleSupportStore()
    private(set) var eduGate = false
    func setEduGate(_ acik: Bool) { eduGate = acik }

    private static let eduID = UUID(uuidString: "5A0E0000-0000-4000-8000-000000000001")!
    private static let feedID = UUID(uuidString: "5A0E0000-0000-4000-8000-000000000002")!

    private(set) var threads: [SupportThread] = [
        SupportThread(id: eduID,
                      message: "Okul e-postamı yazınca “bu adres başka hesapta kullanılıyor” diyor, oysa başka hesabım yok.",
                      screen: "Öğrenci e-postası · email_exists", status: .answered,
                      createdAt: .now.addingTimeInterval(-3_600), lastMessageAt: .now.addingTimeInterval(-600),
                      hasUnread: true),
        SupportThread(id: feedID,
                      message: "Akış yenilenince bazen boş kalıyor.",
                      screen: "Profil", status: .resolved,
                      createdAt: .now.addingTimeInterval(-86_400 * 3), lastMessageAt: .now.addingTimeInterval(-86_400 * 2),
                      hasUnread: false)
    ]

    private var messages: [UUID: [SupportMessage]] = [
        eduID: [SupportMessage(id: UUID(), fromStaff: true,
                               body: "Adresin eski bir denemeden kalan boş bir kayıtta takılıymış, temizledik. Tekrar dener misin?",
                               createdAt: .now.addingTimeInterval(-600))],
        feedID: [SupportMessage(id: UUID(), fromStaff: true,
                                body: "Düzelttik; güncellemeden sonra olmaması lazım. Teşekkürler!",
                                createdAt: .now.addingTimeInterval(-86_400 * 2))]
    ]

    func read(_ id: UUID) -> [SupportMessage] {
        if let i = threads.firstIndex(where: { $0.id == id }) { threads[i].hasUnread = false }
        return messages[id] ?? []
    }

    func send(_ id: UUID, body: String, resolve: Bool) -> SupportThread.Status {
        let metin = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !metin.isEmpty {
            messages[id, default: []].append(SupportMessage(id: UUID(), fromStaff: false, body: metin, createdAt: .now))
        }
        let durum: SupportThread.Status = resolve ? .resolved : .open
        if let i = threads.firstIndex(where: { $0.id == id }) {
            threads[i].status = durum
            threads[i].lastMessageAt = .now
        }
        return durum
    }
}
#endif
