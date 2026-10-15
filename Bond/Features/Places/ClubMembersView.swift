import SwiftUI

/// Kulüp sayfasındaki üye satırı: fotoğraf, ad, rozet, bölüm. Dokununca
/// kişinin kartı açılır; kart her yerde olduğu gibi sağa-sola kaydırılır.
struct ClubMemberRowView: View {
    let member: ClubMember
    let open: () -> Void

    private var subtitle: String {
        [member.profile.department, AcademicYear.display(member.profile.year)]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                ProfileMedia(url: member.profile.imageURL, data: nil,
                             assetName: member.profile.imageAssetName)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(member.profile.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BondTheme.ink)
                            .lineLimit(1)
                        ProfileBadgeLabel(badge: member.profile.badge, compact: true)
                        if member.isManager {
                            Text(L10n.ClubAdmin.managerChip)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(BondTheme.ink.opacity(0.08), in: Capsule())
                                .foregroundStyle(BondTheme.ink)
                                .fixedSize()
                        }
                    }
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(BondTheme.muted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BondTheme.muted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, BondTheme.Space.md)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("club.member.\(member.id)")
    }
}

/// Kulübün bütün üyeleri. Sayfada ilk birkaç kişi görünüyor; "Tüm üyeler"
/// buraya getiriyor. Yönetimdeki liste (`ClubPeopleView`) ayrı: üye çıkarmak için.
struct ClubMembersView: View {
    let clubName: String
    let members: [ClubMember]

    @Environment(\.dismiss) private var dismiss
    @State private var cardProfile: StudentProfile?

    var body: some View {
        NavigationStack {
            List(members) { uye in
                ClubMemberRowView(member: uye) { cardProfile = uye.profile }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(BondTheme.paper)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle("\(clubName) · \(L10n.ClubAdmin.members)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.Common.close) { dismiss() } }
            }
            .sheet(item: $cardProfile) { profile in
                NavigationStack {
                    SocialPersonDetailView(profile: profile, place: nil, showsClose: true)
                }
            }
        }
    }
}
