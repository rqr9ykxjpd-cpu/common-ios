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
    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var videoClip: VideoCompression.PreparedClip?
    @State private var caption = ""
    @State private var selectedPlace: CampusPlace?
    @State private var showCamera = false
    @State private var showCameraUnavailable = false
    @State private var showCameraDenied = false
    @State private var isPublishing = false
    @State private var isPreparingMedia = false
    @State private var myPostCount = 0

    init(initialContentType: Int = 0) {
        _contentType = State(initialValue: ComposerContentType(rawValue: initialContentType) ?? .post)
    }

    private var isStory: Bool { contentType == .story }
    private var cleanCaption: String { caption.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var atPostLimit: Bool {
        guard !isStory, let cap = appState.tier.maxPosts else { return false }
        return myPostCount >= cap
    }
    private var canPublish: Bool {
        guard !isPreparingMedia else { return false }
        if atPostLimit { return true }
        return isStory ? imageData != nil : (imageData != nil || !cleanCaption.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (isStory ? Color.black : BondTheme.paper).ignoresSafeArea()
                ScrollView {
                    // Önceden beş bölüm vardı ve dördü (Kamera, Galeri, açıklama, yer)
                    // birebir aynı yuvarlak kutuydu — hiçbiri öne çıkmıyordu. Ayrıca
                    // tür seçici en alttaydı: ne paylaştığını yazdıktan SONRA seçiyordun,
                    // oysa tür ekranın tamamını değiştiriyor.
                    VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                        turSecici       // ne paylaştığın: ekranın tamamını değiştiriyor
                        preview         // fotoğraf / story videosu: ekranın kahramanı
                        captionField    // kutusuz, doğrudan sayfada
                        placeChip       // küçük bir ayrıntı, tam genişlik kutu değil
                        if atPostLimit {
                            Text(L10n.Composer.postLimit(CampusLimits.maxPostsPerUser))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(BondTheme.muted)
                        }
                    }
                    .padding(.horizontal, BondTheme.Space.lg)
                    .padding(.top, BondTheme.Space.sm)
                    .padding(.bottom, 120)
                }
            }
            .foregroundStyle(isStory ? .white : BondTheme.ink)
            .scrollDismissesKeyboard(.interactively)
            .dismissesKeyboardOnTap()
            .keyboardDoneButton()
            .navigationTitle(isStory ? L10n.Composer.shareStory : L10n.Composer.sharePost)
            .navigationBarTitleDisplayMode(.inline)
            // Story modunda zemin siyah; bar'ı elle boyamak yerine sisteme
            // hangi şemada olduğunu söylüyoruz, materyalini ona göre seçiyor.
            .toolbarColorScheme(isStory ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.close) { dismiss() }
                        .disabled(isPublishing || isPreparingMedia)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomControls }
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
                if type == .post, videoClip != nil {
                    clearVideo()
                    imageData = nil
                    selectedItem = nil
                }
            }
            .task {
                myPostCount = await appState.countMyPosts()
            }
        }
        // Story her zaman koyu zeminde; normal gönderi ekranı kullanıcının seçtiği görünümü izler.
        .preferredColorScheme(isStory ? .dark : nil)
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

    /// Kapatma ve tür seçimi. Tür yukarıda, çünkü ekranın tamamını o belirliyor:
    /// story koyu zeminde ve fotoğraf zorunlu, gönderi açık zeminde ve metin yeterli.
    /// Kapat düğmesi native bar'a taşındı; burada yalnızca tür seçici kaldı.
    private var turSecici: some View {
        HStack(spacing: BondTheme.Space.md) {
            HStack(spacing: 4) {
                ForEach(ComposerContentType.allCases) { type in
                    Button {
                        withAnimation(.snappy) { contentType = type }
                        Haptics.selection()
                    } label: {
                        Text(type.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(contentType == type ? BondTheme.ink : (isStory ? .white.opacity(0.65) : BondTheme.muted))
                            .frame(maxWidth: .infinity).frame(height: 36)
                            .background(contentType == type ? BondTheme.paper : .clear, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(3)
            .background(controlBackground, in: Capsule())
            .overlay(Capsule().stroke(controlStroke))
            .frame(maxWidth: 220)

            Spacer(minLength: 0)
        }
    }

    /// Fotoğraf ekranın kahramanı: dokununca galeri açılıyor, köşedeki küçük düğme
    /// kamerayı açıyor. Önceden altta iki ayrı tam genişlik düğme vardı ("Kamera",
    /// "Galeri") ve fotoğraf seçildikten sonra da yer kaplamaya devam ediyorlardı.
    private var preview: some View {
        // Değerler kapanışa girmeden önce yerel değişkene alınıyor: `PhotosPicker`'ın
        // etiketi Sendable bir kapanış ve oradan doğrudan özellik okumak uyarı üretiyor.
        let currentImage = imageData
        let story = isStory
        let background = controlBackground
        let video = videoClip != nil
        let preparing = isPreparingMedia
        let filter: PHPickerFilter = story ? .any(of: [.images, .videos]) : .images

        return ZStack(alignment: .bottomTrailing) {
            PhotosPicker(selection: $selectedItem, matching: filter) {
                ComposerPreview(
                    imageData: currentImage,
                    isStory: story,
                    background: background,
                    isVideo: video,
                    isPreparing: preparing
                )
            }
            .buttonStyle(PressableStyle())
            .disabled(isPreparingMedia || isPublishing)
            .accessibilityLabel(
                imageData == nil
                    ? (story ? L10n.Composer.pickStoryPhoto : L10n.Composer.pickFromLibrary)
                    : L10n.Composer.changePhoto
            )

            Button(action: openCamera) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BondTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(BondTheme.paper, in: Circle())
                    .overlay(Circle().stroke(BondTheme.ink.opacity(0.12)))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            }
            .buttonStyle(PressableStyle())
            .disabled(isPreparingMedia || isPublishing)
            .padding(14)
            .accessibilityLabel(L10n.Composer.takePhoto)
        }
        .clipShape(RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous).stroke(controlStroke))
        .animation(.snappy, value: contentType)
    }


    /// Kutusuz. Önceden çerçeveli bir kutuydu ve altındaki "yer" kutusuyla,
    /// üstündeki kaynak düğmeleriyle aynı görünüyordu; hangisinin asıl alan olduğu
    /// anlaşılmıyordu. Yazı doğrudan sayfada.
    private var captionField: some View {
        // İpucu metnini sistemin varsayılanına bırakmıyoruz: story modunda zemin
        // siyah ve varsayılan gri neredeyse okunmuyordu.
        TextField("", text: $caption, axis: .vertical)
            .font(.system(size: 17))
            .lineSpacing(3)
            .lineLimit(3...8)
            .textFieldStyle(.plain)
            .padding(.horizontal, 2)
            .overlay(alignment: .topLeading) {
                if caption.isEmpty {
                    Text(isStory ? L10n.Composer.storyPlaceholder : L10n.Composer.postPlaceholder)
                        .font(.system(size: 17))
                        .foregroundStyle(isStory ? .white.opacity(0.55) : BondTheme.muted)
                        .padding(.horizontal, 2)
                        .allowsHitTesting(false)
                }
            }
    }

    /// Küçük bir çip. Yer isteğe bağlı bir ayrıntı; tam genişlik bir kutuyu hak etmiyor.
    private var placeChip: some View {
        Menu {
            Button(L10n.Composer.noPlace) { selectedPlace = nil }
            ForEach(appState.places) { place in
                Button(L10n.Composer.placeOption(place.name, place.area)) { selectedPlace = place }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedPlace == nil ? "mappin" : "mappin.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(selectedPlace?.name ?? L10n.Composer.addPlace)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(selectedPlace == nil ? (isStory ? .white.opacity(0.7) : BondTheme.muted) : BondTheme.violet)
            .padding(.horizontal, 13)
            .frame(height: 38)
            .background(controlBackground, in: Capsule())
            .overlay(Capsule().stroke(controlStroke))
        }
    }

    private var bottomControls: some View {
        // Tür seçici yukarı taşındı; burada yalnızca asıl eylem kalıyor.
        AppButton(
            title: isPublishing
                ? L10n.Common.sending
                : (atPostLimit
                   ? L10n.Paywall.goPlus
                   : (isStory ? L10n.Composer.publishStory : L10n.Composer.publishPost)),
            systemName: isPublishing ? nil : (atPostLimit ? "lock.fill" : "arrow.up"),
            role: isStory ? .accent : .primary,
            enabled: canPublish && !isPublishing
        ) { publish() }
        .padding(.horizontal, BondTheme.Space.lg)
        .padding(.top, BondTheme.Space.md)
        .padding(.bottom, BondTheme.Space.sm)
        .background(.ultraThinMaterial)
    }

    private var controlBackground: Color { isStory ? .white.opacity(0.11) : BondTheme.surface }
    private var controlStroke: Color { isStory ? .white.opacity(0.18) : BondTheme.hairline }

    /// Başarı toast'ı yükleme bitmeden çıkıyordu; kullanıcı kapatınca hata
    /// arkada kalıyordu. Önce sunucuya yazıyoruz, sonra kapatıyoruz.
    private func publish() {
        guard canPublish, !isPublishing else { return }
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
                if let videoClip {
                    upload = .video(
                        fileURL: videoClip.fileURL,
                        posterJPEG: videoClip.posterJPEG,
                        duration: videoClip.duration
                    )
                } else if let imageData {
                    upload = .photo(imageData)
                } else {
                    isPublishing = false
                    return
                }
                ok = await appState.publishStory(upload, caption: cleanCaption, place: selectedPlace)
            } else {
                ok = await appState.publishPost(imageData: imageData, caption: cleanCaption, place: selectedPlace)
            }
            isPublishing = false
            if ok || appState.paywallVisible { dismiss() }
        }
    }

    private func consumeCameraPhoto(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.9).flatMap(ImageCompression.prepareForUpload) {
            clearVideo()
            imageData = data
        } else {
            appState.show(L10n.Composer.photoLoadFailed)
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
        let raw = try? await item.loadTransferable(type: Data.self)
        let loaded = raw.flatMap(ImageCompression.prepareForUpload)
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

    private func ingestPickedVideo(_ item: PhotosPickerItem) async {
        do {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                throw VideoCompression.Failure.empty
            }
            await ingestVideoURL(movie.url)
        } catch {
            await MainActor.run { showVideoFailure(error) }
        }
    }

    private func ingestVideoURL(_ url: URL) async {
        await MainActor.run { isPreparingMedia = true }
        do {
            let prepared = try await VideoCompression.prepareStoryClip(from: url)
            await MainActor.run {
                clearVideo()
                videoClip = prepared
                imageData = prepared.posterJPEG
                isPreparingMedia = false
            }
        } catch {
            await MainActor.run {
                isPreparingMedia = false
                showVideoFailure(error)
            }
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
        if let old = videoClip {
            try? FileManager.default.removeItem(at: old.fileURL)
        }
        videoClip = nil
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

private struct CameraPicker: UIViewControllerRepresentable {
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
    let background: Color
    var isVideo: Bool = false
    var isPreparing: Bool = false

    /// Uç oranlar sınırlanıyor: panorama şeride, çok uzun ekran görüntüsü de bütün
    /// ekranı kaplayan bir sütuna dönüşmesin. Üst sınır 1.34, çünkü telefonun kendi
    /// 4:3 dikey fotoğrafı hiç kırpılmadan sığmalı.
    private func height(for size: CGSize) -> CGFloat {
        guard size.width > 0 else { return 260 }
        let width = UIScreen.main.bounds.width - BondTheme.Space.lg * 2
        return width * min(max(size.height / size.width, 0.524), 1.34)
    }

    var body: some View {
        ZStack {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: height(for: image.size))
                    .clipped()
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
                    .fill(background)
                    .frame(height: isStory ? 420 : 260)
                    .overlay {
                        VStack(spacing: BondTheme.Space.sm) {
                            Image(systemName: isStory ? "photo.badge.plus" : "photo.badge.plus").font(.system(size: 32, weight: .light))
                            Text(isStory ? L10n.Composer.pickStoryPhoto : L10n.Composer.addPhoto)
                                .font(.system(size: 16, weight: .semibold))
                            Text(isStory ? L10n.Composer.storyNeedsPhoto : L10n.Composer.textOnlyOk)
                                .font(.system(size: 12)).opacity(0.55)
                        }
                        .foregroundStyle(isStory ? .white : BondTheme.ink)
                    }
            }

            if isPreparing {
                Color.black.opacity(0.35)
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.15)
            }
        }
    }
}
