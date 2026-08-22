import SwiftUI
import PhotosUI

struct OnboardingFlow: View {
    @Environment(AppState.self) private var appState
    let step: AppState.OnboardingStep
    @State private var showSignOutConfirmation = false

    var body: some View {
        @Bindable var appState = appState
        ZStack {
            BondTheme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                if step != .ready {
                    OnboardingHeader(step: step) {
                        if step == .identity {
                            showSignOutConfirmation = true
                        } else {
                            appState.goBack(from: step)
                        }
                    }
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
        .foregroundStyle(BondTheme.ink)
        .animation(BondTheme.Motion.easing, value: step)
        .scrollDismissesKeyboard(.interactively)
        .dismissesKeyboardOnTap()
        .keyboardDoneButton()
        .alert(L10n.Profile.signOutConfirm, isPresented: $showSignOutConfirmation) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Profile.signOut, role: .destructive) {
                Task { await appState.signOut() }
            }
        } message: {
            Text(L10n.Profile.signOutBody)
        }
    }
}

private struct OnboardingHeader: View {
    let step: AppState.OnboardingStep
    let back: () -> Void

    private var progress: CGFloat {
        let countable = CGFloat(AppState.OnboardingStep.allCases.count - 1)
        guard countable > 0 else { return 0 }
        return CGFloat(step.rawValue + 1) / countable
    }

    var body: some View {
        VStack(spacing: BondTheme.Space.md) {
            HStack {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(BondTheme.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L10n.Common.back)
                Spacer()
                Wordmark(compact: true)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }

            ProgressView(value: progress)
                .tint(BondTheme.acid)
                .animation(BondTheme.Motion.easing, value: step)
        }
        .padding(.horizontal, BondTheme.Space.lg)
        .padding(.top, BondTheme.Space.sm)
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
            Eyebrow(text: eyebrow)
                .padding(.top, BondTheme.Space.xxl)
            Text(title)
                .campusDisplay(34)
                .padding(.top, BondTheme.Space.sm)
            Text(subtitle)
                .font(BondTheme.Typography.body)
                .foregroundStyle(BondTheme.muted)
                .padding(.top, BondTheme.Space.sm)
            content
                .padding(.top, BondTheme.Space.xl)
            Spacer(minLength: BondTheme.Space.lg)
            footer
        }
        .padding(.horizontal, BondTheme.Space.lg)
        .padding(.bottom, BondTheme.Space.lg)
    }
}

private struct IdentityStep: View {
    @Binding var draft: ProfileDraft
    let submit: () -> Void

    var valid: Bool { !draft.name.isEmpty && !draft.department.isEmpty }

    var body: some View {
        StepScaffold(
            eyebrow: L10n.Onboarding.identityEyebrow,
            title: L10n.Onboarding.identityTitle,
            subtitle: L10n.Onboarding.identitySubtitle,
            content: VStack(spacing: BondTheme.Space.md) {
                OnboardingField(label: L10n.Onboarding.name, placeholder: L10n.Onboarding.namePlaceholder, text: $draft.name)
                OnboardingField(label: L10n.Onboarding.department, placeholder: L10n.Onboarding.departmentPlaceholder, text: $draft.department)
                VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                    Eyebrow(text: L10n.Onboarding.birthDate)
                    DatePicker("", selection: $draft.birthDate, in: ...AgeLimit.latestBirthDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    Text(L10n.Onboarding.ageNote)
                        .font(BondTheme.Typography.footnote)
                        .foregroundStyle(BondTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BondTheme.Space.lg)
                .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
            },
            footer: PrimaryEditorialButton(title: L10n.Common.continue_, enabled: valid, action: submit)
        )
    }
}

private struct PreferencesStep: View {
    @Binding var draft: ProfileDraft
    let submit: () -> Void

    private var valid: Bool { draft.gender != nil }

    var body: some View {
        StepScaffold(
            eyebrow: L10n.Onboarding.preferencesEyebrow,
            title: L10n.Onboarding.preferencesTitle,
            subtitle: L10n.Onboarding.preferencesSubtitle,
            content: VStack(alignment: .leading, spacing: BondTheme.Space.xxl) {
                choiceSection(title: L10n.Onboarding.yourGender) {
                    ForEach(ProfileGender.allCases) { option in
                        choiceButton(option.title, selected: draft.gender == option) {
                            draft.gender = option
                        }
                    }
                }
            },
            footer: PrimaryEditorialButton(title: L10n.Common.continue_, enabled: valid, action: submit)
        )
    }

