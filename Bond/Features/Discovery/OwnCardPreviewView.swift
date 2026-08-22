import SwiftUI

/// Kendi keşif kartının önizlemesi. Keşifteki kartın birebir aynısını (`DiscoveryCard`)
/// kullanır, böylece önizleme ile gerçek görünüm zamanla birbirinden ayrışamaz.
struct OwnCardPreviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    /// Önizleme kartın eksiklerini söylüyordu ama düzeltmenin yolunu vermiyordu:
    /// kullanıcı kapatıp profile dönüp ayrı bir düğme bulmak zorundaydı.
    @State private var showEditor = false

    private var profile: StudentProfile { appState.ownDiscoveryCardPreview }

    /// Karşı tarafın kartında boş görünecek alanlar. Profilin neresinin eksik kaldığını
    /// tahmin ettirmek yerine doğrudan söylüyoruz.
    private var missingPieces: [String] {
        var missing: [String] = []
        if appState.avatarURL == nil && appState.avatarData == nil { missing.append(L10n.Discovery.missingAvatar) }
        if appState.galleryURLs.isEmpty && appState.profileGalleryData.isEmpty { missing.append(L10n.Discovery.missingGallery) }
        if appState.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append(L10n.Discovery.missingName) }
        if appState.draft.department.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append(L10n.Discovery.missingDepartment) }
        if appState.draft.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append(L10n.Discovery.missingBio) }
        if appState.draft.interests.count < 3 { missing.append(L10n.Discovery.missingInterests) }
        return missing
    }

    var body: some View {
        ZStack {
            BondTheme.canvasDark.ignoresSafeArea()
            GrainOverlay().ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: BondTheme.Space.lg) {
                        DiscoveryCard(profile: profile, showsCompatibility: false)
                            .frame(height: 520)
                            .padding(.horizontal, BondTheme.Space.lg)

                        if missingPieces.isEmpty {
                            Label(L10n.Discovery.cardComplete, systemImage: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(BondTheme.acid)
                                .padding(.horizontal, BondTheme.Space.lg)
                        } else {
                            missingList
                        }

                    }
                    .padding(.vertical, BondTheme.Space.lg)
                }
            }
        }
        // Sayfanın aşağı çekilerek kapandığını gösteren tutamak. Elle çizgi
        // çizmek yerine sistemin kendi göstergesi kullanılıyor: kullanıcı bu
        // hareketi zaten başka uygulamalardan tanıyor.
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $showEditor) {
            NavigationStack { ProfileEditorView() }
        }
    }

    /// Fotoğraflar, ad, bölüm, hakkımda ve ilgi alanları — kartta görünen her şey
    /// profil düzenleyicide. Ayrı bir düzenleme ekranı yapmak yerine oraya
    /// gönderiyoruz; iki ekran zamanla birbirinden ayrışmasın.
    private var editButton: some View {
        Button {
            Haptics.impact(.light)
            showEditor = true
        } label: {
            Label(L10n.Common.edit, systemImage: "pencil")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(BondTheme.onAccent)
                .padding(.horizontal, 14).frame(height: 44)
                .background(BondTheme.acid, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Discovery.yourCard)
                    .font(.system(size: 24, weight: .bold))
                Text(L10n.Discovery.cardSubtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            editButton
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(L10n.Common.close)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, BondTheme.Space.lg)
        .padding(.top, BondTheme.Space.sm)
        .frame(height: 62)
    }

    private var missingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Discovery.missingHeader)
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.5))
            ForEach(missingPieces, id: \.self) { piece in
                HStack(spacing: 9) {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BondTheme.coral)
                    Text(piece)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                }
            }
            Text(L10n.Discovery.missingFooter)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.65))
                .padding(.top, 2)
        }
        .padding(BondTheme.Space.lg)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        .padding(.horizontal, BondTheme.Space.lg)
    }
}
