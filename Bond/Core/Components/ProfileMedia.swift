import SwiftUI
import UIKit

struct ProfileMedia: View {
    let url: URL?
    let data: Data?
    var assetName: String? = nil

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let assetName {
                Image(assetName).resizable().scaledToFill()
            } else if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
    }

    private var fallback: some View {
        LinearGradient(colors: [BondTheme.violet.opacity(0.9), BondTheme.coral.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Image(systemName: "person.crop.circle.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.35)))
    }
}
