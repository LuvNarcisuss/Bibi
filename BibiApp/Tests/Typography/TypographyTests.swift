import UIKit
import XCTest
@testable import Bibi

final class TypographyTests: XCTestCase {
  @MainActor
  func testEntryStagesBuildAndRefreshAtCompactAndRegularWidths() throws {
    for welcome in [true, false] {
      for width: CGFloat in [320, 393, 430] {
        let controller = EntryController(store: AppStore(), welcome: welcome)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: width, height: 852)
        // A detached controller has no window to enforce the simulated viewport size.
        NSLayoutConstraint.activate([
          controller.view.widthAnchor.constraint(equalToConstant: width),
          controller.view.heightAnchor.constraint(equalToConstant: 852),
        ])
        for _ in 0..<3 {
          controller.refresh()
          controller.view.setNeedsLayout()
          controller.view.layoutIfNeeded()
          XCTAssertEqual(controller.view.bounds.width, width, accuracy: 0.5)
          let hero = try XCTUnwrap(descendants(of: controller.view).first {
            $0.accessibilityIdentifier == "entry.brandHero"
          })
          let logo = try XCTUnwrap(hero.subviews.compactMap { $0 as? UIImageView }.first)
          XCTAssertTrue(hero.superview is UIStackView)
          XCTAssertTrue(logo.isDescendant(of: controller.view))
          XCTAssertGreaterThan(logo.bounds.width, 0)
          XCTAssertLessThanOrEqual(logo.bounds.width, 272.5)
          XCTAssertEqual(logo.bounds.width, logo.bounds.height, accuracy: 0.5)
          // The preferred width can yield to image compression resistance; required bounds cannot.
          XCTAssertLessThanOrEqual(logo.bounds.width, hero.bounds.width + 0.5)
          XCTAssertFalse(logo.hasAmbiguousLayout)
        }
      }
    }
  }

  @MainActor
  private func descendants(of view: UIView) -> [UIView] {
    view.subviews.flatMap { [$0] + descendants(of: $0) }
  }

  @MainActor
  func testBundledFontsResolveWithIntendedWeights() {
    for (isTitle, family, name) in [(true, "Kalam", "Kalam-Bold"),
                                     (false, "Comic Neue", "ComicNeue-Regular")] {
      let font = BibiPalette.font(18, title: isTitle)
      XCTAssertEqual(font.familyName, family)
      XCTAssertEqual(font.fontName, name, "The bundled font must resolve without a system fallback.")
      XCTAssertEqual(font.fontDescriptor.symbolicTraits.contains(.traitBold), isTitle)
    }
  }

  @MainActor
  func testAllRootTitlesLoadOriginalArtwork() throws {
    for title in ["Shorts", "Circles", "Challenges", "Chats", "Me"] {
      let view = StudioTitle(title)
      let imageView = try XCTUnwrap(view.subviews.compactMap { $0 as? UIImageView }.first)
      let image = try XCTUnwrap(imageView.image, "Missing artwork: \(title)")
      XCTAssertFalse(imageView.isHidden)
      XCTAssertEqual(image.renderingMode, .alwaysOriginal)
      XCTAssertEqual(view.accessibilityLabel, title)
      XCTAssertTrue(view.accessibilityTraits.contains(.header))
    }
  }
}


/// Catalog and aggregate regressions run in the existing hosted test target.
final class CommunityProfileTests: XCTestCase {
  @MainActor
  func testEachFictionalAuthorHasPostsAndShorts() throws {
    let clips = AnimationCatalog.entries.filter { $0.surface == .shorts }
    XCTAssertEqual(Set(clips.compactMap(\.curatorID)), Set(CommunityCatalog.storyAuthors.map(\.id)))
    for author in CommunityCatalog.storyAuthors {
      let clip = try XCTUnwrap(clips.first { $0.curatorID == author.id })
      XCTAssertTrue(CommunityCatalog.storyPosts.contains { $0.author.id == author.id })
      let profile = CreatorProfile.from(video: clip.localVideo, profile: LocalProfile(),
                                        coverURL: clip.resourceURL(fileExtension: "jpg"))
      XCTAssertEqual(profile.id, author.id)
      XCTAssertEqual(profile.name, author.name)
      XCTAssertEqual(profile.avatarAsset, author.avatarAsset)
      XCTAssertGreaterThan(author.relationshipStatistics.following, 0)
      XCTAssertGreaterThan(author.relationshipStatistics.followers, 0)
    }
  }

  @MainActor
  func testProfileTotalsIncludePostsAndShorts() {
    let store = AppStore()
    for author in CommunityCatalog.storyAuthors {
      let videos = store.creatorWorks(for: author.id)
      let posts = store.creatorPosts(for: author.id)
      let likes = videos.reduce(0) { $0 + store.shortsSocial.counts(for: $1).likes }
        + posts.reduce(0) { $0 + store.circlePostCounts(for: $1).likes }
      let saves = videos.reduce(0) { $0 + store.shortsSocial.counts(for: $1).saves }
        + posts.reduce(0) { $0 + store.circlePostCounts(for: $1).saves }
      let total = store.statistics(for: author)
      XCTAssertEqual(total.likes, likes)
      XCTAssertEqual(total.saves, saves)
      XCTAssertGreaterThan(total.likes, 0)
      XCTAssertGreaterThan(total.saves, 0)
    }
  }
}
