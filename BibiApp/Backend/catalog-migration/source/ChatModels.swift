import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: String
    let author: String
    let text: String
    let time: String
    let isOwn: Bool
    var createdAt: Date? = nil
    var isPending: Bool? = nil
}

struct CommunityConversation: Identifiable, Hashable {
    enum Kind { case person, group, activity }
    let id: String
    let name: String
    let avatars: [String]
    let kind: Kind
    let time: String
    let initialUnread: Int
    let initiallyPinned: Bool
    let story: String?
    let messages: [ChatMessage]
    var creator: CreatorProfile? = nil
    var summary: String { messages.last?.text ?? "Start with a hello." }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct LocalChatGroup: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var avatarAssets: [String]
    var createdAt: Date
}

struct ChatLocalState: Codable {
    var readIDs: Set<String> = []
    var pinOverrides: [String: Bool] = [:]
    var drafts: [String: String] = [:]
    // Optional fields preserve decoding of earlier library snapshots.
    var sentMessages: [String: [ChatMessage]]? = nil
    var followingOverrides: [String: Bool]? = nil
    var followerIDs: Set<String>? = nil
    var createdGroups: [LocalChatGroup]? = nil
    var unreadMarks: [String: Int]? = nil
    var mutedIDs: Set<String>? = nil
    var hiddenChatIDs: Set<String>? = nil
}

enum ChatInboxFilter: String, CaseIterable, Identifiable {
    case all = "All chats", unread = "Unread", pinned = "Pinned", drafts = "Drafts"
    var id: String { rawValue }
}

/// Community people remain discoverable; inbox entries require personal activity.
enum CommunityChatCatalog {
    static let initialMutualIDs: Set<String> = []
    static let initialFollowerIDs: Set<String> = []
    static let conversations: [CommunityConversation] = [
        CommunityConversation(id: "maya", name: "Maya Chen", avatars: ["Portrait1"], kind: .person, time: "", initialUnread: 0, initiallyPinned: false, story: nil, messages: []),
        CommunityConversation(id: "leo", name: "Leo Brooks", avatars: ["Portrait2"], kind: .person, time: "", initialUnread: 0, initiallyPinned: false, story: nil, messages: []),
        CommunityConversation(id: "zoe", name: "Zoe Park", avatars: ["Portrait3"], kind: .person, time: "", initialUnread: 0, initiallyPinned: false, story: nil, messages: []),
        CommunityConversation(id: "noah", name: "Noah Rivera", avatars: ["Portrait4"], kind: .person, time: "", initialUnread: 0, initiallyPinned: false, story: nil, messages: []),
        CommunityConversation(id: "aria", name: "Aria Wilson", avatars: ["Portrait5"], kind: .person, time: "", initialUnread: 0, initiallyPinned: false, story: nil, messages: []),
        CommunityConversation(id: "finn", name: "Finn Taylor", avatars: ["Portrait6"], kind: .person, time: "", initialUnread: 0, initiallyPinned: false, story: nil, messages: [])
    ]
    static var people: [CommunityConversation] { conversations }
    /// Resolve older user-written drafts/outbox records without restoring authored messages.
    static let legacyGroups: [CommunityConversation] = [
        CommunityConversation(id: "after-class", name: "Starlight Society", avatars: ["Portrait1"], kind: .group, time: "", initialUnread: 0, initiallyPinned: false, story: nil, messages: []),
        CommunityConversation(id: "kpop-circle", name: "Cosplay Constellation", avatars: ["Portrait3"], kind: .group, time: "", initialUnread: 0, initiallyPinned: false, story: nil, messages: []),
        CommunityConversation(id: "ballet-balance", name: "Moonlit Readers", avatars: ["Portrait7"], kind: .group, time: "", initialUnread: 0, initiallyPinned: false, story: nil, messages: [])
    ]
}
