import SwiftUI
import UIKit

struct MeasuredRemoteImage: View {
    let url: URL
    @Binding var naturalSize: CGSize?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                CampusTheme.ink.opacity(0.06)
            }
        }
        .task(id: url) {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let indirilen = UIImage(data: data)
            else { return }
            image = indirilen
            naturalSize = indirilen.size
        }
    }
}

