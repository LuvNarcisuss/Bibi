import Foundation

/// Retired business portraits use the brand mark; interface artwork keeps its name.
enum CommunityArtwork {
  static func avatar(_ asset: String) -> String {
    if asset.hasPrefix("Portrait") || asset.hasPrefix("Avatar-")
      || asset.hasPrefix("PostCover-") || asset.hasPrefix("ChallengeCover-") { return "BibiMark" }
    return asset
  }
  static func creatorAvatar(for id: String) -> String { "BibiMark" }
  static func story(for id: String) -> String { "BibiWelcome" }
}
