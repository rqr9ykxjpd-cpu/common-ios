import SwiftUI

// MARK: - AppState+Stories
extension AppState {
    /// Story'leri sunucudan yükler. Bu liste akışın en üstünde duruyor ama şimdiye kadar
    /// yalnızca bellekteydi; uygulama kapanınca paylaşılan story kayboluyordu.
    func loadStories() async {
        // Kendi süresi dolmuş story'lerini de temizliyoruz: aksi halde her paylaşım
        // depolamada kalıcı olarak yer kaplıyor. En-iyi-çaba, sonucu beklenmiyor.
        Task { await service.purgeMyExpiredStories() }
        isLoadingStories = true
        defer { isLoadingStories = false }
        do {
            stories = try await service.fetchStories().map { story in
                // Sunucu rozeti kaçırsa bile kendi story’nde yerel kurucu/mod rozeti kalsın.
                guard story.isMine, story.author.badge == .none, myBadge != .none else { return story }
                return story.replacingAuthor(story.author.withBadge(myBadge))
            }
        } catch {
            showError(error, fallback: L10n.Story.loadFailed)
        }
    }

    @discardableResult
    func publishStory(_ upload: StoryUpload, caption: String, place: CampusPlace?) async -> Bool {
        do {
            try await service.publishStory(upload, caption: caption, placeID: place?.id)
            await loadStories()
            Haptics.success()
            show(L10n.Composer.storyShared)
            return true
        } catch {
            showError(error, fallback: L10n.Story.postFailed)
            return false
        }
    }
    func deleteStory(_ storyID: UUID) {
        let removed = stories.first(where: { $0.id == storyID })
        if let removed {
            guard removed.isMine || isModerator else { return }
        } else {
            // Liste senkron dışı olsa bile kurucu/moderatör sunucudan silebilsin.
            guard isModerator else { return }
        }
        stories.removeAll { $0.id == storyID }
        if selectedStory?.id == storyID { selectedStory = nil }
        show(L10n.Story.deleted)
        Haptics.success()
        Task {
            do { try await service.deleteStory(storyID) }
            catch {
                if let removed { stories.insert(removed, at: 0) }
                showError(error, fallback: L10n.Story.deleteFailed)
            }
        }
    }
    func markStoryViewed(_ story: CampusStory) {
        guard let storyIndex = stories.firstIndex(where: { $0.id == story.id }) else { return }
        stories[storyIndex].viewed = true

        let storyID = story.id
        let isMine = story.isMine
        Task {
            // İzleyen listesini kayıt yazılmasını beklemeden çek: sayı 0'da kalmasın.
            if isMine {
                do {
                    let records = try await service.fetchStoryViews(storyID)
                    guard let index = stories.firstIndex(where: { $0.id == storyID }) else { return }
                    if !records.isEmpty || stories[index].viewRecords.isEmpty {
                        stories[index].viewRecords = records
                    }
                } catch {
                    showError(error, fallback: L10n.Story.viewersLoadFailed)
                }
            }
            // Sahibinin kendi açışları da sayılıyor: kullanıcı bunu bilerek istedi,
            // sayacın çalıştığını tek hesapla da görebilmek için.
            // Hayalet moddayken hiç kaydetmiyoruz.
            guard !(ghostMode && tier.hasGhostMode) else { return }
            do {
                try await service.markStoryViewed(storyID)
            } catch {
                showError(error, fallback: L10n.Story.viewersLoadFailed)
                return
            }
            guard isMine else { return }
            if let records = try? await service.fetchStoryViews(storyID),
               let index = stories.firstIndex(where: { $0.id == storyID }) {
                stories[index].viewRecords = records
            }
        }
    }
    /// Story beğenisi. Sahibine bildirim sunucudaki tetikleyiciden gidiyor.
    func setStoryLiked(_ storyID: UUID, liked: Bool) {
        Haptics.impact(.light)
        Task {
            do { try await service.setStoryLiked(storyID, liked: liked) }
            catch { showError(error, fallback: liked ? L10n.Story.likeFailed : L10n.Story.unlikeFailed) }
        }
    }

    func isStoryLiked(_ storyID: UUID) async -> Bool {
        (try? await service.isStoryLiked(storyID)) ?? false
    }
}
