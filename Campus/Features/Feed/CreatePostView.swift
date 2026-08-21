import SwiftUI
import PhotosUI
import UIKit

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
    @State private var caption = ""
    @State private var selectedPlace: CampusPlace?
    @State private var showCamera = false
    @State private var showCameraUnavailable = false

    init(initialContentType: Int = 0) {
        _contentType = State(initialValue: ComposerContentType(rawValue: initialContentType) ?? .post)
    }

    private var isStory: Bool { contentType == .story }
    private var cleanCaption: String { caption.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canPublish: Bool { isStory ? imageData != nil : (imageData != nil || !cleanCaption.isEmpty) }

    var body: some View {
        NavigationStack {
            ZStack {
                (isStory ? Color.black : CampusTheme.paper).ignoresSafeArea()
                ScrollView {
                    // Önceden beş bölüm vardı ve dördü (Kamera, Galeri, açıklama, yer)
                    // birebir aynı yuvarlak kutuydu — hiçbiri öne çıkmıyordu. Ayrıca
                    // tür seçici en alttaydı: ne paylaştığını yazdıktan SONRA seçiyordun,
                    // oysa tür ekranın tamamını değiştiriyor.
                    VStack(alignment: .leading, spacing: CampusTheme.Space.lg) {
                        turSecici       // ne paylaştığın: ekranın tamamını değiştiriyor
                        preview         // fotoğraf: ekranın kahramanı
                        captionField    // kutusuz, doğrudan sayfada
                        placeChip       // küçük bir ayrıntı, tam genişlik kutu değil
                    }
                    .padding(.horizontal, CampusTheme.Space.lg)
                    .padding(.top, CampusTheme.Space.sm)
                    .padding(.bottom, 120)
                }
            }
            .foregroundStyle(isStory ? .white : CampusTheme.ink)
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
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomControls }
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in imageData = image.jpegData(compressionQuality: 0.9).flatMap(ImageCompression.prepareForUpload) }
                    .ignoresSafeArea()
            }
            .alert(L10n.Composer.cameraUnavailable, isPresented: $showCameraUnavailable) {
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(L10n.Composer.cameraUnavailableBody)
            }
            .onChange(of: selectedItem) { _, item in
                Task {
                    let raw = try? await item?.loadTransferable(type: Data.self)
                    let loaded = raw.flatMap(ImageCompression.prepareForUpload)
                    await MainActor.run { imageData = loaded }
                }
            }
        }
        // Story her zaman koyu zeminde; normal gönderi ekranı kullanıcının seçtiği görünümü izler.
        .preferredColorScheme(isStory ? .dark : nil)
    }

    /// Kapatma ve tür seçimi. Tür yukarıda, çünkü ekranın tamamını o belirliyor:
    /// story koyu zeminde ve fotoğraf zorunlu, gönderi açık zeminde ve metin yeterli.
    /// Kapat düğmesi native bar'a taşındı; burada yalnızca tür seçici kaldı.
    private var turSecici: some View {
        HStack(spacing: CampusTheme.Space.md) {
            HStack(spacing: 4) {
                ForEach(ComposerContentType.allCases) { type in
                    Button {
                        withAnimation(.snappy) { contentType = type }
                        Haptics.selection()
                    } label: {
                        Text(type.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(contentType == type ? CampusTheme.ink : (isStory ? .white.opacity(0.65) : CampusTheme.muted))
                            .frame(maxWidth: .infinity).frame(height: 36)
                            .background(contentType == type ? CampusTheme.paper : .clear, in: Capsule())
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

        return ZStack(alignment: .bottomTrailing) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                ComposerPreview(imageData: currentImage, isStory: story, background: background)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(imageData == nil ? L10n.Composer.pickFromLibrary : L10n.Composer.changePhoto)

            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true }
                else { showCameraUnavailable = true }
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CampusTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(CampusTheme.paper, in: Circle())
                    .overlay(Circle().stroke(CampusTheme.ink.opacity(0.12)))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            }
            .buttonStyle(PressableStyle())
            .padding(14)
            .accessibilityLabel(L10n.Composer.takePhoto)
        }
        .clipShape(RoundedRectangle(cornerRadius: CampusTheme.Radius.hero, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.hero, style: .continuous).stroke(controlStroke))
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
                        .foregroundStyle(isStory ? .white.opacity(0.55) : CampusTheme.muted)
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
            .foregroundStyle(selectedPlace == nil ? (isStory ? .white.opacity(0.7) : CampusTheme.muted) : CampusTheme.violet)
            .padding(.horizontal, 13)
            .frame(height: 38)
            .background(controlBackground, in: Capsule())
            .overlay(Capsule().stroke(controlStroke))
        }
    }

    private var bottomControls: some View {
        // Tür seçici yukarı taşındı; burada yalnızca asıl eylem kalıyor.
        AppButton(
            title: isStory ? L10n.Composer.publishStory : L10n.Composer.publishPost,
            systemName: "arrow.up",
            role: isStory ? .accent : .primary,
            enabled: canPublish
        ) { publish() }
        .padding(.horizontal, CampusTheme.Space.lg)
        .padding(.top, CampusTheme.Space.md)
        .padding(.bottom, CampusTheme.Space.sm)
        .background(.ultraThinMaterial)
    }

    private var controlBackground: Color { isStory ? .white.opacity(0.11) : CampusTheme.surface }
    private var controlStroke: Color { isStory ? .white.opacity(0.18) : CampusTheme.hairline }

    private func publish() {
        guard canPublish else { return }
        if isStory {
            guard let imageData else { return }
            appState.publishStory(imageData: imageData, caption: cleanCaption, place: selectedPlace)
            appState.show(L10n.Composer.storyShared)
        } else {
            appState.publishPost(imageData: imageData, caption: cleanCaption, place: selectedPlace)
            appState.show(L10n.Composer.postShared)
        }
        dismiss()
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
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

    /// Uç oranlar sınırlanıyor: panorama şeride, çok uzun ekran görüntüsü de bütün
    /// ekranı kaplayan bir sütuna dönüşmesin. Üst sınır 1.34, çünkü telefonun kendi
    /// 4:3 dikey fotoğrafı hiç kırpılmadan sığmalı.
    private func height(for size: CGSize) -> CGFloat {
        guard size.width > 0 else { return 260 }
        let width = UIScreen.main.bounds.width - CampusTheme.Space.lg * 2
        return width * min(max(size.height / size.width, 0.524), 1.34)
    }

    var body: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: height(for: image.size))
                .clipped()
        } else {
            RoundedRectangle(cornerRadius: CampusTheme.Radius.hero, style: .continuous)
                .fill(background)
                .frame(height: isStory ? 420 : 260)
                .overlay {
                    VStack(spacing: CampusTheme.Space.sm) {
                        Image(systemName: "photo.badge.plus").font(.system(size: 32, weight: .light))
                        Text(isStory ? L10n.Composer.pickStoryPhoto : L10n.Composer.addPhoto)
                            .font(.system(size: 16, weight: .semibold))
                        Text(isStory ? L10n.Composer.storyNeedsPhoto : L10n.Composer.textOnlyOk)
                            .font(.system(size: 12)).opacity(0.55)
                    }
                    .foregroundStyle(isStory ? .white : CampusTheme.ink)
                }
        }
    }
}
