import SwiftUI
import PhotosUI

struct OnboardingFlow: View {
    @Environment(AppState.self) private var appState
    let step: AppState.OnboardingStep

    var body: some View {
        @Bindable var appState = appState
        ZStack {
            CampusTheme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                // Son adım bir kutlama ekranı: tüm ekranı kaplıyor. Başlık altında
                // dururken koyu zemin `ignoresSafeArea` ile yukarı taşıp ilerleme
                // çubuğunu kesiyordu; ayrıca 5/5 dolmuş bir çubuğun orada bir işi yok.
                if step != .ready {
                    OnboardingHeader(step: step) { appState.goBack(from: step) }
                }
                Group {
                    switch step {
                    case .identity: IdentityStep(draft: $appState.draft) { appState.advance(from: step) }
                    case .preferences: PreferencesStep(draft: $appState.draft) { appState.advance(from: step) }
                    case .interests: InterestsStep(draft: $appState.draft) { appState.advance(from: step) }
                    case .photo: PhotoStep(avatarData: $appState.avatarData) { appState.advance(from: step) }
                    case .ready:
                        ReadyStep(
                            name: appState.draft.name,
                            isSaving: appState.isFinishingOnboarding,
                            failure: appState.onboardingFailure
                        ) { appState.advance(from: step) }
                    }
                }
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .foregroundStyle(CampusTheme.ink)
        // Ad/bölüm yazarken klavye açık kalıyor ve altındaki tarih seçiciye ulaşmak
        // zorlaşıyordu; kapatmanın görünür bir yolu da yoktu. Üç yol birden:
        // boş yere dokunmak, kaydırmak, klavyenin üstündeki "Bitti".
        .scrollDismissesKeyboard(.interactively)
        .dismissesKeyboardOnTap()
        .keyboardDoneButton()
    }
}

private struct OnboardingHeader: View {
    let step: AppState.OnboardingStep
    let back: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: back) {
                    Image(systemName: "arrow.left")
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(CampusTheme.ink.opacity(0.16)))
                }
                .buttonStyle(PressableStyle())
                Spacer()
                Wordmark(compact: true)
                Spacer()
                Text("0\(step.rawValue + 1)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .frame(width: 44, height: 44)
            }
            HStack(spacing: 5) {
                ForEach(AppState.OnboardingStep.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? CampusTheme.ink : CampusTheme.ink.opacity(0.12))
                        .frame(height: 3)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }
}

private struct StepScaffold<Content: View, Footer: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let content: Content
    let footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: eyebrow, color: CampusTheme.ink.opacity(0.45))
                .padding(.top, 34)
            Text(title)
                .editorialTitle(43)
                .lineSpacing(-3)
                .padding(.top, 12)
            Text(subtitle)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(CampusTheme.ink.opacity(0.5))
                .lineSpacing(4)
                .padding(.top, 12)
            content
                .padding(.top, 34)
            Spacer(minLength: 20)
            footer
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}

private struct IdentityStep: View {
    @Binding var draft: ProfileDraft
    let submit: () -> Void

    var valid: Bool { !draft.name.isEmpty && !draft.department.isEmpty }

    var body: some View {
        StepScaffold(
            eyebrow: "sen kimsin?",
            title: "Profil değil,\nkısa bir portre.",
            subtitle: "İlk izlenimi sade tut. Bunların hepsini daha sonra değiştirebilirsin.",
            content: VStack(spacing: 22) {
                EditorialField(label: "ADIN", placeholder: "Cem", text: $draft.name)
                EditorialField(label: "BÖLÜMÜN", placeholder: "Endüstri Mühendisliği", text: $draft.department)
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "doğum tarihin", color: CampusTheme.ink.opacity(0.42))
                    DatePicker("", selection: $draft.birthDate, in: ...AgeLimit.latestBirthDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    Text("Common yalnızca 18 yaş ve üzeri öğrenciler içindir.")
                        .font(.caption).foregroundStyle(CampusTheme.ink.opacity(0.42))
                }.frame(maxWidth: .infinity, alignment: .leading)
            },
            footer: PrimaryEditorialButton(title: "DEVAM ET", enabled: valid, action: submit)
        )
    }
}

private struct PreferencesStep: View {
    @Binding var draft: ProfileDraft
    let submit: () -> Void

    private var valid: Bool { draft.gender != nil }

