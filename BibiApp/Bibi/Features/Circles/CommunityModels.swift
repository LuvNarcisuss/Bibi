import Foundation

struct InterestCircle: Identifiable {
  let id: String
  let title: String
  let subtitle: String
  let artwork: String
  let prompt: String
  var artworkURL: URL? = nil
}

struct CreativeChallenge: Identifiable {
  let id: String
  let title: String
  let category: String
  let summary: String
  let artwork: String
  let steps: [String]
  let exampleIndex: Int
  var artworkURL: URL? = nil
}

/// Compatibility interfaces contain no bundled community payloads.
/// Current circles, challenges, editorial profiles and discussions come from Supabase.
enum CommunityCatalog {
  static let circles: [InterestCircle] = []
  static let challenges: [CreativeChallenge] = []
  static let prompts: [CirclePost] = []
  static let storyAuthors: [CreatorProfile] = []
  static let storyPosts: [CirclePost] = []
  static let storyReplies: [CircleReply] = []
  static let storyMedia: [String: (credit: String, source: String, description: String)] = [:]
  static let challengeMedia: [String: (credit: String, source: String, description: String)] = [:]

  static func storyAuthor(id: String) -> CreatorProfile? { nil }
}

struct CirclePost: Identifiable, Codable {
  var id = UUID()
  let circleID: String
  let author: CreatorProfile
  let body: String
  var photo: Data? = nil
  var videoID: UUID? = nil
  var createdAt = Date()
  var isEditorial = false
  var remotePhotoURL: URL? = nil
  var remoteStatus: String? = nil
  var bundledArtwork: String? = nil
  var coverStyleID: String? = nil

  var isCharacterStory: Bool { author.id.hasPrefix("bibi-story:") }
}

struct CircleReply: Identifiable, Codable {
  var id = UUID()
  let postID: UUID
  let author: CreatorProfile
  let text: String
  var createdAt = Date()
}

struct ChallengeEntry: Identifiable, Codable {
  var id = UUID()
  let challengeID: String
  let videoID: UUID
  var createdAt = Date()
}

/// Optional in LocalLibrary; older accounts decode without any community state.
struct CommunityState: Codable {
  var joinedCircleIDs: Set<String> = []
  var posts: [CirclePost] = []
  var replies: [CircleReply] = []
  var savedPostIDs: Set<UUID> = []
  var entries: [ChallengeEntry] = []

  mutating func removeVideo(_ id: UUID) {
    entries.removeAll { $0.videoID == id }
    for index in posts.indices where posts[index].videoID == id { posts[index].videoID = nil }
  }
}
