import Foundation

struct InterestCircle: Identifiable {
  let id: String
  let title: String
  let subtitle: String
  let artwork: String
  let prompt: String
}

struct CreativeChallenge: Identifiable {
  let id: String
  let title: String
  let category: String
  let summary: String
  let artwork: String
  let steps: [String]
  let exampleIndex: Int
}

enum CommunityCatalog {
  static let circles = [
    InterestCircle(
      id: "animation", title: "Animation Club", subtitle: "Frames worth talking about",
      artwork: "BibiRoom4",
      prompt:
        "Which tiny animation detail made a story feel alive to you? Share a frame, a thought, or your own short."
    ),
    InterestCircle(
      id: "characters", title: "Character Corner", subtitle: "Big feelings. Favorite characters.",
      artwork: "BibiRoom2",
      prompt:
        "Design a character around one unexpected strength. What would their first adventure be?"),
    InterestCircle(
      id: "sketchbook", title: "Sketchbook Society",
      subtitle: "From first sketch to original world", artwork: "BibiRoom6",
      prompt:
        "Show a work in progress and tell us one thing you want to try next. Credit every reference you use."
    ),
    InterestCircle(
      id: "cosplay", title: "Cosplay Studio", subtitle: "Bring your imagination to life",
      artwork: "BibiRoom8",
      prompt:
        "What everyday object could become a prop for an original character? Share your process, not just the result."
    ),
  ]
  static let challenges = [
    CreativeChallenge(
      id: "first-frame", title: "One Frame, One Feeling", category: "Animation",
      summary: "Tell a small story through color, movement and one clear emotion.",
      artwork: "BibiRoom4",
      steps: [
        "Choose an emotion and a simple setting.",
        "Create a short scene with your own art or licensed footage.",
        "Add a title and explain your creative choice.",
      ], exampleIndex: 0),
    CreativeChallenge(
      id: "character-switch", title: "Character Switch", category: "Cosplay",
      summary: "Turn an everyday look into a character from your imagination.",
      artwork: "BibiRoom8",
      steps: [
        "Sketch an original character or credit your inspiration.",
        "Film a safe transition using clothing, props or editing.",
        "Share the transformation in a short video.",
      ], exampleIndex: 1),
    CreativeChallenge(
      id: "world-sketch", title: "Build a Tiny World", category: "Art",
      summary: "Give a sketch, model or miniature a story of its own.", artwork: "BibiRoom6",
      steps: [
        "Pick a place that could only exist in your world.",
        "Record your process or a short tour of the finished piece.",
        "Introduce the world with an English title and caption.",
      ], exampleIndex: 2),
    CreativeChallenge(
      id: "quiet-story", title: "A Story Without Words", category: "Animation",
      summary: "Make a character's intention clear without dialogue.", artwork: "BibiRoom2",
      steps: [
        "Give your character one small goal.",
        "Use a gesture, expression or visual change to tell the story.",
        "Keep it under three minutes and credit your sources.",
      ], exampleIndex: 3),
  ]
  static let editor = CreatorProfile(
    id: "bibi-editor", name: "Bibi Editorial", biography: "Creative prompts for your next story.",
    avatarAsset: "Portrait52")
  static let prompts: [CirclePost] = circles.enumerated().map { index, circle in
    CirclePost(
      id: UUID(uuidString: "CB110000-0000-4000-8000-00000000000\(index)")!, circleID: circle.id,
      author: editor, body: circle.prompt, createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      isEditorial: true)
  }
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
