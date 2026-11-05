import Combine
import Foundation

struct ShortComment: Identifiable, Codable {
    var id = UUID()
    let name: String
    let text: String
    var avatarAsset: String? = nil
    var parentID: UUID? = nil
    var replyToName: String? = nil
    var remoteAuthorID: String? = nil
    var remoteAvatarURL: URL? = nil
}

struct ShortBullet: Identifiable {
    let id = UUID()
    let videoID: UUID
    let text: String
}

/// Shared per-video state. Only publish mutations after their atomic disk write succeeds.
@MainActor
final class ShortsInteractionStore: ObservableObject {
    @Published private(set) var liked: Set<UUID> = []
    @Published private(set) var comments: [UUID: [ShortComment]] = [:]
    @Published private(set) var latestBullet: ShortBullet?
    @Published var bulletsEnabled = true
    @Published private var completedShares: [UUID: Int] = [:]
    @Published private var bonusLikes: [UUID: Int] = [:]
    @Published private var liveLikes: [UUID: Int] = [:]
    @Published private(set) var isSaving = false
    @Published private(set) var storageError: String?
    private var loaded = false
    private var sessionActive = false
    private var preparedVideos: Set<UUID> = []
    private var pendingLikes: [UUID: Int] = [:]
    private var likeFlush: Task<Void, Never>?
    var online: OnlineState?
    private let repository: ShortsInteractionRepository
    static let maximumComments = 500

    init(root: URL) { repository = ShortsInteractionRepository(root: root) }

    func setSessionActive(_ active: Bool) { sessionActive = active }

    // Called only after writes have been stopped by AppStore.
    func clearAccountMemory() {
        sessionActive = false
        likeFlush?.cancel()
        likeFlush = nil
        pendingLikes = [:]
        loaded = false
        preparedVideos = []
        apply(ShortsInteractionSnapshot())
        latestBullet = nil
        bulletsEnabled = true
        storageError = nil
    }

    func load() async throws {
        guard !loaded else { return }
        do {
            let snapshot = try await repository.load()
            apply(snapshot)
            preparedVideos = Set(snapshot.comments.keys)
            loaded = true
        } catch {
            // Keep the original file and prevent all writes until a successful reload.
            throw LocalLibraryError.unreadableLibrary
        }
    }

    func adoptRemote(_ state: OnlineState) {
        online = state; loaded = true; sessionActive = true
        liked = state.likes
        var next: [UUID: [ShortComment]] = [:]
        for record in state.records where record.kind == "comment" {
            guard let parent = record.parent_id, let revision = state.revision(record) else { continue }
            let author = state.creator(for: record)
            next[parent, default: []].append(ShortComment(id: record.id, name: author.name, text: revision.body,
                avatarAsset: author.avatarAsset, parentID: record.reply_to, remoteAuthorID: record.owner_id?.uuidString,
                remoteAvatarURL: author.avatarURL))
        }
        comments = next
    }

    func counts(for video: LocalVideo) -> ShortVideoCounts {
        if let online {
            let value = online.counts[video.id]
            return ShortVideoCounts(likes: value?.likes ?? 0, comments: value?.comments ?? 0,
                saves: value?.saves ?? 0, shares: value?.shares ?? 0)
        }
        return ShortVideoCounts(likes: (liked.contains(video.id) ? 1 : 0) + bonusLikes[video.id, default: 0],
            comments: comments[video.id]?.count ?? 0,
            saves: video.isSaved ? 1 : 0,
            shares: completedShares[video.id, default: 0])
    }

    func liveLikeCount(for video: LocalVideo) -> Int {
        liveLikes[video.id, default: 0]
    }

    func prepareComments(for video: LocalVideo) {
        if online != nil { return }
        guard loaded, sessionActive else { return }
        guard preparedVideos.insert(video.id).inserted else { return }
    }

    @discardableResult
    func toggleLike(_ id: UUID) async -> Bool {
        if let online { return await remote {
            _ = try await online.content.mutate("like", payload: ["target_id": .string(id.uuidString), "selected": .bool(!self.liked.contains(id))])
        } }
        guard !AnimationCatalog.entries.contains(where: { $0.id == id && $0.surface == .live }) else {
            return false
        }
        // A comment or live-like write may still be finishing. Wait instead of dropping this tap.
        while isSaving {
            do { try await Task.sleep(for: .milliseconds(40)) } catch { return false }
        }
        guard loaded, sessionActive, !isSaving else { return false }
        var updated = snapshot
        if updated.liked.contains(id) {
            updated.liked.remove(id)
            var bonus = updated.bonusLikes ?? [:]
            bonus[id] = nil
            updated.bonusLikes = bonus.isEmpty ? nil : bonus
        } else {
            updated.liked.insert(id)
        }
        return await commit(updated)
    }

    /// Records another live-room like without removing an earlier one.
    func addLiveLike(_ id: UUID) {
        guard loaded, sessionActive else { return }
        pendingLikes[id, default: 0] += 1
        guard likeFlush == nil else { return }
        likeFlush = Task { [weak self] in
            await self?.flushLikes()
        }
    }

