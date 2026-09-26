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
                .tint(BondTheme.burntOrange)
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

    /// Apple/Google'ın verdiği adı tekrar yazmak zorunlu değil. Kullanıcı isterse
    /// görünen adını değiştirebilir; ilerlemek için yalnızca kampüs bilgisi gerekir.
    var valid: Bool { !draft.department.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        StepScaffold(
            eyebrow: L10n.Onboarding.identityEyebrow,
            title: L10n.Onboarding.identityTitle,
            subtitle: L10n.Onboarding.identitySubtitle,
            content: VStack(spacing: 0) {
                OnboardingField(label: L10n.Onboarding.name, placeholder: L10n.Onboarding.namePlaceholder, text: $draft.name)
                OnboardingField(label: L10n.Onboarding.department, placeholder: L10n.Onboarding.departmentPlaceholder, text: $draft.department)
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.Onboarding.birthDate)
                        .font(BondTheme.Typography.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.7)
                        .foregroundStyle(BondTheme.ink)
                    DatePicker("", selection: $draft.birthDate, in: ...AgeLimit.latestBirthDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .accessibilityLabel(L10n.Onboarding.birthDate)
                    Text(L10n.Onboarding.ageNote)
                        .font(BondTheme.Typography.footnote)
                        .foregroundStyle(BondTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(BondTheme.hairline.opacity(0.8))
                        .frame(height: 0.5)
                }
            },
            footer: PrimaryEditorialButton(title: L10n.Common.continue_, enabled: valid, action: submit)
        )
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
                        VStack(alignment: .leading, spacing: 12) {
                            Text(InterestCatalog.displayGroup(grup.baslik))
                                .font(BondTheme.Typography.footnote.weight(.semibold))
                                .textCase(.uppercase)
                                .tracking(0.7)
                                .foregroundStyle(BondTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 16)
                                .overlay(alignment: .top) {
                                    Rectangle()
                                        .fill(BondTheme.hairline.opacity(0.8))
                                        .frame(height: 0.5)
                                }
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
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                } else if disabled {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(InterestCatalog.displayName(option))
                    .font(BondTheme.Typography.footnote.weight(.medium))
            }
            .foregroundStyle(selected ? BondTheme.onAccent : BondTheme.ink)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(selected ? BondTheme.ink : BondTheme.paper, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(selected ? BondTheme.ink : BondTheme.hairline, lineWidth: 1)
            }
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
        VStack(alignment: .leading, spacing: 0) {
            Wordmark(size: 30)

            Spacer(minLength: 48)

            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                Text(L10n.Onboarding.verified)
            }
            .font(BondTheme.Typography.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(BondTheme.burntOrange)

            Text(name.isEmpty ? L10n.Onboarding.welcomePlain : L10n.Onboarding.welcomeName(name))
                .editorialTitle(40)
                .padding(.top, BondTheme.Space.md)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.Onboarding.readySubtitle)
                .font(BondTheme.Typography.body)
                .foregroundStyle(BondTheme.muted)
                .lineSpacing(3)
                .padding(.top, BondTheme.Space.md)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: BondTheme.Space.xxl)

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
                .padding(.bottom, BondTheme.Space.md)
            }

            PrimaryEditorialButton(
                title: isSaving ? L10n.Common.saving : (failure == nil ? L10n.Onboarding.enter : L10n.Common.retry),
                enabled: !isSaving,
                action: submit
            )
        }
        .padding(.horizontal, BondTheme.Space.lg)
        .padding(.top, BondTheme.Space.xl)
        .padding(.bottom, BondTheme.Space.lg)
    }
}

private struct OnboardingField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(BondTheme.Typography.footnote.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.7)
                .foregroundStyle(BondTheme.ink)
            TextField(placeholder, text: $text)
                .font(BondTheme.Typography.body)
                .foregroundStyle(BondTheme.ink)
                .textInputAutocapitalization(.words)
                .frame(minHeight: 32)
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(BondTheme.hairline.opacity(0.8))
                .frame(height: 0.5)
        }
    }
}

/// Kayıt akışında isteğe bağlı fotoğraf adımı. Fotoğraf, sosyal profili daha
/// anlaşılır kılar; ancak kayıt olmanın önünde zorunlu bir engel değildir.
private struct PhotoStep: View {
    @Environment(AppState.self) private var appState
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
                    VStack(spacing: BondTheme.Space.md) {
                        ZStack {
                            ProfileMedia(url: nil, data: currentAvatar)
                                .frame(width: 180, height: 224)
                                .clipShape(RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous)
                                        .stroke(BondTheme.hairline.opacity(0.8), lineWidth: 0.5)
                                }

                            if loading {
                                RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous)
                                    .fill(BondTheme.paper.opacity(0.72))
                                    .frame(width: 180, height: 224)
                                ProgressView().tint(BondTheme.ink)
                            }
                        }

                        HStack(spacing: 8) {
                            Image(systemName: currentAvatar == nil ? "photo" : "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .semibold))
                            Text(currentAvatar == nil ? L10n.Onboarding.pickPhoto : L10n.Onboarding.changePhoto)
                                .font(BondTheme.Typography.footnote.weight(.semibold))
                        }
                        .foregroundStyle(BondTheme.ink)
                        .frame(minHeight: 44)
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(currentAvatar == nil ? L10n.Onboarding.pickPhoto : L10n.Onboarding.changePhoto)

                Text(L10n.Onboarding.photoOptional)
                    .font(BondTheme.Typography.footnote)
                    .foregroundStyle(BondTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity),
            footer: VStack(spacing: BondTheme.Space.sm) {
                PrimaryEditorialButton(title: L10n.Common.continue_, enabled: !loading, action: submit)
            }
        )
        .onChange(of: item) { _, newItem in
            guard newItem != nil else { return }
            isLoading = true
            Task {
                let raw = try? await newItem?.loadTransferable(type: Data.self)
                let picked = raw.flatMap(UIImage.init(data:))
                await MainActor.run {
                    if let picked {
                        cropCandidate = IdentifiableImage(image: picked)
                    } else {
                        appState.show(L10n.Composer.photoLoadFailed)
                    }
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
