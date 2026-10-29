import Combine
import Foundation
import Supabase

@MainActor
final class OnlineState: ObservableObject {
    let services: BackendServices
    let content: ContentRepository
    let media: MediaRepository
    let chat: ChatRepository
    let wallet: OnlineWallet
    let sync: BackendSync
    @Published private(set) var profiles: [UUID: RemoteProfile] = [:]
    @Published private(set) var records: [RemoteContent] = []
    @Published private(set) var revisions: [UUID: RemoteRevision] = [:]
    @Published private(set) var assets: [UUID: RemoteMedia] = [:]
    @Published private(set) var conversations: [RemoteConversation] = []
    @Published private(set) var members: [RemoteMember] = []
    @Published private(set) var messages: [UUID: [RemoteMessage]] = [:]
    @Published private(set) var follows: [RemoteRelationship] = []
    @Published private(set) var blocks: [RemoteRelationship] = []
    @Published private(set) var circles: [RemoteCircle] = []
    @Published private(set) var challenges: [RemoteChallenge] = []
    @Published private(set) var counts: [UUID: RemoteCounts] = [:]
    private(set) var profileCounts: [UUID: RemoteProfileCounts] = [:]
    @Published private(set) var drafts: [String: String] = [:]
    private(set) var saves: Set<UUID> = []
    private(set) var likes: Set<UUID> = []
    private(set) var entries: [RemoteEntry] = []
    private(set) var joins: Set<String> = []
    private(set) var reports: [RemoteReport] = []
    private(set) var signedURLs: [UUID: URL] = [:]
    private var refreshTask: Task<Void, Error>?
    private var refreshGeneration: UUID?

    init(services: BackendServices) {
        self.services = services; content = ContentRepository(services); media = MediaRepository(services)
        chat = ChatRepository(services); wallet = OnlineWallet(services); sync = BackendSync(services)
    }

    func refresh() async throws {
        let generation = services.generation
        if refreshGeneration == generation, let refreshTask { return try await refreshTask.value }
        refreshTask?.cancel()
        let task = Task { try await loadSnapshot() }
        refreshTask = task; refreshGeneration = generation
        defer { if refreshGeneration == generation { refreshTask = nil; refreshGeneration = nil } }
        try await task.value
    }

    private func loadSnapshot() async throws {
        let account = try services.requireAccount(), generation = services.generation
        let profileRows: [RemoteProfile] = try await services.allRows("bibi_profiles")
        let contentRows: [RemoteContent] = try await services.allRows("bibi_content")
        let revisionRows: [RemoteRevision] = try await services.allRows("bibi_content_revisions")
        let mediaRows: [RemoteMedia] = try await services.allRows("bibi_media")
        let followRows: [RemoteRelationship] = try await services.allRows("bibi_follows", keys: ["user_id", "target_id"])
        let blockRows: [RemoteRelationship] = try await services.allRows("bibi_blocks", keys: ["user_id", "target_id"])
        let circleRows: [RemoteCircle] = try await services.allRows("bibi_circles")
        let challengeRows: [RemoteChallenge] = try await services.allRows("bibi_challenges")
        let savedRows: [RemoteSaved] = try await services.allRows("bibi_saved", keys: ["user_id", "content_id"])
        let likeRows: [RemoteSaved] = try await services.allRows("bibi_likes", keys: ["user_id", "content_id"])
        let entryRows: [RemoteEntry] = try await services.allRows("bibi_entries")
        let joinRows: [RemoteCircleMembership] = try await services.allRows("bibi_circle_members", keys: ["user_id", "circle_id"])
        let reportRows: [RemoteReport] = try await services.allRows("bibi_reports")
        let roomRows: [RemoteConversation] = try await services.allRows("bibi_conversations")
        let memberRows: [RemoteMember] = try await services.allRows("bibi_conversation_members", keys: ["conversation_id", "user_id"])
        var messageRows: [UUID: [RemoteMessage]] = [:]
        for room in roomRows { messageRows[room.id] = try await chat.messages(conversation: room.id) }
        let draftRows = try await AccountCache.shared(account: account).drafts()
        var urls: [UUID: URL] = [:]
        for asset in mediaRows where asset.status == "ready" { urls[asset.id] = try? await media.signedURL(asset) }
        var totals: [UUID: RemoteCounts] = [:]
        for record in contentRows where record.kind == "video" { totals[record.id] = try await content.counts(record.id) }
        var profileTotals: [UUID: RemoteProfileCounts] = [:]
        struct Parameters: Encodable { let p_user: UUID }
        for profile in profileRows {
            let value: RemoteProfileCounts = try await services.client.rpc("bibi_profile_counts", params: Parameters(p_user: profile.id)).execute().value
            profileTotals[profile.id] = value
        }
        try services.check(generation)
        profileCounts = profileTotals
        profiles = Dictionary(uniqueKeysWithValues: profileRows.map { ($0.id, $0) })
        records = contentRows.sorted { $0.created_at > $1.created_at }; revisions = Dictionary(uniqueKeysWithValues: revisionRows.map { ($0.id, $0) })
        assets = Dictionary(uniqueKeysWithValues: mediaRows.map { ($0.id, $0) })
        follows = followRows; blocks = blockRows; circles = circleRows; challenges = challengeRows
        saves = Set(savedRows.map(\.content_id)); likes = Set(likeRows.map(\.content_id))
        entries = entryRows; joins = Set(joinRows.map(\.circle_id)); reports = reportRows
        conversations = roomRows; members = memberRows; messages = messageRows; drafts = draftRows
        signedURLs = urls; counts = totals

    }

