import SwiftUI
import UIKit

struct MeasuredRemoteImage: View {
    @Environment(AppState.self) private var appState
    let url: URL
    @Binding var naturalSize: CGSize?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                BondTheme.ink.opacity(0.06)
            }
        }
        .task(id: BondImageLoader.cacheKey(for: url)) {
            let indirilen = await appState.remoteImage(for: url)
            guard let indirilen else { return }
            image = indirilen
            naturalSize = indirilen.size
        }
    }
}
