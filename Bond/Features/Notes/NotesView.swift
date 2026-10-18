import SwiftUI

/// Notlar: üstte arama; bölümünün son notları; altta notu olan diğer
/// bölümler. Nota dokununca tam ekran okuyucu. Kim nerede'de Kulüpler'in
/// altından açılır.
struct NotesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var departments: [NoteDepartment] = []
    @State private var recent: [SocialPost] = []
    @State private var loaded = false
    @State private var failure: String?
    @State private var composer: NoteComposerRoute?
    @State private var reading: NoteReaderRoute?
    @State private var query = ""
    @State private var results: [SocialPost]?

    private var myDepartment: String {
        appState.currentUserProfile.department.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var myDepartmentID: String { myDepartment.lowercased(with: L10n.appLocale) }
    private var isSearching: Bool { query.trimmingCharacters(in: .whitespaces).count >= 2 }
    private var otherDepartments: [NoteDepartment] { departments.filter { $0.id != myDepartmentID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.xl) {
                    if isSearching {
                        searchResults
                    } else if let failure, departments.isEmpty {
                        ScreenFailureView(message: failure, compact: true) { Task { await load() } }
                    } else if !loaded {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, BondTheme.Space.xl)
                    } else {
                        if !myDepartment.isEmpty { myDepartmentSection }
                        if !otherDepartments.isEmpty { departmentsSection }
                    }
                }
                .padding(BondTheme.Space.lg)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Notes.title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: L10n.Notes.searchPrompt)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.Notes.share, systemImage: "plus") {
                        composer = NoteComposerRoute(department: myDepartment)
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
            .fullScreenCover(item: $reading) { route in
                NoteReaderView(postID: route.id)
            }
            .task { await load() }
            .task(id: query) { await search() }
            .refreshable { await load() }
        }
    }

    private var myDepartmentSection: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.md) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow(text: L10n.Notes.fromYourDepartment, color: BondTheme.muted)
                    Text(myDepartment)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BondTheme.ink)
                }
                Spacer(minLength: BondTheme.Space.sm)
                if !recent.isEmpty, let bolum = departments.first(where: { $0.id == myDepartmentID }) {
                    NavigationLink(value: bolum) {
                        Text(L10n.Notes.seeAll)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BondTheme.ink)
                    }
                    .accessibilityIdentifier("notes.seeAll")
                }
            }
            if recent.isEmpty {
                VStack(alignment: .leading, spacing: BondTheme.Space.md) {
                    Text(L10n.Notes.departmentEmpty)
                        .font(.subheadline)
                        .foregroundStyle(BondTheme.muted)
                    Button { composer = NoteComposerRoute(department: myDepartment) } label: {
                        Text(L10n.Notes.share)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BondTheme.paper)
                            .padding(.horizontal, BondTheme.Space.lg)
                            .frame(minHeight: 44)
                            .background(BondTheme.ink, in: Capsule())
                    }
                    .buttonStyle(.pressable)
                }
                .padding(BondTheme.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                NoteGrid(notes: Array(recent.filter { !appState.deletedPostIDs.contains($0.id) }.prefix(4))) {
                    reading = NoteReaderRoute(id: $0.id)
                }
            }
        }
    }

    private var departmentsSection: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            Eyebrow(text: L10n.Notes.departments, color: BondTheme.muted)
            VStack(spacing: 0) {
                ForEach(otherDepartments) { bolum in
                    if bolum.id != otherDepartments.first?.id {
                        Divider().padding(.leading, BondTheme.Space.md)
                    }
                    NavigationLink(value: bolum) { departmentRow(bolum) }
                        .buttonStyle(.pressable)
                }
            }
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder private var searchResults: some View {
        if let results {
            if results.isEmpty {
                Text(L10n.Notes.searchEmpty)
                    .font(.subheadline)
                    .foregroundStyle(BondTheme.muted)
                    .padding(.top, BondTheme.Space.sm)
            } else {
                NoteGrid(notes: results.filter { !appState.deletedPostIDs.contains($0.id) }) {
                    reading = NoteReaderRoute(id: $0.id)
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity).padding(.top, BondTheme.Space.xl)
        }
    }

    private func departmentRow(_ bolum: NoteDepartment) -> some View {
        HStack(spacing: BondTheme.Space.compact) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bolum.name)
                    .font(.headline)
                    .foregroundStyle(BondTheme.ink)
                    .multilineTextAlignment(.leading)
                Text(bolum.noteCount == 0 ? L10n.Notes.noNotesYet : L10n.Notes.noteCount(bolum.noteCount))
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
            let son = myDepartment.isEmpty ? [] : try await appState.departmentNotes(myDepartment)
            withAnimation(BondTheme.Motion.smooth) {
                departments = liste
                recent = son
            }
            failure = nil
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.Notes.loadFailed)
        }
        loaded = true
    }

    /// Yazmayı bırakınca arar; her harfte istek gitmesin.
    private func search() async {
        guard isSearching else { results = nil; return }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        results = nil
        let bulunan = (try? await appState.searchNotes(query)) ?? []
        guard !Task.isCancelled else { return }
        withAnimation(BondTheme.Motion.smooth) { results = bulunan }
    }
}

/// Bir bölümün notları: ders süzgeci, sıralama, iki sütun.
struct DepartmentNotesView: View {
    @Environment(AppState.self) private var appState
    let department: NoteDepartment
    @State private var notes: [SocialPost] = []
    @State private var loaded = false
    @State private var failure: String?
    @State private var composer: NoteComposerRoute?
    @State private var reading: NoteReaderRoute?
    @State private var course: String?
    @State private var sort = NoteSort.newest

