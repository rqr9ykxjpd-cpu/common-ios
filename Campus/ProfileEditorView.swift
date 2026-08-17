import SwiftUI
import PhotosUI

struct ProfileEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ProfileDraft()
    @State private var avatarData: Data?
    @State private var galleryData: [Data] = []
    @State private var avatarItem: PhotosPickerItem?
    @State private var galleryItems: [PhotosPickerItem] = []
    @State private var loaded = false
    @State private var showDiscardAlert = false
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false

    private let interests = ["Canlı müzik", "Sinema", "Gece yürüyüşü", "Tasarım", "Koşu", "Analog", "Kahve", "Sergiler", "Kitaplar", "Elektronik", "Fotoğraf", "Girişim"]
    private let years = ["Hazırlık", "1. sınıf", "2. sınıf", "3. sınıf", "4. sınıf", "Lisansüstü"]

    private var valid: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.department.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        draft.gender != nil &&
        draft.datingPreference != nil &&
        draft.bio.count <= 220
    }

    private var changed: Bool {
        draft != appState.draft || avatarData != appState.avatarData || galleryData != appState.profileGalleryData
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
                AppButton(title: "Değişiklikleri kaydet", systemName: "checkmark", enabled: valid) { save() }
                VStack(spacing: CampusTheme.Space.sm) {
                    Button { showSignOutAlert = true } label: {
                        Label("Oturumu kapat", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(CampusTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.control))
                            .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.control).stroke(CampusTheme.hairline))
                    }
                    .buttonStyle(PressableStyle())

                    Button(role: .destructive) { showDeleteAccountAlert = true } label: {
                        Label("Hesabı sil", systemImage: "trash")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, CampusTheme.Space.lg)
            .padding(.top, CampusTheme.Space.sm)
            .padding(.bottom, CampusTheme.Space.xxl)
        }
        .background(CampusTheme.paper.ignoresSafeArea())
        .foregroundStyle(CampusTheme.ink)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { loadOnce() }
        .onChange(of: avatarItem) { _, item in
            Task {
                let data = try? await item?.loadTransferable(type: Data.self)
                await MainActor.run { avatarData = data }
            }
        }
        .onChange(of: galleryItems) { _, items in
            Task {
                var loadedImages: [Data] = []
                for item in items.prefix(5) {
                    if let data = try? await item.loadTransferable(type: Data.self) { loadedImages.append(data) }
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
        .alert("Oturumu kapat?", isPresented: $showSignOutAlert) {
            Button("Vazgeç", role: .cancel) {}
            Button("Oturumu kapat", role: .destructive) { appState.signOut() }
        } message: {
            Text("Profilin ve hesabın silinmez. Aynı e-posta ve giriş koduyla kaldığın yerden devam edebilirsin.")
        }
        .alert("Hesabı kalıcı olarak sil?", isPresented: $showDeleteAccountAlert) {
            Button("Vazgeç", role: .cancel) {}
            Button("Hesabımı sil", role: .destructive) { appState.deleteAccount() }
        } message: {
            Text("Profilin, fotoğrafların ve bu cihazdaki hesap verilerin silinir. Bu işlem geri alınamaz.")
        }
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
        let galleryButtonTitle = galleryData.isEmpty ? "Galeri fotoğrafları ekle" : "Galeriyi değiştir"

        return VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            AppSectionHeader(title: "Fotoğraflar")
            HStack(alignment: .top, spacing: CampusTheme.Space.md) {
                PhotosPicker(selection: $avatarItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        ProfileMedia(url: nil, data: currentAvatarData)
                            .frame(width: 104, height: 128)
                            .clipShape(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
                        Image(systemName: "camera.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
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
                Picker("Sınıf", selection: $draft.year) {
                    ForEach(years, id: \.self) { Text($0).tag($0) }
                }
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
                Picker("Kimlerle tanışmak istersin?", selection: $draft.datingPreference) {
                    Text("Seç").tag(DatingPreference?.none)
                    ForEach(DatingPreference.allCases) { option in
                        Text(option.title).tag(DatingPreference?.some(option))
                    }
                }
                Text("Cinsiyet ve tanışma tercihi zorunludur.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
                Menu {
                    Button("Konumu gizle") { appState.currentVisiblePlace = nil }
                    ForEach(CampusPlace.samples) { place in
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
    }

    private func save() {
        guard valid else { return }
        appState.saveProfile(draft, avatar: avatarData, gallery: galleryData)
        dismiss()
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
