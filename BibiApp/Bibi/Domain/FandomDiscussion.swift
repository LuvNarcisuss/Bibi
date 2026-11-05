import Foundation

/// Legacy call sites cannot manufacture comments or engagement for a video.
enum FandomDiscussion {
    struct Line {
        let name: String
        let text: String
        let avatarAsset: String
    }
    static func commentCount(for id: UUID) -> Int { 0 }
    static func lines(for video: LocalVideo) -> [Line] { [] }
}