    enum NoteSort: CaseIterable {
        case newest, top
        var title: String { self == .newest ? L10n.Notes.sortNewest : L10n.Notes.sortTop }
    }

    /// Notlardaki dersler, en çok notu olan başta; aynı ders farklı harfle
    /// yazıldıysa en sık yazılışı.
    private var courses: [String] {
        let dersler = notes.compactMap { appState.noteExtras[$0.id]?.course.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let gruplar = Dictionary(grouping: dersler) { $0.lowercased(with: L10n.appLocale) }
        return gruplar.values
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0[0] < $1[0] }
            .compactMap { grup in
                Dictionary(grouping: grup, by: { $0 }).max { $0.value.count < $1.value.count }?.key
            }
    }

    private var visibleNotes: [SocialPost] {
        let canli = notes.compactMap { not in appState.posts.first { $0.id == not.id } ?? not }
            .filter { !appState.deletedPostIDs.contains($0.id) }
        let suzulen = course.map { secilen in
            canli.filter {
                appState.noteExtras[$0.id]?.course.trimmingCharacters(in: .whitespaces)
                    .lowercased(with: L10n.appLocale) == secilen.lowercased(with: L10n.appLocale)
            }
        } ?? canli
        switch sort {
        case .newest: return suzulen.sorted { $0.createdAt > $1.createdAt }
        case .top: return suzulen.sorted { $0.likeCount != $1.likeCount ? $0.likeCount > $1.likeCount : $0.createdAt > $1.createdAt }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BondTheme.Space.md) {
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
                    if courses.count > 1 { courseChips }
                    HStack {
                        Text(L10n.Notes.noteCount(visibleNotes.count))
                            .font(.footnote)
                            .foregroundStyle(BondTheme.muted)
                        Spacer()
                        Menu {
                            Picker(L10n.Notes.sort, selection: $sort) {
                                ForEach(NoteSort.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(sort.title)
                                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BondTheme.ink)
                            .frame(minHeight: 32)
                        }
                        .accessibilityIdentifier("notes.sort")
                    }
                    NoteGrid(notes: visibleNotes) { reading = NoteReaderRoute(id: $0.id) }
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
        .fullScreenCover(item: $reading) { route in
            NoteReaderView(postID: route.id)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private var courseChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BondTheme.Space.sm) {
                chip(L10n.Notes.allCourses, selected: course == nil) { course = nil }
                ForEach(courses, id: \.self) { ders in
                    chip(ders, selected: course?.lowercased(with: L10n.appLocale) == ders.lowercased(with: L10n.appLocale)) {
                        course = ders
                    }
                }
            }
            .padding(.horizontal, BondTheme.Space.lg)
        }
        .padding(.horizontal, -BondTheme.Space.lg)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(BondTheme.Motion.snappy) { action() }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? BondTheme.paper : BondTheme.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(selected ? BondTheme.ink : BondTheme.surface, in: Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(selected ? .isSelected : [])
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

/// İki sütun not kartı.
struct NoteGrid: View {
    let notes: [SocialPost]
    let open: (SocialPost) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: BondTheme.Space.md, alignment: .top),
                            GridItem(.flexible(), spacing: BondTheme.Space.md, alignment: .top)],
                  alignment: .leading, spacing: BondTheme.Space.lg) {
            ForEach(notes) { not in
                Button { open(not) } label: { NoteCard(post: not) }
                    .buttonStyle(.pressableCard)
                    .accessibilityIdentifier("note.card.\(not.id)")
            }
        }
    }
}

/// Not kartı: ilk sayfa, sayfa sayısı; ders, konu; oy, kim, ne zaman.
private struct NoteCard: View {
    @Environment(AppState.self) private var appState
    let post: SocialPost

    private var live: SocialPost { appState.posts.first { $0.id == post.id } ?? post }
    private var extra: NoteExtra? { appState.noteExtras[post.id] }
    private var pageCount: Int { extra?.pageCount ?? max(post.galleryURLs.count, post.galleryData.count, 1) }
    private var course: String {
        let ders = extra?.course.trimmingCharacters(in: .whitespaces) ?? ""
        return ders == post.caption ? "" : ders
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    ProfileMedia(url: post.imageURL, data: post.localImageData ?? post.galleryData.first,
                                 assetName: post.imageAssetName, kind: .content)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(BondTheme.ink.opacity(0.08), lineWidth: 1)
                }
                .overlay(alignment: .bottomLeading) {
                    Text(extra?.isPDF == true ? "PDF · \(L10n.Notes.pageCount(pageCount))" : L10n.Notes.pageCount(pageCount))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.65), in: Capsule())
                        .padding(8)
                }
                .padding(.bottom, 4)
            if !course.isEmpty {
                Text(course)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BondTheme.muted)
                    .lineLimit(1)
            }
            Text(post.caption.isEmpty ? L10n.Notes.title : post.caption)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BondTheme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: 4) {
                Image(systemName: "arrow.up").font(.caption2.weight(.bold))
                Text("\(live.likeCount)").monospacedDigit()
                Text("·")
                Text(post.author.name.split(separator: " ").first.map(String.init) ?? post.author.name)
                Text("·")
                Text(post.createdAt.formatted(.relative(presentation: .named).locale(L10n.appLocale)))
            }
            .font(.caption)
            .foregroundStyle(BondTheme.muted)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
