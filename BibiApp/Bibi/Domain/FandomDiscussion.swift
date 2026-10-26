import Foundation

/// Authored frontend conversation content, not posts fetched from real accounts.
/// Per-video ordering is repeatable; views never regenerate IDs during rendering.
enum FandomDiscussion {
    struct Line {
        let name: String
        let text: String
        let avatarAsset: String
    }

    static let phrases = [
    "That background deserves a frame of its own.",
    "The color script is beautiful.",
    "One more loop.",
    "I love the quiet worldbuilding here.",
    "Which character would you follow into this world?",
    "The tiny expressions say so much.",
    "Keeping this in my inspiration folder.",
    "A whole story in one glance.",
    "The silhouette reads so clearly.",
    "That transition caught me by surprise.",
    "Soft lighting, strong feelings.",
    "The little details make this world feel lived in.",
    "Anyone else watching the background characters?",
    "That sky is everything.",
    "I keep noticing something new.",
    "The timing makes the scene feel alive.",
    "What a lovely use of negative space.",
    "This scene feels like the start of an adventure.",
    "The palette shifts with the mood.",
    "Team cozy fantasy.",
    "I would happily spend an afternoon in that cafe.",
    "That expression is my entire mood.",
    "The sound design adds so much atmosphere.",
    "A good story does not need many words.",
    "I love the contrast between the warm and cool colors.",
    "The camera movement feels so natural.",
    "Look at the way the light changes.",
    "Saving this for a rainy evening.",
    "The world beyond the frame feels huge.",
    "Every little gesture has personality.",
    "Would you explore the city or the forest first?",
    "This could be the cover of my favorite light novel.",
    "That moment has such good comic timing.",
    "It feels like opening a window into another world.",
    "I like the way the scene lets us slow down.",
    "What would you name this place?",
    "The shadows tell half the story.",
    "A small scene with a big heart.",
    "Those clouds look impossibly soft.",
    "The character design has so much charm.",
    "I am here for the tiny sidekick.",
    "The opening shot pulled me right in.",
    "That final frame stays with you.",
    "A perfect little escape.",
    "The costume colors work so well together.",
    "Anyone else collecting favorite opening themes?",
    "This is giving me ideas for my next sketch.",
    "A cozy watch with friends sounds perfect.",
    "The lighting feels almost like a memory.",
    "My watchlist just got longer.",
    "I wonder what happens beyond that doorway.",
    "Such a satisfying visual rhythm.",
    "The detail in the environment is wonderful.",
    "A good reminder to look closely.",
    "No spoilers, please.",
    "That is a great character entrance.",
    "The scene changes so much when you notice the eyes.",
    "I love stories that leave room for imagination.",
    "This made my day a little brighter.",
    "Same sky, different stories."
]

    private static func stableSeed(for id: UUID) -> UInt64 {
        id.uuidString.utf8.reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
    }

    static func commentCount(for id: UUID) -> Int { 14 + Int(stableSeed(for: id) % 9) }

    static func lines(for video: LocalVideo) -> [Line] {
        let seed = stableSeed(for: video.id)
        var generator = ConversationRandom(state: seed)
        var general = phrases.shuffled(using: &generator)
        let specific = ["I love the atmosphere in " + video.title + ".", "There is so much to notice in this scene."]
        general = specific + general
        let names = ["Emma", "Jay", "Sofia", "Marcus", "Chloe", "Daniel", "Maya", "Alex",
                     "Lena", "Noah", "Riley", "Oliver", "Nina", "Ethan", "Grace", "Lucas",
                     "Zoe", "Theo", "Ruby", "Leo", "Eva", "Finn", "Aria", "Miles"]
        let people = names.indices.shuffled(using: &generator)
        let count = commentCount(for: video.id)
        return general.prefix(count).enumerated().map { index, text in
            let person = people[index % people.count]
            return Line(name: names[person], text: text, avatarAsset: CharacterDirectory.asset(forName: names[person]))
        }
    }

    private struct ConversationRandom: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            return value ^ (value >> 31)
        }
    }
}
