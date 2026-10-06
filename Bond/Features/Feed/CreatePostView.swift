import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import UniformTypeIdentifiers
import CoreTransferable

enum ComposerContentType: Int, CaseIterable, Identifiable {
    case post
    case story

    var id: Int { rawValue }
    var title: String { self == .post ? L10n.Composer.post : L10n.Composer.story }
    var systemName: String { self == .post ? "square.and.pencil" : "circle.dashed" }
}

struct CreatePostView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var contentType: ComposerContentType
    /// Gönderi türü (rozet); story'de anlamı yok.
    @State private var kind: PostKind
    @State private var showBadgeCatalog = false
    /// Rozetsiz "Paylaş"a basılınca çıkan el yazısı not.
    @State private var showBadgeHint = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?
    /// Gönderinin fotoğrafları sırayla (ilki kapak, `imageData` ile aynı). Story tek fotoğraf.
    @State private var postPhotos: [Data] = []
    /// Galeriden çoklu seçim; yüklenince boşaltılır, fotoğraflar `postPhotos`'a eklenir.
    @State private var pickedItems: [PhotosPickerItem] = []
    /// Story videosu: önizleme seçilen dosyayla hemen açılır, yüklenecek MP4
    /// arkada hazırlanır (`videoExport`); paylaş'a basılınca o beklenir.
    @State private var videoPreviewURL: URL?
    @State private var videoExport: Task<VideoCompression.PreparedClip, Error>?
    @State private var caption = ""
    @State private var selectedPlace: CampusPlace?
    @State private var showCamera = false
    @State private var showCameraUnavailable = false
    @State private var showCameraDenied = false
    @State private var isPublishing = false
    @State private var isPreparingMedia = false
    /// Hazırlanan video mu (Story'deki bekleme metni için).
    @State private var isPreparingVideo = false
    @State private var myPostCount = 0
    @State private var addToProfile = false
    /// Paylaşım bitti: düğme kısa bir an tike dönüp ekran öyle kapanıyor.
    @State private var publishDone = false
    /// Karakter sınırına her dayanışta artar; alan titrer.
    @State private var limitBump = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(initialContentType: Int = 0, initialKind: PostKind = .moment) {
        _contentType = State(initialValue: ComposerContentType(rawValue: initialContentType) ?? .post)
        _kind = State(initialValue: initialKind)
    }

    private var isStory: Bool { contentType == .story }
    private var captionLimit: Int { isStory ? TextLimit.story : TextLimit.post }
    private var captionLength: Int { TextLimit.length(caption) }
    private var counterVisible: Bool { CharacterCounter.isVisible(count: captionLength, limit: captionLimit) }
    private var hints: [String] { isStory ? L10n.Composer.storyHints : kind.hints }

    private var captionFits: Bool { TextLimit.fits(caption, captionLimit) }
    private var cleanCaption: String { caption.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var atPostLimit: Bool {
        guard !isStory, let cap = appState.tier.maxPosts else { return false }
        return myPostCount >= cap
    }
    private var canPublish: Bool {
        guard !isPreparingMedia, captionFits else { return false }
        if atPostLimit { return true }
        return isStory ? imageData != nil : (imageData != nil || !cleanCaption.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isStory {
                    storyComposer
                } else {
                    composerForm
                        .scrollDismissesKeyboard(.interactively)
                        .dismissesKeyboardOnTap()
                }
            }
            .keyboardDoneButton()
            .onChange(of: caption) { eski, yeni in
                if TextLimit.crossed(from: eski, to: yeni, captionLimit) { limitBump += 1 }
            }
            .navigationTitle(isStory ? L10n.Composer.shareStory : L10n.Composer.sharePost)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(isStory ? .hidden : .automatic, for: .navigationBar)
            .toolbarColorScheme(isStory ? .dark : nil, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.close) { dismiss() }
                        .disabled(isPublishing || isPreparingMedia)
                }
                // iOS 26'da çubuk düğmenin arkasına kendi camını koyuyor ve rengini
                // kendisi seçiyor (sistem mavisi). Camı kapatıp düğmeyi biz çiziyoruz.
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .confirmationAction) { publishButton }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .confirmationAction) { publishButton }
                }
            }
            .sheet(isPresented: $showBadgeCatalog) {
                BadgeCatalogSheet(selection: kindSelection)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(allowsVideo: isStory, onImage: consumeCameraPhoto, onVideo: consumeCameraVideo)
                    .ignoresSafeArea()
            }
            .alert(L10n.Composer.cameraUnavailable, isPresented: $showCameraUnavailable) {
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(L10n.Composer.cameraUnavailableBody)
            }
            .alert(L10n.Composer.cameraDenied, isPresented: $showCameraDenied) {
                Button(L10n.Common.openSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Composer.cameraDeniedBody)
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task { await ingestPickerItem(item) }
            }
            .onChange(of: contentType) { _, type in
                // Gönderi videosuz: story'den geçince klip durmasın.
                if type == .post, videoPreviewURL != nil {
                    clearVideo()
                    imageData = nil
                    selectedItem = nil
                }
                // Story tek fotoğraf; gönderiye geçince o fotoğraf listenin ilki olur.
                if type == .post {
                    postPhotos = imageData.map { [$0] } ?? []
                }
                if type == .story {
                    addToProfile = false
                } else if imageData != nil {
                    addToProfile = !appState.isGalleryFull
                }
            }
            .onChange(of: imageData) { _, data in
                if data == nil || isStory {
                    addToProfile = false
                } else {
                    addToProfile = !appState.isGalleryFull
                }
            }
            .task {
                myPostCount = await appState.countMyPosts()
            }
        }
    }

    /// Kamerayı açmadan önce izin durumuna bakıyoruz: redde boş picker
    /// düşmesin, Ayarlar'a yol çıksın.
    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraUnavailable = true
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            prepareCameraPresentation()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { prepareCameraPresentation() }
                    else { showCameraDenied = true }
                }
            }
        case .denied, .restricted:
            showCameraDenied = true
        @unknown default:
            showCameraDenied = true
        }
    }

    /// Story kamerası video da çekebildiği için mikrofonu da soruyoruz; redde
    /// yine fotoğraf çekilebilir.
    private func prepareCameraPresentation() {
        guard isStory else {
            showCamera = true
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async { showCamera = true }
            }
        default:
            showCamera = true
        }
    }

    /// Tür seçici Form'un dışında: Form bölümü çipleri kendi yuvarlak kutusuna
    /// kırpıyor, sıra kenardan kenara kayamıyordu.
    private var composerForm: some View {
        composerFormContent
            .onChange(of: pickedItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await ingestPostItems(items) }
            }
            // Kapak her yerde `imageData`: yayın, "profiline de ekle" ve story geçişi ona bakıyor.
            .onChange(of: postPhotos) { _, photos in
                guard !isStory else { return }
                imageData = photos.first
            }
    }

    private var composerFormContent: some View {
        VStack(spacing: 0) {
            if !isStory {
                VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                    Text(L10n.PostKind.pickerTitle)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BondTheme.muted)
                        .padding(.horizontal, BondTheme.Space.lg)
                    PostKindChipRow(selection: kindSelection, kinds: PostKind.featured) {
                        MoreBadgesChip { showBadgeCatalog = true }
                    }
                    if showBadgeHint {
                        PickBadgeHint()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(BondTheme.Motion.bouncy, value: showBadgeHint)
                .sensoryFeedback(.warning, trigger: showBadgeHint) { _, yeni in yeni }
                .padding(.top, BondTheme.Space.md)
                .padding(.bottom, BondTheme.Space.xs)
            }
            composerFields
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    /// Story: tam ekran tuval. Görsel izleyicide nasıl görünecekse burada da
    /// öyle (kırpma yok, bulanık dolgu). Not fotoğrafın üstüne yazılır, yer çipi
    /// altta. Form kalktı: küçük kart, gerçek paylaşımı hiç göstermiyordu.
    private var storyComposer: some View {
        let filter: PHPickerFilter = .any(of: [.images, .videos])
        return ZStack {
            Color.black.ignoresSafeArea()
            if imageData == nil {
                // Seçilen dosya hazırlanırken "seç" kutusu değil, hazırlanıyor
                // hâli: eskiden kutu olduğu gibi kalıyordu ve seçiciye geri
                // dönülmüş gibi görünüyordu.
                if isPreparingMedia {
                    storyPreparing
                } else {
                    storyEmptyState(filter: filter)
                }
            } else {
                StoryMediaCanvas(url: nil, data: imageData, videoURL: videoPreviewURL, isPaused: false)
                    .ignoresSafeArea()
                    .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                storyOverlay(filter: filter)
            }
            // Fotoğraf değiştirilirken: eski fotoğrafın üstünde.
            if isPreparingMedia, imageData != nil {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.2)
            }
        }
        .preferredColorScheme(.dark)
        // Önizlemede de ses: izleme ekranı gibi sessiz modda da duyulsun.
        .onChange(of: videoPreviewURL) { _, url in
            if url == nil { StoryPlaybackAudio.deactivate() } else { StoryPlaybackAudio.activate() }
        }
        .onDisappear {
            if videoPreviewURL != nil { StoryPlaybackAudio.deactivate() }
        }
    }

    private var storyPreparing: some View {
        VStack(spacing: BondTheme.Space.md) {
            ProgressView()
                .tint(.white)
                .controlSize(.large)
            Text(isPreparingVideo ? L10n.ScreenStates.videoLoading : L10n.ScreenStates.photoLoading)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.15)))
        .padding(.horizontal, BondTheme.Space.lg)
        .accessibilityElement(children: .combine)
        .transition(.opacity)
    }

    private func storyEmptyState(filter: PHPickerFilter) -> some View {
        VStack(spacing: BondTheme.Space.lg) {
            PhotosPicker(selection: $selectedItem, matching: filter) {
                VStack(spacing: BondTheme.Space.sm) {
                    Image(systemName: "photo.badge.plus").font(.system(size: 40, weight: .light))
                    Text(L10n.Composer.pickStoryPhoto).font(.system(size: 17, weight: .semibold))
                    Text(L10n.Composer.storyNeedsPhoto).font(.footnote).foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.15)))
            }
            .buttonStyle(.pressableCard)
            Button(action: openCamera) {
                Label(L10n.Composer.takePhoto, systemImage: "camera")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, BondTheme.Space.lg)
        .disabled(isPreparingMedia || isPublishing)
    }

    /// Alt şerit: not alanı (izleyicideki yazı stiliyle), yer çipi, değiştir/kamera.
    private func storyOverlay(filter: PHPickerFilter) -> some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: BondTheme.Space.md) {
                TextField("", text: $caption, axis: .vertical)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .overlay(alignment: .topLeading) {
                        if caption.isEmpty {
                            RotatingPlaceholder(prompts: hints)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .accessibilityLabel(L10n.Composer.storyPlaceholder)
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 1)
                    .limitShake(trigger: limitBump)
                if counterVisible {
                    CharacterCounter(count: captionLength, limit: captionLimit)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .transition(.opacity)
                }
                HStack(spacing: 8) {
                    Menu {
                        Button(L10n.Composer.noPlace) { selectedPlace = nil }
                        ForEach(appState.places) { place in
                            Button(L10n.Composer.placeOption(place.name, place.area)) { selectedPlace = place }
                        }
                    } label: {
                        storyChip(selectedPlace?.name ?? L10n.Composer.addPlace, icon: "mappin", highlighted: selectedPlace != nil)
                    }
                    Spacer()
                    PhotosPicker(selection: $selectedItem, matching: filter) {
                        // PhotosPicker etiketi Sendable kapanış; view'i dışarıda kur.
                        StoryChipLabel(title: L10n.Composer.changePhoto, icon: "photo.on.rectangle", highlighted: false)
                    }
                    Button(action: openCamera) {
                        Image(systemName: "camera")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.18), in: Circle())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(L10n.Composer.takePhoto)
                }
            }
            .padding(.horizontal, BondTheme.Space.lg)
            .padding(.top, 40)
            .padding(.bottom, BondTheme.Space.lg)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
        }
        .disabled(isPreparingMedia || isPublishing)
    }

    private func storyChip(_ title: String, icon: String, highlighted: Bool) -> some View {
        StoryChipLabel(title: title, icon: icon, highlighted: highlighted)
    }

    private var composerFields: some View {
        Form {
            // Reddit modeli: yazı önde, fotoğraf yanında — her türde. Story'de
            // fotoğraf zorunlu olduğu için orada önce fotoğraf.
            if !isStory {
                captionSection
            }
            Section {
                preview
                if !isStory, !postPhotos.isEmpty {
                    photoStrip
                }
                Button(action: openCamera) {
                    Label(L10n.Composer.takePhoto, systemImage: "camera")
                }
                .disabled(isPreparingMedia || isPublishing || (!isStory && remainingPhotos == 0))
            } footer: {
                if !isStory, !postPhotos.isEmpty {
                    Text(L10n.PostPhotos.footer(CampusLimits.maxPostPhotos))
                }
            }
            if !isStory, imageData != nil {
                Section {
                    Button {
                        addToProfile.toggle()
                    } label: {
                        Label(
                            addToProfile ? L10n.Composer.addedToProfile : L10n.Composer.addToProfile,
                            systemImage: addToProfile ? "checkmark.circle.fill" : "plus.circle"
                        )
                    }
                    .disabled(appState.isGalleryFull || isPublishing || isPreparingMedia)
                    .accessibilityIdentifier("composer.addToProfile")
                    .accessibilityValue(addToProfile ? L10n.Common.on : L10n.Common.off)
                } footer: {
                    Text(appState.isGalleryFull ? L10n.Composer.galleryFull : L10n.Composer.addToProfileFooter)
                }
            }
            if isStory {
                captionSection
            }
            Section {
                Picker(L10n.Composer.addPlace, selection: $selectedPlace) {
                    Text(L10n.Composer.noPlace).tag(CampusPlace?.none)
                    ForEach(appState.places) { place in
                        Text(L10n.Composer.placeOption(place.name, place.area)).tag(Optional(place))
                    }
                }
            }
            if atPostLimit {
                Section {
                    Text(L10n.Composer.postLimit(CampusLimits.maxPostsPerUser))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var captionSection: some View {
        Section {
            VStack(alignment: .trailing, spacing: 6) {
                TextField("", text: $caption, axis: .vertical)
                    .lineLimit(3...8)
                    // Boşken ipucu birkaç saniyede bir değişiyor; tür değişince
                    // o türün ipuçlarına geçiyor.
                    .overlay(alignment: .topLeading) {
                        if caption.isEmpty {
                            RotatingPlaceholder(prompts: hints)
                                .foregroundStyle(Color(uiColor: .placeholderText))
                        }
                    }
                    .accessibilityLabel(isStory ? L10n.Composer.storyPlaceholder : kind.placeholder)
                    .limitShake(trigger: limitBump)
                if counterVisible {
                    CharacterCounter(count: captionLength, limit: captionLimit)
                        .transition(.opacity.combined(with: .scale(scale: 0.7, anchor: .trailing)))
                }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: counterVisible)
        }
    }

    /// Yazı girilince turuncuyla dolan, paylaşırken dönen halkaya, bitince
    /// tike dönüşen düğme.
    private var publishButton: some View {
        Button(action: publish) {
            publishLabel
                .font(.subheadline)
                .foregroundStyle(canPublish || isPublishing || publishDone ? Color.white : Color(uiColor: .secondaryLabel))
                .padding(.horizontal, 16)
                .frame(minWidth: 76, minHeight: 36)
                .background {
                    Capsule().fill(canPublish || isPublishing || publishDone
                                   ? BondTheme.upvote : Color(uiColor: .systemGray5))
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .modifier(PublishButtonMotion(ready: canPublish, isPublishing: isPublishing,
                                      done: publishDone, limitBump: limitBump))
    }

    private var publishLabel: some View {
        ZStack {
            Text(atPostLimit ? L10n.Paywall.goPlus : (isStory ? L10n.Composer.publishStory : L10n.Composer.publishPost))
                .opacity(isPublishing || publishDone ? 0 : 1)
            if isPublishing {
                ProgressView().controlSize(.small).tint(.white)
                    .transition(.opacity)
            }
            if publishDone {
                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .fontWeight(.semibold)
    }

    /// Çip sırası `PostKind?` ister; composer'da nil = rozet seçilmemiş (`.moment`).
    private var kindSelection: Binding<PostKind?> {
        Binding(
            get: { kind == .moment ? nil : kind },
            set: { yeni in
                kind = yeni ?? .moment
                if kind != .moment { showBadgeHint = false }
            }
        )
    }

    /// Fotoğrafa dokununca galeri açılıyor; kamera Form satırında. Gönderide
    /// galeriden birden çok fotoğraf seçilir, yenileri listenin sonuna eklenir.
    @ViewBuilder private var preview: some View {
        // Değerler kapanışa girmeden önce yerel değişkene alınıyor: `PhotosPicker`'ın
        // etiketi Sendable bir kapanış ve oradan doğrudan özellik okumak uyarı üretiyor.
        let currentImage = imageData
        let story = isStory
        let video = videoPreviewURL != nil
        let preparing = isPreparingMedia
        let filter: PHPickerFilter = story ? .any(of: [.images, .videos]) : .images
        let label = ComposerPreview(imageData: currentImage, isStory: story, isVideo: video, isPreparing: preparing)

        Group {
            if story {
                PhotosPicker(selection: $selectedItem, matching: filter) { label }
            } else {
                PhotosPicker(selection: $pickedItems, maxSelectionCount: max(1, remainingPhotos),
                             selectionBehavior: .ordered, matching: .images) { label }
                    .disabled(remainingPhotos == 0)
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(isPreparingMedia || isPublishing)
        .accessibilityLabel(
            imageData == nil
                ? (story ? L10n.Composer.pickStoryPhoto : L10n.Composer.pickFromLibrary)
                : (story ? L10n.Composer.changePhoto : L10n.PostPhotos.add)
        )
        .clipShape(RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous).stroke(BondTheme.hairline))
    }

    private var remainingPhotos: Int { max(0, CampusLimits.maxPostPhotos - postPhotos.count) }

    /// Seçilen fotoğraflar sırayla; dokununca çıkar. Kapak (ilki) önizlemede büyük.
    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(postPhotos.enumerated()), id: \.offset) { index, data in
                    PostPhotoThumb(data: data)
                        .overlay(alignment: .topTrailing) {
                            Button {
                                withAnimation(BondTheme.Motion.snappy) { _ = postPhotos.remove(at: index) }
                                Haptics.selection()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.6))
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L10n.PostPhotos.remove)
                        }
                }
                if remainingPhotos > 0 {
                    PhotosPicker(selection: $pickedItems, maxSelectionCount: remainingPhotos,
                                 selectionBehavior: .ordered, matching: .images) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(BondTheme.ink)
                            .frame(width: 64, height: 64)
                            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityLabel(L10n.PostPhotos.add)
                }
            }
            .padding(.vertical, 2)
        }
        .disabled(isPreparingMedia || isPublishing)
    }

    /// Başarı toast'ı yükleme bitmeden çıkıyordu; kullanıcı kapatınca hata
    /// arkada kalıyordu. Önce sunucuya yazıyoruz, sonra kapatıyoruz.
    private func publish() {
        guard canPublish, !isPublishing else { return }
        // Rozet zorunlu: seçilmemişse gönderme, çiplerin altında el yazısıyla göster.
        if !isStory, kind == .moment {
            showBadgeHint = true
            return
        }
        if atPostLimit {
            appState.quotaHit = .posts
            appState.paywallVisible = true
            dismiss()
            return
        }
        isPublishing = true
        Task {
            let ok: Bool
            if isStory {
                let upload: StoryUpload
                if let videoExport {
                    // Dönüştürme bitmediyse düğme dönerken burada beklenir.
                    guard let clip = try? await videoExport.value else {
                        isPublishing = false
                        appState.show(L10n.Composer.videoLoadFailed)
                        return
                    }
                    upload = .video(fileURL: clip.fileURL, posterJPEG: clip.posterJPEG, duration: clip.duration)
                } else if let imageData {
                    upload = .photo(imageData)
                } else {
                    isPublishing = false
                    return
                }
                ok = await appState.publishStory(upload, caption: cleanCaption, place: selectedPlace)
            } else {
                ok = await appState.publishPost(images: postPhotos, caption: cleanCaption, place: selectedPlace, kind: kind)
                if ok, addToProfile, let imageData {
                    _ = await appState.appendGalleryPhoto(imageData)
                }
            }
            isPublishing = false
            // Düğme bir an tike dönsün; ekran hemen kapanınca paylaşımın gerçekten
            // gittiği hissedilmiyordu.
            if ok, !reduceMotion {
                publishDone = true
                try? await Task.sleep(for: .milliseconds(550))
            }
            if ok || appState.paywallVisible { dismiss() }
        }
    }

    private func consumeCameraPhoto(_ image: UIImage) {
        isPreparingMedia = true
        Task {
            defer { isPreparingMedia = false }
            if let data = await ImageCompression.prepareForUploadInBackground(image) {
                clearVideo()
                if isStory {
                    imageData = data
                } else if postPhotos.count < CampusLimits.maxPostPhotos {
                    postPhotos.append(data)
                }
            } else {
                appState.show(L10n.Composer.photoLoadFailed)
            }
        }
    }

    private func consumeCameraVideo(_ url: URL) {
        Task { await ingestVideoURL(url) }
    }

    private func ingestPickerItem(_ item: PhotosPickerItem) async {
        if isStory, looksLikeVideo(item) {
            await ingestPickedVideo(item)
            return
        }
        // Fotoğraf iCloud'dan inip küçültülürken gösterge açık. Eskiden yalnız
        // videoda açılıyordu; fotoğrafta ekran boş seçme hâline dönüp birkaç
        // saniye hiçbir şey olmuyormuş gibi bekliyordu.
        isPreparingMedia = true
        defer { isPreparingMedia = false }
        let raw = try? await item.loadTransferable(type: Data.self)
        var loaded: Data?
        if let raw { loaded = await ImageCompression.prepareForUploadInBackground(raw) }
        if let loaded {
            await MainActor.run {
                clearVideo()
                imageData = loaded
            }
            return
        }
        if isStory, let movie = try? await item.loadTransferable(type: PickedMovie.self) {
            await ingestVideoURL(movie.url)
            return
        }
        await MainActor.run {
            appState.show(L10n.Composer.photoLoadFailed)
        }
    }

    /// Gönderi: seçilen fotoğraflar sırayla hazırlanıp listenin sonuna eklenir.
    /// Aynı anda hazırlanır; biri açılamazsa diğerleri yine eklenir.
    private func ingestPostItems(_ items: [PhotosPickerItem]) async {
        isPreparingMedia = true
        defer { isPreparingMedia = false; pickedItems = [] }
        let hazir = await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    guard let raw = try? await item.loadTransferable(type: Data.self) else { return (index, nil) }
                    return (index, await ImageCompression.prepareForUploadInBackground(raw))
                }
            }
            var sonuc: [(Int, Data?)] = []
            for await parca in group { sonuc.append(parca) }
            return sonuc.sorted { $0.0 < $1.0 }.compactMap(\.1)
        }
        if hazir.count < items.count { appState.show(L10n.Composer.photoLoadFailed) }
        let yer = max(0, CampusLimits.maxPostPhotos - postPhotos.count)
        withAnimation(BondTheme.Motion.snappy) { postPhotos.append(contentsOf: hazir.prefix(yer)) }
    }

    private func ingestPickedVideo(_ item: PhotosPickerItem) async {
        // Dosya galeriden (gerekirse iCloud'dan) kopyalanırken de gösterge açık.
        await MainActor.run {
            isPreparingMedia = true
            isPreparingVideo = true
        }
        do {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                throw VideoCompression.Failure.empty
            }
            await ingestVideoURL(movie.url)
        } catch {
            await MainActor.run {
                isPreparingMedia = false
                isPreparingVideo = false
                showVideoFailure(error)
            }
        }
    }

    /// Önizleme ilk kare ve süre okununca açılır (anlık). Yüklenecek MP4'e
    /// dönüştürme eskiden önizlemeden önce bekleniyordu; birkaç saniye
    /// "Video hazırlanıyor" kalıyordu. Artık arkada sürüyor.
    private func ingestVideoURL(_ url: URL) async {
        await MainActor.run {
            isPreparingMedia = true
            isPreparingVideo = true
        }
        do {
            let look = try await VideoCompression.quickLook(at: url)
            await MainActor.run {
                clearVideo()
                videoPreviewURL = url
                imageData = look.poster
                isPreparingMedia = false
                isPreparingVideo = false
                let export = Task { try await VideoCompression.prepareStoryClip(from: url) }
                videoExport = export
                Task { await reportExportFailure(export, for: url) }
            }
        } catch {
            try? FileManager.default.removeItem(at: url)
            await MainActor.run {
                isPreparingMedia = false
                isPreparingVideo = false
                showVideoFailure(error)
            }
        }
    }

    /// Dönüştürme başarısız olursa (çok büyük, bozuk) paylaş'ı beklemeden söyle.
    /// Bu arada başka video seçildiyse eski hata gösterilmez.
    private func reportExportFailure(_ export: Task<VideoCompression.PreparedClip, Error>, for url: URL) async {
        guard case .failure(let error) = await export.result else { return }
        await MainActor.run {
            guard videoPreviewURL == url else { return }
            clearVideo()
            imageData = nil
            selectedItem = nil
            showVideoFailure(error)
        }
    }

    private func looksLikeVideo(_ item: PhotosPickerItem) -> Bool {
        let types = item.supportedContentTypes
        let hasMovie = types.contains { $0.conforms(to: .movie) || $0.conforms(to: .video) }
        guard hasMovie else { return false }
        // Canlı fotoğraf hem görsel hem video taşır; story'de fotoğraf kalsın.
        if types.contains(where: { $0.conforms(to: .image) || $0.conforms(to: .livePhoto) }) {
            return false
        }
        return true
    }

    private func showVideoFailure(_ error: Error) {
        if let failure = error as? VideoCompression.Failure, failure == .tooLarge {
            appState.show(L10n.Composer.videoTooLong)
        } else {
            appState.show(L10n.Composer.videoLoadFailed)
        }
    }

    private func clearVideo() {
        if let old = videoPreviewURL {
            try? FileManager.default.removeItem(at: old)
        }
        if let export = videoExport {
            export.cancel()
            Task.detached {
                if let clip = try? await export.value {
                    try? FileManager.default.removeItem(at: clip.fileURL)
                }
            }
        }
        videoPreviewURL = nil
        videoExport = nil
    }
}

