import AVFoundation
import UIKit
import XCTest
@testable import Bibi

final class AssetResourceTests: XCTestCase {
  @MainActor
  func testNewAccountHasCommunityWithoutPersonalActivity() {
    let store = AppStore()
    XCTAssertTrue(store.library.videos.isEmpty)
    XCTAssertTrue(store.personalWorks.isEmpty)
    XCTAssertTrue(store.likedVideos.isEmpty)
    XCTAssertTrue(store.savedVideos.isEmpty)
    XCTAssertTrue(store.chatConversations.isEmpty)
    XCTAssertTrue(CommunityChatCatalog.initialMutualIDs.isEmpty)
    XCTAssertTrue(CommunityChatCatalog.initialFollowerIDs.isEmpty)
    XCTAssertFalse(store.chatDirectory.isEmpty)
    XCTAssertFalse(store.availableCircles.isEmpty)
    XCTAssertFalse(store.availableChallenges.isEmpty)
    XCTAssertFalse(store.circlePosts().isEmpty)
    XCTAssertFalse(store.shortsDiscoveryVideos.isEmpty)
  }
  private struct Inventory: Decodable {
    let images: [String]
    let resources: [String]
    let colors: [String]
  }

  @MainActor
  func testEveryBundledImageAndColorLoads() throws {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "runtime-asset-inventory", withExtension: "json"))
    let inventory = try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: url))
    XCTAssertEqual(inventory.images.count, 171)
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
    XCTAssertEqual(AnimationCatalog.entries.count, 18)
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

  @MainActor
  func testLooksAndChallengeLedgerRoundTrip() async throws {
    let wallet = WalletStore()
    wallet.adopt(WalletLedger(diamonds: 10_000, activity: [], creditedTransactionIDs: []))
    var saved = WalletLedger.empty
    wallet.setPersist { ledger in saved = ledger; return true }
    var expected = 10_000
    for kind in [CosmeticKind.avatarFrame, .profileBackground, .chatBubble, .chatBackground, .coverTemplate] {
      let item = try XCTUnwrap(CosmeticCatalog.items(kind).first)
      let unlocked = await wallet.unlock(item)
      XCTAssertNil(unlocked)
      expected -= item.diamonds
      XCTAssertEqual(wallet.snapshot.diamonds, expected)
      XCTAssertEqual(wallet.snapshot.cosmetics.equippedID(kind), item.id)
      let repeated = await wallet.unlock(item)
      XCTAssertNil(repeated)
      XCTAssertEqual(wallet.snapshot.diamonds, expected)
      let classic = await wallet.equip(kind, id: nil)
      XCTAssertNil(classic)
      XCTAssertNil(wallet.snapshot.cosmetics.equippedID(kind))
    }
    let paid = await wallet.payForChallenge("qa-challenge")
    XCTAssertNil(paid)
    XCTAssertEqual(wallet.snapshot.diamonds, expected - 100)
    let repeated = await wallet.payForChallenge("qa-challenge")
    XCTAssertNil(repeated)
    XCTAssertEqual(wallet.snapshot.diamonds, expected - 100)
    let refunded = await wallet.refundChallenge("qa-challenge")
    XCTAssertNil(refunded)
    let repeatedRefund = await wallet.refundChallenge("qa-challenge")
    XCTAssertNil(repeatedRefund)
    XCTAssertEqual(wallet.snapshot.diamonds, expected)
    let restored = try JSONDecoder().decode(WalletLedger.self, from: JSONEncoder().encode(saved))
    XCTAssertTrue(restored.isValid)
    XCTAssertEqual(restored.diamonds, expected)
    XCTAssertEqual(restored.snapshot.cosmetics.ownedIDs.count, 5)
    let reloaded = WalletStore()
    reloaded.adopt(restored)
    XCTAssertEqual(reloaded.snapshot.diamonds, expected)
  }

  @MainActor
  func testWalletRejectsInsufficientFundsAndFailedPersistence() async throws {
    let wallet = WalletStore()
    let item = try XCTUnwrap(CosmeticCatalog.items(.avatarFrame).first)
    wallet.adopt(.empty)
    var saves = 0
    wallet.setPersist { _ in saves += 1; return true }
    let insufficient = await wallet.unlock(item)
    XCTAssertNotNil(insufficient)
    let entry = await wallet.payForChallenge("qa-insufficient")
    XCTAssertNotNil(entry)
    XCTAssertEqual(wallet.snapshot.diamonds, 0)
    XCTAssertEqual(saves, 0)
    wallet.adopt(WalletLedger(diamonds: 1_000, activity: [], creditedTransactionIDs: []))
    wallet.setPersist { _ in false }
    let failed = await wallet.unlock(item)
    XCTAssertNotNil(failed)
    XCTAssertEqual(wallet.snapshot.diamonds, 1_000)
    XCTAssertTrue(wallet.snapshot.cosmetics.ownedIDs.isEmpty)
    let failedEntry = await wallet.payForChallenge("qa-failed-save")
    XCTAssertNotNil(failedEntry)
    XCTAssertEqual(wallet.snapshot.diamonds, 1_000)
    XCTAssertTrue(wallet.snapshot.cosmetics.paidChallengeIDs.isEmpty)
  }
}
