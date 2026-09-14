import SwiftUI

/// Kim ne oy vermiş — yalnızca kurucu/moderatör. Sunucu rozeti kontrol eder;
/// başkası çağırırsa hata alır, liste boş kalır.
struct PostVotersView: View {
    /// Gönderi ya da cevap; liste aynı, sunucu çağrısı farklı.
    enum Target { case post(UUID), comment(UUID) }

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let target: Target

    init(postID: UUID) { target = .post(postID) }
    init(target: Target) { self.target = target }
    @State private var voters: [PostVoter] = []
    @State private var isLoading = true
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { _ in SkeletonRow() }
                    }
                    .padding(.horizontal, BondTheme.Space.lg)
                } else if let failure {
                    ScreenFailureView(message: failure) { Task { await load() } }
                        .padding(.horizontal, BondTheme.Space.lg)
                } else if voters.isEmpty {
                    ContentUnavailableView(L10n.Board.votersEmpty, systemImage: "arrow.up.arrow.down")
                } else {
                    List(voters) { voter in
                        HStack(spacing: BondTheme.Space.compact) {
                            ProfileMedia(url: voter.avatarURL, data: nil, assetName: voter.avatarAssetName)
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                            Text(voter.name)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: voter.value > 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(voter.value > 0 ? BondTheme.paper : BondTheme.ink)
                                .frame(width: 26, height: 26)
                                .background(voter.value > 0 ? BondTheme.ink : BondTheme.surface, in: Circle())
                                .accessibilityLabel(voter.value > 0 ? L10n.Board.vote : L10n.Board.downvote)
                        }
                        .foregroundStyle(BondTheme.ink)
                        .listRowBackground(BondTheme.paper)
                    }
                    .listStyle(.plain)
                }
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Board.voters)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        failure = nil
        do {
            switch target {
            case .post(let id): voters = try await appState.fetchPostVoters(id)
            case .comment(let id): voters = try await appState.fetchCommentVoters(id)
            }
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.Board.founderActionFailed)
        }
        isLoading = false
    }
}