/// Galeriden gelen video. `Data` olarak yüklemek dosyayı belleğe yığardı.
private struct PickedMovie: Transferable, Sendable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("bond-pick-\(UUID().uuidString).\(ext)")
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: received.file, to: dest)
            return Self(url: dest)
        }
    }
}

/// Kart fotoğrafı ekranı da kullanıyor (CardPhotoComposer).
struct CameraPicker: UIViewControllerRepresentable {
    var allowsVideo: Bool
    let onImage: (UIImage) -> Void
    let onVideo: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        if allowsVideo {
            picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
            picker.videoMaximumDuration = CampusStory.maxVideoDuration
            picker.videoQuality = .typeHigh
            picker.cameraCaptureMode = .photo
        } else {
            picker.mediaTypes = [UTType.image.identifier]
            picker.cameraCaptureMode = .photo
        }
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            } else if let url = info[.mediaURL] as? URL {
                let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent("bond-cam-\(UUID().uuidString).\(ext)")
                try? FileManager.default.copyItem(at: url, to: dest)
                parent.onVideo(FileManager.default.fileExists(atPath: dest.path) ? dest : url)
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

/// Fotoğraf seçilmeden önceki alan. Ayrı bir `View`: `PhotosPicker`'ın etiketi
/// farklı bir aktör bağlamında değerlendiriliyor ve oradan `CreatePostView`'ın
/// metotları çağrılamıyor.
/// Önizlemenin tamamı ayrı bir `View`.
///
/// `PhotosPicker`'ın etiketi farklı bir aktör bağlamında değerlendiriliyor; oradan
/// `CreatePostView`'ın özelliklerine erişmek uyarı üretiyordu.
private struct ComposerPreview: View {
    let imageData: Data?
    let isStory: Bool
    var isVideo: Bool = false
    var isPreparing: Bool = false
    @State private var preview: UIImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Uç oranlar sınırlanıyor: panorama şeride, çok uzun ekran görüntüsü de bütün
    /// ekranı kaplayan bir sütuna dönüşmesin. Üst sınır 1.34, çünkü telefonun kendi
    /// 4:3 dikey fotoğrafı hiç kırpılmadan sığmalı.
    private func height(for size: CGSize) -> CGFloat {
        guard size.width > 0 else { return 260 }
        let width = UIScreen.main.bounds.width - BondTheme.Space.lg * 2
        return width * min(max(size.height / size.width, 0.524), 1.34)
    }

    private var previewID: String {
        guard let imageData else { return "empty" }
        return "\(imageData.count)-\(imageData.first ?? 0)-\(imageData.last ?? 0)"
    }

    var body: some View {
        ZStack {
            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: height(for: preview.size))
                    .clipped()
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .overlay {
                        if isVideo {
                            Image(systemName: "play.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(.black.opacity(0.42), in: Circle())
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous)
                    .fill(BondTheme.surface)
                    .frame(height: 260)
                    .overlay {
                        VStack(spacing: BondTheme.Space.sm) {
                            Image(systemName: "photo.badge.plus").font(.system(size: 32, weight: .light))
                            Text(isStory ? L10n.Composer.pickStoryPhoto : L10n.Composer.addPhoto)
                                .font(.system(size: 16, weight: .semibold))
                            Text(isStory ? L10n.Composer.storyNeedsPhoto : L10n.Composer.textOnlyOk)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(BondTheme.ink)
                    }
            }

            if isPreparing {
                Color.black.opacity(0.35)
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.15)
            }
        }
        .onChange(of: previewID, initial: true) { eski, id in
            let yeni = (imageData != nil && id != "empty") ? imageData.flatMap { ImageCompression.imageForDisplay($0) } : nil
            // İlk açılışta hareket yok; sonradan seçilen fotoğraf küçükten büyüyerek oturur.
            withAnimation(eski == id || reduceMotion ? nil : BondTheme.Motion.bouncy) { preview = yeni }
        }
    }
}

/// Şeritteki küçük kare. Küçültme arka planda: altı büyük fotoğrafı ana iş
/// parçacığında çözmek şeridi takılarak açıyordu.
private struct PostPhotoThumb: View {
    let data: Data
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            BondTheme.surface
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: data.count) {
            let veri = data
            image = await Task.detached(priority: .userInitiated) {
                ImageCompression.imageForDisplay(veri, maxDimension: 200)
            }.value
        }
    }
}

private struct StoryChipLabel: View {
    let title: String
    let icon: String
    let highlighted: Bool
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            Text(title).font(.footnote.weight(.semibold)).lineLimit(1)
        }
        .foregroundStyle(highlighted ? .black : .white)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(highlighted ? Color.white : Color.white.opacity(0.18), in: Capsule())
    }
}

/// Paylaş düğmesinin durum geçişleri: hazır olunca, paylaşırken ve bitince.
private struct PublishButtonMotion: ViewModifier {
    let ready: Bool
    let isPublishing: Bool
    let done: Bool
    let limitBump: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .disabled(!ready || isPublishing || done)
            .animation(reduceMotion ? nil : BondTheme.Motion.bouncy, value: ready)
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isPublishing)
            .animation(reduceMotion ? nil : BondTheme.Motion.bouncy, value: done)
            .sensoryFeedback(.warning, trigger: limitBump)
    }
}
