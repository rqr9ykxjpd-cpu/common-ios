import SwiftUI
import UIKit

struct ProfileGalleryPhoto: Identifiable, Equatable {
    let id: String
    var url: URL?
    var data: Data?
    var assetName: String?

    static func remote(_ urls: [URL]) -> [Self] {
        var seen = Set<String>()
        return urls.compactMap { url in
            guard seen.insert(url.absoluteString).inserted else { return nil }
            return Self(id: url.absoluteString, url: url)
        }
    }
}

extension ProfileGalleryPhoto {
    /// Kart destesi yalnızca profil galerisi. Gönderiler altta paylaşım listesinde;
    /// böylece aynı fotoğraf hem karta hem gönderiye yazılabilir, deste şişmez.
    static func deck(gallery: [ProfileGalleryPhoto]) -> [ProfileGalleryPhoto] {
        var seen = Set<String>()
        var result: [ProfileGalleryPhoto] = []
        for photo in gallery {
            if let path = photo.url?.path {
                guard seen.insert(path).inserted else { continue }
            } else if let asset = photo.assetName {
                guard seen.insert("asset:\(asset)").inserted else { continue }
            }
            result.append(photo)
        }
        return result
    }
}

/// Deck'in üstünden başlayan yatay sürükleme. Fotoğrafı oynatmaz; kartın
/// bağlan/kapat jestine (SocialPersonDetailView) ham çeviri olarak gider.
/// UIKit görünümü dokunuşu SwiftUI'nın DragGesture'ına geçirmediği için
/// tek yol bu: UIKit tanıyıcı yakalar, SwiftUI kartı oynatır.
typealias CardPanHandler = (_ translation: CGPoint, _ state: UIGestureRecognizer.State, _ velocity: CGPoint) -> Void

/// Profil fotoğraf destesi — yalnızca fotoğraf.
///
/// Sayfalama dokunmayla: sağ yarı sonraki, sol yarı önceki; üstteki kart o yöne
/// uçar. Yatay sürükleme bilerek burada değil — o hareket kartın kendisine ait
/// (bağlantı kur / kapat, SocialPersonDetailView). Tam ekran için köşedeki ikon.
struct ProfileGalleryStack: View {
    let photos: [ProfileGalleryPhoto]
    var height: CGFloat = 440
    @State private var front = 0
    @State private var showsViewer = false

    private var current: Int { min(front, max(0, photos.count - 1)) }

    var body: some View {
        if photos.isEmpty {
            EmptyView()
        } else {
            PhotoDeckHost(
                photos: photos,
                front: front,
                onFrontChange: { front = $0 },
                onTap: { showsViewer = true }
            )
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(alignment: .bottomLeading) {
                if photos.count > 1 {
                    Text(L10n.CampusDesign.photoIndex(current + 1, of: photos.count))
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(BondTheme.ink)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(BondTheme.Space.md)
                        .contentTransition(.numericText())
                        .animation(BondTheme.Motion.snappy, value: current)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.CampusDesign.photoIndex(current + 1, of: photos.count))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { showsViewer = true }
            .accessibilityAction(named: L10n.CampusDesign.nextPhoto) { step(1) }
            .accessibilityAction(named: L10n.CampusDesign.previousPhoto) { step(-1) }
            .accessibilityIdentifier("profile.photoDeck")
            .onChange(of: photos) { _, new in
                if new.isEmpty || front >= new.count {
                    front = 0
                    showsViewer = false
                }
            }
            .fullScreenCover(isPresented: $showsViewer) {
                ProfileGalleryViewer(photos: photos, startingIndex: current)
            }
        }
    }

    private func step(_ direction: Int) {
        guard photos.count > 1 else { return }
        front = ProfileGestureDecision.photoIndex(current, step: direction, count: photos.count)
        Haptics.selection()
    }
}

private struct ProfileGalleryViewer: View {
    let photos: [ProfileGalleryPhoto]
    let startingIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var selection = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { offset, photo in
                    ProfileMedia(url: photo.url, data: photo.data, assetName: photo.assetName,
                                 kind: .content, showsRetry: true, contentMode: .fit)
                        .padding(.horizontal, 12)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page)
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.CampusDesign.photoIndex(min(selection + 1, photos.count), of: photos.count))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
        }
        .onAppear { selection = startingIndex }
    }
}

