import PhotosUI
import SwiftUI

/// Notlar: notu olan bölümler; kendi bölümün en üstte. Bölüme dokununca o
/// bölümün notları. Kim nerede'de Kulüpler'in altından açılır.
struct NotesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var departments: [NoteDepartment] = []
    @State private var loaded = false
    @State private var failure: String?
    @State private var composer: NoteComposerRoute?

    private var myDepartmentID: String {
        appState.currentUserProfile.department.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: L10n.appLocale)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
                    Text(L10n.Notes.entrySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(BondTheme.muted)
                        .padding(.bottom, BondTheme.Space.sm)
                    if let failure, departments.isEmpty {
                        ScreenFailureView(message: failure, compact: true) { Task { await load() } }
                    } else if !loaded {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, BondTheme.Space.xl)
                    } else {
                        Eyebrow(text: L10n.Notes.departments, color: BondTheme.muted)
                        VStack(spacing: 0) {
                            ForEach(departments) { bolum in
                                if bolum.id != departments.first?.id {
                                    Divider().padding(.leading, BondTheme.Space.md)
                                }
                                NavigationLink(value: bolum) { departmentRow(bolum) }
                                    .buttonStyle(.pressable)
                            }
                        }
                        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(BondTheme.Space.lg)
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Notes.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.Notes.share, systemImage: "plus") {
                        composer = NoteComposerRoute(department: appState.currentUserProfile.department)
                    }
                    .accessibilityIdentifier("notes.share")
                }
            }
            .navigationDestination(for: NoteDepartment.self) { bolum in
                DepartmentNotesView(department: bolum)
            }
            .sheet(item: $composer) { route in
                NoteComposer(department: route.department) { Task { await load() } }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func departmentRow(_ bolum: NoteDepartment) -> some View {
        HStack(spacing: BondTheme.Space.compact) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bolum.name)
                    .font(.headline)
                    .foregroundStyle(BondTheme.ink)
                    .multilineTextAlignment(.leading)
                Text([bolum.noteCount == 0 ? L10n.Notes.noNotesYet : L10n.Notes.noteCount(bolum.noteCount),
                      bolum.id == myDepartmentID ? L10n.Notes.yourDepartment : nil]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(BondTheme.muted)
            }
            Spacer(minLength: BondTheme.Space.sm)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BondTheme.muted)
        }
        .padding(.horizontal, BondTheme.Space.md)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }

    private func load() async {
        do {
            let liste = try await appState.fetchNoteDepartments()
            withAnimation(BondTheme.Motion.smooth) { departments = liste }
            failure = nil
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.Notes.loadFailed)
        }
        loaded = true
    }
}

/// Bir bölümün notları, yeniden eskiye. Dokununca gönderi sayfası.
struct DepartmentNotesView: View {
    @Environment(AppState.self) private var appState
    let department: NoteDepartment
    @State private var notes: [SocialPost] = []
    @State private var loaded = false
    @State private var failure: String?
    @State private var composer: NoteComposerRoute?
    @State private var openedPost: ClubRoute?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
                if let failure, notes.isEmpty {
                    ScreenFailureView(message: failure, compact: true) { Task { await load() } }
                } else if !loaded {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, BondTheme.Space.xl)
                } else if notes.isEmpty {
                    VStack(alignment: .leading, spacing: BondTheme.Space.md) {
                        Text(L10n.Notes.departmentEmpty)
                            .font(.body)
                            .foregroundStyle(BondTheme.muted)
                        Button { composer = NoteComposerRoute(department: department.name) } label: {
                            Text(L10n.Notes.share)
                                .font(.headline)
                                .foregroundStyle(BondTheme.paper)
                                .padding(.horizontal, BondTheme.Space.lg)
                                .frame(minHeight: 48)
                                .background(BondTheme.ink, in: Capsule())
                        }
                        .buttonStyle(.pressable)
                    }
                    .padding(.top, BondTheme.Space.sm)
                } else {
                    VStack(spacing: 0) {
                        ForEach(visibleNotes) { not in
                            if not.id != visibleNotes.first?.id {
                                Divider().padding(.leading, 96)
                            }
                            Button { open(not) } label: { NoteRow(post: not) }
                                .buttonStyle(.pressable)
                        }
                    }
                    .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(BondTheme.Space.lg)
        }
        .background(BondTheme.paper.ignoresSafeArea())
        .navigationTitle(department.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(L10n.Notes.share, systemImage: "plus") {
                    composer = NoteComposerRoute(department: department.name)
                }
            }
        }
        .sheet(item: $composer) { route in
            NoteComposer(department: route.department) { Task { await load() } }
        }
        .sheet(item: $openedPost) { route in
            NavigationStack { PostDetailView(postID: route.id, showsClose: true) }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    /// Silinen not listeden hemen düşsün.
    private var visibleNotes: [SocialPost] { notes.filter { !appState.deletedPostIDs.contains($0.id) } }

    private func open(_ not: SocialPost) {
        Task {
            if await appState.loadPostIfNeeded(not.id) { openedPost = ClubRoute(id: not.id) }
        }
    }

    private func load() async {
        do {
            let liste = try await appState.departmentNotes(department.name)
            withAnimation(BondTheme.Motion.smooth) { notes = liste }
            failure = nil
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.Notes.loadFailed)
        }
        loaded = true
    }
}

