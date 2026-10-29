import Foundation

/// One fictional illustration for each persona who appears in chats, rooms, comments, or as a film credit.
/// The same name keeps the same illustration everywhere. Credits are not the real people.
enum CharacterDirectory {
    static let people: [String: String] = [
        "Maya": "Portrait1", "Leo": "Portrait2", "Zoe": "Portrait3", "Noah": "Portrait4",
        "Aria": "Portrait5", "Finn": "Portrait6", "Ivy": "Portrait7", "Oliver": "Portrait8",
        "Elena": "Portrait9", "Emma": "Portrait10", "Priya": "Portrait11", "Nina": "Portrait12",
        "Sofia": "Portrait13", "Isla": "Portrait14", "Chloe": "Portrait15", "Ruby": "Portrait16",
        "Leah": "Portrait17", "Mila": "Portrait18", "Grace": "Portrait19", "Ella": "Portrait20",
        "Freya": "Portrait21", "Alice": "Portrait22", "Lily": "Portrait23", "Eva": "Portrait24",
        "Hazel": "Portrait25", "Sakura": "Portrait26", "Lucy": "Portrait27", "Clara": "Portrait28",
        "Mabel": "Portrait29", "Lena": "Portrait30", "Riley": "Portrait31", "Luca": "Portrait32",
        "Owen": "Portrait33", "Jay": "Portrait34", "Lucas": "Portrait35", "Theo": "Portrait36",
        "Marcus": "Portrait37", "Ethan": "Portrait38", "Adam": "Portrait39", "Oscar": "Portrait40",
        "Alex": "Portrait41", "Jude": "Portrait42", "Hugo": "Portrait43", "Max": "Portrait44",
        "James": "Portrait45", "Daniel": "Portrait46", "Felix": "Portrait47", "Ben": "Portrait48",
        "Cole": "Portrait49", "Miles": "Portrait50",
    ]

    static let creators: [String: String] = [
        "local-owner": "BibiMark",
        "bibi-curator:Animation Club": "Portrait52"
    ]

    static func asset(forName name: String) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? name
        return people[name] ?? people[first] ?? "Portrait1"
    }

    static func asset(forCreator id: String) -> String {
        CommunityCatalog.storyAuthor(id: id)?.avatarAsset ?? creators[id] ?? "Portrait51"
    }
}
