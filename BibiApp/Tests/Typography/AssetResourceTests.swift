import AVFoundation
import UIKit
import XCTest
@testable import Bibi

final class AssetResourceTests: XCTestCase {
  private struct Inventory: Decodable {
    let images: [String]
    let resources: [String]
    let colors: [String]
  }

  @MainActor
  func testEveryBundledImageAndColorLoads() throws {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "runtime-asset-inventory", withExtension: "json"))
    let inventory = try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: url))
    XCTAssertEqual(inventory.images.count, 138)
    for name in inventory.images {
      let image = try XCTUnwrap(UIImage(named: name), "Missing image: \(name)")
      XCTAssertGreaterThan(image.size.width, 0, name)
      XCTAssertGreaterThan(image.size.height, 0, name)
    }
    for name in inventory.colors {
      XCTAssertNotNil(UIColor(named: name), "Missing color: \(name)")
    }
    for filename in inventory.resources {
      let path = Bundle.main.bundleURL.appendingPathComponent(filename)
      XCTAssertTrue(FileManager.default.fileExists(atPath: path.path), "Missing resource: \(filename)")
    }
    for excluded in ["original-hero.mp4", "original-spring.mp4", "review-contact-1.jpg",
                     "generated-welcome.png", "asset-migration.json"] {
      XCTAssertFalse(FileManager.default.fileExists(atPath: Bundle.main.bundleURL.appendingPathComponent(excluded).path))
    }
    XCTAssertNotNil(Bundle.main.url(forResource: "AppIcon60x60@2x", withExtension: "png"))
  }

  func testAllVideosAndCoversDecodeFromBundle() async throws {
    XCTAssertEqual(AnimationCatalog.entries.count, 16)
    for clip in AnimationCatalog.entries {
      let url = clip.resourceURL(fileExtension: "mp4")
      XCTAssertEqual(url.deletingLastPathComponent(), Bundle.main.bundleURL)
      let asset = AVURLAsset(url: url)
      let playable = try await asset.load(.isPlayable)
      let duration = try await asset.load(.duration)
      XCTAssertTrue(playable, clip.assetName)
      XCTAssertEqual(duration.seconds, clip.duration, accuracy: 0.15, clip.assetName)
      let cover = clip.resourceURL(fileExtension: "jpg")
      XCTAssertNotNil(UIImage(contentsOfFile: cover.path), clip.assetName)
      let generator = AVAssetImageGenerator(asset: asset)
      generator.maximumSize = CGSize(width: 80, height: 80)
      let frame = try await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600))
      XCTAssertGreaterThan(frame.image.width, 0, clip.assetName)
    }
  }

  func testAgreementFallbackReadsFlatHTML() throws {
    for document in AgreementDocument.allCases {
      let url = try XCTUnwrap(document.fileURL)
      XCTAssertEqual(url.deletingLastPathComponent(), Bundle.main.bundleURL)
      let html = try String(contentsOf: url, encoding: .utf8)
      XCTAssertTrue(html.contains("Bibi"))
      XCTAssertTrue(html.contains("</html>"))
    }
    XCTAssertTrue(BibiUserAgreement.version.hasPrefix("local-"))
  }
}