    func clear() {
        refreshTask?.cancel(); refreshTask = nil; refreshGeneration = nil
        profiles = [:]; records = []; revisions = [:]; assets = [:]; conversations = []; members = []
        messages = [:]; follows = []; blocks = []; circles = []; challenges = []; counts = [:]
        profileCounts = [:]; drafts = [:]; saves = []; likes = []; entries = []; joins = []; reports = []; signedURLs = [:]
        wallet.stop()
        chat.stop(); sync.stop()
    }

    func avatarURL(_ user: UUID) -> URL? {
        records.filter { $0.kind == "avatar" && $0.owner_id == user && !$0.removed && !$0.withdrawn }
            .sorted { $0.created_at > $1.created_at }
            .compactMap { record in record.approved_revision.flatMap { revisions[$0]?.media_id }.flatMap { signedURLs[$0] } }.first
    }

    func creator(_ id: UUID?) -> CreatorProfile {
        guard let id else { return CommunityCatalog.editor }
        let profile = profiles[id]
        return CreatorProfile(id: id.uuidString, name: profile?.display_name ?? "Member",
            biography: profile?.biography ?? "", avatarURL: avatarURL(id), avatarAsset: "BibiMark", following: 0, followers: 0,
            isLocalOwner: id == services.accountID)
    }

    func revision(_ record: RemoteContent) -> RemoteRevision? {
        let id = record.owner_id == services.accountID ? record.pending_revision ?? record.approved_revision : record.approved_revision
        if let selected = id.flatMap({ revisions[$0] }) { return selected }
        guard record.owner_id == services.accountID else { return nil }
        return revisions.values.filter { $0.content_id == record.id }.max { $0.created_at < $1.created_at }
    }

