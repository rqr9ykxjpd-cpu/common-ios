import SwiftUI
import PhotosUI

/// Akıştaki çalışma grubu kartı: kim, nerede, ne zaman; katılanların küçük
/// avatarları; Kim nerede'deki BURADAYIM gibi tek dokunuşla "Katıl".
/// Avatarlara dokununca kişinin kartı açılır — tanışma oradan (sağa kaydır).
struct StudyGroupCard: View {
    let group: StudyGroup
    /// Avatarlar profil sayfasının büyüyerek açıldığı kaynak olur.
    var zoomNamespace: Namespace.ID? = nil
    let openProfile: (StudentProfile) -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCancelConfirm = false
    @State private var spotPickerItem: PhotosPickerItem?
    @State private var isSharingSpot = false
    @State private var showSpotViewer = false

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
                    // Başlamasına bir saatten az kalınca fotoğrafın etrafında
                    // zamanla dolan halka; son 10 dakikada hafifçe atar. Halka
                    // kendi alanında: fotoğrafın dışına taşınca kenardan kesiliyordu.
                    ZStack {
                        // Atarken %7 büyüyor; çevresinde o kadar pay var.
                        StartCountdownRing(startsAt: group.startsAt, diameter: 44)
                        ProfileMedia(url: group.host.imageURL, data: nil, assetName: group.host.imageAssetName)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    }
                    .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .zoomSource(id: "grup-\(group.id)-\(group.host.id)", in: zoomNamespace)
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
                    // Tek Text: dar kartta (yatay şerit) yer adı kesilmek yerine
                    // ikinci satıra sarar, saat hep tam görünür.
                    (Text(Image(systemName: "mappin.and.ellipse")) + Text(" \(group.place.name)  ")
                        + Text(Image(systemName: "clock")) + Text(" \(group.hasStarted ? L10n.StudyGroup.started : whenText)"))
                        .font(.system(size: 13))
                        .foregroundStyle(BondTheme.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
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

            spotSection
        }
        // Yatay şeritte kartlar aynı boyda: kısa içerikli kartın zemini de dolsun.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(14)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous)
                .strokeBorder(group.joined ? BondTheme.ink.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .onChange(of: spotPickerItem) { _, item in
            guard let item else { return }
            Task { await shareSpot(item) }
        }
        .fullScreenCover(isPresented: $showSpotViewer) {
            PhotoZoomView(url: group.spotPhotoURL, data: nil)
        }
        .confirmationDialog(L10n.StudyGroup.cancel, isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button(L10n.StudyGroup.cancel, role: .destructive) { appState.cancelStudyGroup(group.id) }
        } message: {
            Text(L10n.StudyGroup.cancelConfirm)
        }
        .animation(reduceMotion ? nil : BondTheme.Motion.snappy, value: group.joined)
        // Katılınca avatar sekerek dizinin sonuna girer; ayrılınca aynı yoldan çıkar.
        .animation(reduceMotion ? nil : BondTheme.Motion.bouncy, value: group.members.count)
        .animation(reduceMotion ? nil : BondTheme.Motion.bouncy, value: group.hasSpotPhoto)
    }

    // MARK: - "Yerimi göster"

    /// Ev sahibi: pencere açıksa çek/yeniden çek; kapalıysa ipucu. Katılan: fotoğraf
    /// ya da "başlayınca gösterecek". Katılmayan: fotoğraf varsa "katılanlara açık".
    @ViewBuilder private var spotSection: some View {
        if group.isMine {
            if group.spotWindowOpen {
                VStack(alignment: .leading, spacing: 8) {
                    if group.hasSpotPhoto { spotThumbnail }
                    PhotosPicker(selection: $spotPickerItem, matching: .images) {
                        HStack(spacing: 6) {
                            if isSharingSpot { ProgressView().controlSize(.small) }
                            else { Image(systemName: "camera.fill").font(.system(size: 13, weight: .semibold)) }
                            Text(group.hasSpotPhoto ? L10n.StudyGroup.spotRetake : L10n.StudyGroup.spotShow)
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundStyle(group.hasSpotPhoto ? BondTheme.ink : BondTheme.paper)
                        .background(group.hasSpotPhoto ? BondTheme.paper : BondTheme.ink, in: Capsule())
                    }
                    .disabled(isSharingSpot)
                    if !group.hasSpotPhoto {
                        Text(L10n.StudyGroup.spotHint)
                            .font(.system(size: 12))
                            .foregroundStyle(BondTheme.muted)
                    }
                }
            } else if !group.hasStarted {
                Label(L10n.StudyGroup.spotBeforeWindow, systemImage: "camera")
                    .font(.system(size: 12))
                    .foregroundStyle(BondTheme.muted)
            }
        } else if group.hasSpotPhoto {
            if group.spotPhotoURL != nil {
                spotThumbnail
            } else {
                Label(L10n.StudyGroup.spotMembersOnly, systemImage: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(BondTheme.muted)
            }
        } else if group.joined {
            Label(L10n.StudyGroup.spotWaiting, systemImage: "camera")
                .font(.system(size: 12))
                .foregroundStyle(BondTheme.muted)
        }
    }

    private var spotThumbnail: some View {
        Button { showSpotViewer = true } label: {
            HStack(spacing: 10) {
                ProfileMedia(url: group.spotPhotoURL, data: nil, kind: .content)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.StudyGroup.spotHere(group.host.name, group.spotPhotoAt.map { Self.saat.string(from: $0) } ?? ""))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BondTheme.ink)
                    Text(group.place.name)
                        .font(.system(size: 12))
                        .foregroundStyle(BondTheme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BondTheme.muted)
            }
            .padding(8)
            .background(BondTheme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.StudyGroup.spotViewerTitle)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }

    private func shareSpot(_ item: PhotosPickerItem) async {
        isSharingSpot = true
        defer { isSharingSpot = false; spotPickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            appState.showError(L10n.StudyGroup.spotFailed); return
        }
        await appState.shareStudyGroupSpot(group.id, imageData: data)
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
                // Ev sahibi başlıkta zaten kaynak; aynı kimlik iki kez verilmesin.
                .zoomSource(id: "grup-\(group.id)-\(kisi.id)", in: kisi.id == group.host.id ? nil : zoomNamespace)
                .transition(.scale(scale: 0.3).combined(with: .opacity))
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
