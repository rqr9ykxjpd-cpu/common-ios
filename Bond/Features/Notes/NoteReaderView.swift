import PDFKit
import SwiftUI

struct NoteReaderRoute: Identifiable, Hashable {
    let id: UUID
}

/// Notu tam ekranda okumak: sayfalar alt alta, iki parmakla yakınlaşır.
/// Fotoğraflı not da PDF'e çevrilip burada açılır; paylaşınca tek dosya gider.
/// Altta sayfa, oy, cevaplar ve kaydet.
struct NoteReaderView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let postID: UUID
    @State private var document: PDFDocument?
    @State private var fileURL: URL?
    @State private var failed = false
    @State private var page = 1
    @State private var showComments = false
    @State private var confirmDelete = false

    private var post: SocialPost? { appState.posts.first { $0.id == postID } }
    private var extra: NoteExtra? { appState.noteExtras[postID] }
    private var pageCount: Int { document?.pageCount ?? extra?.pageCount ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            ZStack {
                if let document {
                    NotePDFView(document: document, page: $page)
                        .ignoresSafeArea(edges: .horizontal)
                } else if failed {
                    ScreenFailureView(message: L10n.Notes.openFailed, compact: true) { Task { await load() } }
                        .padding(BondTheme.Space.lg)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BondTheme.surface)
            if let post {
                Divider()
                bottomBar(post)
            }
        }
        .background(BondTheme.paper.ignoresSafeArea())
        .task { await load() }
        // Not silindi (buradan ya da yorumlardaki menüden): okuyucu kapanır.
        .onChange(of: appState.deletedPostIDs.contains(postID)) { _, silindi in
            if silindi { dismiss() }
        }
        .confirmationDialog(L10n.Notes.deleteConfirm, isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L10n.Notes.delete, role: .destructive) { appState.deletePost(postID) }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Feed.irreversible)
        }
        .sheet(isPresented: $showComments) {
            NavigationStack { PostDetailView(postID: postID, showsClose: true) }
                .presentationDragIndicator(.visible)
        }
    }

    private var topBar: some View {
        HStack(spacing: BondTheme.Space.compact) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(L10n.Common.close)
            VStack(alignment: .leading, spacing: 1) {
                if let ders = extra?.course, !ders.isEmpty, ders != post?.caption {
                    Text(ders)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BondTheme.muted)
                        .lineLimit(1)
                }
                Text(post?.caption ?? L10n.Notes.title)
                    .font(.headline)
                    .foregroundStyle(BondTheme.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let fileURL {
                ShareLink(item: fileURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.Notes.saveFile)
            }
            if let post { moreMenu(post) }
        }
        .foregroundStyle(BondTheme.ink)
        .padding(.horizontal, BondTheme.Space.sm)
        .padding(.vertical, 4)
    }

    /// Kendi notunda sil, başkasınınkinde şikayet et (gönderi menüsündekiyle aynı sebepler).
    private func moreMenu(_ post: SocialPost) -> some View {
        Menu {
            if post.isMine {
                Button(L10n.Notes.delete, systemImage: "trash", role: .destructive) { confirmDelete = true }
            } else {
                Menu {
                    ForEach(ReportReason.allCases) { reason in
                        Button(reason.title) {
                            appState.reportContent(.init(kind: .post, id: post.id), reason: reason)
                        }
                    }
                } label: {
                    Label(L10n.Common.report, systemImage: "flag")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(L10n.Common.options)
    }

    private func bottomBar(_ post: SocialPost) -> some View {
        HStack(spacing: BondTheme.Space.sm) {
            Text(pageCount > 0 ? "\(min(page, pageCount)) / \(pageCount)" : " ")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(BondTheme.ink)
                .contentTransition(.numericText())
                .animation(BondTheme.Motion.snappy, value: page)
                .frame(minWidth: 56, alignment: .leading)
                .accessibilityLabel(L10n.Notes.pageOf(min(page, pageCount), pageCount))
            Spacer(minLength: 0)
            VoteControl(
                score: post.likeCount,
                myVote: post.myVote,
                onUp: { appState.vote(postID: post.id, up: true) },
                onDown: { appState.vote(postID: post.id, up: false) }
            )
            Button { showComments = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left")
                    Text("\(post.comments.count)").monospacedDigit()
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(BondTheme.surface, in: Capsule())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(L10n.Feed.openComments)
            Button { appState.toggleSaved(postID: post.id) } label: {
                Image(systemName: post.saved ? "bookmark.fill" : "bookmark")
                    .font(.body)
                    .frame(width: 36, height: 36)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(post.saved ? L10n.Feed.removeSaved : L10n.Feed.save)
        }
        .foregroundStyle(BondTheme.ink)
        .padding(.horizontal, BondTheme.Space.lg)
        .padding(.vertical, BondTheme.Space.sm)
    }

    private func load() async {
        failed = false
        guard document == nil else { return }
        if post == nil { await appState.loadPostIfNeeded(postID) }
        guard let post else { failed = true; return }
        if extra == nil { await appState.loadNoteExtras(for: [post]) }
        guard let url = await appState.noteDocument(for: post), let belge = PDFDocument(url: url) else {
            failed = true
            return
        }
        fileURL = url
        document = belge
    }
}

/// PDFKit'in okuyucusu: sayfalar alt alta, ekrana sığar, yakınlaşır.
private struct NotePDFView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var page: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        view.pageShadowsEnabled = false
        view.pageBreakMargins = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        view.backgroundColor = UIColor(BondTheme.surface)
        view.document = document
        context.coordinator.observe(view)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.page = $page
        if view.document !== document { view.document = document }
    }

    func makeCoordinator() -> Coordinator { Coordinator(page: $page) }

    @MainActor
    final class Coordinator: NSObject {
        var page: Binding<Int>

        init(page: Binding<Int>) { self.page = page }

        func observe(_ view: PDFView) {
            NotificationCenter.default.addObserver(self, selector: #selector(pageChanged(_:)),
                                                   name: .PDFViewPageChanged, object: view)
        }

        @objc private func pageChanged(_ notification: Notification) {
            guard let view = notification.object as? PDFView,
                  let current = view.currentPage, let document = view.document else { return }
            page.wrappedValue = document.index(for: current) + 1
        }
    }
}
