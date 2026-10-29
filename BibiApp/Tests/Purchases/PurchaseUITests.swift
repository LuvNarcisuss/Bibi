import StoreKit
import StoreKitTest
import XCTest

/// Run only on a disposable purchase simulator; all transactions use StoreKit Test.
final class PurchaseUITests: XCTestCase {
  @MainActor
  func testPostGiftsRemovedAndSafetyAvailable() async throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    openWallet(app)
    let initial = try XCTUnwrap(Int(app.staticTexts["wallet.balance"].value as? String ?? ""))
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
    XCTAssertFalse(app.buttons["circle.gift"].exists)
    let safety = app.buttons.matching(identifier: "Report or block").firstMatch
    reveal(safety, app: app)
    safety.tap()
    XCTAssertTrue(app.buttons["Report circle post"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Block '")).firstMatch.exists)
    capture(app, name: "Post safety actions without gifts")
    app.terminate()
    openWallet(app)
    try await expectBalance(initial, app: app)
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
    let amounts = [400, 800, 2450, 5150, 10800, 16800, 29400, 42700, 63700]
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
    XCTAssertEqual(session.allTransactions().filter { $0.state == .purchased }.count, amounts.count)
    reveal(balance, app: app, upward: false)
    capture(app, name: "Nine purchases credited")

    // Cancel before submitting a payment: no new StoreKit transaction or balance change.
    let first = app.buttons["wallet.package.400"]
    reveal(first, app: app)
    first.tap()
    app.buttons["Cancel"].tap()
    try await expectBalance(expected, app: app)
    XCTAssertEqual(session.allTransactions().count, amounts.count)

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
  func testSavedShortJoinsChallengeAndRefundsOnWithdraw() async throws {
    continueAfterFailure = false
    let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "BibiDiamonds", withExtension: "storekit"))
    let session = try SKTestSession(contentsOf: file)
    session.resetToDefaultState()
    session.clearTransactions()
    session.disableDialogs = true
    defer { session.resetToDefaultState() }

    let app = XCUIApplication()
    enterApp(app)
    let funded = try await ensureDiamonds(atLeast: 100, app: app)
    app.buttons["Back"].tap()
    app.buttons["tab.Challenges"].tap()
    let explore = app.buttons["Explore challenge"].firstMatch
    reveal(explore, app: app)
    XCTAssertTrue(explore.waitForExistence(timeout: 8))
    let cover = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'challenge.cover.'"))
      .allElementsBoundByIndex.filter {
        abs($0.frame.midX - explore.frame.midX) < 30 && $0.frame.maxY <= explore.frame.minY
      }.min { explore.frame.minY - $0.frame.maxY < explore.frame.minY - $1.frame.maxY }
    let challengeCoverID = try XCTUnwrap(cover?.identifier)
    explore.tap()
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'uses 100 diamonds'")).firstMatch.waitForExistence(timeout: 8))
    capture(app, name: "Challenge entry fee")

    reveal(app.buttons["Choose one of my videos"], app: app)
    app.buttons["Choose one of my videos"].tap()
    let first = app.buttons["Red robe and gold headdress · 0:12"]
    let second = app.buttons["Gold kimono in the smoke · 0:12"]
    XCTAssertTrue(first.waitForExistence(timeout: 8), "Saved practice shorts did not appear")
    XCTAssertTrue(second.exists)
    XCTAssertTrue(app.buttons["Chainsaw mask at the expo · 0:08"].exists)
    XCTAssertTrue(app.buttons["Pink wig by the window · 0:12"].exists)
    capture(app, name: "Saved short video choices")
    first.tap()

    XCTAssertTrue(app.staticTexts["Your entry"].waitForExistence(timeout: 12))
    XCTAssertTrue(app.staticTexts["Red robe and gold headdress"].waitForExistence(timeout: 8))
    capture(app, name: "Challenge entry saved")
    let afterEntry = try await walletBalance(app)
    XCTAssertEqual(afterEntry, funded - 100)

    app.buttons["tab.Challenges"].tap()
    let manage = app.buttons[challengeCoverID]
    reveal(manage, app: app)
    manage.tap()
    reveal(app.buttons["Choose one of my videos"], app: app)
    app.buttons["Choose one of my videos"].tap()
    XCTAssertTrue(second.waitForExistence(timeout: 8))
    second.tap()
    XCTAssertTrue(app.staticTexts["Gold kimono in the smoke"].waitForExistence(timeout: 12))
    let afterReplace = try await walletBalance(app)
    XCTAssertEqual(afterReplace, funded - 100, "Replacing an entry must not charge again")

    app.buttons["tab.Challenges"].tap()
    reveal(app.buttons[challengeCoverID], app: app)
    app.buttons[challengeCoverID].tap()
    reveal(app.buttons["Withdraw entry"], app: app)
    app.buttons["Withdraw entry"].tap()
    XCTAssertTrue(app.buttons["Withdraw"].waitForExistence(timeout: 5))
    app.buttons["Withdraw"].tap()
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'uses 100 diamonds'")).firstMatch.waitForExistence(timeout: 12))
    XCTAssertFalse(app.staticTexts["Your entry"].exists)
    capture(app, name: "Challenge entry withdrawn")
    let afterRefund = try await walletBalance(app)
    XCTAssertEqual(afterRefund, funded)
  }

