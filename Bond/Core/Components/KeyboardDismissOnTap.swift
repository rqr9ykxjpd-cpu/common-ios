import SwiftUI
import UIKit

/// Klavye açıkken ekranın herhangi bir yerine dokununca klavye kapanır.
///
/// Uygulama genelinde tek yer: pencereye `cancelsTouchesInView = false` bir
/// dokunma tanıyıcı ekleniyor; dokunuş altındaki düğmeye/alana yine gidiyor.
/// Sheet ve tam ekran sunumlar aynı pencerede olduğu için onları da kapsıyor.
/// Metin alanına dokunuş klavyeyi kapatmaz (alan odak alırken kapatıp açmasın).
struct KeyboardDismissOnTap: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        private static var installedWindows = NSHashTable<UIWindow>.weakObjects()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, !Self.installedWindows.contains(window) else { return }
            Self.installedWindows.add(window)
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
        }

        @objc private func dismiss() {
            window?.endEditing(true)
        }
    }
}

extension KeyboardDismissOnTap.InstallerView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Klavye kapalıysa iş yok; metin alanına dokunuş odağı bozmasın.
        guard window?.firstResponderView != nil else { return false }
        var view = touch.view
        while let current = view {
            if current is UITextInput { return false }
            view = current.superview
        }
        return true
    }
}

private extension UIView {
    var firstResponderView: UIView? {
        if isFirstResponder { return self }
        for child in subviews {
            if let found = child.firstResponderView { return found }
        }
        return nil
    }
}