    private func flushLikes() async {
        while !pendingLikes.isEmpty, loaded, sessionActive, !Task.isCancelled {
            while isSaving {
                do { try await Task.sleep(for: .milliseconds(40)) } catch {
                    likeFlush = nil
                    return
                }
            }
            let batch = pendingLikes
            pendingLikes = [:]
            var updated = snapshot
            var live = updated.liveLikes ?? [:]
            for (id, count) in batch {
                let (total, overflow) = live[id, default: 0].addingReportingOverflow(count)
                live[id] = overflow ? Int.max : total
            }
            updated.liveLikes = live
            if !(await commit(updated)) {
                for (id, count) in batch { pendingLikes[id, default: 0] += count }
                break
            }
        }
        likeFlush = nil
        // Keep failed taps for the next explicit tap; do not retry a failing disk write in a loop.
    }

    @discardableResult
    func addComment(_ text: String, to id: UUID, floating: Bool, replyingTo target: ShortComment? = nil) async -> Bool {
        if let online {
            let saved = await remote {
                _ = try await online.content.publish(kind: "comment", body: text, parent: id, replyingTo: target?.id)
            }
            if saved, floating { bulletsEnabled = true; latestBullet = ShortBullet(videoID: id, text: text) }
            return saved
        }
        guard loaded, sessionActive, !isSaving else { return false }
        storageError = nil
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= (floating ? 80 : 200) else { return false }
        var entries = comments[id] ?? []
        guard entries.count < Self.maximumComments else { return false }
        if let target {
            guard !floating, entries.contains(where: { $0.id == target.id }),
                  entries.contains(where: { $0.id == (target.parentID ?? target.id) && $0.parentID == nil }) else { return false }
        }
        entries.append(ShortComment(name: "You", text: text,
            parentID: target.map { $0.parentID ?? $0.id }, replyToName: target?.name))
        var updated = snapshot
        updated.comments[id] = entries
        guard await commit(updated) else { return false }
        if floating {
            bulletsEnabled = true
            latestBullet = ShortBullet(videoID: id, text: text)
        }
        return true
    }

    @discardableResult
    func recordCompletedShare(for id: UUID) async -> Bool {
        if let online { return await remote { _ = try await online.content.mutate("share", payload: ["target_id": .string(id.uuidString)]) } }
        // A system completion may arrive while a different local write is finishing.
        while isSaving {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return false }
        }
        guard loaded, sessionActive, !Task.isCancelled else { return false }
        var updated = snapshot
        updated.completedShares[id, default: 0] += 1
        return await commit(updated)
    }

    private func remote(_ action: () async throws -> Void) async -> Bool {
        guard !isSaving, let online else { return false }
        isSaving = true; defer { isSaving = false }
        do {
            try await action()
            do { try await online.refresh(); adoptRemote(online) } catch { storageError = "Saved online. Refresh to update this view." }
            return true
        } catch { storageError = error.localizedDescription; return false }
    }

    private var snapshot: ShortsInteractionSnapshot {
        ShortsInteractionSnapshot(
            liked: liked, comments: comments, completedShares: completedShares,
            bonusLikes: bonusLikes.isEmpty ? nil : bonusLikes,
            liveLikes: liveLikes.isEmpty ? nil : liveLikes)
    }

    private func commit(_ updated: ShortsInteractionSnapshot) async -> Bool {
        guard loaded, sessionActive, !isSaving else { return false }
        isSaving = true
        storageError = nil
        defer { isSaving = false }
        do {
            try await repository.save(updated)
            // Preserve independently loaded user comments without replacing stable IDs.
            var merged = updated
            for (id, entries) in comments where merged.comments[id] == nil { merged.comments[id] = entries }
            apply(merged)
            return true
        } catch {
            storageError = "Your changes could not be saved. Please try again."
            return false
        }
    }

    private func apply(_ snapshot: ShortsInteractionSnapshot) {
        liked = snapshot.liked
        comments = snapshot.comments
        completedShares = snapshot.completedShares
        bonusLikes = snapshot.bonusLikes ?? [:]
        liveLikes = snapshot.liveLikes ?? [:]
    }
}

extension LocalVideo {
    var communityDescription: String {
        if let clip = bundledClip { return clip.caption }
        return "\(title) · A story from your constellation. #Anime #Bibi"
    }
    func creatorName(profile: LocalProfile) -> String { remoteCreator?.name ?? bundledClip?.creator ?? profile.displayName }
}

enum ShortsPanelKind: String { case floating, comments, profile, share, more, gifts }
struct ShortsPanel: Identifiable {
    let kind: ShortsPanelKind
    let video: LocalVideo
    var id: String { "\(video.id)-\(kind.rawValue)" }
}

/// Counts come from actual server records or explicit device activity.
struct ShortVideoCounts {
    let likes: Int
    let comments: Int
    let saves: Int
    let shares: Int

    static func authored(for id: UUID) -> Self {
        Self(likes: 0, comments: 0, saves: 0, shares: 0)
    }
}
