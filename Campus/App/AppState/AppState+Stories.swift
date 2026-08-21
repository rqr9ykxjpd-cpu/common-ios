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
            stories = try await service.fetchStories()
        } catch {
            showError(error, fallback: L10n.Story.loadFailed)
        }
    }

    func publishStory(imageData: Data, caption: String, place: CampusPlace?) {
        Task {
            do {
                try await service.publishStory(imageData: imageData, caption: caption, placeID: place?.id)
                await loadStories()
                Haptics.success()
            } catch {
                showError(error, fallback: L10n.Story.postFailed)
            }
        }
    }
    func deleteStory(_ storyID: UUID) {
        guard let removed = stories.first(where: { $0.id == storyID && $0.isMine }) else { return }
        stories.removeAll { $0.id == storyID }
        if selectedStory?.id == storyID { selectedStory = nil }
        show(L10n.Story.deleted)
        Haptics.success()
        Task {
            do { try await service.deleteStory(storyID) }
            catch {
                stories.insert(removed, at: 0)
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
            // Sahibinin kendi açışları da sayılıyor: kullanıcı bunu bilerek istedi,
            // sayacın çalıştığını tek hesapla da görebilmek için.
            // Hayalet moddayken hiç kaydetmiyoruz.
            if !(ghostMode && tier.hasGhostMode) {
                try? await service.markStoryViewed(storyID)
            }
            // İzleyen listesini yalnızca story sahibi görebilir; başkasının story'sinde
            // bu sorgu boş döneceği için hiç yapmıyoruz.
            guard isMine else { return }
            do {
                let records = try await service.fetchStoryViews(storyID)
                guard let index = stories.firstIndex(where: { $0.id == storyID }) else { return }
                stories[index].viewRecords = records
            } catch {
                showError(error, fallback: L10n.Story.viewersLoadFailed)
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
