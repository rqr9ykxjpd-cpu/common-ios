import SwiftUI

/// Ayarlar → "Destek taleplerim": bildirdiğin sorunlar ve yanıtlarımız.
/// Destek bildirimi de buraya açılıyor.
struct SupportInboxView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var opened: SupportOpening?
    @State private var showReport = false
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading, appState.supportThreads.isEmpty {
                    VStack(spacing: 0) { ForEach(0..<3, id: \.self) { _ in SkeletonRow() } }
                        .padding(.horizontal, BondTheme.Space.lg)
                        .frame(maxHeight: .infinity, alignment: .top)
                } else if appState.supportThreads.isEmpty {
                    AppEmptyState(
                        systemImage: "lifepreserver",
                        title: L10n.Support.emptyTitle,
                        message: L10n.Support.emptyBody,
                        actionTitle: L10n.ProblemReport.button
                    ) { showReport = true }
                    .padding(BondTheme.Space.lg)
                } else {
                    List(appState.supportThreads) { talep in
                        Button { opened = talep.opening } label: { row(talep) }
                            .buttonStyle(.plain)
                            .listRowBackground(BondTheme.paper)
                    }
                    .listStyle(.plain)
                    .refreshable { await appState.loadSupportThreads() }
                }
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Support.inboxTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showReport = true } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel(L10n.ProblemReport.button)
                }
            }
            .sheet(item: $opened, onDismiss: { Task { await appState.loadSupportThreads() } }) { talep in
                SupportThreadView(opening: talep, isStaff: false)
            }
            .sheet(isPresented: $showReport, onDismiss: { Task { await appState.loadSupportThreads() } }) {
                ProblemReportView(screen: "Destek")
            }
            .task {
                await appState.loadSupportThreads()
                isLoading = false
            }
        }
    }

    private func row(_ talep: SupportThread) -> some View {
        HStack(alignment: .top, spacing: BondTheme.Space.compact) {
            Circle()
                .fill(talep.hasUnread ? BondTheme.burntOrange : .clear)
                .frame(width: 8, height: 8)
                .padding(.top, 7)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(talep.message)
                    .font(.subheadline.weight(talep.hasUnread ? .semibold : .regular))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    SupportStatusChip(status: talep.status)
                    Text(talep.lastMessageAt.relativeTurkish)
                        .font(.caption)
                        .foregroundStyle(BondTheme.muted)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BondTheme.muted)
                .padding(.top, 4)
                .accessibilityHidden(true)
        }
        .foregroundStyle(BondTheme.ink)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
