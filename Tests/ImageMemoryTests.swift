import Foundation
import UIKit
import ImageIO

@main
struct ImageMemoryTests {
    static func main() throws {
        var count = 0
        func check(_ condition: Bool, _ name: String) {
            precondition(condition, name); count += 1
        }

        let signed = URL(string: "https://example.com/storage/v1/object/sign/post-media/a.jpg?token=abc")!
        let signed2 = URL(string: "https://example.com/storage/v1/object/sign/post-media/a.jpg?token=xyz")!
        check(BondImageLoader.cacheKey(for: signed) == BondImageLoader.cacheKey(for: signed2), "signed URL query is not the cache key")

        let big = try jpeg(width: 2400, height: 1800)
        let shown = ImageCompression.imageForDisplay(big)
        check(shown != nil, "display decode succeeds")
        let longest = max(shown!.size.width, shown!.size.height)
        check(longest <= ImageCompression.maxDimension + 1, "display image is capped")

        let avatar = ImageCompression.imageForDisplay(big, maxDimension: ImageCompression.avatarDimension)
        check(avatar != nil, "avatar decode succeeds")
        let avatarLongest = max(avatar!.size.width, avatar!.size.height)
        check(avatarLongest <= ImageCompression.avatarDimension + 1, "avatar image is capped")

        let size = ImageCompression.pixelSize(of: big)
        check(size == CGSize(width: 2400, height: 1800), "pixel size reads JPEG header")

        check(ImageCompression.imageForDisplay(Data([0x00, 0x01, 0x02])) == nil, "corrupt bytes are not fully decoded")

        let prepared = ImageCompression.prepareForUpload(big)
        check(prepared != nil, "upload compact succeeds")
        check(prepared!.count <= ImageCompression.maxBytes, "upload compact stays under the byte cap")
        check(prepared!.count < big.count, "upload compact is smaller than the source JPEG")

        print("Image memory: \(count) checks passed (cache key, downsample cap, header size, upload compact).")
    }

    private static func jpeg(width: Int, height: Int) throws -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "ImageMemoryTests", code: 1)
        }
        return data
    }
}
