import UIKit

/// Sistem çubuğu gizli ekranlarda da kenardan kaydırıp geri dönülsün.
///
/// iOS, gezinme çubuğu gizlenince geri kaydırma hareketini de kapatıyor. Sohbet
/// ekranı üst çubuğunu kendisi çiziyor (iOS 26 başlığı ekran kaydıktan sonra
/// gösteriyordu); orada geri kaydırma çalışmıyordu. Hareket yalnızca yığında
/// geri dönülecek bir ekran varken ve bir geçiş sürmüyorken başlar: geçiş
/// ortasında başlayan hareket gezinmeyi kilitleyebiliyor.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer else { return true }
        // Geri düğmesini bilerek gizleyen ekranda kaydırarak da geri dönülmesin.
        return viewControllers.count > 1 && transitionCoordinator == nil
            && topViewController?.navigationItem.hidesBackButton != true
    }
}