    func projectLibrary() -> LocalLibrary {
        var library = LocalLibrary()
        if let account = services.accountID, let profile = profiles[account] {
            library.profile.remoteAccountID = account
            library.profile.remoteAvatarURL = avatarURL(account)
            library.profile.displayName = profile.display_name; library.profile.biography = profile.biography
        }
        var community = CommunityState()
        community.joinedCircleIDs = joins
        community.savedPostIDs = saves
        community.entries = entries.filter { $0.user_id == services.accountID }.map {
            ChallengeEntry(id: $0.id, challengeID: $0.challenge_id, videoID: $0.video_id, createdAt: $0.created_at)
        }
        for record in records where !record.withdrawn && !record.removed {
            guard let revision = revision(record) else { continue }
            switch record.kind {
            case "post":
                community.posts.append(CirclePost(id: record.id, circleID: record.circle_id ?? "", author: creator(record.owner_id),
                    body: revision.body, videoID: revision.video_id, createdAt: record.created_at, isEditorial: record.editorial,
                    remotePhotoURL: revision.media_id.flatMap { signedURLs[$0] }, remoteStatus: revision.status))
            case "reply":
                if let parent = record.parent_id { community.replies.append(CircleReply(id: record.id, postID: parent, author: creator(record.owner_id), text: revision.body, createdAt: record.created_at)) }
            case "video":
                guard let assetID = revision.media_id, let asset = assets[assetID] else { continue }
                var video = LocalVideo(id: record.id, title: revision.title, fileExtension: "mp4", duration: asset.duration_seconds ?? 0,
                    importedAt: record.created_at, isSaved: saves.contains(record.id), isDance: true)
                video.remoteCreator = creator(record.owner_id); video.remoteMediaID = assetID
                library.videos.append(video)
                if record.approved_revision == nil, record.owner_id == services.accountID {
                    var submission = CreationSubmission(kind: .shortVideo, title: revision.title, caption: revision.body, category: "Animation")
                    submission.id = record.id
                    submission.videoID = record.id
                    submission.status = revision.status == "rejected" ? .rejected : .underReview
                    library.submissions = (library.submissions ?? []) + [submission]
                }
            default: break
            }
        }
        library.community = community
        var creators = CreatorLocalState(); creators.followedIDs = Set(follows.filter { $0.user_id == services.accountID }.map { $0.target_id.uuidString })
        library.creatorState = creators
        var safety = ContentSafetyState()
        for block in blocks { safety.blockedCreators[block.target_id.uuidString] = creator(block.target_id) }
        for report in reports where report.hidden {
            guard let identifier = report.content_id ?? report.target_id else { continue }
            let record = records.first { $0.id == report.content_id }
            let author = creator(record?.owner_id ?? report.target_id)
            let kind: ContentSafetyTarget.Kind = report.content_id == nil ? .profile
                : record?.kind == "post" ? .circlePost : record?.kind == "video" ? .shortVideo : .comment
            safety.reports.append(LocalContentReport(id: report.id, contentID: identifier.uuidString,
                title: kind == .profile ? author.name : "Reported content", kind: kind,
                creatorID: author.id, creatorName: author.name,
                reason: ContentReportReason(rawValue: report.reason) ?? .other,
                details: report.details, savedAt: report.created_at))
        }
        library.contentSafety = safety
        return library
    }

    var inbox: [CommunityConversation] {
        conversations.compactMap { room in
            guard let own = members.first(where: { $0.conversation_id == room.id && $0.user_id == services.accountID }), own.status == "active", !own.hidden else { return nil }
            let peer = members.first { $0.conversation_id == room.id && $0.user_id != services.accountID }
            let person = peer.map { creator($0.user_id) }
            let rows = messages[room.id] ?? []
            return CommunityConversation(id: room.id.uuidString, name: room.kind == "direct" ? person?.name ?? "Conversation" : room.title,
                avatars: ["BibiMark"], kind: room.kind == "direct" ? .person : .group,
                time: rows.last?.created_at.formatted(.dateTime.hour().minute()) ?? "",
                initialUnread: rows.filter { $0.sequence > own.read_sequence && $0.sender_id != services.accountID }.count,
                initiallyPinned: own.pinned, story: nil,
                messages: rows.map { ChatMessage(id: $0.id.uuidString, author: $0.sender_id == services.accountID ? "You" : creator($0.sender_id).name,
                    text: $0.body, time: $0.created_at.formatted(.dateTime.hour().minute()), isOwn: $0.sender_id == services.accountID,
                    createdAt: $0.created_at, isPending: false) }, creator: room.kind == "direct" ? person : nil)
        }
    }
}
