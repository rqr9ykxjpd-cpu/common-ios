import SwiftUI
import PhotosUI

struct ProfileEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ProfileDraft()
    @State private var avatarData: Data?
    @State private var galleryData: [Data] = []
    @State private var baselineAvatarData: Data?
    @State private var baselineGalleryData: [Data] = []
    @State private var avatarItem: PhotosPickerItem?
    @State private var galleryItems: [PhotosPickerItem] = []
    @State private var loaded = false
    @State private var showDiscardAlert = false

    private let interests = ["Canlı müzik", "Sinema", "Gece yürüyüşü", "Tasarım", "Koşu", "Analog", "Kahve", "Sergiler", "Kitaplar", "Elektronik", "Fotoğraf", "Girişim"]
    private let years = ["Hazırlık", "1. sınıf", "2. sınıf", "3. sınıf", "4. sınıf", "Lisansüstü"]

    private var valid: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.department.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        draft.gender != nil &&
        draft.bio.count <= 220 &&
        draft.interests.count >= 3
    }

    private var changed: Bool {
        draft != appState.draft || avatarData != baselineAvatarData || galleryData != baselineGalleryData
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CampusTheme.Space.xl) {
                header
                photos
                basicInformation
                about
                interestSelection
                preferences
                accountInformation
            }
            .padding(.horizontal, CampusTheme.Space.lg)
            .padding(.top, CampusTheme.Space.sm)
            .padding(.bottom, CampusTheme.Space.lg)
        }
        .background(CampusTheme.paper.ignoresSafeArea())
        .foregroundStyle(CampusTheme.ink)
        // Kaydet butonu kaydırma içeriğinin sonundayken alt çubuğun altında kalıp
        // tıklanamıyordu; forma ait birincil eylem olarak sabitleniyor.
        .safeAreaInset(edge: .bottom, spacing: 0) { saveBar }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { loadOnce() }
        .onChange(of: avatarItem) { _, item in
            Task {
                let raw = try? await item?.loadTransferable(type: Data.self)
                let data = raw.flatMap(ImageCompression.prepareForUpload)
                await MainActor.run { avatarData = data }
            }
        }
        .onChange(of: galleryItems) { _, items in
            Task {
                var loadedImages: [Data] = []
                for item in items.prefix(5) {
                    if let raw = try? await item.loadTransferable(type: Data.self),
                       let data = ImageCompression.prepareForUpload(raw) { loadedImages.append(data) }
                }
                await MainActor.run { galleryData = loadedImages }
            }
        }
        .alert("Değişiklikler kaydedilmedi", isPresented: $showDiscardAlert) {
            Button("Düzenlemeye devam et", role: .cancel) {}
            Button("Kaydetmeden çık", role: .destructive) { dismiss() }
        } message: {
            Text("Yaptığın profil değişiklikleri kaybolacak.")
        }
    }

    private var saveBar: some View {
        VStack(spacing: 6) {
            if !valid {
                Text("Ad, bölüm, cinsiyet ve en az 3 ilgi alanı zorunlu.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            AppButton(title: "Değişiklikleri kaydet", systemName: "checkmark", enabled: valid) { save() }
        }
        .padding(.horizontal, CampusTheme.Space.lg)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(CampusTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(CampusTheme.hairline).frame(height: 0.5) }
    }

    private var header: some View {
        HStack {
            AppIconButton(systemName: "arrow.left") {
                changed ? (showDiscardAlert = true) : dismiss()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Profili düzenle")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Değişiklikler kaydettiğinde yayınlanır")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
            }
            Spacer()
            Button("Kaydet") { save() }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(valid ? CampusTheme.violet : CampusTheme.muted)
                .disabled(!valid)
        }
    }

    private var photos: some View {
        let currentAvatarData = avatarData
        let currentAvatarURL = appState.avatarURL
        let galleryButtonTitle = galleryData.isEmpty ? "Galeri fotoğrafları ekle" : "Galeriyi değiştir"

        return VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            AppSectionHeader(title: "Fotoğraflar")
            HStack(alignment: .top, spacing: CampusTheme.Space.md) {
                PhotosPicker(selection: $avatarItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        ProfileMedia(url: currentAvatarURL, data: currentAvatarData)
                            .frame(width: 104, height: 128)
                            .clipShape(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
                        Image(systemName: "camera.fill")
                            .font(.caption.bold())
                            .foregroundStyle(CampusTheme.paper)
                            .frame(width: 30, height: 30)
                            .background(CampusTheme.ink, in: Circle())
                            .padding(7)
                    }
                }
                .buttonStyle(PressableStyle())
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ana profil fotoğrafı")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("Yüzünün net göründüğü güncel bir fotoğraf kullan.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(CampusTheme.muted)
                    if avatarData != nil {
                        Button("Fotoğrafı kaldır", role: .destructive) { avatarData = nil }
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                }
                .padding(.top, 8)
            }

            PhotosPicker(selection: $galleryItems, maxSelectionCount: 5, matching: .images) {
                Label(galleryButtonTitle, systemImage: "photo.stack")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CampusTheme.ink)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.control))
                    .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.control).stroke(CampusTheme.hairline))
            }
            .buttonStyle(PressableStyle())

            if !galleryData.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(galleryData.enumerated()), id: \.offset) { index, data in
                            ZStack(alignment: .topTrailing) {
                                ProfileMedia(url: nil, data: data)
                                    .frame(width: 82, height: 104)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Button { galleryData.remove(at: index) } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption.bold()).foregroundStyle(.white)
                                        .frame(width: 44, height: 44).background(.black.opacity(0.62), in: Circle())
                                }
                                .accessibilityLabel("Bu fotoğrafı kaldır")
                                .padding(5)
                            }
                        }
                    }
                }
            }
        }
    }

    private var basicInformation: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 18) {
                AppSectionHeader(title: "Temel bilgiler")
                ProfileTextField(title: "Ad", text: $draft.name)
                ProfileTextField(title: "Bölüm", text: $draft.department)
                DatePicker("Doğum tarihi", selection: $draft.birthDate, in: ...Calendar.current.date(byAdding: .year, value: -18, to: .now)!, displayedComponents: .date)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .environment(\.locale, Locale(identifier: "tr_TR"))
                Picker("Sınıf", selection: $draft.year) {
                    ForEach(years, id: \.self) { Text($0).tag($0) }
                }
                .tint(CampusTheme.violet)
            }
        }
    }

    private var about: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Hakkımda")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    Text("\(draft.bio.count)/220")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(draft.bio.count > 220 ? CampusTheme.coral : CampusTheme.muted)
                }
                TextField("Kendinden ve kampüs hayatından kısaca bahset...", text: $draft.bio, axis: .vertical)
                    .font(.system(size: 15, design: .rounded))
                    .lineLimit(4...7)
                    .padding(12)
                    .background(CampusTheme.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: CampusTheme.Radius.control))
            }
        }
    }

    private var interestSelection: some View {
        VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            AppSectionHeader(title: "İlgi alanları")
            ProfileFlowLayout(spacing: 8) {
                ForEach(interests, id: \.self) { interest in
                    let selected = draft.interests.contains(interest)
                    Button {
                        if selected { draft.interests.remove(interest) } else { draft.interests.insert(interest) }
                    } label: {
                        Text(interest)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(selected ? .white : CampusTheme.ink)
                            .padding(.horizontal, 12).frame(height: 34)
                            .background(selected ? CampusTheme.violet : CampusTheme.surface, in: Capsule())
                            .overlay(Capsule().stroke(selected ? .clear : CampusTheme.hairline))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var preferences: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                AppSectionHeader(title: "Tanış tercihleri")
                Picker("Cinsiyet", selection: $draft.gender) {
                    Text("Seç").tag(ProfileGender?.none)
                    ForEach(ProfileGender.allCases) { option in
                        Text(option.title).tag(ProfileGender?.some(option))
                    }
                }
                .tint(CampusTheme.violet)
                Picker("Tanışma niyetin", selection: $draft.relationshipIntent) {
                    ForEach(RelationshipIntent.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .tint(CampusTheme.violet)
                Text("Cinsiyet zorunludur; kimlerin gösterileceği buna göre belirlenir.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
                Menu {
                    Button("Konumu gizle") { appState.currentVisiblePlace = nil }
                    ForEach(appState.places) { place in
                        Button(place.name) { appState.currentVisiblePlace = place }
                    }
                } label: {
                    HStack {
                        Label("Görünür yer", systemImage: "location")
                        Spacer()
                        Text(appState.currentVisiblePlace?.name ?? "Kapalı")
                            .foregroundStyle(CampusTheme.muted)
                        Image(systemName: "chevron.up.chevron.down").font(.caption)
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(CampusTheme.ink)
                }
            }
        }
    }

    private var accountInformation: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 14) {
                AppSectionHeader(title: "Hesap ve doğrulama")
                readOnlyRow("Hesap", appState.email.isEmpty ? "Henüz giriş yapılmadı" : appState.email)
                readOnlyRow("Öğrenci durumu", "Doğrulandı")
                Text("Bu bilgiler güvenlik nedeniyle profil üzerinden değiştirilemez.")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(CampusTheme.muted)
            }
        }
    }

    private func readOnlyRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(CampusTheme.muted)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(.system(size: 13, design: .rounded))
    }

    private func loadOnce() {
        guard !loaded else { return }
        draft = appState.draft
        avatarData = appState.avatarData
        galleryData = appState.profileGalleryData
        loaded = true
        Task { await hydrateExistingPhotos() }
    }

    // Sunucudaki mevcut fotoğraflar yalnızca imzalı URL olarak biliniyor (bkz. AppState.avatarURL/
    // galleryURLs); editör Data tabanlı önizleme/kaydetme akışını kullandığından burada bir kerelik
    // indirip yerel baseline'a alıyoruz — böylece "değişiklik var mı?" karşılaştırması yanlış pozitif
    // vermez ve kaydetmeden çıkıldığında mevcut fotoğraflar kaybolmuş gibi görünmez.
    private func hydrateExistingPhotos() async {
        if avatarData == nil, let url = appState.avatarURL {
            avatarData = try? await downloadImageData(url)
        }
        if galleryData.isEmpty, !appState.galleryURLs.isEmpty {
            var hydrated: [Data] = []
            for url in appState.galleryURLs {
                if let data = try? await downloadImageData(url) { hydrated.append(data) }
            }
            galleryData = hydrated
        }
        baselineAvatarData = avatarData
        baselineGalleryData = galleryData
    }

    private func downloadImageData(_ url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    private func save() {
        guard valid else { return }
        Task {
            if await appState.saveProfile(draft, avatar: avatarData, gallery: galleryData) {
                dismiss()
            }
        }
    }
}

private struct ProfileTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(CampusTheme.muted)
            TextField(title, text: $text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .padding(.horizontal, 12).frame(height: 46)
                .background(CampusTheme.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: CampusTheme.Radius.control))
        }
    }
}
