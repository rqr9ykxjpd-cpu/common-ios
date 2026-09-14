import SwiftUI

struct MeasuredRemoteImage: View {
    let url: URL
    @Binding var naturalSize: CGSize?

    var body: some View {
        ProfileMedia(url: url, data: nil, kind: .content, showsRetry: true,
                     onImageSize: { naturalSize = $0 })
    }
}
