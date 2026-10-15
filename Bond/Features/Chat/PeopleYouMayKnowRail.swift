import SwiftUI

/// Sohbet sekmesinin üstünde "Tanıyor olabileceğin kişiler": yuvarlak foto,
/// ad ve ortak nokta. Dokununca kişinin kartı açılır; × öneriyi kaldırır.
///
/// Kartı açan pencere burada değil, sohbet ekranında: son öneri kapatılınca
/// satır kayboluyor, pencere burada olsaydı kartla birlikte aniden kapanırdı.
/// Sağa geçilen kişi satırda kalır, altında "Gönderildi" yazar.
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

    /// Kurucu satırda öne çıksın: kurucu renginde ince halka ve adın yanında
    /// tik; altında yazı yok. Parlama ya da hareket yok; göz rengi bulur.
    private var isFounder: Bool { suggestion.profile.badge == .founder }

    /// Fotoğrafın altında bölüm ve sınıf; kulüp, ortak bağlantı ya da ilgi
    /// değil (kurucunun isteği). Sohbetini temizlediğin bağlantında "Bağlantın".
    /// Sınıf kendi satırında: uzun bölüm adı iki satırı doldurunca kesiliyordu.
    private var subtitleLines: [String] {
        if case .connection = suggestion.reason { return [suggestion.reason.label] }
        let kisi = suggestion.profile
        let bolum = DepartmentCatalog.educationParts(kisi.department).first ?? kisi.department
        return [bolum, AcademicYear.display(kisi.year)].filter { !$0.isEmpty }
    }

    private var subtitle: String { subtitleLines.joined(separator: " · ") }

    /// Ekranda yazmasa da VoiceOver kurucu olduğunu söylesin.
    private var spokenReason: String {
        if suggestion.sent { return L10n.Suggestions.sent }
        return isFounder ? (suggestion.profile.badge.title ?? "") : subtitle
    }

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
                    // Kurucunun fotoğrafındaki kırmızı halka kaldırıldı (kurucunun isteği);
                    // adın yanındaki tik kalıyor.
                    .overlay(Circle().strokeBorder(BondTheme.hairline, lineWidth: 0.5))

                    HStack(spacing: 3) {
                        // İki satır: "Alperen Kuvvet", "Emre Karadaş" tek satırda
                        // "Alperen…" diye kesiliyordu.
                        Text(suggestion.profile.name)
                            .font(BondTheme.Typography.footnote.weight(.semibold))
                            .foregroundStyle(BondTheme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        if isFounder {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, BondTheme.ember)
                                .accessibilityHidden(true)
                        }
                    }

                    if suggestion.sent {
                        // Bölüm yerine durum: istek gitti, yanıt bekleniyor.
                        Label(L10n.Suggestions.sent, systemImage: "paperplane.fill")
                            .labelStyle(.titleAndIcon)
                            .font(BondTheme.Typography.caption2.weight(.semibold))
                            .foregroundStyle(BondTheme.burntOrangeText)
                            .lineLimit(1)
                            // Büyük yazı boyunda "Gönde…" olmasın.
                            .minimumScaleFactor(0.75)
                    } else if !isFounder {
                        VStack(spacing: 1) {
                            ForEach(Array(subtitleLines.enumerated()), id: \.offset) { sira, satir in
                                Text(satir)
                                    .lineLimit(sira == 0 ? 2 : 1)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .font(BondTheme.Typography.caption2)
                        .foregroundStyle(BondTheme.muted)
                        .multilineTextAlignment(.center)
                    }
                }
                .frame(width: 92)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(suggestion.profile.name), \(spokenReason)")
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
