import SwiftUI

struct OnboardingFlow: View {
    @Environment(AppState.self) private var appState
    let step: AppState.OnboardingStep

    var body: some View {
        @Bindable var appState = appState
        ZStack {
            CampusTheme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                OnboardingHeader(step: step) { appState.goBack(from: step) }
                Group {
                    switch step {
                    case .email: EmailStep(email: $appState.email) { submitEmail() }
                    case .code: CodeStep(code: $appState.verificationCode, email: appState.email) { submitCode() }
                    case .identity: IdentityStep(draft: $appState.draft) { appState.advance(from: step) }
                    case .preferences: PreferencesStep(draft: $appState.draft) { appState.advance(from: step) }
                    case .interests: InterestsStep(selection: $appState.draft.interests) { appState.advance(from: step) }
                    case .ready: ReadyStep(name: appState.draft.name) { appState.advance(from: step) }
                    }
                }
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .foregroundStyle(CampusTheme.ink)
    }

    private func submitEmail() {
        Task {
            try? await appState.service.requestOTP(email: appState.email)
            Haptics.impact(.light)
            appState.advance(from: step)
        }
    }

    private func submitCode() {
        Task {
            try? await appState.service.verifyOTP(email: appState.email, code: appState.verificationCode)
            Haptics.success()
            appState.advance(from: step)
        }
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

private struct EmailStep: View {
    @Binding var email: String
    let submit: () -> Void
    @FocusState private var focused: Bool

    var isValid: Bool { UniversityDomain.isValid(email) }

    var body: some View {
        StepScaffold(
            eyebrow: "öğrenci doğrulaması",
            title: "Önce aynı\nyerden başlayalım.",
            subtitle: "Yalnızca üniversite uzantılı e-postaları kabul ediyoruz. Adresin profilinde görünmez.",
            content: VStack(alignment: .leading, spacing: 12) {
                TextField("ad.soyad@yalova.edu.tr", text: $email)
                    .font(.system(size: 21, weight: .medium, design: .rounded))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .padding(.vertical, 16)
                    .overlay(alignment: .bottom) { Rectangle().fill(isValid ? CampusTheme.ink : CampusTheme.ink.opacity(0.2)).frame(height: 1) }
                HStack(spacing: 7) {
                    Image(systemName: "lock.fill")
                    Text("E-posta yalnızca doğrulama için kullanılır")
                }
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(CampusTheme.ink.opacity(0.4))
            },
            footer: PrimaryEditorialButton(title: "KODU GÖNDER", enabled: isValid, action: submit)
        )
        .onAppear { focused = true }
    }
}

private struct CodeStep: View {
    @Binding var code: String
    let email: String
    let submit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        StepScaffold(
            eyebrow: "gelen kutuna bak",
            title: "Dört rakam,\ntek küçük adım.",
            subtitle: "\(email) adresine gönderdiğimiz dört haneli kodu gir.",
            content: ZStack {
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .opacity(0.01)
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        Text(character(at: index))
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                            .background(index < code.count ? CampusTheme.acid : CampusTheme.ink.opacity(0.05))
                            .overlay(Rectangle().stroke(CampusTheme.ink.opacity(index == code.count ? 0.7 : 0.1)))
                    }
                }
                .onTapGesture { focused = true }
            },
            footer: PrimaryEditorialButton(title: "DOĞRULA", enabled: code == "1283", action: submit)
        )
        .onChange(of: code) { _, newValue in code = String(newValue.filter(\.isNumber).prefix(4)) }
        .onAppear { focused = true }
    }

    private func character(at index: Int) -> String {
        guard index < code.count else { return "" }
        return String(code[code.index(code.startIndex, offsetBy: index)])
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
                    DatePicker("", selection: $draft.birthDate, in: ...Calendar.current.date(byAdding: .year, value: -18, to: .now)!, displayedComponents: .date)
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

    private var valid: Bool {
        draft.gender != nil && draft.datingPreference != nil
    }

    var body: some View {
        StepScaffold(
            eyebrow: "tanışma tercihlerin",
            title: "Seni ve aradığını\nnetleştirelim.",
            subtitle: "İki seçim de zorunludur. Bu bilgileri daha sonra profil ayarlarından değiştirebilirsin.",
            content: VStack(alignment: .leading, spacing: 28) {
                choiceSection(title: "CİNSİYETİN") {
                    ForEach(ProfileGender.allCases) { option in
                        choiceButton(option.title, selected: draft.gender == option) {
                            draft.gender = option
                        }
                    }
                }
                choiceSection(title: "KİMLERLE TANIŞMAK İSTİYORSUN?") {
                    ForEach(DatingPreference.allCases) { option in
                        choiceButton(option.title, selected: draft.datingPreference == option) {
                            draft.datingPreference = option
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
    @Binding var selection: Set<String>
    let submit: () -> Void
    let options = ["Canlı müzik", "Sinema", "Gece yürüyüşü", "Tasarım", "Koşu", "Analog", "Kahve", "Sergiler", "Kitaplar", "Elektronik", "Fotoğraf", "Girişim"]

    var body: some View {
        StepScaffold(
            eyebrow: "ortak frekanslar",
            title: "Nerede denk\ngelebilirsiniz?",
            subtitle: "Seni anlatan en az üç şey seç. Algoritmadan önce sohbeti düşün.",
            content: FlowLayout(spacing: 9) {
                ForEach(options, id: \.self) { option in
                    Button {
                        Haptics.selection()
                        if selection.contains(option) { selection.remove(option) } else if selection.count < 6 { selection.insert(option) }
                    } label: {
                        Text(option)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(selection.contains(option) ? CampusTheme.paper : CampusTheme.ink)
                            .padding(.horizontal, 15).padding(.vertical, 12)
                            .background(selection.contains(option) ? CampusTheme.ink : .clear)
                            .overlay(Capsule().stroke(CampusTheme.ink.opacity(0.22)))
                            .clipShape(Capsule())
                    }.buttonStyle(PressableStyle())
                }
            },
            footer: PrimaryEditorialButton(title: "SEÇİMİ TAMAMLA · \(selection.count)/6", enabled: selection.count >= 3, action: submit)
        )
    }
}

private struct ReadyStep: View {
    let name: String
    let submit: () -> Void

    var body: some View {
        ZStack {
            CampusTheme.ink.ignoresSafeArea()
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
                PrimaryEditorialButton(title: "COMMON'A GİR", enabled: true, inverted: true, action: submit)
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
