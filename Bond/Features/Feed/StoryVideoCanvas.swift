import AVFoundation
import SwiftUI
import UIKit

/// Story videosu. Sistem `VideoPlayer` kontrolleri göstermesin diye katman.
struct StoryVideoCanvas: UIViewRepresentable {
    let url: URL
    var isPaused: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        context.coordinator.attach(url: url, to: view, play: !isPaused)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        context.coordinator.update(url: url, isPaused: isPaused, view: uiView)
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    @MainActor
    final class Coordinator {
        var player: AVPlayer?
        var currentURL: URL?

        func attach(url: URL, to view: PlayerView, play: Bool) {
            let item = AVPlayer(url: url)
            item.actionAtItemEnd = .pause
            player = item
            currentURL = url
            view.playerLayer.player = item
            view.playerLayer.videoGravity = .resizeAspectFill
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
            player?.pause()
            player = nil
            currentURL = nil
        }
    }
}

final class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
