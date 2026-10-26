import CoreText
import UIKit
import XCTest
@testable import Bibi

final class TypographyTests: XCTestCase {
  @MainActor
  func testBundledFontsResolveWithIntendedWeights() {
    for (isTitle, family, weight) in [(true, "Fredoka", 600.0), (false, "Nunito", 500.0)] {
      let font = BibiPalette.font(18, title: isTitle)
      XCTAssertTrue(font.familyName.contains(family), "Unexpected font: \(font.fontName)")
      let variations = CTFontCopyVariation(font as CTFont) as? [NSNumber: NSNumber]
      XCTAssertEqual(variations?[NSNumber(value: 0x77676874)]?.doubleValue, weight)
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
