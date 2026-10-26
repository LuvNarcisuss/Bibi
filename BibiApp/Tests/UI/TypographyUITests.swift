import XCTest

/// Runs against the owner's dedicated local QA simulator and existing consent fixture.
final class TypographyUITests: XCTestCase {
  private let titles = ["Shorts", "Circles", "Challenges", "Chats", "Me"]

  override func setUpWithError() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .portrait
  }

  @MainActor
  func testFiveIllustratedTitles() throws {
    try inspectPages(size: "default")
  }

  @MainActor
  func testFiveIllustratedTitlesWithLargerText() throws {
    try inspectPages(size: "larger")
  }

  @MainActor
  private func inspectPages(size: String) throws {
    let app = XCUIApplication()
    if size == "larger" {
      app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]
    }
    app.launch()
    let start = app.buttons["Get started"]
    XCTAssertTrue(start.waitForExistence(timeout: 20))
    reveal(start, in: app)
    start.tap()
    let consent = app.buttons["Agree to the agreements"]
    if consent.exists {
      reveal(consent, in: app)
      consent.tap()
    }
    let enter = app.buttons["Enter Bibi"]
    XCTAssertTrue(enter.waitForExistence(timeout: 5))
    reveal(enter, in: app)
    enter.tap()

    for title in titles {
      let tab = app.buttons["tab.\(title)"]
      XCTAssertTrue(tab.waitForExistence(timeout: 10), "Missing tab: \(title)")
      XCTAssertTrue(tab.isHittable)
      tab.tap()
      let header = app.descendants(matching: .any).matching(identifier: "page-title.\(title)").firstMatch
      XCTAssertTrue(header.waitForExistence(timeout: 8), "Missing illustrated header: \(title)")
      XCTAssertEqual(header.label, title)
      XCTAssertGreaterThanOrEqual(header.frame.height, 30)
      XCTAssertGreaterThanOrEqual(header.frame.width, 60)
      XCTAssertTrue(app.frame.contains(header.frame), "Header outside visible window: \(title)")
      XCTAssertFalse(header.frame.intersects(tab.frame))
      let attachment = XCTAttachment(screenshot: app.screenshot())
      attachment.name = "\(size)-\(title)"
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }

  @MainActor
  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<4 {
      if element.isHittable { return }
      app.swipeUp()
    }
    XCTAssertTrue(element.isHittable)
  }
}
