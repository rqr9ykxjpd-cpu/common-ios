import SwiftUI

struct ClubDetailView: View {
    let club: CampusClub
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var joined: Bool { appState.isJoined(to: club) }

    var body: some View {
        ZStack {
            BondTheme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Image(systemName: club.icon)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(Color(hex: club.accentHex), in: Circle())
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").frame(width: 44, height: 44)
                                .background(BondTheme.surface, in: Circle())
                                .overlay(Circle().stroke(BondTheme.hairline))
                        }
                        .accessibilityLabel(L10n.Common.close)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: L10n.Club.yuClub, color: Color(hex: club.accentHex))
                        Text(club.name).editorialTitle(40).lineSpacing(-2)
                        Text(club.summary)
                            .font(.system(size: 16))
                            .foregroundStyle(BondTheme.ink.opacity(0.62))
                            .lineSpacing(5)
                    }

                    HStack(spacing: 10) {
                        infoCard(value: "\(club.memberCount + (joined ? 1 : 0))", label: L10n.Club.members, icon: "person.2.fill")
                        infoCard(value: joined ? L10n.Club.joinedStatus : L10n.Club.openStatus, label: L10n.Club.status, icon: joined ? "checkmark.circle.fill" : "door.left.hand.open")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: L10n.Club.upcoming, color: BondTheme.muted)
                        // Sunucuda `next_event` varsayılanı boş metin. Etkinlik
                        // girilmemiş kulüplerde kart bomboş görünüyordu.
                        let etkinlik = club.nextEvent.trimmingCharacters(in: .whitespacesAndNewlines)
                        HStack(spacing: 13) {
                            Image(systemName: etkinlik.isEmpty ? "calendar" : "calendar.badge.clock")
                                .font(.system(size: 22))
                                .foregroundStyle(etkinlik.isEmpty
                                                 ? BondTheme.ink.opacity(0.25)
                                                 : Color(hex: club.accentHex))
                            VStack(alignment: .leading, spacing: 4) {
                                if etkinlik.isEmpty {
                                    Text(L10n.Club.noEvent)
                                        .font(.system(size: 15))
                                        .foregroundStyle(BondTheme.muted)
                                } else {
                                    Text(etkinlik).font(.system(size: 17, weight: .semibold))
                                    if let place = club.meetingPlace {
                                        Label(place.name, systemImage: "mappin.and.ellipse")
                                            .font(.system(size: 12)).foregroundStyle(BondTheme.muted)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: L10n.Club.whatToExpect, color: BondTheme.muted)
                        benefit(L10n.Club.benefitMeet)
                        benefit(L10n.Club.benefitEvents)
                        benefit(L10n.Club.benefitProjects)
                    }

                    Button { appState.toggleClubMembership(club) } label: {
                        HStack {
                            Image(systemName: joined ? "checkmark.circle.fill" : "plus.circle.fill")
                            Text(joined ? L10n.Club.leave : L10n.Club.join)
                                .font(.system(size: 11, weight: .black)).tracking(1)
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(joined ? BondTheme.ink : .white)
                        .padding(.horizontal, 18).frame(height: 56)
                        .background(joined ? BondTheme.ink.opacity(0.08) : Color(hex: club.accentHex), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(PressableStyle())
                }
                .foregroundStyle(BondTheme.ink)
                .padding(22)
                .padding(.bottom, 20)
            }
        }
    }

    private func infoCard(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color(hex: club.accentHex))
            Text(value).font(.system(size: 17, weight: .semibold))
            Text(label).font(.system(size: 11, weight: .bold)).tracking(0.7).opacity(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: club.accentHex))
                .frame(width: 24, height: 24).background(Color(hex: club.accentHex).opacity(0.12), in: Circle())
            Text(text).font(.system(size: 15)).foregroundStyle(BondTheme.ink.opacity(0.7))
        }
    }
}
