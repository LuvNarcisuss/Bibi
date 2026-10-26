import Foundation

enum CommunityArtwork {
  static func avatar(_ asset: String) -> String {
    let mapping = [
      "ChatAvatar1": "Portrait1", "ChatAvatar2": "Portrait2",
      "ChatAvatar3": "Portrait3", "ChatAvatar4": "Portrait4",
      "ChatAvatar5": "Portrait5", "ChatAvatar6": "Portrait6",
      "ChatAvatar7": "Portrait7", "ChatAvatar8": "Portrait8",
      "PartyAvatar1": "Portrait1", "PartyAvatar2": "Portrait2",
      "PartyAvatar3": "Portrait3", "PartyAvatar4": "Portrait4",
    ]
    return mapping[asset] ?? asset
  }
  /// Photographic artwork for a creator account, not a claim about the credited filmmaker.
  static func creatorAvatar(for id: String) -> String {
    CharacterDirectory.asset(forCreator: id)
  }

  static func story(for id: String) -> String {
    let stories = [
      "maya": "BibiRoom1", "leo": "BibiRoom7",
      "zoe": "BibiRoom1", "noah": "BibiRoom7",
      "aria": "BibiRoom1", "finn": "BibiRoom7",
    ]
    return stories[id] ?? "BibiRoom7"
  }

}
