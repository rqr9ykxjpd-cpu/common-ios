import CoreMotion
import Observation

/// Telefonun eğimi, -1…1 aralığında. "Kartını düzenle"deki kart telefonla
/// birlikte hafifçe döner ve üstündeki ışık kayar (Apple Card hissi).
///
/// Açıldığı andaki duruş sıfır kabul ediliyor: kullanıcı telefonu nasıl
/// tutuyorsa kart düz başlar. Değerler yumuşatılıyor ki kart titremesin.
/// Hareket verisi izin istemiyor; yalnızca ekran açıkken çalışıyor.
@MainActor
@Observable
final class DeviceTilt {
    private(set) var x: Double = 0
    private(set) var y: Double = 0

    private let manager = CMMotionManager()
    @ObservationIgnored private var baseline: CMAttitude?

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            MainActor.assumeIsolated {
                self?.apply(motion.attitude)
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        baseline = nil
        x = 0
        y = 0
    }

    private func apply(_ attitude: CMAttitude) {
        if baseline == nil { baseline = attitude.copy() as? CMAttitude }
        if let baseline { attitude.multiply(byInverseOf: baseline) }
        // ±0.45 radyan (~25°) eğim tam sapma; ötesi kırpılır.
        let hedefX = max(-1, min(1, attitude.roll / 0.45))
        let hedefY = max(-1, min(1, attitude.pitch / 0.45))
        // Alçak geçiren süzgeç: ani sarsıntılar karta geçmesin.
        x += (hedefX - x) * 0.18
        y += (hedefY - y) * 0.18
    }
}