    private func choiceSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            Eyebrow(text: title)
            HStack(spacing: BondTheme.Space.sm) { content() }
        }
    }

    private func choiceButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title)
                .font(BondTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(selected ? BondTheme.onAccent : BondTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(selected ? BondTheme.acid : BondTheme.surface, in: Capsule())
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
            eyebrow: L10n.Onboarding.interestsEyebrow,
            title: L10n.Onboarding.interestsTitle,
            subtitle: L10n.Onboarding.interestsSubtitle(InterestCatalog.minimumSelection, InterestCatalog.maximumSelection),
            content: ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.xl) {
                    ForEach(InterestCatalog.grouped, id: \.baslik) { grup in
                        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                            Text(InterestCatalog.displayGroup(grup.baslik))
                                .font(BondTheme.Typography.footnote.weight(.semibold))
                                .foregroundStyle(BondTheme.muted)
                            FlowLayout(spacing: BondTheme.Space.sm) {
                                ForEach(grup.secenekler, id: \.self) { option in
                                    interestChip(option)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, BondTheme.Space.xxl)
            }
            .scrollIndicators(.hidden),
            footer: PrimaryEditorialButton(
                title: L10n.Onboarding.completeProfile(draft.interests.count, InterestCatalog.maximumSelection),
                enabled: complete,
                action: submit
            )
        )
    }

    private func interestChip(_ option: String) -> some View {
        let selected = draft.interests.contains(option)
        let disabled = !selected && full
        return Button {
            Haptics.selection()
            if selected { draft.interests.remove(option) }
            else if !full { draft.interests.insert(option) }
        } label: {
            HStack(spacing: 6) {
                if disabled {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(InterestCatalog.displayName(option))
                    .font(BondTheme.Typography.footnote.weight(.medium))
            }
            .foregroundStyle(selected ? BondTheme.onAccent : BondTheme.ink)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(selected ? BondTheme.acid : BondTheme.surface, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(disabled ? L10n.Onboarding.maxInterestsHint(InterestCatalog.maximumSelection) : "")
    }
}

private struct ReadyStep: View {
    let name: String
    var isSaving = false
    var failure: String?
    let submit: () -> Void

    var body: some View {
        VStack(spacing: BondTheme.Space.xl) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(BondTheme.acid)
                .symbolRenderingMode(.hierarchical)
            Eyebrow(text: L10n.Onboarding.verified)
            Text(name.isEmpty ? L10n.Onboarding.welcomePlain : L10n.Onboarding.welcomeName(name))
                .campusDisplay(34)
                .multilineTextAlignment(.center)
            Text(L10n.Onboarding.readySubtitle)
                .font(BondTheme.Typography.body)
                .foregroundStyle(BondTheme.muted)
                .multilineTextAlignment(.center)
            Spacer()
            if let failure {
                HStack(alignment: .top, spacing: BondTheme.Space.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(BondTheme.coral)
                    Text(failure)
                        .font(BondTheme.Typography.footnote)
                        .foregroundStyle(BondTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(BondTheme.Space.md)
                .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
                .padding(.horizontal, BondTheme.Space.lg)
            }
            PrimaryEditorialButton(
                title: isSaving ? L10n.Common.saving : (failure == nil ? L10n.Onboarding.enter : L10n.Common.retry),
                enabled: !isSaving,
                action: submit
            )
            .padding(.horizontal, BondTheme.Space.lg)
        }
        .padding(.vertical, BondTheme.Space.lg)
    }
}

private struct OnboardingField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            Eyebrow(text: label)
            TextField(placeholder, text: $text)
                .font(BondTheme.Typography.body)
                .foregroundStyle(BondTheme.ink)
        }
        .padding(BondTheme.Space.lg)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
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
        let currentAvatar = avatarData
        let loading = isLoading
        return StepScaffold(
            eyebrow: L10n.Onboarding.photoEyebrow,
            title: L10n.Onboarding.photoTitle,
            subtitle: L10n.Onboarding.photoSubtitle,
            content: VStack(spacing: BondTheme.Space.md) {
                PhotosPicker(selection: $item, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        ProfileMedia(url: nil, data: currentAvatar)
                            .frame(width: 168, height: 208)
                            .clipShape(RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous))
                        if loading {
                            ProgressView().tint(.white).padding(12)
                        } else {
                            Image(systemName: currentAvatar == nil ? "plus" : "arrow.triangle.2.circlepath")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(BondTheme.onAccent)
                                .frame(width: 36, height: 36)
                                .background(BondTheme.acid, in: Circle())
                                .padding(BondTheme.Space.sm)
                        }
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(currentAvatar == nil ? L10n.Onboarding.pickPhoto : L10n.Onboarding.changePhoto)

                if currentAvatar == nil {
                    Text(L10n.Onboarding.photoRequired)
                        .font(BondTheme.Typography.footnote)
                        .foregroundStyle(BondTheme.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity),
            footer: VStack(spacing: BondTheme.Space.sm) {
                PrimaryEditorialButton(title: L10n.Common.continue_, enabled: currentAvatar != nil && !loading, action: submit)
            }
        )
        .onChange(of: item) { _, newItem in
            guard newItem != nil else { return }
            isLoading = true
            Task {
                let raw = try? await newItem?.loadTransferable(type: Data.self)
                let picked = raw.flatMap(UIImage.init(data:))
                await MainActor.run {
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
