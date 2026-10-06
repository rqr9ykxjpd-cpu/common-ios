import AVFoundation
import SwiftUI
import UIKit

/// Story videosu. Sistem `VideoPlayer` kontrolleri göstermesin diye katman.
///
/// Oynayıp oynamadığını ve bittiğini bildirir: izleyicinin süresi videonun
/// gerçekten oynadığı süreye göre işler. Eskiden süre story açılınca başlıyordu;
/// video inerken ya da takılırken de işlediği için story video bitmeden geçiyordu.
struct StoryVideoCanvas: UIViewRepresentable {
    let url: URL
    var isPaused: Bool
    var onPlaying: ((Bool) -> Void)? = nil
    var onEnd: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        context.coordinator.onPlaying = onPlaying
        context.coordinator.onEnd = onEnd
        context.coordinator.attach(url: url, to: view, play: !isPaused)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        context.coordinator.onPlaying = onPlaying
        context.coordinator.onEnd = onEnd
        context.coordinator.update(url: url, isPaused: isPaused, view: uiView)
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    @MainActor
    final class Coordinator {
        var player: AVPlayer?
        var currentURL: URL?
        var onPlaying: ((Bool) -> Void)?
        var onEnd: (() -> Void)?
        private var statusObservation: NSKeyValueObservation?
        private var failureObservation: NSKeyValueObservation?
        private var endObserver: NSObjectProtocol?

        func attach(url: URL, to view: PlayerView, play: Bool) {
            stopObserving()
            let item = AVPlayer(url: url)
            item.actionAtItemEnd = .pause
            player = item
            currentURL = url
            view.playerLayer.player = item
            // İnerken ve takılınca `waitingToPlay`; yalnızca `playing` süre işletir.
            statusObservation = item.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
                let oynuyor = player.timeControlStatus == .playing
                Task { @MainActor in self?.onPlaying?(oynuyor) }
            }
            // Video hiç yüklenemezse süre işlemez; story ekranda takılı kalmasın, geçilsin.
            failureObservation = item.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
                guard item.status == .failed else { return }
                Task { @MainActor in self?.onEnd?() }
            }
            endObserver = NotificationCenter.default.addObserver(
                forName: AVPlayerItem.didPlayToEndTimeNotification, object: item.currentItem, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.onEnd?() }
            }
            // Video da kırpılmasın: yatay klip siyah bantla tam sığar.
            view.playerLayer.videoGravity = .resizeAspect
            if play {
                item.play()
            }
        }

        func update(url: URL, isPaused: Bool, view: PlayerView) {
            if currentURL != url {
                player?.pause()
                attach(url: url, to: view, play: !isPaused)
                return
            }
            if isPaused {
                player?.pause()
            } else if player?.timeControlStatus != .playing {
                player?.play()
            }
        }

        func tearDown() {
            stopObserving()
            player?.pause()
            player = nil
            currentURL = nil
        }

        private func stopObserving() {
            statusObservation?.invalidate()
            statusObservation = nil
            failureObservation?.invalidate()
            failureObservation = nil
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            endObserver = nil
        }
    }
}

final class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
