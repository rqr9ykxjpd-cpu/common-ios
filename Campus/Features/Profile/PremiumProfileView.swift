import SwiftUI

struct PremiumProfileView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
        ZStack {
            CampusTheme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack { Wordmark(compact: true); Spacer(); Eyebrow(text: L10n.Profile.premiumEyebrow, color: CampusTheme.ink.opacity(0.5)) }
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [CampusTheme.violet, CampusTheme.coral], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(height: 260)
                        Text("S").font(.system(size: 210, weight: .medium)).foregroundStyle(.white.opacity(0.72)).offset(x: 18, y: 38)
                        Text("CEM\n21").font(.system(size: 26, weight: .black)).foregroundStyle(.white).padding(18)
                    }.clipped()

                    Text(L10n.Profile.speaksFirst).editorialTitle(37).foregroundStyle(CampusTheme.ink)

                    VStack(spacing: 0) {
                        NavigationLink { ProfileEditorView() } label: { settingsRow("01", L10n.Profile.editStory, "person.text.rectangle") }
                        settingsRow("02", L10n.Profile.whoToMeet, "scope")
                        settingsRow("03", L10n.Profile.safety, "checkmark.shield")
                    }
                    Button(L10n.Profile.signOutCaps) { Task { await appState.signOut() } }
                        .font(.system(size: 9, weight: .bold)).tracking(1.4).foregroundStyle(CampusTheme.ink.opacity(0.4))
                }
                .padding(22).padding(.bottom, 90)
            }
        }
        }
    }

    private func settingsRow(_ number: String, _ title: String, _ icon: String) -> some View {
        HStack(spacing: 14) {
            Text(number).font(.system(size: 10, design: .monospaced)).foregroundStyle(CampusTheme.ink.opacity(0.4))
            Image(systemName: icon).frame(width: 22)
            Text(title).font(.system(size: 15, weight: .semibold))
            Spacer(); Image(systemName: "arrow.right").font(.caption)
        }
        .foregroundStyle(CampusTheme.ink).padding(.vertical, 18)
        .overlay(alignment: .bottom) { Rectangle().fill(CampusTheme.ink.opacity(0.14)).frame(height: 1) }
    }
}
