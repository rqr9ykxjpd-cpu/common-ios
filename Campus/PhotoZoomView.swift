import SwiftUI

/// Profil fotoğrafının tam ekran hali.
///
/// Küçük yuvarlak avatardan fotoğrafın gerçekte nasıl göründüğü anlaşılmıyordu.
/// Koyu zemin ve tek dokunuşla kapanma: bir fotoğrafa bakmak için ayrı bir
/// gezinme yapısına gerek yok.
struct PhotoZoomView: View {
    let url: URL?
    let data: Data?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ProfileMedia(url: url, data: data)
                .aspectRatio(contentMode: .fit)
                .padding(.horizontal, 8)

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Kapat")
                }
                Spacer()
            }
            .padding(20)
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .preferredColorScheme(.dark)
    }
}
