import Foundation

/// Missing or legacy portrait references use interface artwork, never a bundled person.
enum CharacterDirectory {
    static func asset(forName name: String) -> String { "BibiMark" }
    static func asset(forCreator id: String) -> String { "BibiMark" }
}