  @MainActor
  func testPendingAndFailedPurchasesKeepBalance() async throws {
    continueAfterFailure = false
    let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "BibiDiamonds", withExtension: "storekit"))
    let session = try SKTestSession(contentsOf: file)
    session.resetToDefaultState()
    session.disableDialogs = true
    defer { session.resetToDefaultState() }
    let app = XCUIApplication()
    openWallet(app)
    let balance = try XCTUnwrap(Int(app.staticTexts["wallet.balance"].value as? String ?? ""))
    let package = app.buttons["wallet.package.400"]
    let ready = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: package)], timeout: 25)
    XCTAssertEqual(ready, .completed)
    session.askToBuyEnabled = true
    package.tap()
    app.buttons["Continue"].tap()
    XCTAssertTrue(app.staticTexts["This purchase is waiting for approval. Diamonds are added when it is approved."].waitForExistence(timeout: 20))
    capture(app, name: "Pending approval leaves balance unchanged")
    app.buttons["OK"].tap()
    try await expectBalance(balance, app: app)
    for transaction in session.allTransactions() where transaction.state == .deferred {
      try session.declineAskToBuyTransaction(identifier: transaction.identifier)
    }
    session.askToBuyEnabled = false
    if app.buttons["OK"].exists { app.buttons["OK"].tap() }
    if #available(iOS 17.0, *) {
      try await session.setSimulatedError(.generic(.unknown), forAPI: .purchase)
      package.tap()
      app.buttons["Continue"].tap()
      XCTAssertTrue(app.staticTexts["Purchase did not go through. You have not been charged."].waitForExistence(timeout: 20))
      capture(app, name: "StoreKit failure leaves balance unchanged")
      app.buttons["OK"].tap()
      try await expectBalance(balance, app: app)
      try await session.setSimulatedError(nil, forAPI: .purchase)
    }
  }

  @MainActor
  func testLooksPurchaseEquipAndPersistence() async throws {
    continueAfterFailure = false
    let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "BibiDiamonds", withExtension: "storekit"))
    let session = try SKTestSession(contentsOf: file)
    session.resetToDefaultState()
    session.disableDialogs = true
    defer { session.resetToDefaultState() }
    let app = XCUIApplication()
    enterApp(app)
    _ = try await ensureDiamonds(atLeast: 100, app: app)
    let package = app.buttons["wallet.package.2450"]
    reveal(package, app: app)
    let ready = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: package)], timeout: 25)
    XCTAssertEqual(ready, .completed)
    let before = try XCTUnwrap(Int(app.staticTexts["wallet.balance"].value as? String ?? ""))
    package.tap()
    app.buttons["Continue"].tap()
    try await expectBalance(before + 2450, app: app)
    var expected = before + 2450
    app.buttons["Back"].tap()
    app.buttons["Settings"].tap()
    app.buttons["Edit profile"].tap()
    reveal(app.buttons["Profile looks"], app: app)
    app.buttons["Profile looks"].tap()
    expected -= unlockLook("Sakura Ring", cost: 200, app: app)
    expected -= unlockLook("Sakura Header", cost: 800, app: app)
    capture(app, name: "Profile frame and header equipped")
    app.buttons["Back"].tap()
    app.buttons["Back"].tap()
    app.buttons["Back"].tap()
    app.buttons["tab.Chats"].tap()
    let chat = app.staticTexts["Maya Chen"]
    XCTAssertTrue(chat.waitForExistence(timeout: 8))
    chat.tap()
    app.buttons["Chat style"].tap()
    expected -= unlockLook("Sakura Bubble", cost: 300, app: app)
    expected -= unlockLook("Paper Room", cost: 600, app: app)
    capture(app, name: "Chat bubble and room equipped")
    app.buttons["Back"].tap()
    app.buttons["Back"].tap()
    app.buttons["tab.Shorts"].tap()
    app.buttons["Create a short video"].tap()
    reveal(app.buttons["Cover style"], app: app)
    app.buttons["Cover style"].tap()
    expected -= unlockLook("Blossom Frame", cost: 400, app: app)
    capture(app, name: "Cover frame equipped")
    app.terminate()
    enterApp(app)
    let balance = try await walletBalance(app)
    XCTAssertEqual(balance, expected)
    app.buttons["Settings"].tap()
    app.buttons["Edit profile"].tap()
    app.buttons["Profile looks"].tap()
    XCTAssertTrue(app.buttons["Sakura Ring · Using"].waitForExistence(timeout: 8))
    let classic = app.buttons["Classic · Use"].firstMatch
    reveal(classic, app: app)
    classic.tap()
    let owned = app.buttons["Sakura Ring · Use"]
    XCTAssertTrue(owned.waitForExistence(timeout: 8))
    owned.tap()
    XCTAssertTrue(app.buttons["Sakura Ring · Using"].waitForExistence(timeout: 8))
    capture(app, name: "Owned look re-equipped after relaunch")
  }

  @MainActor
  private func unlockLook(_ name: String, cost: Int, app: XCUIApplication) -> Int {
    let using = app.buttons[name + " · Using"]
    if using.exists { return 0 }
    let owned = app.buttons[name + " · Use"]
    if owned.exists {
      reveal(owned, app: app)
      owned.tap()
      XCTAssertTrue(using.waitForExistence(timeout: 8))
      return 0
    }
    let purchase = app.buttons[name + " · " + String(cost) + " diamonds"]
    reveal(purchase, app: app)
    XCTAssertTrue(purchase.exists)
    purchase.tap()
    XCTAssertTrue(app.buttons["Use diamonds"].waitForExistence(timeout: 5))
    app.buttons["Use diamonds"].tap()
    XCTAssertTrue(using.waitForExistence(timeout: 10))
    return cost
  }

  @MainActor
  private func enterApp(_ app: XCUIApplication) {
    app.launch()
    if app.buttons["Get started"].waitForExistence(timeout: 12) {
      reveal(app.buttons["Get started"], app: app)
      app.buttons["Get started"].tap()
      let consent = app.buttons["Agree to the agreements"]
      if consent.waitForExistence(timeout: 4) { reveal(consent, app: app); consent.tap() }
      reveal(app.buttons["Enter Bibi"], app: app)
      app.buttons["Enter Bibi"].tap()
    }
    XCTAssertTrue(app.buttons["tab.Shorts"].waitForExistence(timeout: 20))
  }

  @MainActor
  private func ensureDiamonds(atLeast minimum: Int, app: XCUIApplication) async throws -> Int {
    app.buttons["tab.Me"].tap()
    XCTAssertTrue(app.buttons["Wallet"].waitForExistence(timeout: 5))
    app.buttons["Wallet"].tap()
    let balance = app.staticTexts["wallet.balance"]
    XCTAssertTrue(balance.waitForExistence(timeout: 8))
    var amount = try XCTUnwrap(Int(balance.value as? String ?? ""))
    if amount >= minimum { return amount }
    let package = app.buttons["wallet.package.400"]
    let ready = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: package)], timeout: 25)
    XCTAssertEqual(ready, .completed)
    reveal(package, app: app)
    package.tap()
    XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
    app.buttons["Continue"].tap()
    amount += 400
    try await expectBalance(amount, app: app)
    return amount
  }

  @MainActor
  private func walletBalance(_ app: XCUIApplication) async throws -> Int {
    for _ in 0..<6 where !app.buttons["tab.Me"].exists {
      let back = app.buttons["Back"]
      if back.exists, back.isHittable { back.tap() } else { break }
    }
    XCTAssertTrue(app.buttons["tab.Me"].waitForExistence(timeout: 5))
    app.buttons["tab.Me"].tap()
    if !app.buttons["Wallet"].waitForExistence(timeout: 2) {
      if app.buttons["Back"].exists { app.buttons["Back"].tap() }
      app.buttons["tab.Me"].tap()
    }
    XCTAssertTrue(app.buttons["Wallet"].waitForExistence(timeout: 5))
    app.buttons["Wallet"].tap()
    let balance = app.staticTexts["wallet.balance"]
    XCTAssertTrue(balance.waitForExistence(timeout: 8))
    let amount = try XCTUnwrap(Int(balance.value as? String ?? ""))
    app.buttons["Back"].tap()
    return amount
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
