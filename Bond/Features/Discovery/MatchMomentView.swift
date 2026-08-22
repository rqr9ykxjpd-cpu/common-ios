import SwiftUI

struct MatchMomentView: View {
    @Environment(AppState.self) private var appState
    let profile: StudentProfile
    let close: () -> Void
    let message: (String?) -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            BondTheme.canvasDark.ignoresSafeArea()
            GrainOverlay().ignoresSafeArea()
            Circle().fill(BondTheme.violet.opacity(0.5)).frame(width: 420, height: 420).blur(radius: 80).offset(y: -160)

            VStack(spacing: 0) {
                HStack {
                    Eyebrow(text: L10n.Discovery.matchEyebrowBrand, color: BondTheme.onCanvasDark)
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.Common.close)
                }
                .padding(24)

                Spacer()
                ZStack {
                    portrait(profile, x: 58, rotation: 8)
                    ProfileMedia(url: appState.avatarURL, data: appState.avatarData)
                        .frame(width: 180, height: 250)
                        .clipped()
                        .rotationEffect(.degrees(-8))
                        .offset(x: -58)
                        .shadow(color: .black.opacity(0.35), radius: 25, y: 18)
                    Circle().fill(BondTheme.onCanvasDark).frame(width: 68, height: 68)
                        .overlay(Image(systemName: "link").font(.system(size: 22, weight: .bold)).foregroundStyle(BondTheme.canvasDark))
                        .scaleEffect(appeared ? 1 : 0.2)
                }
                .frame(height: 310)

                Eyebrow(text: L10n.Discovery.matchEyebrow, color: BondTheme.onCanvasDark)
                Text(L10n.Discovery.matchTitle(profile.name))
                    .editorialTitle(42).multilineTextAlignment(.center).foregroundStyle(.white).lineSpacing(-2).padding(.top, 14)
                Text(L10n.Discovery.matchSubtitle)
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center).lineSpacing(4).padding(.top, 15)
                Spacer()
                VStack(spacing: 10) {
                    ForEach(conversationStarters, id: \.self) { starter in
                        Button(starter) { message(starter) }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                    PrimaryEditorialButton(title: L10n.Discovery.writeOwn, enabled: true, inverted: true) { message(nil) }
                    Button(L10n.Discovery.backToDeck, action: close)
                        .font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(.white.opacity(0.5)).frame(height: 44)
                }.padding(24)
            }
        }
        .onAppear { Haptics.success(); withAnimation(.spring(response: 0.65, dampingFraction: 0.65)) { appeared = true } }
    }

    private var conversationStarters: [String] {
        // Ortak olanı ortak diye, olmayanı merak sorusu olarak soruyoruz.
        let mine = Set(appState.draft.interests)
        let shared = profile.interests.filter { mine.contains($0) }
        if !shared.isEmpty {
            return shared.prefix(2).map { L10n.Discovery.starterCampus(InterestCatalog.displayName($0)) }
        }
        if let ilk = profile.interests.first {
            return [L10n.Discovery.starterHow(InterestCatalog.displayName(ilk)), L10n.Discovery.starterCorner]
        }
        return [L10n.Discovery.starterHello]
    }

    private func portrait(_ profile: StudentProfile, x: CGFloat, rotation: Double) -> some View {
        ProfileMedia(url: profile.imageURL, data: nil, assetName: profile.imageAssetName)
            .frame(width: 180, height: 250).clipped().rotationEffect(.degrees(rotation)).offset(x: x)
            .shadow(color: .black.opacity(0.35), radius: 25, y: 18)
    }
}
