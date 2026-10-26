import StoreKit
import StoreKitTest
import XCTest

/// Run only on a disposable purchase simulator; all transactions use StoreKit Test.
final class PurchaseUITests: XCTestCase {
  @MainActor
  func testContentGiftsAndPersistence() async throws {
    continueAfterFailure = false
    let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "BibiDiamonds", withExtension: "storekit"))
    let session = try SKTestSession(contentsOf: file)
    session.resetToDefaultState()
    session.disableDialogs = true
    defer { session.resetToDefaultState() }
    let app = XCUIApplication()
    openWallet(app)
    let initial = try XCTUnwrap(Int(app.staticTexts["wallet.balance"].value as? String ?? ""))
    let package = app.buttons["wallet.package.400"]
    let ready = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "enabled == true"), object: package)], timeout: 25)
    XCTAssertEqual(ready, .completed)
    package.tap()
    app.buttons["Continue"].tap()
    try await expectBalance(initial + 400, app: app)
    app.buttons["Back"].tap()
    app.buttons["tab.Shorts"].tap()
    XCTAssertFalse(app.buttons["shorts.gift"].exists)
    app.buttons["tab.Circles"].tap()
    let explore = app.buttons.matching(NSPredicate(format: "label == 'Explore circle' OR label == 'Open joined circle'")).firstMatch
    reveal(explore, app: app)
    explore.tap()
    let discussion = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Read discussion'")).firstMatch
    reveal(discussion, app: app)
    discussion.tap()
    let circleGift = app.buttons["circle.gift"]
    reveal(circleGift, app: app)
    circleGift.tap()
    let rose = app.buttons["gift.item.rose"]
    XCTAssertTrue(rose.waitForExistence(timeout: 10))
    reveal(rose, app: app)
    rose.tap()
    app.buttons["Cancel"].tap()
    try await expectGiftBalance(initial + 400, app: app)
    rose.tap()
    app.buttons["Use diamonds"].tap()
    try await expectGiftBalance(initial + 390, app: app)
    capture(app, name: "Circle post gift saved")
    let five = app.buttons["5 gifts"]
    reveal(five, app: app, upward: false)
    five.tap()
    reveal(rose, app: app)
    rose.tap()
    app.buttons["Use diamonds"].tap()
    try await expectGiftBalance(initial + 340, app: app)
    if initial < 49000 {
      let galaxy = app.buttons["gift.item.galaxy"]
      reveal(galaxy, app: app)
      capture(app, name: "Full gift prices for five items")
      galaxy.tap()
      XCTAssertTrue(app.staticTexts["Not enough diamonds"].waitForExistence(timeout: 5))
      app.buttons["Cancel"].tap()
      try await expectGiftBalance(initial + 340, app: app)
    }
    app.terminate()
    openWallet(app)
    try await expectBalance(initial + 340, app: app)
    let history = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Local gift'")).firstMatch
    XCTAssertTrue(history.exists)
    reveal(history, app: app)
    capture(app, name: "Gift history survives relaunch")
  }

  @MainActor
  private func expectGiftBalance(_ amount: Int, app: XCUIApplication) async throws {
    let result = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", String(amount)),
      object: app.staticTexts["gift.balance"])], timeout: 15)
    XCTAssertEqual(result, .completed)
  }

  @MainActor
  func testApplePaymentSheetCancellation() async throws {
    continueAfterFailure = false
    let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "BibiDiamonds", withExtension: "storekit"))
    let session = try SKTestSession(contentsOf: file)
    session.resetToDefaultState()
    session.disableDialogs = false
    defer { session.resetToDefaultState() }
    let app = XCUIApplication()
    openWallet(app)
    let balance = try XCTUnwrap(Int(app.staticTexts["wallet.balance"].value as? String ?? ""))
    let package = app.buttons["wallet.package.400"]
    let ready = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: package)], timeout: 25)
    XCTAssertEqual(ready, .completed)
    package.tap()
    app.buttons["Continue"].tap()
    let paymentUI = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let cancel = paymentUI.otherElements["payment-sheet"].buttons["dismiss"]
    let shown = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: cancel)], timeout: 25)
    capture(app, name: "Apple StoreKit payment sheet")
    let hierarchy = XCTAttachment(string: paymentUI.debugDescription)
    hierarchy.name = "Apple payment sheet hierarchy"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
    guard shown == .completed else {
      XCTFail("The StoreKit payment sheet close button was not found.")
      throw NSError(domain: "BibiPurchaseTests", code: 2)
    }
    XCTAssertTrue(paymentUI.staticTexts["In-App Purchase"].exists)
    XCTAssertTrue(paymentUI.staticTexts["$0.99"].exists)
    XCTAssertFalse(app.buttons["Continue"].exists)
    cancel.tap()
    XCTAssertTrue(app.staticTexts["Purchase canceled. You have not been charged."].waitForExistence(timeout: 15))
    app.buttons["OK"].tap()
    try await expectBalance(balance, app: app)
  }

  @MainActor
  func testCatalogPurchasesCancellationAndPersistence() async throws {
    continueAfterFailure = false
    let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "BibiDiamonds", withExtension: "storekit"))
    let session = try SKTestSession(contentsOf: file)
    session.resetToDefaultState()
    session.clearTransactions()
    session.disableDialogs = true
    defer { session.resetToDefaultState() }

    let app = XCUIApplication()
    openWallet(app)
    let balance = app.staticTexts["wallet.balance"]
    let original = try XCTUnwrap(Int(balance.value as? String ?? ""))
    var expected = original
    let amounts = [400, 800, 2450, 5150, 10800, 29400, 63700]
    for amount in amounts {
      let package = app.buttons["wallet.package.\(amount)"]
      XCTAssertTrue(package.waitForExistence(timeout: 25))
      let enabled = NSPredicate(format: "enabled == true")
      let ready = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(predicate: enabled, object: package)], timeout: 25)
      XCTAssertEqual(ready, .completed)
      XCTAssertFalse(package.label.contains("Unavailable"))
      XCTAssertFalse(package.label.contains("Loading"))
      reveal(package, app: app)
      if amount == 400 { capture(app, name: "Loaded diamond catalog") }
      package.tap()
      let proceed = app.buttons["Continue"]
      XCTAssertTrue(proceed.waitForExistence(timeout: 5))
      if amount == 400 { capture(app, name: "Purchase confirmation with StoreKit price") }
      proceed.tap()
      expected += amount
      try await expectBalance(expected, app: app)
    }
    XCTAssertEqual(session.allTransactions().filter { $0.state == .purchased }.count, 7)
    reveal(balance, app: app, upward: false)
    capture(app, name: "Seven purchases credited")

    // Cancel before submitting a payment: no new StoreKit transaction or balance change.
    let first = app.buttons["wallet.package.400"]
    reveal(first, app: app)
    first.tap()
    app.buttons["Cancel"].tap()
    try await expectBalance(expected, app: app)
    XCTAssertEqual(session.allTransactions().count, 7)

    // Exercise StoreKit's canceled result, not just the application's confirmation.
    if #available(iOS 17.0, *) {
      try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
      first.tap()
      app.buttons["Continue"].tap()
      XCTAssertTrue(app.staticTexts["Purchase canceled. You have not been charged."].waitForExistence(timeout: 15))
      capture(app, name: "StoreKit cancellation leaves balance unchanged")
      app.buttons["OK"].tap()
      try await expectBalance(expected, app: app)
      try await session.setSimulatedError(nil, forAPI: .purchase)
    }

    app.terminate()
    openWallet(app)
    try await expectBalance(expected, app: app)
    capture(app, name: "Balance preserved after relaunch")
  }

  @MainActor
  private func openWallet(_ app: XCUIApplication) {
    app.launch()
    XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 25))
    reveal(app.buttons["Get started"], app: app)
    app.buttons["Get started"].tap()
    let consent = app.buttons["Agree to the agreements"]
    if consent.exists { reveal(consent, app: app); consent.tap() }
    reveal(app.buttons["Enter Bibi"], app: app)
    app.buttons["Enter Bibi"].tap()
    XCTAssertTrue(app.buttons["tab.Me"].waitForExistence(timeout: 10))
    app.buttons["tab.Me"].tap()
    XCTAssertTrue(app.buttons["Wallet"].waitForExistence(timeout: 5))
    app.buttons["Wallet"].tap()
    XCTAssertTrue(app.staticTexts["wallet.balance"].waitForExistence(timeout: 5))
  }

  @MainActor
  private func expectBalance(_ amount: Int, app: XCUIApplication) async throws {
    let predicate = NSPredicate(format: "value == %@", String(amount))
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.staticTexts["wallet.balance"])
    let result = await XCTWaiter.fulfillment(of: [expectation], timeout: 45)
    if result != .completed {
      let details = XCTAttachment(string: app.debugDescription)
      details.name = "Purchase failure hierarchy"
      details.lifetime = .keepAlways
      add(details)
      capture(app, name: "Purchase failure screen")
      let actual = app.staticTexts["wallet.balance"].value ?? "missing"
      XCTFail("Expected balance \(amount); actual: \(actual)")
      throw NSError(domain: "BibiPurchaseTests", code: 1)
    }
  }

  @MainActor
  private func reveal(_ element: XCUIElement, app: XCUIApplication, upward: Bool = true) {
    for _ in 0..<5 {
      if element.isHittable { return }
      if upward { app.swipeUp() } else { app.swipeDown() }
    }
    XCTAssertTrue(element.isHittable)
  }

  @MainActor
  private func capture(_ app: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