    var body: some View {
        StepScaffold(
            eyebrow: "tanışma tercihlerin",
            title: "Kısaca\nseni tanıyalım.",
            subtitle: "Kimlerin gösterileceği cinsiyetine göre belirlenir. İkisini de sonradan değiştirebilirsin.",
            content: VStack(alignment: .leading, spacing: 28) {
                choiceSection(title: "CİNSİYETİN") {
                    ForEach(ProfileGender.allCases) { option in
                        choiceButton(option.title, selected: draft.gender == option) {
                            draft.gender = option
                        }
                    }
                }
            },
            footer: PrimaryEditorialButton(title: "DEVAM ET", enabled: valid, action: submit)
        )
    }

    private func choiceSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: title, color: CampusTheme.ink.opacity(0.42))
            HStack(spacing: 9) { content() }
        }
    }

    private func choiceButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? CampusTheme.paper : CampusTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(selected ? CampusTheme.ink : CampusTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? .clear : CampusTheme.hairline))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct InterestsStep: View {
    @Binding var draft: ProfileDraft
    let submit: () -> Void

    private var complete: Bool { draft.interests.count >= InterestCatalog.minimumSelection }
    private var full: Bool { draft.interests.count >= InterestCatalog.maximumSelection }

    var body: some View {
        StepScaffold(
            eyebrow: "ortak frekanslar",
            title: "Sohbete bir\nipucu bırak.",
            subtitle: "En az \(InterestCatalog.minimumSelection) tane seç, \(InterestCatalog.maximumSelection) taneye kadar ekleyebilirsin. Ortak ilgiler keşifte öne çıkarılır.",
            content: ScrollView {
                // Gruplu liste: tek yığın halinde kırk seçenek göz yoruyor, kimse
                // sonuna kadar inmiyordu.
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(InterestCatalog.grouped, id: \.baslik) { grup in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(grup.baslik.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(CampusTheme.ink.opacity(0.38))
                            FlowLayout(spacing: 9) {
                                ForEach(grup.secenekler, id: \.self) { option in
                                    interestChip(option)
                                }
                            }
                        }
                    }
                }
                // Alta boşluk: son satır düğmeyle tam ortadan kesiliyordu ve "bozuk"
                // görünüyordu. Boşluk + aşağıdaki solma "devamı var" diyor.
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.94),
                        .init(color: .black.opacity(0), location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            ),
            footer: PrimaryEditorialButton(
                title: "PROFİLİ TAMAMLA · \(draft.interests.count)/\(InterestCatalog.maximumSelection)",
                enabled: complete,
                action: submit
            )
        )
    }

    private func interestChip(_ option: String) -> some View {
        let selected = draft.interests.contains(option)
        // Sınıra gelindiğinde seçili olmayanlar soluklaşıyor; önceden dokunulunca
        // sessizce hiçbir şey olmuyor ve düğme bozuk sanılıyordu.
        let disabled = !selected && full
        return Button {
            Haptics.selection()
            if selected { draft.interests.remove(option) }
            else if !full { draft.interests.insert(option) }
        } label: {
            Text(option)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? CampusTheme.paper : CampusTheme.ink)
                .padding(.horizontal, 15).padding(.vertical, 12)
                .background(selected ? CampusTheme.ink : .clear)
                .overlay(Capsule().stroke(CampusTheme.ink.opacity(0.22)))
                .clipShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }
}

private struct ReadyStep: View {
    let name: String
    var isSaving = false
    /// Kayıt başarısız olduysa sebebi. Kayıt akışının son adımı: burada hata yalnızca
    /// üstte bir anlığına beliren toast'la gösterilince kullanıcı "düğme çalışmıyor"
    /// sanıyordu. Sebebi ekranda kalıcı olarak duruyor.
    var failure: String?
    let submit: () -> Void

    var body: some View {
        ZStack {
            CampusTheme.canvasDark.ignoresSafeArea()
            GrainOverlay().ignoresSafeArea()
            VStack(spacing: 26) {
                Spacer()
                ZStack {
                    Circle().fill(CampusTheme.violet).frame(width: 220, height: 220)
                    Circle().stroke(CampusTheme.acid, lineWidth: 2).frame(width: 174, height: 174).offset(x: 45, y: -34)
                    Text("✓").font(.system(size: 90, weight: .thin, design: .serif)).foregroundStyle(CampusTheme.acid)
                }
                Eyebrow(text: "doğrulandı", color: CampusTheme.acid)
                Text("Hoş geldin,\n\(name.isEmpty ? "Cem" : name).")
                    .editorialTitle(48).foregroundStyle(.white).multilineTextAlignment(.center).lineSpacing(-3)
                Text("Kampüsün akışı, yeni insanlar ve\nyeni sohbetler seni bekliyor.")
                    .font(.system(size: 15, design: .rounded)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center).lineSpacing(4)
                Spacer()
                if let failure {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(CampusTheme.coral)
                        Text(failure)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 24)
                }
                PrimaryEditorialButton(
                    title: isSaving ? "KAYDEDİLİYOR…" : (failure == nil ? "COMMON'A GİR" : "TEKRAR DENE"),
                    enabled: !isSaving,
                    inverted: true,
                    action: submit
                )
                .padding(.horizontal, 24)
            }.padding(.vertical, 22)
        }
    }
}

