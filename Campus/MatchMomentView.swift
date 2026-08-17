import SwiftUI

struct MatchMomentView: View {
    @Environment(AppState.self) private var appState
    let profile: StudentProfile
    let close: () -> Void
    let message: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            CampusTheme.ink.ignoresSafeArea()
            GrainOverlay().ignoresSafeArea()
            Circle().fill(CampusTheme.violet.opacity(0.5)).frame(width: 420, height: 420).blur(radius: 80).offset(y: -160)

            VStack(spacing: 0) {
                HStack {
                    Eyebrow(text: "common / yeni bağlantı", color: CampusTheme.acid)
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                }
                .padding(24)

                Spacer()
                ZStack {
                    portrait(profile, x: 58, rotation: 8)
                    ProfileMedia(url: nil, data: appState.avatarData)
                        .frame(width: 180, height: 250)
                        .clipped()
                        .rotationEffect(.degrees(-8))
                        .offset(x: -58)
                        .shadow(color: .black.opacity(0.35), radius: 25, y: 18)
                    Circle().fill(CampusTheme.acid).frame(width: 68, height: 68)
                        .overlay(Image(systemName: "link").font(.title2.bold()).foregroundStyle(CampusTheme.ink))
                        .scaleEffect(appeared ? 1 : 0.2)
                }
                .frame(height: 310)

                Eyebrow(text: "karşılıklı merak", color: CampusTheme.acid)
                Text("Sen ve \(profile.name)\n**denk geldiniz.**")
                    .editorialTitle(42).multilineTextAlignment(.center).foregroundStyle(.white).lineSpacing(-2).padding(.top, 14)
                Text("İlk mesajın mükemmel olması gerekmiyor.\nSadece size ait olsun.")
                    .font(.system(size: 14, design: .rounded)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center).lineSpacing(4).padding(.top, 15)
                Spacer()
                VStack(spacing: 10) {
                    PrimaryEditorialButton(title: "MESAJ GÖNDER", enabled: true, inverted: true, action: message)
                    Button("SEÇKİYE DÖN", action: close)
                        .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.2).foregroundStyle(.white.opacity(0.5)).frame(height: 44)
                }.padding(24)
            }
        }
        .onAppear { Haptics.success(); withAnimation(.spring(response: 0.65, dampingFraction: 0.65)) { appeared = true } }
    }

    private func portrait(_ profile: StudentProfile, x: CGFloat, rotation: Double) -> some View {
        ProfileMedia(url: profile.imageURL, data: nil, assetName: profile.imageAssetName)
            .frame(width: 180, height: 250).clipped().rotationEffect(.degrees(rotation)).offset(x: x)
            .shadow(color: .black.opacity(0.35), radius: 25, y: 18)
    }
}
