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
    /// Kırpma ekranında bekleyen fotoğraf.
    @State private var cropCandidate: IdentifiableImage?
    @State private var galleryItems: [PhotosPickerItem] = []
    @State private var loaded = false
    @State private var showDiscardAlert = false

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
        .scrollDismissesKeyboard(.interactively)
        .dismissesKeyboardOnTap()
        .keyboardDoneButton()
        .background(CampusTheme.paper.ignoresSafeArea())
        .foregroundStyle(CampusTheme.ink)
        // Kaydet butonu kaydırma içeriğinin sonundayken alt çubuğun altında kalıp
        // tıklanamıyordu; forma ait birincil eylem olarak sabitleniyor.
        .safeAreaInset(edge: .bottom, spacing: 0) { saveBar }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { loadOnce() }
        .onChange(of: avatarItem) { _, item in
            // Seçilen fotoğraf doğrudan kaydedilmiyor: önce dairesel çerçeveye göre
            // konumlandırılıyor. Aksi halde kadraj neredeyse her fotoğrafta ortadan
            // kırpılıyor ve kullanıcının yapabileceği bir şey olmuyordu.
            Task {
                guard let raw = try? await item?.loadTransferable(type: Data.self),
                      let picked = UIImage(data: raw) else { return }
                await MainActor.run { cropCandidate = IdentifiableImage(image: picked) }
            }
        }
        .fullScreenCover(item: $cropCandidate) { candidate in
            AvatarCropView(image: candidate.image) {
                cropCandidate = nil
            } onConfirm: { data in
                avatarData = data
                cropCandidate = nil
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

    /// Kaydetme çubuğu.
    ///
    /// Önceden her durumda aynı görünüyordu: dolu bir kutunun içinde "Değişiklikleri
    /// kaydet" ve üstünde sürekli duran bir uyarı satırı. Ne değiştiğini, neyin eksik
    /// olduğunu söylemiyordu; sadece bir düğme duruyordu.
    ///
    /// Artık üç hâli var: değişiklik yoksa sessiz, eksik varsa **ne eksik olduğunu
    /// tek tek** söylüyor, hazırsa kaydetmeye çağırıyor.
    private var saveBar: some View {
        VStack(spacing: 8) {
            if !missingFields.isEmpty {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(CampusTheme.coral)
                    Text(missingFields.joined(separator: " · "))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(CampusTheme.ink.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            } else if !changed {
                Text("Her şey kayıtlı")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            AppButton(
                title: changed ? "Değişiklikleri kaydet" : "Kaydedildi",
                systemName: changed ? "arrow.up" : "checkmark",
                enabled: valid && changed
            ) { save() }
        }
        .padding(.horizontal, CampusTheme.Space.lg)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(CampusTheme.hairline).frame(height: 0.5) }
    }

    /// Neyin eksik olduğu tek tek. "Şunlar zorunlu" demek, hangisinin eksik olduğunu
    /// kullanıcıya aratıyordu.
    private var missingFields: [String] {
        var missing: [String] = []
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("Ad") }
        if draft.department.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("Bölüm") }
        if draft.gender == nil { missing.append("Cinsiyet") }
        if draft.interests.count < InterestCatalog.minimumSelection {
            missing.append("\(InterestCatalog.minimumSelection - draft.interests.count) ilgi alanı daha")
        }
        if draft.bio.count > 220 { missing.append("Hakkımda çok uzun") }
        return missing
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
                DatePicker("Doğum tarihi", selection: $draft.birthDate, in: ...AgeLimit.latestBirthDate, displayedComponents: .date)
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
        let full = draft.interests.count >= InterestCatalog.maximumSelection
        return VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            AppSectionHeader(title: "İlgi alanları")
            Text("\(draft.interests.count)/\(InterestCatalog.maximumSelection) seçili · en az \(InterestCatalog.minimumSelection) gerekli")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(CampusTheme.muted)
            ForEach(InterestCatalog.grouped, id: \.baslik) { grup in
                VStack(alignment: .leading, spacing: 8) {
                    Text(grup.baslik.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(CampusTheme.muted)
                    ProfileFlowLayout(spacing: 8) {
                        ForEach(grup.secenekler, id: \.self) { interest in
                            let selected = draft.interests.contains(interest)
                            // Sınıra gelindiğinde seçili olmayanlar soluk ve pasif:
                            // önceden dokunulunca sessizce hiçbir şey olmuyordu.
                            let disabled = !selected && full
                            Button {
                                if selected { draft.interests.remove(interest) }
                                else if !full { draft.interests.insert(interest) }
                            } label: {
                                Text(interest)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(selected ? .white : CampusTheme.ink)
                                    .padding(.horizontal, 12).frame(height: 34)
                                    .background(selected ? CampusTheme.violet : CampusTheme.surface, in: Capsule())
                                    .overlay(Capsule().stroke(selected ? .clear : CampusTheme.hairline))
                            }
                            .buttonStyle(PressableStyle())
                            .disabled(disabled)
                            .opacity(disabled ? 0.35 : 1)
                        }
                    }
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
