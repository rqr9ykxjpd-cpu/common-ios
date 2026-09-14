import SwiftUI

struct CampusClubsView: View {
    var showsCloseButton = false
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedClub: CampusClub?
    @State private var hasStartedEntrance = false
    @State private var entranceIDs: [UUID] = []
    @State private var entranceVisible = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    if let error = appState.clubsError, !appState.clubs.isEmpty {
                        ScreenFailureView(message: error, compact: true) {
                            Task { await appState.loadClubs() }
                        }
                    }

                    if appState.clubs.isEmpty {
                        clubsState
                    } else {
                        ForEach(appState.clubs) { club in
                            clubCard(club)
                                .opacity(entranceIsHidden(club) ? 0 : 1)
                                .offset(y: entranceIsHidden(club) ? 12 : 0)
                                .animation(
                                    reduceMotion ? nil : BondTheme.Motion.smooth.delay(
                                        Double(entranceIDs.firstIndex(of: club.id) ?? 0) * 0.04
                                    ),
                                    value: entranceVisible
                                )
                        }
                    }
                }
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.vertical, BondTheme.Space.md)
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.CampusNavigation.clubs)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .background(BondTheme.surface, in: Circle())
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(L10n.Common.close)
                    }
                }
            }
            .refreshable { await appState.loadClubs() }
            .task { await appState.loadClubs() }
            .task(id: appState.clubs.isEmpty) {
                guard !appState.clubs.isEmpty, !hasStartedEntrance else { return }
                hasStartedEntrance = true
                entranceIDs = appState.clubs.map(\.id)
                await Task.yield()
                entranceVisible = true
            }
            .tint(BondTheme.ink)
            .sheet(item: $selectedClub) { club in
                ClubDetailView(club: club)
                    .presentationCornerRadius(28)
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.fraction(0.72), .large])
            }
        }
        .transaction {
            if reduceMotion {
                $0.animation = nil
                $0.disablesAnimations = true
            }
        }
    }

    @ViewBuilder
    private var clubsState: some View {
        if appState.isLoadingClubs {
            VStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonRow()
                        .padding(12)
                        .background(
                            BondTheme.surface,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
            }
        } else if let error = appState.clubsError {
            ScreenFailureView(message: error) {
                Task { await appState.loadClubs() }
            }
        } else {
            ContentUnavailableView(
                L10n.CampusNavigation.emptyClubs,
                systemImage: "person.3"
            )
        }
    }

    private func clubCard(_ club: CampusClub) -> some View {
        let accent = Color(hex: club.accentHex)
        let event = club.nextEvent.trimmingCharacters(in: .whitespacesAndNewlines)

        return Button { selectedClub = club } label: {
            HStack(alignment: .top, spacing: BondTheme.Space.compact) {
                Image(systemName: club.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(accent.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                    Text(club.name)
                        .font(.headline)
                        .foregroundStyle(BondTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(club.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: BondTheme.Space.compact) {
                        Label("\(club.memberCount)", systemImage: "person.2")
                        if !event.isEmpty {
                            Label(event, systemImage: "calendar")
                                .lineLimit(1)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if appState.isJoined(to: club) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(accent)
                        .accessibilityLabel(L10n.Club.joinedStatus)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(
                BondTheme.surface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        }
        .buttonStyle(.pressableCard)
        .accessibilityElement(children: .combine)
    }

    private func entranceIsHidden(_ club: CampusClub) -> Bool {
        !reduceMotion && !entranceVisible &&
            (!hasStartedEntrance || entranceIDs.contains(club.id))
    }
}
