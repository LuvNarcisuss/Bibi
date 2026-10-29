import Foundation

struct CreatorProfile: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let biography: String
    var coverURL: URL? = nil
    var avatarURL: URL? = nil
    var avatarAsset: String? = nil
    var avatarSymbol = "figure.dance"
    var likes: Int? = nil
    var following: Int? = nil
    var followers: Int? = nil
    var ipRegion: String? = nil
    var sourceURL: URL? = nil
    var isLocalOwner = false

    var relationshipStatistics: CreatorStatistics {
        let baseline = CreatorStatistics.authored(for: id)
        // Per-work totals are derived by AppStore. Retain legacy stored likes for decoding only.
        return CreatorStatistics(likes: 0, saves: 0,
                                 following: following ?? baseline.following,
                                 followers: followers ?? baseline.followers)
    }

    static func from(video: LocalVideo, profile: LocalProfile, coverURL: URL) -> Self {
        if let remote = video.remoteCreator { return remote }
        let clip = video.bundledClip
        if var curator = CommunityCatalog.storyAuthor(id: video.creatorID) {
            curator.coverURL = coverURL
            curator.sourceURL = clip?.sourceURL
            return curator
        }
        return Self(id: video.creatorID, name: video.creatorName(profile: profile),
                    biography: clip == nil ? profile.biography : "Animation, worldbuilding and stories worth sharing.",
                    coverURL: coverURL,
                    avatarAsset: clip != nil || profile.avatarSymbol == "figure.dance"
                        ? CommunityArtwork.creatorAvatar(for: video.creatorID) : nil,
                    avatarSymbol: clip == nil ? profile.avatarSymbol : "figure.dance",
                    sourceURL: clip?.sourceURL, isLocalOwner: clip == nil)
    }

    static func signedIn(_ profile: LocalProfile) -> Self {
        Self(
            id: profile.remoteAccountID?.uuidString ?? "local-owner", name: profile.displayName, biography: profile.biography,
            avatarURL: profile.remoteAvatarURL,
            avatarAsset: profile.remoteAccountID == nil ? CommunityArtwork.creatorAvatar(for: "local-owner") : "BibiMark",
            avatarSymbol: profile.avatarSymbol, isLocalOwner: true)
    }
}

extension LocalVideo {
    var creatorID: String {
        remoteCreator?.id ?? bundledClip.map { $0.curatorID ?? "bibi-curator:\($0.creator)" } ?? "local-owner"
    }
}

/// Optional in LocalLibrary for backward-compatible decoding of saved libraries.
struct CreatorLocalState: Codable {
    var followedIDs: Set<String> = []
    var messageDrafts: [String: String] = [:]
    var conversations: [String: CreatorConversationRecord]? = nil
}

struct CreatorConversationRecord: Codable {
    var creator: CreatorProfile
    var updatedAt: Date?
}

/// Local presentation figures, not counts fetched from the credited media source.
/// Stable IDs keep each creator's figures consistent across videos and app launches.
struct CreatorStatistics {
    let likes: Int
    let saves: Int
    let following: Int
    let followers: Int

    static func authored(for creatorID: String) -> Self {
        func value(_ field: String) -> UInt64 {
            (creatorID + ":" + field).utf8.reduce(UInt64(14695981039346656037)) {
                ($0 ^ UInt64($1)) &* 1099511628211
            }
        }
        let following = 10 + Int(value("following") % 21)
        let followers = 10 + Int(value("followers") % 20)
        return Self(likes: 0, saves: 0, following: following, followers: followers)
    }
}
