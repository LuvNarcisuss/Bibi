import Foundation

enum ContentSurface: String, Decodable { case live, shorts }

/// An explicitly credited excerpt, independent of the fictional community curator.
struct AnimationClip: Decodable {
  let id: UUID
  let title: String
  let creator: String
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
  func resourceURL(fileExtension: String) -> URL {
    Bundle.main.url(forResource: assetName, withExtension: fileExtension)
      ?? Bundle.main.bundleURL.appendingPathComponent("\(assetName).\(fileExtension)")
  }
}

/// Editorial content is versioned data; interactions remain keyed by immutable UUIDs.
enum AnimationCatalog {
  static let entries: [AnimationClip] = {
    guard let url = Bundle.main.url(forResource: "animation-catalog", withExtension: "json"),
          let bytes = try? Data(contentsOf: url),
          let clips = try? JSONDecoder().decode([AnimationClip].self, from: bytes),
          Set(clips.map(\.id)).count == clips.count,
          Set(clips.map(\.assetName)).count == clips.count,
          clips.allSatisfy({ !$0.assetName.isEmpty && $0.duration > 0 && $0.duration <= 180 })
    else { return [] }
    return clips
  }()

  static func shuffledDiscoveryIDs(for surface: ContentSurface) -> [UUID] {
    let batches = Dictionary(grouping: entries.filter { $0.surface == surface }, by: \.collectionGeneration)
    return batches.keys.sorted(by: >).flatMap { generation in
      (batches[generation] ?? []).shuffled().map(\.id)
    }
  }
}
