import SwiftUI
import PhotosUI
import UIKit

enum ComposerContentType: Int, CaseIterable, Identifiable {
    case post
    case story

    var id: Int { rawValue }
    var title: String { self == .post ? "Gönderi" : "Story" }
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
                    VStack(alignment: .leading, spacing: CampusTheme.Space.lg) {
                        header
                        preview
                        sourceControls
                        captionField
                        placeMenu
                    }
                    .padding(.horizontal, CampusTheme.Space.lg)
                    .padding(.top, CampusTheme.Space.sm)
                    .padding(.bottom, 128)
                }
            }
            .foregroundStyle(isStory ? .white : CampusTheme.ink)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomControls }
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in imageData = image.jpegData(compressionQuality: 0.9).flatMap(ImageCompression.prepareForUpload) }
                    .ignoresSafeArea()
            }
            .alert("Kamera kullanılamıyor", isPresented: $showCameraUnavailable) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text("Bu cihazda kamera bulunamadı. Galeriden bir fotoğraf seçebilirsin.")
            }
            .onChange(of: selectedItem) { _, item in
                Task {
                    let raw = try? await item?.loadTransferable(type: Data.self)
                    let loaded = raw.flatMap(ImageCompression.prepareForUpload)
                    await MainActor.run { imageData = loaded }
                }
            }
        }
        .preferredColorScheme(isStory ? .dark : .light)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Paylaş").font(.system(size: 28, weight: .bold, design: .rounded))
                Text(isStory ? "24 saat görünür" : "YÜ akışında yayınlanır")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(isStory ? .white.opacity(0.58) : CampusTheme.muted)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                    .frame(width: 44, height: 44).background(controlBackground, in: Circle())
            }.buttonStyle(PressableStyle())
        }
    }

    private var preview: some View {
        ZStack {
            if let imageData {
                ProfileMedia(url: nil, data: imageData)
                    .frame(maxWidth: .infinity).frame(height: isStory ? 470 : 280).clipped()
            } else if isStory {
                emptyMediaPreview(height: 470)
            } else {
                VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
                    Label("METİN GÖNDERİSİ", systemImage: "text.alignleft")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(CampusTheme.violet)
                    Text(cleanCaption.isEmpty ? "Aklından geçenleri kampüsle paylaş." : cleanCaption)
                        .font(.system(size: cleanCaption.isEmpty ? 22 : 25, weight: .bold, design: .rounded))
                        .foregroundStyle(cleanCaption.isEmpty ? CampusTheme.muted : CampusTheme.ink)
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                    Text("Fotoğraf eklemek isteğe bağlı")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(CampusTheme.muted)
                }
                .padding(CampusTheme.Space.xl)
                .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
                .background(CampusTheme.acid.opacity(0.3))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CampusTheme.Radius.hero, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.hero).stroke(controlStroke))
        .animation(.snappy, value: contentType)
    }

    private func emptyMediaPreview(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: CampusTheme.Radius.hero, style: .continuous)
            .fill(controlBackground).frame(height: height)
            .overlay {
                VStack(spacing: CampusTheme.Space.md) {
                    Image(systemName: "photo.badge.plus").font(.system(size: 36, weight: .light))
                    Text("Bir fotoğraf ekle").font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text("Kamerayı kullan veya galerinden seç").font(.system(size: 13, design: .rounded)).opacity(0.58)
                }
            }
    }

    private var sourceControls: some View {
        let background = isStory ? Color.white.opacity(0.11) : CampusTheme.surface
        let stroke = isStory ? Color.white.opacity(0.18) : CampusTheme.hairline

        return HStack(spacing: CampusTheme.Space.md) {
            sourceButton(title: "Kamera", systemName: "camera.fill") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true }
                else { showCameraUnavailable = true }
            }
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Galeri", systemImage: "photo.on.rectangle")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(background, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.control))
                    .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.control).stroke(stroke))
            }.buttonStyle(PressableStyle())
        }
    }

    private func sourceButton(title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(controlBackground, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.control))
                .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.control).stroke(controlStroke))
        }.buttonStyle(PressableStyle())
    }

    private var captionField: some View {
        TextField(isStory ? "Story'e kısa bir not ekle..." : "Bu an hakkında bir şey söyle...", text: $caption, axis: .vertical)
            .font(.system(size: 15, design: .rounded)).lineLimit(2...5).padding(CampusTheme.Space.lg)
            .background(controlBackground, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.control))
            .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.control).stroke(controlStroke))
    }

    private var placeMenu: some View {
        Menu {
            Button("Yer ekleme") { selectedPlace = nil }
            ForEach(appState.places) { place in
                Button("\(place.name) · \(place.area)") { selectedPlace = place }
            }
        } label: {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                Text(selectedPlace?.name ?? "Yer ekle").font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer(); Image(systemName: "chevron.down")
            }
            .padding(.horizontal, CampusTheme.Space.lg).frame(height: 48)
            .background(controlBackground, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.control))
            .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.control).stroke(controlStroke))
        }
    }

    private var bottomControls: some View {
        VStack(spacing: CampusTheme.Space.md) {
            HStack(spacing: CampusTheme.Space.sm) {
                ForEach(ComposerContentType.allCases) { type in
                    Button {
                        withAnimation(.snappy) { contentType = type }
                        Haptics.selection()
                    } label: {
                        Label(type.title, systemImage: type.systemName)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(contentType == type ? CampusTheme.ink : (isStory ? .white.opacity(0.68) : CampusTheme.muted))
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(contentType == type ? CampusTheme.acid : .clear, in: Capsule())
                    }.buttonStyle(PressableStyle())
                }
            }
            .padding(4).background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(isStory ? 0.2 : 0.55)))

            AppButton(title: isStory ? "Story'yi paylaş" : "Gönderiyi paylaş", systemName: "arrow.up", role: isStory ? .accent : .primary, enabled: canPublish) { publish() }
        }
        .padding(.horizontal, CampusTheme.Space.lg).padding(.top, CampusTheme.Space.md).padding(.bottom, CampusTheme.Space.sm)
        .background(.ultraThinMaterial)
    }

    private var controlBackground: Color { isStory ? .white.opacity(0.11) : CampusTheme.surface }
    private var controlStroke: Color { isStory ? .white.opacity(0.18) : CampusTheme.hairline }

    private func publish() {
        guard canPublish else { return }
        if isStory {
            guard let imageData else { return }
            appState.publishStory(imageData: imageData, caption: cleanCaption, place: selectedPlace)
            appState.toast = "Story paylaşıldı"
        } else {
            appState.publishPost(imageData: imageData, caption: cleanCaption, place: selectedPlace)
            appState.toast = "Gönderi paylaşıldı"
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
