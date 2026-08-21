import SwiftUI

struct PremiumDiscoverView: View {
    @Environment(AppState.self) private var appState
    @State private var drag: CGSize = .zero
    /// Karar eşiği geçildiğinde bir kez titreşim vermek için. Kullanıcı kartı
    /// bırakmadan önce "yeterince kaydırdım mı" diye kestirmek zorundaydı.
    @State private var pastThreshold = false
    @State private var detailVisible = false
    @State private var showChats = false
    @State private var showFilters = false
    @State private var matchConversation: MatchConversationRoute?

    var body: some View {
        ZStack {
            CampusTheme.canvasDark.ignoresSafeArea()
            GrainOverlay().ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if let profile = appState.profiles.first {
                    ZStack {
                        DiscoveryCard(profile: profile, highlightedInterests: appState.draft.interests)
                            // Kararın rengi kartın tamamına yayılıyor: damga küçük ve
                            // köşede kalıyordu, kaydırırken göz kartın ortasında oluyor.
                            .overlay {
                                RoundedRectangle(cornerRadius: CampusTheme.Radius.hero, style: .continuous)
                                    .fill(drag.width > 0 ? CampusTheme.acid : CampusTheme.coral)
                                    .opacity(0.3 * swipeProgress)
                                    .allowsHitTesting(false)
                            }
                            .overlay(alignment: .top) {
                                HStack {
                                    decisionStamp(L10n.Discovery.meetStamp, color: CampusTheme.acid, rotation: -12)
                                        .opacity(drag.width > 0 ? swipeProgress : 0)
                                    Spacer()
                                    // Eskiden beyazdı: iki karar da aynı renkteydi ve
                                    // hangisinin ne olduğu yalnızca yazıdan anlaşılıyordu.
                                    decisionStamp(L10n.Discovery.passStamp, color: CampusTheme.coral, rotation: 12)
                                        .opacity(drag.width < 0 ? swipeProgress : 0)
                                }
                                .padding(20)
                            }
                            .offset(drag)
                            .rotationEffect(.degrees(Double(drag.width / 35)))
                            .contentShape(RoundedRectangle(cornerRadius: CampusTheme.Radius.hero, style: .continuous))
                            .onTapGesture { detailVisible = true }
                            .gesture(swipeGesture)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    swipeHint
                    controls
                } else {
                    emptyState
                }
            }
            .padding(.bottom, 8)

        }
        .task {
            if appState.profiles.isEmpty { await appState.loadDiscovery(reset: true) }
            await appState.loadConversations()
        }
#if DEBUG
        .onAppear { if appState.opensChats { showChats = true } }
        .fullScreenCover(isPresented: Binding(
            get: { appState.opensMessageRequests },
            set: { appState.opensMessageRequests = $0 }
        )) { MessageRequestsView() }
#endif
        .fullScreenCover(isPresented: $showChats) {
            PremiumMatchesView(close: { showChats = false })
        }
        .sheet(isPresented: $showFilters) {
            DiscoveryFilterSheet(filters: appState.discoveryFilters) { filters in
                Task { await appState.applyDiscoveryFilters(filters) }
            }
        }
        .sheet(isPresented: $detailVisible) {
            if let profile = appState.profiles.first { ProfileDetailSheet(profile: profile) }
        }
        .fullScreenCover(item: Binding(get: { appState.currentMatch }, set: { appState.currentMatch = $0 })) { profile in
            MatchMomentView(profile: profile) {
                appState.currentMatch = nil
            } message: { starter in
                // Eşleşme anında sohbet zaten gerçek eşleşme kimliğiyle açılıyor.
                guard let conversationID = appState.conversationID(for: profile) else {
                    appState.currentMatch = nil
                    return
                }
                if let starter { Task { await appState.send(starter, in: conversationID) } }
                appState.currentMatch = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    matchConversation = MatchConversationRoute(id: conversationID)
                }
            }
        }
        .fullScreenCover(item: $matchConversation) { route in
            NavigationStack { ConversationView(conversationID: route.id) }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Discovery.title)
                    .font(.system(size: 26, weight: .bold))
                Text(L10n.Discovery.subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Button {
                Haptics.impact(.light)
                showFilters = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.1), in: Circle())
                    if appState.discoveryFilters.activeCount > 0 {
                        Text("\(appState.discoveryFilters.activeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(CampusTheme.onAccent)
                            .frame(width: 17, height: 17)
                            .background(CampusTheme.acid, in: Circle())
                    }
                }
                .accessibilityLabel(appState.discoveryFilters.activeCount > 0
                    ? L10n.Discovery.filtersActiveA11y(appState.discoveryFilters.activeCount)
                    : L10n.Discovery.filtersA11y)
            }
            .buttonStyle(PressableStyle())
            Button {
                Haptics.impact(.light)
                showChats = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "message.fill")
                    Text(L10n.Discovery.chats)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(CampusTheme.onAccent)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(CampusTheme.acid, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
            .zIndex(10)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(height: 62)
    }


    /// Kaydırma sırasında kararın ne yönde olduğunu gösterir. Sürükleme hareketi vardı ama
    /// hiçbir görsel karşılığı yoktu; kullanıcı kartı bırakana kadar ne olacağını bilmiyordu.
    private var swipeProgress: CGFloat {
        min(abs(drag.width) / 110, 1)
    }

    private func decisionStamp(_ text: String, color: Color, rotation: Double) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .black))
            .tracking(1.5)
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(color, lineWidth: 3))
            .rotationEffect(.degrees(rotation))
    }

    /// Kaydırmanın ne yaptığı hiçbir yerde yazmıyordu. Kaydırırken o yönün metni
    /// öne çıkıyor, böylece bilgi ilk denemede de kararın ortasında da veriliyor.
    private var swipeHint: some View {
        HStack(spacing: 8) {
            Label(L10n.Discovery.swipePass, systemImage: "arrow.left")
                .foregroundStyle(drag.width < 0
                                 ? CampusTheme.coral
                                 : .white.opacity(0.4))
            Text("·").foregroundStyle(.white.opacity(0.25))
            Label(L10n.Discovery.swipeMeet, systemImage: "arrow.right")
                .foregroundStyle(drag.width > 0
                                 ? CampusTheme.acid
                                 : .white.opacity(0.4))
        }
        .font(.system(size: 11, weight: .semibold))
        .animation(.easeOut(duration: 0.15), value: drag.width > 0)
        .animation(.easeOut(duration: 0.15), value: drag.width < 0)
        .padding(.top, 12)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            // "Geri al" kaldırıldı: kararlar sunucuya yazılıyor ve geri alınamıyordu,
            // buton backend modunda her zaman pasifti.
            actionButton(icon: "xmark", label: L10n.Discovery.pass, fill: .white.opacity(0.08), color: .white) { dismiss(-1) }
            actionButton(icon: "heart.fill", label: L10n.Discovery.meet, fill: CampusTheme.acid, color: CampusTheme.ink) { dismiss(1) }

            iconButton(systemName: "person.text.rectangle", tint: .white) { detailVisible = true }
                .accessibilityLabel(L10n.Discovery.seeFullProfile)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func iconButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(CampusTheme.line))
        }
        .buttonStyle(PressableStyle())
    }

    private func actionButton(icon: String, label: String, fill: Color, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label).font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(fill, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(CampusTheme.line))
        }
        .buttonStyle(PressableStyle())
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            if appState.isLoadingDiscovery {
                ProgressView().tint(CampusTheme.acid)
                Text(L10n.Discovery.preparing).foregroundStyle(.white)
            } else if let error = appState.discoveryError {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(CampusTheme.coral)
                Text(error).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                Button(L10n.Common.retry) { Task { await appState.loadDiscovery(reset: true) } }
                    .foregroundStyle(CampusTheme.acid)
            } else {
                let activeFilters = appState.discoveryFilters.activeCount
                Image(systemName: activeFilters > 0 ? "line.3.horizontal.decrease.circle" : "person.2.slash")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(CampusTheme.acid)
                Text(activeFilters > 0 ? L10n.Discovery.noFilterMatches : L10n.Discovery.deckEmpty)
                    .editorialTitle(38)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Liste boş kalınca sebebin filtreler mi yoksa gerçekten kimsenin olmaması mı
                // olduğu anlaşılmıyordu; kullanıcı filtreyi daralttığını unutmuş olabilir.
                if activeFilters > 0 {
                    Text(L10n.Discovery.filtersOpen(activeFilters))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                    VStack(spacing: 10) {
                        Button {
                            Haptics.impact(.light)
                            Task { await appState.applyDiscoveryFilters(DiscoveryFilters()) }
                        } label: {
                            Text(L10n.Discovery.clearFilters)
                                .font(.system(size: 11, weight: .black)).tracking(1)
                                .foregroundStyle(CampusTheme.onAccent)
                                .padding(.horizontal, 22).frame(height: 46)
                                .background(CampusTheme.acid, in: Capsule())
                        }
                        .buttonStyle(PressableStyle())
                        Button(L10n.Discovery.editFilters) { showFilters = true }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else {
                    Text(L10n.Discovery.emptyHint)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                    Button {
                        Haptics.impact(.light)
                        Task { await appState.reloadDiscoveryIncludingPasses() }
                    } label: {
                        Label(L10n.Common.refresh, systemImage: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(CampusTheme.acid)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                drag = value.translation
                let asildi = abs(value.translation.width) > 100
                if asildi != pastThreshold {
                    pastThreshold = asildi
                    if asildi { Haptics.impact(.light) }
                }
            }
            .onEnded { value in
                abs(value.translation.width) > 100 ? dismiss(value.translation.width > 0 ? 1 : -1) : withAnimation(.spring(response: 0.4, dampingFraction: 0.76)) { drag = .zero }
            }
    }

    private func dismiss(_ direction: CGFloat) {
        guard let profile = appState.profiles.first else { return }
        Haptics.impact(direction > 0 ? .medium : .light)
        withAnimation(.easeIn(duration: 0.24)) { drag = CGSize(width: direction * 650, height: 20) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            drag = .zero
            Task { await appState.react(to: profile, liked: direction > 0) }
        }
    }
}

struct MatchConversationRoute: Identifiable {
    let id: UUID
}
