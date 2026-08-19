import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selection = 0

    var body: some View {
        Group {
            switch selection {
            case 1: PremiumDiscoverView()
            case 2: SocialProfileView()
            default: SocialFeedView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .ignoresSafeArea(.keyboard)
#if DEBUG
        .onAppear { selection = appState.initialTab }
#endif
    }

    private var bottomBar: some View {
        HStack(spacing: 6) {
            NavItem(index: 0, selection: $selection, icon: "house", title: "Akış")
            NavItem(index: 1, selection: $selection, icon: "heart", title: "Tanış")
            NavItem(index: 2, selection: $selection, icon: "person", title: "Profil")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .frame(height: 68)
        .background(CampusTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(CampusTheme.hairline).frame(height: 0.5) }
    }
}

private struct NavItem: View {
    let index: Int
    @Binding var selection: Int
    let icon: String
    let title: String

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.3)) { selection = index }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selection == index ? "\(icon).fill" : icon)
                    .font(.system(size: 18, weight: selection == index ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 11, weight: selection == index ? .semibold : .medium, design: .rounded))
            }
            .foregroundStyle(selection == index ? CampusTheme.ink : CampusTheme.ink.opacity(0.46))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(selection == index ? CampusTheme.ink.opacity(0.055) : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}