private struct EditorialField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: label, color: CampusTheme.ink.opacity(0.42))
            TextField(placeholder, text: $text)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(CampusTheme.ink.opacity(0.2)).frame(height: 1) }
        }
    }
}

struct PrimaryEditorialButton: View {
    let title: String
    let enabled: Bool
    var inverted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 11, weight: .black, design: .rounded)).tracking(1.2)
                Spacer(); Image(systemName: "arrow.right")
            }
            .foregroundStyle(inverted ? CampusTheme.ink : CampusTheme.paper)
            .padding(.horizontal, 20).frame(height: 58)
            .background(inverted ? CampusTheme.acid : CampusTheme.ink)
            .opacity(enabled ? 1 : 0.25)
        }
        .disabled(!enabled)
        .buttonStyle(PressableStyle())
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() { subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified) }
    }
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var points: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y)); x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}


/// Kayıt akışında fotoğraf adımı. Bu adım yokken kullanıcı kaydını fotoğrafsız
/// tamamlayabiliyordu; Tanış'ta gri bir kartla görünüyor, kimse beğenmiyor ve
/// uygulamanın boş olduğunu düşünüyordu.
private struct PhotoStep: View {
    @Binding var avatarData: Data?
    let submit: () -> Void
    @State private var item: PhotosPickerItem?
    @State private var cropCandidate: IdentifiableImage?
    @State private var isLoading = false

    var body: some View {
        // Değerler önce yerele alınıyor: StepScaffold içeriği izole olmayan bir bağlamda
        // değerlendirildiği için doğrudan @State okumak eşzamanlılık uyarısı üretiyor.
        let currentAvatar = avatarData
        let loading = isLoading
        return StepScaffold(
            eyebrow: "son adım",
            title: "Bir fotoğrafla\ntanışalım.",
            subtitle: "Yüzünün net göründüğü güncel bir fotoğraf seç. Sonradan değiştirebilirsin.",
            content: VStack(spacing: 16) {
                PhotosPicker(selection: $item, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        ProfileMedia(url: nil, data: currentAvatar)
                            .frame(width: 168, height: 208)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(CampusTheme.ink.opacity(0.12)))
                        if loading {
                            ProgressView().tint(.white).padding(12)
                        } else {
                            Image(systemName: currentAvatar == nil ? "plus" : "arrow.triangle.2.circlepath")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(CampusTheme.paper)
                                .frame(width: 38, height: 38)
                                .background(CampusTheme.ink, in: Circle())
                                .padding(9)
                        }
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(currentAvatar == nil ? "Profil fotoğrafı seç" : "Profil fotoğrafını değiştir")

                if currentAvatar == nil {
                    Text("Fotoğrafı olmayan profiller keşifte çok az görüntüleniyor.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(CampusTheme.ink.opacity(0.45))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity),
            footer: VStack(spacing: 10) {
                PrimaryEditorialButton(title: "DEVAM ET", enabled: currentAvatar != nil && !loading, action: submit)
                // Zorunlu tutmuyoruz: fotoğrafı olmayan biri kayıt akışında tıkanıp
                // uygulamayı hiç kullanamamaktansa sonradan ekleyebilsin.
                Button("Şimdilik atla") { submit() }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(CampusTheme.ink.opacity(0.45))
            }
        )
        .onChange(of: item) { _, newItem in
            guard newItem != nil else { return }
            isLoading = true
            Task {
                let raw = try? await newItem?.loadTransferable(type: Data.self)
                let picked = raw.flatMap(UIImage.init(data:))
                await MainActor.run {
                    // Doğrudan kaydetmiyoruz: önce dairesel çerçeveye göre konumlandırılıyor.
                    if let picked { cropCandidate = IdentifiableImage(image: picked) }
                    isLoading = false
                }
            }
        }
        .fullScreenCover(item: $cropCandidate) { candidate in
            AvatarCropView(image: candidate.image) {
                cropCandidate = nil
            } onConfirm: { data in
                avatarData = data
                cropCandidate = nil
            }
        }
    }
}
