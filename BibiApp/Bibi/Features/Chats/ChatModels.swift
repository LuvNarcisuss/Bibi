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

/// Authored conversations, not downloaded messages or real user activity.
/// Stable IDs let local read, pin and draft state survive catalog reloads.
enum CommunityChatCatalog {
    // Authored relationships for the existing fictional inbox, not remote account data.
    static let initialMutualIDs: Set<String> = ["maya", "leo", "zoe"]
    static let initialFollowerIDs: Set<String> = ["maya", "leo", "zoe", "noah"]
    private static func conversation(_ id: String, _ name: String, avatars: [String], kind: CommunityConversation.Kind = .person,
                                     time: String, unread: Int = 0, pinned: Bool = false, story: String? = nil,
                                     lines: [(String, String)]) -> CommunityConversation {
        let clock = time.split(separator: ":").compactMap { Int($0) }
        let endMinute = clock.count == 2 ? clock[0] * 60 + clock[1] : 13 * 60 + 30
        return CommunityConversation(id: id, name: name, avatars: avatars, kind: kind, time: time,
            initialUnread: unread, initiallyPinned: pinned, story: story,
            messages: lines.enumerated().map { index, line in
                ChatMessage(id: "\(id)-\(index)", author: line.0, text: line.1,
                            time: String(format: "%02d:%02d", (endMinute - lines.count + index + 1) / 60,
                                         (endMinute - lines.count + index + 1) % 60), isOwn: line.0 == "You")
            })
    }
    static let conversations: [CommunityConversation] = [
        conversation("activity", "Bibi notices", avatars: ["BibiMark"], kind: .activity, time: "Today", unread: 1, pinned: false, lines: [
            ("Bibi", "Welcome to your constellation."),
            ("Bibi", "Find a room, save a story, and say hello."),
            ("Bibi", "Your messages and submissions stay on this device until a service is connected."),
        ]),
        conversation("maya", "Maya Chen", avatars: ["Portrait1"], kind: .person, time: "13:25", unread: 2, pinned: true, story: "A new sketchbook and a sky full of ideas.", lines: [
            ("Maya", "Have you seen the colors in that new animation?"),
            ("You", "The violet sky is my favorite."),
            ("Maya", "I saved it for my next character sketch."),
            ("Maya", "Meet me in Moonlit Cafe?"),
        ]),
        conversation("after-class", "Starlight Society", avatars: ["Portrait1", "Portrait2", "Portrait3", "Portrait4"], kind: .group, time: "12:48", unread: 4, pinned: false, lines: [
            ("Noah", "Cozy fantasy or space adventure tonight?"),
            ("Zoe", "Space adventure!"),
            ("You", "I will bring a spoiler-free watchlist."),
            ("Leo", "Meet you under the stars."),
        ]),
        conversation("leo", "Leo Brooks", avatars: ["Portrait2"], kind: .person, time: "11:42", unread: 0, pinned: false, story: "Opening themes on repeat.", lines: [
            ("Leo", "Found a soundtrack you might like."),
            ("You", "Is it the one with the quiet piano opening?"),
            ("Leo", "Yes! It feels like walking through a rainy city."),
        ]),
        conversation("zoe", "Zoe Park", avatars: ["Portrait3"], kind: .person, time: "Yesterday", unread: 1, pinned: false, story: "One more chapter before sleep.", lines: [
            ("Zoe", "The background art in this chapter is incredible."),
            ("You", "I keep stopping to look at the panels."),
            ("Zoe", "Same. The little details tell their own story."),
        ]),
        conversation("noah", "Noah Rivera", avatars: ["Portrait4"], kind: .person, time: "Yesterday", unread: 0, pinned: false, story: "Building a tiny universe, one character at a time.", lines: [
            ("Noah", "Working on an original character tonight."),
            ("You", "What kind of world do they live in?"),
            ("Noah", "A floating city above the clouds."),
        ]),
        conversation("kpop-circle", "Cosplay Constellation", avatars: ["Portrait3", "Portrait5", "Portrait6", "Portrait2"], kind: .group, time: "Thu", unread: 3, pinned: false, lines: [
            ("Aria", "My star hairpin is finally finished."),
            ("Finn", "The cyan highlight looks great."),
            ("You", "Would love to hear about the costume details."),
        ]),
        conversation("aria", "Aria Wilson", avatars: ["Portrait5"], kind: .person, time: "Wed", unread: 0, pinned: false, story: "Sakura skies and costume details.", lines: [
            ("Aria", "Which color works better for the cape?"),
            ("You", "Lavender with a darker lining."),
            ("Aria", "That is exactly the mood I wanted."),
        ]),
        conversation("finn", "Finn Taylor", avatars: ["Portrait6"], kind: .person, time: "Tue", unread: 0, pinned: false, story: "Reading stories from another world.", lines: [
            ("Finn", "Started a new fantasy story."),
            ("You", "No spoilers, but is the world interesting?"),
            ("Finn", "There is a library inside a giant tree."),
        ]),
        conversation("ballet-balance", "Moonlit Readers", avatars: ["Portrait7", "Portrait8", "Portrait9"], kind: .group, time: "Mon", unread: 0, pinned: false, lines: [
            ("Ivy", "Favorite quiet scene of the week?"),
            ("Oliver", "The cafe window in the rain."),
            ("Elena", "A good story can be such a small thing."),
        ]),
    ]
    static var people: [CommunityConversation] { conversations.filter { $0.kind == .person } }
}
