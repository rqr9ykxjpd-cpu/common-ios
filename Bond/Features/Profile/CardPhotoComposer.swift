import AVFoundation
import PhotosUI
import SwiftUI

/// Yalnız karta fotoğraf: akışa düşmez, yalnızca kartını açanlar görür.
///
/// Eskiden bunun tek yolu profil düzenleme ekranının içindeydi; artıdaki
/// "Kartlara ekle" ise fotoğrafı akışta da paylaşıyordu. Artı menüsünden ve
/// profilin fotoğraf bölümünden açılıyor. Önizleme kartın kendi destesi:
/// yeni fotoğraf, karta ekleneceği yerde (sonda) açık duruyor; sırayı
/// "Düzenle" değiştiriyor.
struct CardPhotoComposer: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isPreparing = false
    @State private var showCamera = false
    @State private var showCameraDenied = false
    /// Yükleme sürerken seçim, kamera ve kapatma kilitli.
    @State private var isAdding = false
    /// Her yeni seçimde artar; deste baştan kurulur ve yeni fotoğraf önde açılır.
    /// Yoksa destede başka fotoğrafa geçilmişse yeni seçilen arkada kalıyordu.
    @State private var pickCount = 0

    private var existing: [ProfileGalleryPhoto] {
        if !appState.galleryURLs.isEmpty { return ProfileGalleryPhoto.remote(appState.galleryURLs) }
        return appState.profileGalleryData.enumerated().map { index, data in
            ProfileGalleryPhoto(id: "local-gallery-\(index)", url: nil, data: data, assetName: nil)
        }
    }

    /// Sunucu yeni fotoğrafı sona ekliyor; önizleme de öyle gösteriyor.
    /// Önceki hâli yeni fotoğrafı öne koyuyordu, kartta ise sonda çıkıyordu.
    private var preview: [ProfileGalleryPhoto] {
        guard let imageData else { return existing }
        return existing + [ProfileGalleryPhoto(id: "card-photo-new", url: nil, data: imageData, assetName: nil)]
    }

    private var isFull: Bool { appState.isGalleryFull }
    private var shownCount: Int { min(appState.galleryCount + (imageData == nil ? 0 : 1), CampusLimits.maxGalleryPhotos) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: BondTheme.Space.lg) {
                        Label(L10n.CardStudio.photoNote, systemImage: "rectangle.stack")
                            .font(BondTheme.Typography.footnote)
                            .foregroundStyle(BondTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if preview.isEmpty {
                            emptyPicker
                        } else {
                            ProfileGalleryStack(photos: preview, height: 380,
                                                startAt: imageData == nil ? 0 : preview.count - 1)
                                .id(pickCount)
                                .transition(.opacity)
                        }

                        if !preview.isEmpty, !isFull { sourceButtons }

                        Text(isFull ? L10n.Composer.galleryFull
                                    : L10n.CardStudio.photoCount(shownCount, CampusLimits.maxGalleryPhotos))
                            .font(BondTheme.Typography.footnote.weight(.medium))
                            .foregroundStyle(isFull ? BondTheme.burntOrangeText : BondTheme.muted)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, BondTheme.Space.lg)
                    .padding(.top, BondTheme.Space.sm)
                    .padding(.bottom, BondTheme.Space.xl)
                }

                PrimaryActionButton(
                    title: L10n.CardStudio.photoAdd,
                    enabled: imageData != nil && !isFull && !isPreparing && !isAdding
                ) {
                    guard let imageData else { return false }
                    isAdding = true
                    let ok = await appState.appendGalleryPhoto(imageData)
                    if !ok { isAdding = false }
                    return ok
                } onDone: {
                    appState.show(L10n.CardStudio.photoAdded)
                    dismiss()
                }
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.bottom, BondTheme.Space.sm)
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .foregroundStyle(BondTheme.ink)
            .navigationTitle(L10n.CardStudio.photoTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.close) { dismiss() }
                        .disabled(isAdding)
                }
            }
            .interactiveDismissDisabled(isAdding)
            .overlay {
                if isPreparing { ProgressView().controlSize(.large) }
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task { await ingest(item) }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(allowsVideo: false, onImage: ingestCamera, onVideo: { _ in })
                    .ignoresSafeArea()
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
        }
    }

    /// Kartta hiç fotoğraf yokken: destenin yerinde büyük bir seçim alanı.
    private var emptyPicker: some View {
        VStack(spacing: BondTheme.Space.md) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                VStack(spacing: BondTheme.Space.sm) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 36, weight: .light))
                    Text(L10n.CardStudio.photoPick)
                        .font(BondTheme.Typography.body.weight(.semibold))
                }
                .foregroundStyle(BondTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous)
                        .strokeBorder(BondTheme.hairline, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                }
            }
            .buttonStyle(.pressableCard)
            cameraButton
        }
        .disabled(isPreparing)
    }

    private var sourceButtons: some View {
        HStack(spacing: BondTheme.Space.sm) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label(imageData == nil ? L10n.CardStudio.photoPick : L10n.CardStudio.photoChange,
                      systemImage: "photo.on.rectangle")
                    .font(BondTheme.Typography.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.secondaryCapsule)
            cameraButton
        }
        .disabled(isAdding || isPreparing)
    }

    private var cameraButton: some View {
        Button(action: openCamera) {
            Label(L10n.Composer.takePhoto, systemImage: "camera")
                .font(BondTheme.Typography.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.secondaryCapsule)
    }

    private func ingest(_ item: PhotosPickerItem) async {
        isPreparing = true
        defer {
            isPreparing = false
            // Aynı fotoğraf yeniden seçilebilsin; seçici aynı seçimi değişiklik saymıyor.
            selectedItem = nil
        }
        let raw = try? await item.loadTransferable(type: Data.self)
        if let data = raw.flatMap(ImageCompression.prepareForUpload) {
            show(data)
        } else {
            appState.show(L10n.Composer.photoLoadFailed)
        }
    }

    private func show(_ data: Data) {
        withAnimation(BondTheme.Motion.smooth) {
            imageData = data
            pickCount += 1
        }
        Haptics.selection()
    }

    private func ingestCamera(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.9).flatMap(ImageCompression.prepareForUpload) {
            show(data)
        } else {
            appState.show(L10n.Composer.photoLoadFailed)
        }
    }

    /// İzin reddedildiyse boş kamera açılmasın, Ayarlar'a yol çıksın.
    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            appState.show(L10n.Composer.cameraUnavailable)
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showCamera = true } else { showCameraDenied = true }
                }
            }
        default:
            showCameraDenied = true
        }
    }
}