private struct PhotoDeckHost: UIViewRepresentable {
    var photos: [ProfileGalleryPhoto]
    var front: Int
    var onFrontChange: (Int) -> Void
    var onTap: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> PhotoDeckView {
        let view = PhotoDeckView()
        configure(view)
        return view
    }

    func updateUIView(_ uiView: PhotoDeckView, context: Context) {
        configure(uiView)
    }

    private func configure(_ uiView: PhotoDeckView) {
        uiView.configure(
            photos: photos,
            front: front,
            appState: appState,
            reduceMotion: reduceMotion,
            onFrontChange: onFrontChange,
            onTap: onTap
        )
    }
}

/// Transform the wrapper, never the photo. Setting `frame` on a rotated
/// image stretches it; the bitmap stays on the inner `UIImageView`.
private final class PhotoCardSlot: UIView {
    private let imageView = UIImageView()
    private var loadGeneration = 0
    private var photoID: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        clipsToBounds = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        imageView.backgroundColor = .clear
        imageView.layer.cornerRadius = BondTheme.Radius.media
        imageView.layer.cornerCurve = .continuous
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }

    func render(_ photo: ProfileGalleryPhoto, appState: AppState) {
        if photoID == photo.id, imageView.image != nil { return }
        photoID = photo.id
        loadGeneration += 1
        let generation = loadGeneration
        if let data = photo.data, let image = ImageCompression.imageForDisplay(data) {
            imageView.image = image
            return
        }
        if let asset = photo.assetName, let loaded = UIImage(named: asset) {
            imageView.image = ImageCompression.capped(loaded)
            return
        }
        imageView.image = nil
        guard let url = photo.url else { return }
        Task { @MainActor in
            let image = await appState.remoteImage(for: url)
            guard generation == loadGeneration else { return }
            imageView.image = image
        }
    }
}

