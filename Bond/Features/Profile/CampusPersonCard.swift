import SwiftUI

/// Campus directory row: round photo, name, department. Not a photo card.
struct CampusPersonCard: View {
    let profile: StudentProfile
    var place: CampusPlace? = nil
    var showsDisclosure = true

    var body: some View {
        HStack(spacing: BondTheme.Space.compact) {
            ProfileMedia(url: profile.imageURL, data: nil, assetName: profile.imageAssetName)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.body)
                Text([profile.department, AcademicYear.display(profile.year)].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let place {
                    Text(place.name)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(BondTheme.ink)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityName)
        .accessibilityHint(L10n.CampusDesign.viewProfile)
    }

    private var accessibilityName: String {
        var parts = [profile.name, profile.department, AcademicYear.display(profile.year)]
        if let place { parts.append(place.name) }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
