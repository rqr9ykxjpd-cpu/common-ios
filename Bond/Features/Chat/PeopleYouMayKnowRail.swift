import SwiftUI

/// Sohbet sekmesinin üstünde "Tanıyor olabileceğin kişiler": yuvarlak foto,
/// ad ve ortak nokta. Dokununca kişinin kartı açılır; × öneriyi kaldırır.
///
/// Kartı açan pencere burada değil, sohbet ekranında: son öneriye sağa
/// kaydırınca satır kayboluyor, pencere burada olsaydı kartla birlikte
/// aniden kapanırdı.
struct PeopleYouMayKnowRail: View {
    let suggestions: [PersonSuggestion]
    let open: (StudentProfile) -> Void
    let dismiss: (PersonSuggestion) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            Text(L10n.Suggestions.title)
                .font(BondTheme.Typography.footnote.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.7)
                .foregroundStyle(BondTheme.muted)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: BondTheme.Space.md) {
                    ForEach(suggestions) { suggestion in
                        SuggestionBubble(
                            suggestion: suggestion,
                            open: { open(suggestion.profile) },
                            dismiss: {
                                withAnimation(reduceMotion ? nil : BondTheme.Motion.smooth) { dismiss(suggestion) }
                            }
                        )
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                    }
                }
                // Sayfa kenar boşluğu satırın içinde: yuvarlaklar ekranın
                // kenarına kadar kayıyor, ilk yuvarlak başlıkla hizalı başlıyor.
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.top, 6)
            }
            .padding(.horizontal, -BondTheme.Space.lg)
        }
    }
}

private struct SuggestionBubble: View {
    let suggestion: PersonSuggestion
    let open: () -> Void
    let dismiss: () -> Void

    private let avatar: CGFloat = 68

    /// Kurucu satırda öne çıksın: kurucu renginde ince halka, adın yanında tik,
    /// "Common kurucusu" aynı renkte. Parlama ya da hareket yok; göz rengi bulur.
    private var isFounder: Bool { suggestion.profile.badge == .founder }

    var body: some View {
        ZStack(alignment: .top) {
            Button(action: open) {
                VStack(spacing: 6) {
                    ProfileMedia(
                        url: suggestion.profile.imageURL,
                        data: nil,
                        assetName: suggestion.profile.imageAssetName
                    )
                    .frame(width: avatar, height: avatar)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(BondTheme.hairline, lineWidth: 0.5))
                    .overlay {
                        // Halka fotoğrafın dışında, arada kâğıt rengi boşluk (story halkası gibi).
                        if isFounder {
                            Circle()
                                .strokeBorder(BondTheme.ember, lineWidth: 2.5)
                                .padding(-5)
                        }
                    }

                    HStack(spacing: 3) {
                        Text(suggestion.profile.name)
                            .font(BondTheme.Typography.footnote.weight(.semibold))
                            .foregroundStyle(BondTheme.ink)
                            .lineLimit(1)
                        if isFounder {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, BondTheme.ember)
                                .accessibilityHidden(true)
                        }
                    }

                    Text(suggestion.reason.label)
                        .font(BondTheme.Typography.caption2.weight(isFounder ? .semibold : .regular))
                        .foregroundStyle(isFounder ? BondTheme.ember : BondTheme.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 84)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(suggestion.profile.name), \(suggestion.reason.label)")
            .accessibilityHint(L10n.Suggestions.openHint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: L10n.Suggestions.dismiss, dismiss)

            // Fotoğrafın sağ üst köşesinde; görünen daire 20pt, dokunma alanı 36pt.
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(BondTheme.muted)
                    .frame(width: 20, height: 20)
                    .background(BondTheme.paper, in: Circle())
                    .overlay(Circle().strokeBorder(BondTheme.hairline, lineWidth: 0.5))
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .offset(x: avatar / 2 - 4, y: -10)
            .accessibilityHidden(true)
        }
    }
}