/// Listede bir not: ilk sayfanın küçük resmi, ders ve konu, kim, ne zaman.
private struct NoteRow: View {
    let post: SocialPost

    private var pageCount: Int { max(post.galleryURLs.count, post.galleryData.count, 1) }

    var body: some View {
        HStack(alignment: .top, spacing: BondTheme.Space.md) {
            ProfileMedia(url: post.imageURL, data: post.localImageData ?? post.galleryData.first,
                         assetName: post.imageAssetName, kind: .content)
                .frame(width: 64, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(post.caption.isEmpty ? L10n.Notes.title : post.caption)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BondTheme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(post.author.name + " · " + post.createdAt.formatted(.relative(presentation: .named).locale(L10n.appLocale)))
                    .font(.footnote)
                    .foregroundStyle(BondTheme.muted)
                    .lineLimit(1)
                HStack(spacing: BondTheme.Space.compact) {
                    Label("\(post.likeCount)", systemImage: "arrow.up")
                    Label("\(pageCount)", systemImage: "doc.on.doc")
                }
                .font(.caption)
                .foregroundStyle(BondTheme.muted)
                .labelStyle(.titleAndIcon)
            }
            Spacer(minLength: 0)
        }
        .padding(BondTheme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct NoteComposerRoute: Identifiable {
    let id = UUID()
    let department: String
}

/// Not paylaş: sayfaların fotoğrafı (en fazla 6), ders ve konu, bölüm.
/// Bölüm kendi bölümünle dolu gelir; yazarken notu olan bölümler önerilir,
/// aynı bölüm iki ayrı yazılışla açılmasın.
struct NoteComposer: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var caption = ""
    @State private var department: String
    @State private var pages: [Data] = []
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var preparing = false
    @State private var saving = false
    @State private var knownDepartments: [String] = []
    @State private var confirmDiscard = false
    @FocusState private var focus: Field?
    private let onShared: () -> Void

    private enum Field { case caption, department }

    init(department: String, onShared: @escaping () -> Void = {}) {
        _department = State(initialValue: department)
        self.onShared = onShared
    }

    private var trimmedDepartment: String { department.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedCaption: String { caption.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isDirty: Bool { !pages.isEmpty || !trimmedCaption.isEmpty }
    private var canShare: Bool {
        !pages.isEmpty && !trimmedCaption.isEmpty && !trimmedDepartment.isEmpty && !saving && !preparing
    }

    /// Yazılana uyan, şu an yazılı olandan farklı bölümler (en fazla 6).
    private var suggestions: [String] {
        let yazilan = trimmedDepartment.lowercased(with: L10n.appLocale)
        return knownDepartments
            .filter { $0.lowercased(with: L10n.appLocale) != yazilan }
            .filter { yazilan.isEmpty || $0.lowercased(with: L10n.appLocale).contains(yazilan) }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.xl) {
                    pagesSection
                    VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
                        TextField(L10n.Notes.captionPlaceholder, text: $caption, axis: .vertical)
                            .font(.headline)
                            .lineLimit(1...4)
                            .focused($focus, equals: .caption)
                            .onChange(of: caption) { _, yeni in
                                if yeni.count > 300 { caption = String(yeni.prefix(300)) }
                            }
                            .padding(BondTheme.Space.md)
                            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityIdentifier("note.caption")
                    }
                    departmentSection
                    Text(L10n.Notes.copyright)
                        .font(.footnote)
                        .foregroundStyle(BondTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(BondTheme.Space.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BondTheme.paper.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { shareBar }
            .navigationTitle(L10n.Notes.share)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) {
                        if isDirty { confirmDiscard = true } else { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(isDirty)
            .confirmationDialog(L10n.Notes.discardTitle, isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button(L10n.ClubEvents.discard, role: .destructive) { dismiss() }
                Button(L10n.ClubEvents.keepEditing, role: .cancel) {}
            }
            .onChange(of: pickedItems) { _, yeni in
                guard !yeni.isEmpty else { return }
                Task { await ingest(yeni) }
            }
            .task { await loadKnownDepartments() }
        }
    }

    private var pagesSection: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: L10n.Notes.pages)
                Spacer()
                Text("\(pages.count)/\(CampusLimits.maxPostPhotos)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BondTheme.muted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BondTheme.Space.sm) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, data in
                        pageThumb(data, index: index)
                    }
                    if pages.count < CampusLimits.maxPostPhotos {
                        PhotosPicker(selection: $pickedItems,
                                     maxSelectionCount: CampusLimits.maxPostPhotos - pages.count,
                                     matching: .images) {
                            VStack(spacing: 6) {
                                if preparing {
                                    ProgressView()
                                } else {
                                    Image(systemName: "plus")
                                        .font(.title3.weight(.semibold))
                                    Text(L10n.Notes.addPages)
                                        .font(.caption.weight(.semibold))
                                }
                            }
                            .foregroundStyle(BondTheme.ink)
                            .frame(width: 96, height: 128)
                            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(preparing)
                        .accessibilityIdentifier("note.addPages")
                    }
                }
                .padding(.horizontal, BondTheme.Space.lg)
            }
            .padding(.horizontal, -BondTheme.Space.lg)
            Text(L10n.Notes.pagesHint)
                .font(.footnote)
                .foregroundStyle(BondTheme.muted)
        }
    }

    private func pageThumb(_ data: Data, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let resim = UIImage(data: data) {
                    Image(uiImage: resim).resizable().scaledToFill()
                } else {
                    BondTheme.surface
                }
            }
            .frame(width: 96, height: 128)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Button {
                withAnimation(reduceMotion ? nil : BondTheme.Motion.snappy) { _ = pages.remove(at: index) }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BondTheme.paper)
                    .frame(width: 24, height: 24)
                    .background(BondTheme.ink.opacity(0.8), in: Circle())
            }
            .padding(6)
            .accessibilityLabel(L10n.Common.delete)
        }
    }

    private var departmentSection: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            Eyebrow(text: L10n.Notes.department)
            TextField(L10n.Notes.departmentPlaceholder, text: $department)
                .focused($focus, equals: .department)
                .textInputAutocapitalization(.words)
                .onChange(of: department) { _, yeni in
                    if yeni.count > 80 { department = String(yeni.prefix(80)) }
                }
                .padding(.horizontal, BondTheme.Space.md)
                .frame(minHeight: 52)
                .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("note.department")
            if !suggestions.isEmpty {
                FlowLayout(spacing: BondTheme.Space.sm) {
                    ForEach(suggestions, id: \.self) { ad in
                        Button {
                            department = ad
                            focus = nil
                        } label: {
                            Text(ad)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(BondTheme.ink)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 36)
                                .background(BondTheme.surface, in: Capsule())
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
        }
    }

    private var shareBar: some View {
        Button { Task { await share() } } label: {
            ZStack {
                if saving { ProgressView().tint(BondTheme.paper) } else { Text(L10n.Notes.publish) }
            }
            .font(.headline)
            .foregroundStyle(canShare || saving ? BondTheme.paper : BondTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(canShare || saving ? BondTheme.ink : BondTheme.surface, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .disabled(!canShare)
        .padding(.horizontal, BondTheme.Space.lg)
        .padding(.vertical, BondTheme.Space.sm)
        .background(BondTheme.paper)
        .accessibilityIdentifier("note.publish")
    }

    /// Seçilen fotoğraflar sırayla hazırlanıp sona eklenir (gönderidekiyle aynı sıkıştırma).
    private func ingest(_ items: [PhotosPickerItem]) async {
        preparing = true
        defer { preparing = false; pickedItems = [] }
        let hazir = await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    guard let raw = try? await item.loadImageData() else { return (index, nil) }
                    return (index, await ImageCompression.prepareForUploadInBackground(raw))
                }
            }
            var sonuc: [(Int, Data?)] = []
            for await parca in group { sonuc.append(parca) }
            return sonuc.sorted { $0.0 < $1.0 }.compactMap(\.1)
        }
        if hazir.count < items.count { appState.show(L10n.Composer.photoLoadFailed) }
        let yer = max(0, CampusLimits.maxPostPhotos - pages.count)
        withAnimation(reduceMotion ? nil : BondTheme.Motion.snappy) { pages.append(contentsOf: hazir.prefix(yer)) }
    }

    private func loadKnownDepartments() async {
        let notlu = (try? await appState.fetchNoteDepartments().map(\.name)) ?? []
        var gorulen = Set<String>()
        knownDepartments = (notlu + DepartmentCatalog.all).filter {
            let anahtar = $0.lowercased(with: L10n.appLocale)
            return !anahtar.isEmpty && gorulen.insert(anahtar).inserted
        }
    }

    private func share() async {
        guard canShare else { return }
        focus = nil
        saving = true
        defer { saving = false }
        if await appState.publishNote(caption: trimmedCaption, department: trimmedDepartment, images: pages) {
            onShared()
            dismiss()
        }
    }
}
