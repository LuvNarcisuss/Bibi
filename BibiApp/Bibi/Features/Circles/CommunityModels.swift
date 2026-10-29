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
      artwork: "PostCover-RedHorns",
      prompt:
        "Which tiny animation detail made a story feel alive to you? Share a frame, a thought, or your own short."
    ),
    InterestCircle(
      id: "characters", title: "Character Corner", subtitle: "Big feelings. Favorite characters.",
      artwork: "PostCover-RedBlackHair",
      prompt:
        "Design a character around one unexpected strength. What would their first adventure be?"),
    InterestCircle(
      id: "sketchbook", title: "Sketchbook Society",
      subtitle: "From first sketch to original world", artwork: "PostCover-PinkBows",
      prompt:
        "Show a work in progress and tell us one thing you want to try next. Credit every reference you use."
    ),
    InterestCircle(
      id: "cosplay", title: "Cosplay Studio", subtitle: "Bring your imagination to life",
      artwork: "PostCover-BlueBow",
      prompt:
        "What everyday object could become a prop for an original character? Share your process, not just the result."
    ),
  ]
  static let challenges = [
    CreativeChallenge(
      id: "first-frame", title: "One Frame, One Feeling", category: "Animation",
      summary: "Tell a small story through color, movement and one clear emotion.",
      artwork: "ChallengeCover-OrangeScarf",
      steps: [
        "Choose an emotion and a simple setting.",
        "Create a short scene with your own art or licensed footage.",
        "Add a title and explain your creative choice.",
      ], exampleIndex: 0),
    CreativeChallenge(
      id: "character-switch", title: "Character Switch", category: "Cosplay",
      summary: "Turn an everyday look into a character from your imagination.",
      artwork: "ChallengeCover-BlueCostume",
      steps: [
        "Sketch an original character or credit your inspiration.",
        "Film a safe transition using clothing, props or editing.",
        "Share the transformation in a short video.",
      ], exampleIndex: 1),
    CreativeChallenge(
      id: "world-sketch", title: "Build a Tiny World", category: "Art",
      summary: "Give a sketch, model or miniature a story of its own.", artwork: "ChallengeCover-GreenArmor",
      steps: [
        "Pick a place that could only exist in your world.",
        "Record your process or a short tour of the finished piece.",
        "Introduce the world with an English title and caption.",
      ], exampleIndex: 2),
    CreativeChallenge(
      id: "quiet-story", title: "A Story Without Words", category: "Animation",
      summary: "Make a character's intention clear without dialogue.", artwork: "ChallengeCover-WhiteFox",
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

  /// Authored fiction for local browsing only; never mixed into the online feed.
  static let storyAuthors: [CreatorProfile] = [
    CreatorProfile(id: "bibi-story:luna", name: "Luna Frames", biography: "A fictional Bibi character who loves quiet animation and moonlit scenes.", avatarAsset: "Avatar-LunaCosplay", following: 18, followers: 23),
    CreatorProfile(id: "bibi-story:kai", name: "Kai Orbit", biography: "A fictional Bibi character exploring space stations and expressive silhouettes.", avatarAsset: "Avatar-KaiPortrait", following: 24, followers: 17),
    CreatorProfile(id: "bibi-story:mira", name: "Mira Ink", biography: "A fictional Bibi character collecting story ideas in a sketchbook.", avatarAsset: "Avatar-MiraPortrait", following: 16, followers: 28),
    CreatorProfile(id: "bibi-story:rowan", name: "Rowan Tales", biography: "A fictional Bibi character imagining libraries, gardens and gentle adventures.", avatarAsset: "Portrait4", following: 21, followers: 19),
    CreatorProfile(id: "bibi-story:nova", name: "Nova Stitch", biography: "A fictional Bibi character planning original costumes and lightweight props.", avatarAsset: "Avatar-NovaCosplay", following: 14, followers: 26),
    CreatorProfile(id: "bibi-story:theo", name: "Theo Lantern", biography: "A fictional Bibi character fascinated by color, lighting and tiny worlds.", avatarAsset: "Avatar-TheoCosplay", following: 27, followers: 22),
  ]

  static func storyAuthor(id: String) -> CreatorProfile? {
    storyAuthors.first { $0.id == id }
  }

  static let storyMedia: [String: (credit: String, source: String, description: String)] = [
    "PostCover-RedHorns": ("Photo: Quyet Nguyen · Pexels", "https://www.pexels.com/photo/vibrant-anime-cosplay-costume-portrait-39797621/", "A cosplayer in a red dress with blue horn accessories and clasped hands."),
    "PostCover-PinkSuit": ("Photo: Mario Spencer · Pexels", "https://www.pexels.com/photo/cosplay-enthusiast-at-outdoor-anime-convention-29901442/", "A cosplayer with a pink wig and a black suit turned toward another attendee."),
    "PostCover-MintHall": ("Photo: TBD Tuyen · Pexels", "https://www.pexels.com/photo/cosplay-character-at-convention-center-event-37206376/", "A cosplayer with mint hair standing in a busy convention hall."),
    "PostCover-RedBlackHair": ("Photo: TBD Tuyen · Pexels", "https://www.pexels.com/photo/colorful-cosplay-portrait-at-convention-33156707/", "A close portrait of a cosplayer with black and red hair holding the ends of the wig."),
    "PostCover-GreenHeadband": ("Photo: Martin.que · Pexels", "https://www.pexels.com/photo/cosplay-enthusiast-in-anime-character-costume-29797036/", "A cosplayer with a dark wig, a green and yellow headband and a cream vest."),
    "PostCover-PurpleRibbon": ("Photo: Vladimir Flores · Pexels", "https://www.pexels.com/photo/stylish-anime-inspired-cosplay-portrait-35526892/", "A cosplayer with a purple wig, a white sleeveless shirt and a long black ribbon."),
    "PostCover-PinkBows": ("Photo: Tiến Anh Hoàng · Pexels", "https://www.pexels.com/photo/vibrant-cosplayer-in-pink-wig-and-dress-at-convention-32313090/", "A cosplayer in a pink wig and a pastel dress covered in bows and lace."),
    "PostCover-PinkBraids": ("Photo: Mario Spencer · Pexels", "https://www.pexels.com/photo/anime-cosplay-enthusiast-with-pink-hair-in-costa-rica-29901306/", "A smiling cosplayer with pink and yellow braids and a white coat."),
    "PostCover-PinkCape": ("Photo: Hoàng Tiến Anh · Pexels", "https://www.pexels.com/photo/pink-haired-cosplay-enthusiast-at-convention-31471180/", "A cosplayer with a pink bob, a red outfit and a cream cape, arms crossed."),
    "PostCover-SteampunkCostume": ("Photo: Vika Glitter · Pexels", "https://www.pexels.com/photo/a-woman-wearing-a-steampunk-costume-9849182/", "A steampunk costume with goggles, a top hat and a small belt bag."),
    "PostCover-PinkArmor": ("Photo: TBD Tuyen · Pexels", "https://www.pexels.com/photo/stunning-cosplay-portrait-with-pink-wig-and-armor-37301596/", "A cosplayer with a pink wig, silver ear pieces and red and teal armor."),
    "PostCover-BlueBow": ("Photo: Sơn Ngọc · Pexels", "https://www.pexels.com/photo/young-woman-in-blue-wig-and-red-bow-at-convention-28793664/", "A cosplayer with long blue hair, a large red bow and a white dress with gold trim."),
    "PostCover-CosplayConvention": ("Video still: TBD Tuyen · Pexels", "https://www.pexels.com/video/cosplay-portrait-with-detailed-costume-in-indoor-setting-31038234/", "A lavender cosplay costume with butterfly details."),
    "PostCover-CosplayGarden": ("Video still: TBD Tuyen · Pexels", "https://www.pexels.com/video/elegant-woman-in-intricate-cosplay-costume-30794058/", "A silver and blue cosplay costume with a floral prop."),
  ]

  static let challengeMedia: [String: (credit: String, source: String, description: String)] = [
    "ChallengeCover-OrangeScarf": ("Photo: 阮 南庆 · Pexels", "https://www.pexels.com/photo/dynamic-anime-cosplay-character-portrait-29355064/", "A close portrait of a cosplayer with orange hair, a red scarf and a dark glove."),
    "ChallengeCover-BlueCostume": ("Photo: Quyet Nguyen · Pexels", "https://www.pexels.com/photo/anime-inspired-blue-costume-cosplay-portrait-39815674/", "A cosplayer in a blue and white costume with a light blue wig and a black bow."),
    "ChallengeCover-GreenArmor": ("Photo: Calvin Seng · Pexels", "https://www.pexels.com/photo/vibrant-cosplay-portrait-at-anime-convention-31490103/", "A cosplayer with green hair and black-and-gold armor in front of pink blossoms."),
    "ChallengeCover-WhiteFox": ("Photo: Martin.que · Pexels", "https://www.pexels.com/photo/elegant-cosplay-portrait-at-anime-convention-30462155/", "A close portrait of a cosplayer with long white hair and pale fox ears."),
    "ChallengeCover-GothicPair": ("Photo: TBD Tuyen · Pexels", "https://www.pexels.com/photo/cosplayers-in-gothic-attire-at-convention-37206401/", "Two cosplayers in black gothic costumes with mint hair at a convention."),
  ]

  private struct Story {
    let id: Int
    let circle: String
    let author: Int
    var artwork: String? = nil
    let body: String
    let replies: [String]
  }

  // IDs and dates are fixed editorial metadata, not live activity timestamps.
  private static let stories: [Story] = [
    Story(id: 1, circle: "animation", author: 0, artwork: "PostCover-RedHorns",
      body: "Costume reference: clasped hands, a red dress and two blue horns make the silhouette readable before anyone moves. I would study this pose for a one-frame animation of someone gathering courage. Which detail would you move first?",
      replies: ["The hands. A small opening of the fingers could show the decision.", "I would move one horn ribbon so the stillness feels deliberate."]),
    Story(id: 2, circle: "animation", author: 1, artwork: "PostCover-PinkSuit",
      body: "A convention reference: pink hair, a black jacket and a red bow, turned toward another person. The conversation is already happening in the body language. For a short animated exchange, would you start on the listener or the speaker?",
      replies: ["The listener first. The turn of the head already tells me who is speaking.", "I would start on the red bow, then reveal the other person."]),
    Story(id: 3, circle: "animation", author: 5, artwork: "PostCover-MintHall",
      body: "Hall study: one mint-haired costume stands still while the convention keeps moving behind them. That contrast could be a quiet establishing shot. Would you hold the pose or let the background carry the motion?",
      replies: ["Hold the pose. The busy hall does the moving for you.", "A slow blink would be enough. The coat already feels heavy and calm."]),
    Story(id: 4, circle: "characters", author: 3, artwork: "PostCover-RedBlackHair",
      body: "Character notebook from a licensed cosplay portrait: black roots into red lengths, both hands gathering the hair. The face stays calm while the color does the talking. Which feature would you exaggerate in an original design?",
      replies: ["The color break in the hair. It reads from across a room.", "I would keep the calm face and make the hands more deliberate."]),
    Story(id: 5, circle: "characters", author: 2, artwork: "PostCover-GreenHeadband",
      body: "Character reference: a green and yellow headband, two white pom-poms and a cream vest over green. The costume reads clearly from the shoulders up. Which piece would you keep if you had to simplify it?",
      replies: ["The headband. The yellow stripe is enough to recognize the character.", "I would keep one pom-pom and drop the rest."]),
    Story(id: 6, circle: "characters", author: 1, artwork: "PostCover-PurpleRibbon",
      body: "Design exercise from a licensed portrait: a purple wig covering one eye, a white shirt and a long black ribbon. The hidden eye makes the character feel like they are deciding something. What ordinary weakness would you give them?",
      replies: ["They can face a crowd but cannot look someone in the eye while asking for help.", "The ribbon could be a lucky charm they are afraid to lose."]),
    Story(id: 7, circle: "sketchbook", author: 2, artwork: "PostCover-PinkBows",
      body: "Costume study: a bright pink wig and a dress built from small bows, lace and pastel ribbons. The repeating shapes make the whole outfit feel like one idea. Which motif would you repeat in an original design?",
      replies: ["The bows. One size, used on the hair, cuffs and skirt.", "I would repeat the heart-shaped choker detail instead."]),
    Story(id: 8, circle: "sketchbook", author: 3, artwork: "PostCover-PinkBraids",
      body: "Color study: pink braids fading into yellow, a white coat and a wide smile. The expression is as much a part of the character as the wig. What emotion would you pair with a bright costume?",
      replies: ["Relief, like they just found the person they were looking for.", "Mischief. The smile can do more work than another accessory."]),
    Story(id: 9, circle: "sketchbook", author: 5, artwork: "PostCover-PinkCape",
      body: "Reference from a finished costume: pink hair, a red jacket and a cream cape, with the arms crossed. I would draw three versions and change only the light. Which time of day would you choose?",
      replies: ["Late afternoon, so the cape edge catches a warm rim.", "Night, with the string lights behind them kept soft."]),
    Story(id: 10, circle: "cosplay", author: 4, artwork: "PostCover-SteampunkCostume",
      body: "Costume reference: goggles, a tall hat and a small belt bag make this steampunk silhouette immediately readable. For an original airship courier, I would choose one of those details and simplify the rest. Which accessory tells the strongest story?",
      replies: ["The goggles suggest a job before the character says anything.", "The belt bag could hold maps, tools or one mysterious letter."]),
    Story(id: 11, circle: "cosplay", author: 5, artwork: "PostCover-PinkArmor",
      body: "Costume reference: silver ear pieces, a pink wig and red-and-teal armor. The metal shapes frame the face before the dress does. Which piece would you build first for an original character?",
      replies: ["The ear pieces. They make the silhouette recognizable from the side.", "I would start with one shoulder guard and keep the rest simple."]),
    Story(id: 12, circle: "cosplay", author: 4, artwork: "PostCover-BlueBow",
      body: "Costume study: long blue hair, a large red bow and a white dress with gold trim. The bow is the first thing I notice. Which single accent would you choose for an original look?",
      replies: ["One oversized bow, and almost no other decoration.", "Gold trim on the hem could be the only accent if the bow stays small."]),
    Story(id: 13, circle: "cosplay", author: 4, artwork: "PostCover-CosplayConvention",
      body: "Costume study: this licensed cosplay reference repeats butterfly shapes across the headpiece and gloves. The lavender fabric ties the details together. Which small motif would you repeat in an original costume?",
      replies: ["Repeating one shape makes the costume feel connected.", "I would try a moon motif on the collar and cuffs."]),
    Story(id: 14, circle: "characters", author: 5, artwork: "PostCover-CosplayGarden",
      body: "Color study from a licensed cosplay reference: the blue flower stands out against silver fabric. A single accent can give a character a strong visual identity. What color would you choose for your own design?",
      replies: ["Deep blue keeps the silver from feeling flat.", "A warm accent could create a very different mood."]),
  ]

  static let storyPosts: [CirclePost] = stories.map { story in
    CirclePost(
      id: UUID(uuidString: String(format: "CB120000-0000-4000-8000-%012d", story.id))!,
      circleID: story.circle, author: storyAuthors[story.author], body: story.body,
      createdAt: Date(timeIntervalSince1970: 1_792_929_600 + Double((13 - story.id) * 3600)),
      bundledArtwork: story.artwork)
  }

  static let storyReplies: [CircleReply] = stories.flatMap { story in
    story.replies.enumerated().map { index, text in
      CircleReply(
        id: UUID(uuidString: String(format: "CB130000-0000-4000-8000-%012d", story.id * 10 + index))!,
        postID: UUID(uuidString: String(format: "CB120000-0000-4000-8000-%012d", story.id))!,
        author: storyAuthors[(story.author + index + 1) % storyAuthors.count], text: text,
        createdAt: Date(timeIntervalSince1970: 1_792_929_600 + Double((13 - story.id) * 3600 + (index + 1) * 300)))
    }
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