/// Yatay fotoğraf kaydırması. Eşleşme / kapat buraya bağlanmaz.
/// Dikey parmak List/ScrollView’da kalır.
private final class PhotoDeckView: UIView, UIGestureRecognizerDelegate {
    private let pan = UIPanGestureRecognizer()
    private let tap = UITapGestureRecognizer()
    private var slots: [PhotoCardSlot] = []
    private var photos: [ProfileGalleryPhoto] = []
    private var front = 0
    private var displayedIDs: [String] = []
    private var displayedFront = -1
    private var appState: AppState?
    private var reduceMotion = false
    private var onFrontChange: (Int) -> Void = { _ in }
    private var onTap: () -> Void = {}
    private var dragging = false
    private var flying = false
    private var liftedCell: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = false
        isMultipleTouchEnabled = false
        isExclusiveTouch = false
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = true
        pan.delaysTouchesBegan = false
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = true
        pan.delaysTouchesBegan = false
        tap.delegate = self
        tap.cancelsTouchesInView = true
        tap.require(toFail: pan)
        pan.addTarget(self, action: #selector(handlePan))
        tap.addTarget(self, action: #selector(handleTap))
        addGestureRecognizer(pan)
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { nil }

    func configure(
        photos: [ProfileGalleryPhoto],
        front: Int,
        appState: AppState,
        reduceMotion: Bool,
        onFrontChange: @escaping (Int) -> Void,
        onTap: @escaping () -> Void
    ) {
        self.onFrontChange = onFrontChange
        self.onTap = onTap
        if pan.state != .began && pan.state != .changed {
            // Tek fotoğrafta çevrilecek şey yok.
            pan.isEnabled = photos.count > 1 && !flying
        }
        self.appState = appState
        self.reduceMotion = reduceMotion
        let ids = photos.map(\.id)
        if dragging || flying {
            self.photos = photos
            return
        }
        let same = ids == displayedIDs && front == displayedFront && !slots.isEmpty
        self.photos = photos
        self.front = min(front, max(0, photos.count - 1))
        if same {
            return
        }
        rebuildHosts()
        layoutCards()
        applyRestTransforms()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutCards()
        if !dragging && !flying {
            applyRestTransforms()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        unclipAncestors()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        unclipAncestors()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.contains(point)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === tap { return !dragging && !flying }
        guard gestureRecognizer === pan, photos.count > 1, !flying else { return false }
        let translation = pan.translation(in: self)
        return ProfileGestureDecision.deckClaimsPan(x: translation.x, y: translation.y)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === pan else { return false }
        return enclosingScrollViews().contains { $0.panGestureRecognizer === other }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
        false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf other: UIGestureRecognizer
    ) -> Bool {
        false
    }

    private func rebuildHosts() {
        displayedIDs = photos.map(\.id)
        displayedFront = front
        let visible = min(3, photos.count)
        guard let appState, visible > 0 else {
            slots.forEach { $0.removeFromSuperview() }
            slots.removeAll()
            return
        }
        while slots.count > visible {
            slots.removeLast().removeFromSuperview()
        }
        while slots.count < visible {
            let slot = PhotoCardSlot(frame: .zero)
            addSubview(slot)
            slots.append(slot)
        }
        for depth in 0..<visible {
            let index = ProfileGestureDecision.photoIndex(front, step: depth, count: photos.count)
            slots[depth].render(photos[index], appState: appState)
        }
        updateZOrder()
    }

    private var cardFrame: CGRect {
        let maxW = max(0, bounds.width - 20)
        let maxH = max(0, bounds.height - 24)
        var width = min(maxW, maxH * 3 / 4)
        var height = width * 4 / 3
        if height > maxH {
            height = maxH
            width = height * 3 / 4
        }
        return CGRect(
            x: (bounds.width - width) / 2,
            y: max(0, (bounds.height - height) / 2),
            width: width,
            height: height
        )
    }

    private func layoutCards() {
        let frame = cardFrame
        for (index, slot) in slots.enumerated() {
            if (dragging || flying) && index == 0 { continue }
            let saved = slot.transform
            slot.transform = .identity
            slot.bounds = CGRect(origin: .zero, size: frame.size)
            slot.center = CGPoint(x: frame.midX, y: frame.midY)
            slot.transform = saved
        }
    }

    private func updateZOrder() {
        for (depth, slot) in slots.enumerated() {
            slot.layer.zPosition = CGFloat(10 - depth)
        }
    }

    private func applyRestTransforms() {
        for (depth, slot) in slots.enumerated() {
            slot.transform = restTransform(depth: depth)
        }
    }

    private func restTransform(depth: Int) -> CGAffineTransform {
        guard photos.count > 1 else { return .identity }
        let scale = 1 - CGFloat(depth) * 0.04
        let degrees: CGFloat
        switch depth {
        case 0: degrees = 3
        case 1: degrees = -4.5
        default: degrees = 2
        }
        return CGAffineTransform(rotationAngle: degrees * .pi / 180).scaledBy(x: scale, y: scale)
    }

    private func dragTransform(_ translation: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: translation.x, y: translation.y)
            .concatenating(restTransform(depth: 0))
    }

    private func enclosingScrollViews() -> [UIScrollView] {
        var scrolls: [UIScrollView] = []
        var node = superview
        while let current = node {
            if let scroll = current as? UIScrollView {
                scrolls.append(scroll)
            }
            node = current.superview
        }
        return scrolls
    }

    private func enclosingCell() -> UIView? {
        var node = superview
        while let current = node {
            if current.superview is UIScrollView {
                return current
            }
            node = current.superview
        }
        return nil
    }

    /// Dönen kartlar List hücresinde kesilmesin. Jest ilişkisini burada
    /// kurmak kaydırma sırasında pan’i kilitliyordu.
    private func unclipAncestors() {
        var node: UIView? = self
        while let current = node {
            if current is UIScrollView { break }
            current.clipsToBounds = false
            node = current.superview
        }
    }

    private func cancelEnclosingScrollPans() {
        for scroll in enclosingScrollViews() {
            let gesture = scroll.panGestureRecognizer
            if gesture.isEnabled {
                gesture.isEnabled = false
                gesture.isEnabled = true
            }
        }
    }

    private func liftCell(_ lift: Bool) {
        if lift {
            liftedCell = enclosingCell()
            liftedCell?.layer.zPosition = 1000
        } else {
            liftedCell?.layer.zPosition = 0
            liftedCell = nil
        }
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: self)
        switch pan.state {
        case .began:
            dragging = true
            cancelEnclosingScrollPans()
            liftCell(true)
            dragTop(translation)
        case .changed:
            dragTop(translation)
        case .ended:
            finishDrag(translation: translation, velocity: pan.velocity(in: self))
        case .cancelled, .failed:
            dragging = false
            liftCell(false)
            snapBack()
        default:
            break
        }
    }

    @objc private func handleTap() {
        guard !dragging, !flying else { return }
        onTap()
    }

    private func dragTop(_ translation: CGPoint) {
        guard let top = slots.first else { return }
        top.transform = dragTransform(translation)
        if slots.count > 1 {
            let progress = min(1, hypot(translation.x, translation.y) / 120)
            let scale = 0.96 + 0.04 * progress
            slots[1].transform = CGAffineTransform(rotationAngle: -4.5 * .pi / 180)
                .scaledBy(x: scale, y: scale)
        }
    }

    private func finishDrag(translation: CGPoint, velocity: CGPoint) {
        let predicted = CGPoint(
            x: translation.x + velocity.x * 0.18,
            y: translation.y + velocity.y * 0.18
        )
        if ProfileGestureDecision.photoDragCommit(x: predicted.x, y: predicted.y, count: photos.count) {
            flyOff(from: translation, velocity: velocity)
        } else {
            dragging = false
            liftCell(false)
            snapBack()
        }
    }

    private func snapBack() {
        UIView.animate(
            withDuration: reduceMotion ? 0 : 0.22,
            delay: 0,
            usingSpringWithDamping: 0.92,
            initialSpringVelocity: 0.2,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
        ) {
            self.applyRestTransforms()
        }
    }

    private func flyOff(from translation: CGPoint, velocity: CGPoint) {
        guard let top = slots.first else {
            dragging = false
            liftCell(false)
            return
        }
        flying = true
        dragging = false
        pan.isEnabled = false
        Haptics.selection()
        let dx = translation.x + velocity.x * 0.12
        let dy = translation.y + velocity.y * 0.12
        let length = max(hypot(dx, dy), 1)
        let travel = hypot(bounds.width, bounds.height) + 80
        let end = CGPoint(x: dx / length * travel, y: dy / length * travel)
        let animations = {
            top.transform = self.dragTransform(end)
            if self.slots.count > 1 {
                self.slots[1].transform = self.restTransform(depth: 0)
            }
        }
        let finish = { [weak self] in
            guard let self else { return }
            let next = ProfileGestureDecision.photoIndex(self.front, step: 1, count: self.photos.count)
            self.front = next
            self.flying = false
            self.liftCell(false)
            self.rebuildHosts()
            self.layoutCards()
            self.applyRestTransforms()
            self.pan.isEnabled = !self.photos.isEmpty
            self.onFrontChange(next)
        }
        if reduceMotion {
            finish()
            return
        }
        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState]
        ) {
            animations()
        } completion: { _ in
            finish()
        }
    }
}
