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
  func testEntryConsentRefreshKeepsLogoAndActionsAvailable() throws {
    let app = XCUIApplication()
    app.launch()
    let start = app.buttons["Get started"]
    XCTAssertTrue(start.waitForExistence(timeout: 25))
    reveal(start, in: app)
    start.tap()
    for _ in 0..<3 {
      let unchecked = app.buttons["Agree to the agreements"]
      XCTAssertTrue(unchecked.waitForExistence(timeout: 5))
      reveal(unchecked, in: app)
      unchecked.tap()
      let checked = app.buttons["Agreement checked"]
      XCTAssertTrue(checked.waitForExistence(timeout: 5))
      reveal(checked, in: app)
      checked.tap()
    }
    let entry = app.buttons["Enter Bibi"]
    XCTAssertTrue(entry.waitForExistence(timeout: 5))
    reveal(entry, in: app)
    entry.tap()
    let decline = app.buttons["Disagree"]
    XCTAssertTrue(decline.waitForExistence(timeout: 5))
    decline.tap()
    XCTAssertTrue(app.buttons["Agree to the agreements"].waitForExistence(timeout: 5))
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "entry-after-repeated-consent-refresh"
    attachment.lifetime = .keepAlways
    add(attachment)
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
    let shortsTab = app.buttons["tab.Shorts"]
    let deadline = Date().addingTimeInterval(25)
    while Date() < deadline, !start.exists, !shortsTab.exists {
      RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }
    if start.exists {
      reveal(start, in: app)
      start.tap()
      let consent = app.buttons["Agree to the agreements"]
      if consent.exists {
        reveal(consent, in: app)
        consent.tap()
      }
      let enter = app.buttons["Enter Bibi"]
      XCTAssertTrue(enter.waitForExistence(timeout: 8))
      reveal(enter, in: app)
      enter.tap()
    }
    XCTAssertTrue(shortsTab.waitForExistence(timeout: 15))
    XCTAssertTrue(shortsTab.isSelected, "Entering the home screen must select Shorts.")

    for title in titles {
      let tab = app.buttons["tab.\(title)"]
      XCTAssertTrue(tab.waitForExistence(timeout: 10), "Missing tab: \(title)")
      XCTAssertTrue(tab.isHittable)
      if !tab.isSelected { tab.tap() }
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

    app.buttons["tab.Circles"].tap()
    XCTAssertTrue(app.buttons["tab.Circles"].isSelected)
    XCUIDevice.shared.press(.home)
    app.activate()
    let shortsSelected = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "selected == true"), object: shortsTab)
    XCTAssertEqual(XCTWaiter.wait(for: [shortsSelected], timeout: 10), .completed,
                   "Reopening the app from a root tab must return to Shorts.")
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
