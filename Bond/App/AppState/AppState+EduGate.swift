import SwiftUI
import UIKit

// MARK: - AppState+EduGate
extension AppState {
    /// Öğrenci kilidi: okul e-postası doğrulanmamış (ve muaf olmayan) hesap
    /// akışı ve Kim nerede'yi gezer ama paylaşamaz, yorum yazamaz, oy veremez,
    /// story izleyemez, mesaj/bağlantı/buluşma isteği gönderemez, "Buradayım"
    /// diyemez. Durum henüz sunucudan gelmediyse kilit yok sayılıyor; sunucu
    /// kilidi ayrıca uyguluyor (`EDU_REQUIRED`), o zaman da aynı pencere açılır.
    var isEduLocked: Bool {
        EduVerificationRollout.isEnabled && !isModerator && (eduStatus?.needsAttention ?? false)
    }

    /// Kilitli eylemin başında çağrılır: serbestse `true`; kilitliyse doğrulama
    /// penceresini açar ve `false` döner.
    @discardableResult
    func requireStudent() -> Bool {
        guard isEduLocked else { return true }
        presentEduGate(.action)
        return false
    }

    /// Pencere en üstteki ekrandan açılır: kişi kartı, gönderi sayfası gibi başka
    /// bir pencerenin içindeyken de görünsün.
    func presentEduGate(_ intro: EduVerificationSheet.Intro = .action) {
        Haptics.selection()
        EduGatePresenter.present(self, intro: intro)
    }
}

/// Doğrulama penceresini en üstteki görünüm denetleyicisinden açar. SwiftUI'nin
/// kök `.sheet`i başka bir pencere açıkken görünmüyor; kilit ise en çok kişi
/// kartında ve gönderi sayfasında tetikleniyor.
@MainActor
enum EduGatePresenter {
    static func present(_ appState: AppState, intro: EduVerificationSheet.Intro) {
        let pencere = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        guard var ust = pencere?.rootViewController else { return }
        while let sonraki = ust.presentedViewController, !sonraki.isBeingDismissed { ust = sonraki }
        guard !(ust is EduGateHostingController) else { return }

        let host = EduGateHostingController(rootView: AnyView(EmptyView()))
        host.rootView = AnyView(
            EduVerificationSheet(intro: intro) { [weak host] in host?.dismiss(animated: true) }
                .environment(appState)
        )
        host.modalPresentationStyle = .pageSheet
        if let sayfa = host.sheetPresentationController {
            sayfa.detents = intro == .welcome ? [.large()] : [.medium(), .large()]
            sayfa.prefersGrabberVisible = true
        }
        ust.present(host, animated: true)
    }
}

final class EduGateHostingController: UIHostingController<AnyView> {}

extension View {
    /// Kilitliyken bu pencere hiç açılmaz; açılmak istendiğinde yerine doğrulama
    /// penceresi gelir. Yazdıktan sonra "doğrula" demek yerine kapıda karşılar.
    func eduGatedSheet<Content: View>(
        isPresented: Binding<Bool>,
        appState: AppState,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self
            .sheet(
                isPresented: Binding(
                    get: { isPresented.wrappedValue && !appState.isEduLocked },
                    set: { isPresented.wrappedValue = $0 }
                ),
                onDismiss: onDismiss,
                content: content
            )
            .onChange(of: isPresented.wrappedValue) { _, yeni in
                guard yeni, appState.isEduLocked else { return }
                isPresented.wrappedValue = false
                appState.presentEduGate(.action)
            }
    }
}
