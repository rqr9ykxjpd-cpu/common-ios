import SwiftUI

/// Akıştaki çalışma grubu kartı: kim, nerede, ne zaman; katılanların küçük
/// avatarları; Kim nerede'deki BURADAYIM gibi tek dokunuşla "Katıl".
/// Avatarlara dokununca kişinin kartı açılır — tanışma oradan (sağa kaydır).
struct StudyGroupCard: View {
    let group: StudyGroup
    let openProfile: (StudentProfile) -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCancelConfirm = false

    private static let saat: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "tr_TR"); f.dateFormat = "HH:mm"; return f
    }()

    private var whenText: String {
        let gun = Calendar.current.isDateInToday(group.startsAt) ? L10n.StudyGroup.today
            : Calendar.current.isDateInTomorrow(group.startsAt) ? L10n.StudyGroup.tomorrow
            : group.startsAt.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "tr_TR")))
        return "\(gun) \(Self.saat.string(from: group.startsAt))"
    }

    private var headcountText: String {
        if let cap = group.capacity { return L10n.StudyGroup.headcountOf(group.headcount, cap) }
        return L10n.StudyGroup.headcount(group.headcount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Button { openProfile(group.host) } label: {
                    ProfileMedia(url: group.host.imageURL, data: nil, assetName: group.host.imageAssetName)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(group.host.name)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(group.host.name).font(.system(size: 15, weight: .semibold))
                        if group.isMine {
                            Text(L10n.StudyGroup.mine)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(BondTheme.burntOrange)
                        }
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 11, weight: .semibold))
                        Text(group.place.name)
                        Text("·")
                        Image(systemName: "clock").font(.system(size: 11, weight: .semibold))
                        Text(group.hasStarted ? L10n.StudyGroup.started : whenText)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(BondTheme.muted)
                    .lineLimit(1)
                }
                Spacer(minLength: 8)
                if group.isMine {
                    Menu {
                        Button(L10n.StudyGroup.cancel, systemImage: "xmark.circle", role: .destructive) {
                            showCancelConfirm = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BondTheme.muted)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                }
            }

            if !group.note.isEmpty {
                Text(group.note)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(BondTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                memberStack
                Text(headcountText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BondTheme.muted)
                    .contentTransition(.numericText())
                Spacer(minLength: 8)
                if !group.isMine { joinButton }
            }
        }
        .padding(14)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous)
                .strokeBorder(group.joined ? BondTheme.ink.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .confirmationDialog(L10n.StudyGroup.cancel, isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button(L10n.StudyGroup.cancel, role: .destructive) { appState.cancelStudyGroup(group.id) }
        } message: {
            Text(L10n.StudyGroup.cancelConfirm)
        }
        .animation(reduceMotion ? nil : BondTheme.Motion.snappy, value: group.joined)
        .animation(reduceMotion ? nil : BondTheme.Motion.snappy, value: group.members.count)
    }

    /// Ev sahibi + katılanlar, üst üste binen küçük avatarlar; 4'ten sonrası "+N".
    private var memberStack: some View {
        let kisiler = [group.host] + group.members
        let gorunen = Array(kisiler.prefix(4))
        let fazla = kisiler.count - gorunen.count
        return HStack(spacing: -8) {
            ForEach(gorunen) { kisi in
                Button { openProfile(kisi) } label: {
                    ProfileMedia(url: kisi.imageURL, data: nil, assetName: kisi.imageAssetName)
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(BondTheme.surface, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(kisi.name)
            }
            if fazla > 0 {
                Text("+\(fazla)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(BondTheme.ink)
                    .frame(width: 28, height: 28)
                    .background(BondTheme.paper, in: Circle())
                    .overlay(Circle().strokeBorder(BondTheme.surface, lineWidth: 2))
            }
        }
    }

    private var joinButton: some View {
        let dolu = group.isFull && !group.joined
        return Button {
            guard !dolu else { return }
            Haptics.selection()
            appState.toggleStudyGroupMembership(group.id)
        } label: {
            ZStack {
                Text(L10n.StudyGroup.joined).hidden()
                Text(L10n.StudyGroup.join).hidden()
                Text(group.joined ? L10n.StudyGroup.joined : (dolu ? L10n.StudyGroup.full : L10n.StudyGroup.join))
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 18)
            .frame(minHeight: 40)
            .foregroundStyle(group.joined ? BondTheme.paper : (dolu ? BondTheme.muted : BondTheme.ink))
            .background(group.joined ? BondTheme.ink : BondTheme.paper, in: Capsule())
            .contentTransition(.opacity)
        }
        .buttonStyle(.pressable)
        .disabled(dolu)
        .accessibilityLabel(group.joined ? L10n.StudyGroup.joined : L10n.StudyGroup.join)
    }
}
