import Foundation

enum ContentSurface: String, Decodable { case live, shorts }

/// An explicitly credited excerpt, independent of the fictional community curator.
struct AnimationClip: Decodable {
  let id: UUID
  let title: String
  let creator: String
  let curatorID: String?
  let legacyCuratorID: String?
  let assetName: String
  let duration: Double
  let surface: ContentSurface
  let sourceURL: URL
  let collectionGeneration: Int
  let caption: String
  let credit: String

  var localVideo: LocalVideo {
    LocalVideo(id: id, title: title, fileExtension: "mp4", duration: duration,
               importedAt: Date(timeIntervalSince1970: 0), isSaved: false, isDance: true)
  }

}

/// Legacy type compatibility only. Editorial discovery is loaded from Supabase.
enum AnimationCatalog {
  static let entries: [AnimationClip] = []
  static func shuffledDiscoveryIDs(for surface: ContentSurface) -> [UUID] { [] }
}
