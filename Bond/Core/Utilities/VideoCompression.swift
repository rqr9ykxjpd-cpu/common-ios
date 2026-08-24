import AVFoundation
import UIKit

/// Story videosunu yüklemeden önce MP4'e çevirir, 15 sn'ye keser, kapak üretir.
///
/// Galeri/kamera MOV/HEVC verebiliyor; bucket yalnızca `video/mp4` kabul ediyor
/// ve 30 MB sınırlı. Ham dosyayı olduğu gibi göndermek hem reddedilir hem de
/// kampüs netinde akışı kilitler.
enum VideoCompression {
    static let maxDuration = CampusStory.maxVideoDuration
    static let maxBytes = 28_000_000

    struct PreparedClip: Sendable {
        let fileURL: URL
        let posterJPEG: Data
        let duration: TimeInterval
    }

    enum Failure: Error, Equatable {
        case empty
        case exportFailed
        case tooLarge
        case posterFailed
    }

    static func prepareStoryClip(from source: URL) async throws -> PreparedClip {
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0.2 else { throw Failure.empty }

        let clipped = min(seconds, maxDuration)
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("bond-story-\(UUID().uuidString).mp4")

        let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset960x540)
            ?? AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality)
        guard let session else { throw Failure.exportFailed }
        session.timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: clipped, preferredTimescale: 600)
        )
        session.shouldOptimizeForNetworkUse = true
        do {
            try await session.export(to: output, as: .mp4)
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw Failure.exportFailed
        }

        let size = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
        guard size > 0, size <= maxBytes else {
            try? FileManager.default.removeItem(at: output)
            throw Failure.tooLarge
        }

        let poster = try await posterJPEG(from: AVURLAsset(url: output))
        return PreparedClip(fileURL: output, posterJPEG: poster, duration: clipped)
    }

    private static func posterJPEG(from asset: AVAsset) async throws -> Data {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: ImageCompression.maxDimension, height: ImageCompression.maxDimension)
        let cgImage = try await generator.image(at: .zero).image
        let image = UIImage(cgImage: cgImage)
        guard let jpeg = image.jpegData(compressionQuality: 0.85),
              let prepared = ImageCompression.prepareForUpload(jpeg) ?? Optional(jpeg) else {
            throw Failure.posterFailed
        }
        return prepared
    }
}
