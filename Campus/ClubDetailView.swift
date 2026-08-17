import SwiftUI

struct ClubDetailView: View {
    let club: CampusClub
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var joined: Bool { appState.isJoined(to: club) }

    var body: some View {
        ZStack {
            CampusTheme.paper.ignoresSafeArea()
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
                                .background(CampusTheme.surface, in: Circle())
                                .overlay(Circle().stroke(CampusTheme.hairline))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "YÜ öğrenci kulübü", color: Color(hex: club.accentHex))
                        Text(club.name).editorialTitle(40).lineSpacing(-2)
                        Text(club.summary)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundStyle(CampusTheme.ink.opacity(0.62))
                            .lineSpacing(5)
                    }

                    HStack(spacing: 10) {
                        infoCard(value: "\(club.memberCount + (joined ? 1 : 0))", label: "ÜYE", icon: "person.2.fill")
                        infoCard(value: joined ? "ÜYESİN" : "AÇIK", label: "DURUM", icon: joined ? "checkmark.circle.fill" : "door.left.hand.open")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "yaklaşan etkinlik", color: CampusTheme.ink.opacity(0.4))
                        HStack(spacing: 13) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.title2).foregroundStyle(Color(hex: club.accentHex))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(club.nextEvent).font(.headline)
                                if let place = club.meetingPlace {
                                    Label(place.name, systemImage: "mappin.and.ellipse")
                                        .font(.caption).foregroundStyle(CampusTheme.ink.opacity(0.5))
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "kulüpte seni ne bekliyor?", color: CampusTheme.ink.opacity(0.4))
                        benefit("Yeni insanlarla ortak bir amaç etrafında tanış")
                        benefit("Etkinlik ve gönüllülük duyurularını takip et")
                        benefit("Kampüs projelerine fikir ve emekle katıl")
                    }

                    Button { appState.toggleClubMembership(club) } label: {
                        HStack {
                            Image(systemName: joined ? "checkmark.circle.fill" : "plus.circle.fill")
                            Text(joined ? "KULÜPTEN AYRIL" : "KULÜBE KATIL")
                                .font(.system(size: 11, weight: .black, design: .rounded)).tracking(1)
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(joined ? CampusTheme.ink : .white)
                        .padding(.horizontal, 18).frame(height: 56)
                        .background(joined ? CampusTheme.ink.opacity(0.08) : Color(hex: club.accentHex), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(PressableStyle())
                }
                .foregroundStyle(CampusTheme.ink)
                .padding(22)
                .padding(.bottom, 20)
            }
        }
    }

    private func infoCard(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color(hex: club.accentHex))
            Text(value).font(.headline)
            Text(label).font(.system(size: 11, weight: .bold, design: .rounded)).tracking(0.7).opacity(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.caption.bold()).foregroundStyle(Color(hex: club.accentHex))
                .frame(width: 24, height: 24).background(Color(hex: club.accentHex).opacity(0.12), in: Circle())
            Text(text).font(.subheadline).foregroundStyle(CampusTheme.ink.opacity(0.7))
        }
    }
}
