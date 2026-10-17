import PDFKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

struct NoteComposerRoute: Identifiable {
    let id = UUID()
    let department: String
}

/// Not ekle: kamerayla tara, galeriden en fazla 20 fotoğraf ya da bir PDF
/// (25 MB); ders, konu, bölüm. Bölüm kendi bölümünle dolu gelir; yazarken
/// notu olan bölümler önerilir, aynı bölüm iki ayrı yazılışla açılmasın.
struct NoteComposer: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var course = ""
    @State private var title = ""
    @State private var department: String
    @State private var pages: [PageDraft] = []
    @State private var pdf: PickedPDF?
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var choosingPhotos = false
    @State private var scanning = false
    @State private var importingPDF = false
    @State private var preparing = false
    @State private var saving = false
    @State private var knownDepartments: [String] = []
    @State private var confirmDiscard = false
    @FocusState private var focus: Field?
    private let onShared: () -> Void

    private enum Field { case course, title, department }

    /// Sayfa ve küçük resmi: küçük resim her çizimde yeniden açılmasın.
    private struct PageDraft: Identifiable {
        let id = UUID()
        let data: Data
        let thumbnail: UIImage?
    }

    private struct PickedPDF {
        let name: String
        let data: Data
        let pageCount: Int
        let cover: Data?
        let coverImage: UIImage?
    }

    init(department: String, onShared: @escaping () -> Void = {}) {
        _department = State(initialValue: department)
        self.onShared = onShared
    }

    private var canScan: Bool { VNDocumentCameraViewController.isSupported }
    private var trimmedCourse: String { course.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedDepartment: String { department.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasContent: Bool { !pages.isEmpty || pdf != nil }
    private var isDirty: Bool { hasContent || !trimmedCourse.isEmpty || !trimmedTitle.isEmpty }
    private var canShare: Bool {
        hasContent && !trimmedCourse.isEmpty && !trimmedDepartment.isEmpty && !saving && !preparing
    }
    private var roomLeft: Int { max(0, NoteLimits.maxPages - pages.count) }

    /// Yazılana uyan, şu an yazılı olandan farklı bölümler (en fazla 6).
    private var departmentSuggestions: [String] {
        let yazilan = trimmedDepartment.lowercased(with: L10n.appLocale)
        return knownDepartments
            .filter { $0.lowercased(with: L10n.appLocale) != yazilan }
            .filter { yazilan.isEmpty || $0.lowercased(with: L10n.appLocale).contains(yazilan) }
            .prefix(6)
            .map { $0 }
    }

    /// Daha önce yazılmış dersler: aynı ders iki ayrı yazılışla dağılmasın.
    private var courseSuggestions: [String] {
        let yazilan = trimmedCourse.lowercased(with: L10n.appLocale)
        var gorulen = Set<String>()
        return appState.noteExtras.values.map { $0.course.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && gorulen.insert($0.lowercased(with: L10n.appLocale)).inserted }
            .filter { $0.lowercased(with: L10n.appLocale) != yazilan }
            .filter { yazilan.isEmpty || $0.lowercased(with: L10n.appLocale).contains(yazilan) }
            .sorted()
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.xl) {
                    contentSection
                    VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
                        Eyebrow(text: L10n.Notes.course)
                        TextField(L10n.Notes.coursePlaceholder, text: $course)
                            .font(.headline)
                            .focused($focus, equals: .course)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                            .onSubmit { focus = .title }
                            .onChange(of: course) { _, yeni in
                                if yeni.count > 60 { course = String(yeni.prefix(60)) }
                            }
                            .padding(.horizontal, BondTheme.Space.md)
                            .frame(minHeight: 52)
                            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityIdentifier("note.course")
                        if focus == .course, !courseSuggestions.isEmpty {
                            suggestionChips(courseSuggestions) { course = $0; focus = .title }
                        }
                    }
                    VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
                        Eyebrow(text: L10n.Notes.topic)
                        TextField(L10n.Notes.topicPlaceholder, text: $title, axis: .vertical)
                            .lineLimit(1...3)
                            .focused($focus, equals: .title)
                            .onChange(of: title) { _, yeni in
                                if yeni.count > 200 { title = String(yeni.prefix(200)) }
                            }
                            .padding(BondTheme.Space.md)
                            .frame(minHeight: 52)
                            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityIdentifier("note.title")
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
            .photosPicker(isPresented: $choosingPhotos, selection: $pickedItems,
                          maxSelectionCount: max(1, roomLeft), selectionBehavior: .ordered, matching: .images)
            .onChange(of: pickedItems) { _, yeni in
                guard !yeni.isEmpty else { return }
                Task { await ingest(yeni) }
            }
            .fileImporter(isPresented: $importingPDF, allowedContentTypes: [.pdf]) { sonuc in
                ingestPDF(sonuc)
            }
            .fullScreenCover(isPresented: $scanning) {
                DocumentScanner { tarama in
                    scanning = false
                    if let tarama { Task { await ingest(tarama) } }
                }
                .ignoresSafeArea()
            }
            .task { await loadKnownDepartments() }
        }
    }

    // MARK: - Sayfalar / PDF

    @ViewBuilder private var contentSection: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: L10n.Notes.pages)
                Spacer()
                if !pages.isEmpty {
                    Text("\(pages.count)/\(NoteLimits.maxPages)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(BondTheme.muted)
                }
            }
            if let pdf {
                pdfCard(pdf)
            } else if pages.isEmpty {
                sourceTiles
                Text(L10n.Notes.sourcesHint)
                    .font(.footnote)
                    .foregroundStyle(BondTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                pageStrip
                Text(L10n.Notes.reorderHint)
                    .font(.footnote)
                    .foregroundStyle(BondTheme.muted)
            }
        }
    }

    private var sourceTiles: some View {
        HStack(spacing: BondTheme.Space.sm) {
            if canScan {
                sourceTile(L10n.Notes.sourceScan, icon: "doc.viewfinder", id: "scan") { scanning = true }
            }
            sourceTile(L10n.Notes.sourcePhotos, icon: "photo.on.rectangle", id: "photos") { choosingPhotos = true }
            sourceTile(L10n.Notes.sourcePDF, icon: "doc.text", id: "pdf") { importingPDF = true }
        }
        .overlay {
            if preparing {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BondTheme.paper.opacity(0.85))
                    .overlay { ProgressView() }
            }
        }
        .disabled(preparing)
    }

    private func sourceTile(_ title: String, icon: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(BondTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 112)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("note.source.\(id)")
    }

    private var pageStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: BondTheme.Space.sm) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, sayfa in
                    pageThumb(sayfa, index: index)
                }
                if roomLeft > 0 { addMoreTile }
            }
            .padding(.horizontal, BondTheme.Space.lg)
        }
        .padding(.horizontal, -BondTheme.Space.lg)
    }

    private func pageThumb(_ sayfa: PageDraft, index: Int) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let resim = sayfa.thumbnail {
                        Image(uiImage: resim).resizable().scaledToFill()
                    } else {
                        BondTheme.surface
                    }
                }
                .frame(width: 96, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(BondTheme.ink.opacity(0.08), lineWidth: 1)
                }
                Button { remove(at: index) } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BondTheme.paper)
                        .frame(width: 24, height: 24)
                        .background(BondTheme.ink.opacity(0.8), in: Circle())
                }
                .padding(6)
                .accessibilityLabel(L10n.Common.delete)
            }
            .contextMenu {
                if index > 0 {
                    Button(L10n.Notes.moveEarlier, systemImage: "arrow.left") { move(index, by: -1) }
                }
                if index < pages.count - 1 {
                    Button(L10n.Notes.moveLater, systemImage: "arrow.right") { move(index, by: 1) }
                }
                Button(L10n.Common.delete, systemImage: "trash", role: .destructive) { remove(at: index) }
            }
            Text("\(index + 1)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(BondTheme.muted)
        }
    }

    @ViewBuilder private var addMoreTile: some View {
        let etiket = VStack(spacing: 6) {
            if preparing {
                ProgressView()
            } else {
                Image(systemName: "plus").font(.title3.weight(.semibold))
                Text(L10n.Notes.addPages).font(.caption.weight(.semibold))
            }
        }
        .foregroundStyle(BondTheme.ink)
        .frame(width: 96, height: 128)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

        Group {
            if canScan {
                Menu {
                    Button(L10n.Notes.sourceScan, systemImage: "doc.viewfinder") { scanning = true }
                    Button(L10n.Notes.sourcePhotos, systemImage: "photo.on.rectangle") { choosingPhotos = true }
                } label: { etiket }
            } else {
                Button { choosingPhotos = true } label: { etiket }
                    .buttonStyle(.pressable)
            }
        }
        .disabled(preparing)
        .accessibilityIdentifier("note.addPages")
    }

    private func pdfCard(_ dosya: PickedPDF) -> some View {
        HStack(spacing: BondTheme.Space.md) {
            Group {
                if let resim = dosya.coverImage {
                    Image(uiImage: resim).resizable().scaledToFill()
                } else {
                    Image(systemName: "doc.text").font(.title2).foregroundStyle(BondTheme.muted)
                }
            }
            .frame(width: 66, height: 88)
            .background(BondTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(BondTheme.ink.opacity(0.08), lineWidth: 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(dosya.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BondTheme.ink)
                    .lineLimit(2)
                Text("PDF · " + L10n.Notes.pageCount(dosya.pageCount) + " · "
                     + ByteCountFormatter.string(fromByteCount: Int64(dosya.data.count), countStyle: .file))
                    .font(.footnote)
                    .foregroundStyle(BondTheme.muted)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(reduceMotion ? nil : BondTheme.Motion.snappy) { pdf = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(BondTheme.ink)
                    .frame(width: 36, height: 36)
                    .background(BondTheme.paper, in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(L10n.Notes.removeFile)
        }
        .padding(BondTheme.Space.md)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Bölüm

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
            if focus == .department, !departmentSuggestions.isEmpty {
                suggestionChips(departmentSuggestions) { department = $0; focus = nil }
            }
        }
    }

    private func suggestionChips(_ items: [String], pick: @escaping (String) -> Void) -> some View {
        FlowLayout(spacing: BondTheme.Space.sm) {
            ForEach(items, id: \.self) { ad in
                Button { pick(ad) } label: {
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

    // MARK: - İşler

    private func remove(at index: Int) {
        guard pages.indices.contains(index) else { return }
        withAnimation(reduceMotion ? nil : BondTheme.Motion.snappy) { _ = pages.remove(at: index) }
    }

    private func move(_ index: Int, by offset: Int) {
        let hedef = index + offset
        guard pages.indices.contains(index), pages.indices.contains(hedef) else { return }
        withAnimation(reduceMotion ? nil : BondTheme.Motion.snappy) { pages.swapAt(index, hedef) }
    }

    private func append(_ hazir: [Data]) {
        let yeni = hazir.prefix(roomLeft).map {
            PageDraft(data: $0, thumbnail: ImageCompression.imageForDisplay($0, maxDimension: 300))
        }
        withAnimation(reduceMotion ? nil : BondTheme.Motion.snappy) {
            pdf = nil
            pages.append(contentsOf: yeni)
        }
    }

    /// Seçilen fotoğraflar seçilme sırasıyla hazırlanıp sona eklenir; not
    /// yazısı okunsun diye akıştakinden büyük.
    private func ingest(_ items: [PhotosPickerItem]) async {
        preparing = true
        defer { preparing = false; pickedItems = [] }
        let hazir = await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    guard let raw = try? await item.loadImageData() else { return (index, nil) }
                    return (index, await ImageCompression.prepareNotePageInBackground(raw))
                }
            }
            var sonuc: [(Int, Data?)] = []
            for await parca in group { sonuc.append(parca) }
            return sonuc.sorted { $0.0 < $1.0 }.compactMap(\.1)
        }
        if hazir.count < items.count { appState.show(L10n.Composer.photoLoadFailed) }
        append(hazir)
    }

    /// Taranan sayfalar tek tek küçültülür: hepsi birden bellekte durmasın.
    private func ingest(_ tarama: VNDocumentCameraScan) async {
        preparing = true
        defer { preparing = false }
        var hazir: [Data] = []
        for sira in 0..<min(tarama.pageCount, roomLeft) {
            if let veri = await ImageCompression.prepareNotePageInBackground(tarama.imageOfPage(at: sira)) {
                hazir.append(veri)
            }
        }
        if tarama.pageCount > roomLeft { appState.show(L10n.Notes.pageLimit) }
        append(hazir)
    }

    private func ingestPDF(_ sonuc: Result<URL, any Error>) {
        guard case .success(let adres) = sonuc else { return }
        let erisim = adres.startAccessingSecurityScopedResource()
        defer { if erisim { adres.stopAccessingSecurityScopedResource() } }
        let boyut = (try? adres.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard boyut <= NoteLimits.maxPDFBytes else { appState.show(L10n.Notes.pdfTooLarge); return }
        guard let veri = try? Data(contentsOf: adres), let belge = PDFDocument(data: veri) else {
            appState.show(L10n.Notes.pdfUnreadable)
            return
        }
        guard veri.count <= NoteLimits.maxPDFBytes else { appState.show(L10n.Notes.pdfTooLarge); return }
        guard !belge.isLocked else { appState.show(L10n.Notes.pdfLocked); return }
        guard (1...500).contains(belge.pageCount) else { appState.show(L10n.Notes.pdfTooManyPages); return }
        let kapak = NotePDF.cover(of: belge)
        let dosya = PickedPDF(name: adres.deletingPathExtension().lastPathComponent, data: veri,
                              pageCount: belge.pageCount, cover: kapak,
                              coverImage: kapak.flatMap { ImageCompression.imageForDisplay($0, maxDimension: 300) })
        withAnimation(reduceMotion ? nil : BondTheme.Motion.snappy) {
            pages = []
            pdf = dosya
        }
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
        let not = NoteUpload(
            title: trimmedTitle.isEmpty ? trimmedCourse : trimmedTitle,
            course: trimmedCourse,
            department: trimmedDepartment,
            pages: pdf == nil ? pages.map(\.data) : [],
            pdf: pdf?.data,
            pdfThumbnail: pdf?.cover,
            pageCount: pdf?.pageCount ?? pages.count
        )
        if await appState.publishNote(not) {
            onShared()
            dismiss()
        }
    }
}

/// VisionKit'in belge tarayıcısı: kenarları bulur, düzeltir, sayfa sayfa
/// çeker. Vazgeçilirse ya da hata olursa nil.
private struct DocumentScanner: UIViewControllerRepresentable {
    let onFinish: (VNDocumentCameraScan?) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let tarayici = VNDocumentCameraViewController()
        tarayici.delegate = context.coordinator
        return tarayici
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        let onFinish: (VNDocumentCameraScan?) -> Void

        init(onFinish: @escaping (VNDocumentCameraScan?) -> Void) { self.onFinish = onFinish }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            onFinish(scan)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish(nil)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: any Error) {
            onFinish(nil)
        }
    }
}
