import SwiftUI

struct ClubDetailView: View {
    let club: CampusClub
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var joined: Bool { appState.isJoined(to: club) }
    private var accent: Color { Color(hex: club.accentHex) }
    private var displayedMemberCount: Int { club.memberCount + (joined ? 1 : 0) }

    var body: some View {
        ZStack {
            BondTheme.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                    header
                    identity
                    clubInfo
                    upcomingEvent
                    benefits
                    membershipButton
                }
                .foregroundStyle(BondTheme.ink)
                .padding(BondTheme.Space.lg)
                .padding(.bottom, BondTheme.Space.lg)
            }
        }
        .transaction {
            if reduceMotion {
                $0.animation = nil
                $0.disablesAnimations = true
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: club.icon)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 60, height: 60)
                .background(accent.opacity(0.14), in: Circle())

            Spacer()

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

    private var identity: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            Eyebrow(text: L10n.Club.yuClub, color: accent)
            Text(club.name)
                .editorialTitle(40)
                .fixedSize(horizontal: false, vertical: true)
            Text(club.summary)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var clubInfo: some View {
        HStack(spacing: 10) {
            infoCard(
                value: "\(displayedMemberCount)",
                label: L10n.Club.members,
                icon: "person.2.fill",
                numeric: true
            )
            infoCard(
                value: joined ? L10n.Club.joinedStatus : L10n.Club.openStatus,
                label: L10n.Club.status,
                icon: joined ? "checkmark.circle.fill" : "door.left.hand.open"
            )
        }
    }

    private var upcomingEvent: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            Eyebrow(text: L10n.Club.upcoming, color: BondTheme.muted)

            let event = club.nextEvent.trimmingCharacters(in: .whitespacesAndNewlines)
            HStack(spacing: 13) {
                Image(systemName: event.isEmpty ? "calendar" : "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: BondTheme.Space.xs) {
                    if event.isEmpty {
                        Text(L10n.Club.noEvent)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(event)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        if let place = club.meetingPlace {
                            Label(place.name, systemImage: "mappin.and.ellipse")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(BondTheme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                BondTheme.surface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            Eyebrow(text: L10n.Club.whatToExpect, color: BondTheme.muted)
            benefit(L10n.Club.benefitMeet)
            benefit(L10n.Club.benefitEvents)
            benefit(L10n.Club.benefitProjects)
        }
    }

    private var membershipButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : BondTheme.Motion.bouncy) {
                appState.toggleClubMembership(club)
            }
        } label: {
            HStack(spacing: BondTheme.Space.sm) {
                Image(systemName: joined ? "checkmark.circle.fill" : "plus.circle.fill")
                    .contentTransition(.symbolEffect(.replace))
                Text(joined ? L10n.Club.leave : L10n.Club.join)
                    .font(.headline)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(joined ? BondTheme.ink : Color.white)
            .padding(.horizontal, BondTheme.Space.md)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                joined ? BondTheme.surface : accent,
                in: Capsule()
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("club.membership")
        .animation(reduceMotion ? nil : BondTheme.Motion.bouncy, value: joined)
    }

    private func infoCard(
        value: String,
        label: String,
        icon: String,
        numeric: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            Image(systemName: icon)
                .foregroundStyle(accent)
                .contentTransition(.symbolEffect(.replace))
            Text(value)
                .font(.headline)
                .contentTransition(numeric ? .numericText() : .opacity)
                .animation(reduceMotion ? nil : BondTheme.Motion.snappy, value: value)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BondTheme.Space.md)
        .background(
            BondTheme.surface,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
                .background(accent.opacity(0.12), in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
