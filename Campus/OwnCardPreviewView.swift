import SwiftUI

/// Kendi keşif kartının önizlemesi. Keşifteki kartın birebir aynısını (`DiscoveryCard`)
/// kullanır, böylece önizleme ile gerçek görünüm zamanla birbirinden ayrışamaz.
struct OwnCardPreviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var profile: StudentProfile { appState.ownDiscoveryCardPreview }

    /// Karşı tarafın kartında boş görünecek alanlar. Profilin neresinin eksik kaldığını
    /// tahmin ettirmek yerine doğrudan söylüyoruz.
    private var missingPieces: [String] {
        var missing: [String] = []
        if appState.avatarURL == nil && appState.avatarData == nil { missing.append("Ana profil fotoğrafı") }
        if appState.galleryURLs.isEmpty && appState.profileGalleryData.isEmpty { missing.append("Galeri fotoğrafları") }
        if appState.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("Ad") }
        if appState.draft.department.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("Bölüm") }
        if appState.draft.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("Hakkımda") }
        if appState.draft.interests.count < 3 { missing.append("En az 3 ilgi alanı") }
        if appState.draft.prompts.allSatisfy({ $0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            missing.append("Profil soruları")
        }
        return missing
    }

    var body: some View {
        ZStack {
            CampusTheme.canvasDark.ignoresSafeArea()
            GrainOverlay().ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: CampusTheme.Space.lg) {
                        DiscoveryCard(profile: profile, showsCompatibility: false)
                            .frame(height: 520)
                            .padding(.horizontal, CampusTheme.Space.lg)

                        if missingPieces.isEmpty {
                            Label("Kartın eksiksiz görünüyor.", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(CampusTheme.acid)
                                .padding(.horizontal, CampusTheme.Space.lg)
                        } else {
                            missingList
                        }
                    }
                    .padding(.vertical, CampusTheme.Space.lg)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kartın")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Tanış'ta karşı taraf bunu görüyor")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Kapat")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, CampusTheme.Space.lg)
        .padding(.top, CampusTheme.Space.sm)
        .frame(height: 62)
    }

    private var missingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Eksik kalanlar")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.5))
            ForEach(missingPieces, id: \.self) { piece in
                HStack(spacing: 9) {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CampusTheme.coral)
                    Text(piece)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                }
            }
            Text("Bu alanlar dolmadan kartın keşifte zayıf görünür.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 2)
        }
        .padding(CampusTheme.Space.lg)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
        .padding(.horizontal, CampusTheme.Space.lg)
    }
}
