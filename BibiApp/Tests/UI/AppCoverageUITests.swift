import XCTest

/// Walks the five current modules, their detail pages, sheets and empty states.
/// State-changing flows live in `testIsolatedStateChanges` and run only on a disposable simulator.
final class AppCoverageUITests: XCTestCase {
  private var gaps: [String] = []

  override func setUpWithError() throws {
    continueAfterFailure = true
    XCUIDevice.shared.orientation = .portrait
  }

  @MainActor
  func testShortsAndCircles() throws {
    let app = launch(larger: false)
    enter(app, prefix: "default")
    walkShorts(app, prefix: "default")
    walkCircles(app, prefix: "default", mutate: false)
    attachNotes("shorts-circles")
  }

  @MainActor
  func testChallengesChatsAndMe() throws {
    let app = launch(larger: false)
    enter(app, prefix: "default-b")
    walkChallenges(app, prefix: "default")
    walkChats(app, prefix: "default", mutate: false)
    walkMe(app, prefix: "default", mutate: false)
    attachNotes("challenges-chats-me")
  }

  @MainActor
  func testLargerTextAcrossModules() throws {
    let app = launch(larger: true)
    enter(app, prefix: "larger")
    for title in ["Shorts", "Circles", "Challenges", "Chats", "Me"] {
      openTab(app, title)
      shot(app, "larger-\(title)")
      assertTitle(app, title)
    }
    openTab(app, "Circles")
    openFirst(app, predicate: "label == 'Explore circle' OR label == 'Open joined circle'", name: "larger-circle", required: true)
    shot(app, "larger-circle-detail")
    back(app)
    openTab(app, "Challenges")
    openFirst(app, predicate: "label == 'Explore challenge' OR label == 'View your entry'", name: "larger-challenge", required: true)
    shot(app, "larger-challenge-detail")
    back(app)
    openTab(app, "Chats")
    openChat(app, name: "Maya Chen", shotName: "larger-chat")
    back(app)
    openTab(app, "Me")
    if tapButton(app, "Settings", required: false) {
      shot(app, "larger-settings")
      back(app)
    }
    if tapButton(app, "Wallet", required: false) {
      shot(app, "larger-wallet")
      back(app)
    }
    attachNotes("larger-text")
  }

  @MainActor
  func testRootsStayPortraitWhenDeviceRotates() throws {
    let app = launch(larger: false)
    enter(app, prefix: "landscape-entry")
    XCUIDevice.shared.orientation = .landscapeLeft
    for title in ["Shorts", "Circles", "Challenges", "Chats", "Me"] {
      openTab(app, title)
      shot(app, "landscape-\(title)")
      assertTitle(app, title)
      XCTAssertGreaterThan(app.frame.height, app.frame.width, "\(title) must remain portrait when the device rotates")
    }
    XCUIDevice.shared.orientation = .portrait
    shot(app, "landscape-returned-portrait")
    attachNotes("landscape")
  }

  @MainActor
  func testShortCommentAndReply() throws {
    continueAfterFailure = false
    let app = launch(larger: false)
    enter(app, prefix: "comment-reply")
    XCTAssertTrue(tapButton(app, "Comments", required: true))
    let comment = app.textFields["Write a comment"]
    XCTAssertTrue(comment.waitForExistence(timeout: 8))
    comment.tap()
    let commentText = "A costume detail " + UUID().uuidString.prefix(8)
    comment.typeText(commentText)
    XCTAssertTrue(tapButton(app, "Send comment", required: true))
    XCTAssertTrue(app.staticTexts[commentText].waitForExistence(timeout: 8))
    shot(app, "isolated-short-comment-saved")
    app.staticTexts[commentText].tap()
    shot(app, "isolated-comment-action-card")
    XCTAssertTrue(tapButton(app, "Reply", required: true))
    comment.typeText("The stitching is beautiful")
    XCTAssertTrue(tapButton(app, "Send comment", required: true))
    XCTAssertTrue(app.staticTexts["The stitching is beautiful"].waitForExistence(timeout: 8))
    shot(app, "isolated-short-reply-saved")
    closeSheet(app)
    attachNotes("comment-reply")
  }

  /// Join, reply, report, block, chat outbox, permissions, logout and account deletion.
  /// Invoke only on a disposable simulator. These steps rewrite local account data.
  @MainActor
  func testIsolatedStateChanges() throws {
    continueAfterFailure = false
    let app = launch(larger: false)
    enter(app, prefix: "isolated")
    walkCircles(app, prefix: "isolated", mutate: true)
    walkChats(app, prefix: "isolated", mutate: true)
    walkSafety(app)
    walkPermissionsAndAccount(app)
    attachNotes("isolated")
  }

  @MainActor
  func testFreshLocalAccountForPurchaseAcceptance() throws {
    continueAfterFailure = false
    let app = launch(larger: false)
    enter(app, prefix: "fresh-payment-account")
    openTab(app, "Me")
    XCTAssertTrue(tapButton(app, "Settings", required: true))
    XCTAssertTrue(tapButton(app, "Delete account", required: true))
    XCTAssertTrue(tapButton(app, "Delete account", required: true))
    XCTAssertTrue(app.buttons["Enter Bibi"].waitForExistence(timeout: 15))
    enter(app, prefix: "fresh-payment-account-reenter")
    openTab(app, "Me")
    XCTAssertTrue(tapButton(app, "Wallet", required: true))
    XCTAssertTrue(app.staticTexts["wallet.balance"].waitForExistence(timeout: 10))
    XCTAssertEqual(app.staticTexts["wallet.balance"].value as? String, "0")
    shot(app, "fresh-payment-wallet")
  }

  @MainActor
  func testProfileEditSurvivesRelaunch() throws {
    continueAfterFailure = false
    let app = launch(larger: false)
    enter(app, prefix: "profile-edit")
    openTab(app, "Me")
    XCTAssertTrue(tapButton(app, "Settings", required: true))
    XCTAssertTrue(tapButton(app, "Edit profile", required: true))
    let name = app.textFields["Name"]
    XCTAssertTrue(name.waitForExistence(timeout: 8))
    let previous = name.value as? String ?? ""
    let updated = "Costume " + UUID().uuidString.prefix(8)
    reveal(name, app)
    name.tap()
    name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
    name.typeText(updated)
    dismissKeyboard(app)
    XCTAssertTrue(tapButton(app, "Save", required: true))
    back(app)
    XCTAssertTrue(app.staticTexts[updated].waitForExistence(timeout: 10))
    app.terminate()
    app.launch()
    enter(app, prefix: "profile-edit-relaunch")
    openTab(app, "Me")
    XCTAssertTrue(app.staticTexts[updated].waitForExistence(timeout: 10))
    shot(app, "profile-edit-persisted")
    attachNotes("profile-edit")
  }

  @MainActor
  func testShortVideoMediaUploadAndRemoval() throws {
    continueAfterFailure = false
    let app = launch(larger: false)
    enter(app, prefix: "upload")
    XCTAssertTrue(tapButton(app, "Create a short video", required: true))
    XCTAssertTrue(tapButton(app, "Save upload", required: true))
    XCTAssertTrue(app.staticTexts["Please confirm this is anime-related content that you have permission to share."].waitForExistence(timeout: 8))
    XCTAssertTrue(tapButton(app, "OK", required: true))
    let title = "A costume movement study " + UUID().uuidString.prefix(8)
    let name = app.textFields["Title"]
    reveal(name, app)
    name.tap()
    name.typeText(title)
    let caption = app.textFields["Tell us about your story"]
    reveal(caption, app)
    caption.tap()
    caption.typeText("A licensed practice clip saved on this device.")
    dismissKeyboard(app)
    XCTAssertTrue(tapButton(app, "This is anime-related content and I have permission to share it.", required: true))
    XCTAssertTrue(tapButton(app, "Save upload", required: true))
    XCTAssertTrue(app.staticTexts["Choose an anime video first."].waitForExistence(timeout: 8))
    XCTAssertTrue(tapButton(app, "OK", required: true))
    XCTAssertTrue(tapButton(app, "Choose an anime video", required: true))
    let picker = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow.photospicker")
    let media = picker.images.matching(identifier: "PXGGridLayout-Info").firstMatch
    let ready = media.waitForExistence(timeout: 40)
    shot(app, "upload-system-video-picker")
    if !ready {
      let hierarchy = XCTAttachment(string: app.debugDescription + "\nPhotos picker\n" + picker.debugDescription)
      hierarchy.name = "Media picker hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
    }
    XCTAssertTrue(ready, "The system media picker did not expose the imported QA video")
    let thumbnail = media.frame
    picker.coordinate(withNormalizedOffset: .zero).withOffset(
      CGVector(dx: thumbnail.midX, dy: thumbnail.midY)).tap()
    if app.buttons["Add"].firstMatch.exists { app.buttons["Add"].firstMatch.tap() }
    XCTAssertTrue(app.staticTexts["Video selected"].waitForExistence(timeout: 20))
    XCTAssertTrue(tapButton(app, "Save upload", required: true))
    let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: name)
    XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 25), .completed)
    app.terminate()
    app.launch()
    enter(app, prefix: "upload-relaunch")
    openTab(app, "Me")
    let uploads = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Uploads ('")).firstMatch
    for _ in 0..<6 where !uploads.isHittable {
      if let strip = app.scrollViews.allElementsBoundByIndex.first(where: { $0.frame.height > 0 && $0.frame.height < 120 && $0.isHittable }) {
        strip.swipeLeft()
      } else { app.swipeUp() }
    }
    XCTAssertTrue(uploads.isHittable)
    uploads.tap()
    XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["Waiting to submit"].firstMatch.exists)
    let watch = app.buttons["Watch video"].firstMatch
    reveal(watch, app)
    watch.tap()
    XCTAssertTrue(app.staticTexts["Local upload · Not published"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch.exists)
    XCTAssertFalse(app.buttons["Share"].isEnabled)
    shot(app, "upload-private-playback")
    closeSheet(app)
    let remove = app.buttons["Remove"].firstMatch
    reveal(remove, app)
    remove.tap()
    XCTAssertTrue(tapButton(app, "Cancel", required: true))
    XCTAssertTrue(app.staticTexts[title].exists)
    reveal(remove, app)
    remove.tap()
    XCTAssertTrue(tapButton(app, "Remove", required: true))
    XCTAssertFalse(app.staticTexts[title].waitForExistence(timeout: 3))
    shot(app, "upload-removed")
    attachNotes("upload")
  }

  @MainActor
  func testChatCreationAndSwipeActions() throws {
    continueAfterFailure = false
    let app = launch(larger: false)
    enter(app, prefix: "chat-actions")
    openTab(app, "Chats")
    let maya = app.staticTexts["Maya Chen"]
    XCTAssertTrue(maya.waitForExistence(timeout: 8))
    maya.swipeLeft()
    let pin = app.buttons["Unpin"].firstMatch
    let wasPinned = pin.exists && pin.isHittable
    XCTAssertTrue(tapButton(app, wasPinned ? "Unpin" : "Pin", required: true))
    maya.swipeLeft()
    XCTAssertTrue(tapButton(app, wasPinned ? "Pin" : "Unpin", required: true))
    maya.swipeLeft()
    let wasMuted = app.buttons["Unmute"].firstMatch.exists && app.buttons["Unmute"].firstMatch.isHittable
    XCTAssertTrue(tapButton(app, wasMuted ? "Unmute" : "Mute", required: true))
    maya.swipeLeft()
    XCTAssertTrue(tapButton(app, wasMuted ? "Mute" : "Unmute", required: true))
    shot(app, "chat-swipe-actions-restored")
    XCTAssertTrue(tapButton(app, "Add a friend", required: true))
    XCTAssertTrue(tapButton(app, "Create a group", required: true))
    let create = app.buttons["Create now, choose at least two friends"]
    XCTAssertTrue(create.waitForExistence(timeout: 8))
    XCTAssertFalse(create.isEnabled)
    XCTAssertTrue(tapButton(app, "Maya Chen", required: true))
    XCTAssertFalse(create.isEnabled)
    XCTAssertTrue(tapButton(app, "Leo Brooks", required: true))
    XCTAssertTrue(tapButton(app, "Create now", required: true))
    XCTAssertTrue(app.staticTexts["This group is saved on this device."].waitForExistence(timeout: 10))
    XCTAssertTrue(tapButton(app, "OK", required: true))
    let message = app.textFields["Message"]
    XCTAssertTrue(message.waitForExistence(timeout: 8))
    message.tap()
    message.typeText("A new costume planning circle")
    XCTAssertTrue(tapButton(app, "Send", required: true))
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'A new costume planning circle'")).firstMatch.waitForExistence(timeout: 8))
    shot(app, "created-group-local-outbox")
    attachNotes("chat-actions")
  }

  @MainActor
  func testPostCreationBookmarkAndPersistence() throws {
    continueAfterFailure = false
    let app = launch(larger: false)
    enter(app, prefix: "post-lifecycle")
    openTab(app, "Circles")
    XCTAssertTrue(openFirst(app, predicate: "label == 'Explore circle' OR label == 'Open joined circle'", name: "creation circle", required: true))
    if app.buttons["Join circle"].exists { app.buttons["Join circle"].tap() }
    XCTAssertTrue(tapButton(app, "Write a post", required: true))
    let body = app.textViews["Post text"]
    XCTAssertTrue(body.waitForExistence(timeout: 8))
    XCTAssertTrue(tapButton(app, "Save post", required: true))
    XCTAssertTrue(body.exists, "An empty post must keep the composer open")
    shot(app, "post-empty-validation")
    reveal(body, app)
    body.tap()
    let text = "A starlight costume journal " + UUID().uuidString
    body.typeText(text)
    dismissKeyboard(app)
    XCTAssertTrue(tapButton(app, "Attach a short video", required: true))
    let video = app.buttons.matching(NSPredicate(format: "label CONTAINS ' · 0:'")).firstMatch
    XCTAssertTrue(video.waitForExistence(timeout: 8))
    reveal(video, app)
    video.tap()
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Video: '")).firstMatch.waitForExistence(timeout: 8))
    XCTAssertTrue(tapButton(app, "Remove attachments", required: true))
    XCTAssertTrue(app.staticTexts["No attachments"].exists)
    XCTAssertTrue(tapButton(app, "Save post", required: true))
    XCTAssertFalse(body.waitForExistence(timeout: 2), "A saved post should close the composer")
    let post = app.staticTexts[text]
    XCTAssertTrue(post.waitForExistence(timeout: 10))
    reveal(post, app)
    post.tap()
    XCTAssertTrue(tapButton(app, "Save post", required: true))
    XCTAssertTrue(app.buttons["Saved · Remove bookmark"].waitForExistence(timeout: 8))
    shot(app, "post-created-and-bookmarked")
    app.terminate()
    app.launch()
    enter(app, prefix: "post-relaunch")
    openTab(app, "Circles")
    XCTAssertTrue(tapButton(app, "Saved", required: true))
    XCTAssertTrue(post.waitForExistence(timeout: 8), "The created bookmark must survive relaunch")
    reveal(post, app)
    post.tap()
    XCTAssertTrue(tapButton(app, "Saved · Remove bookmark", required: true))
    XCTAssertTrue(app.buttons["Save post"].waitForExistence(timeout: 8))
    XCTAssertTrue(tapButton(app, "Delete post", required: true))
    XCTAssertTrue(tapButton(app, "Cancel", required: true))
    XCTAssertTrue(app.staticTexts[text].exists)
    XCTAssertTrue(tapButton(app, "Delete post", required: true))
    XCTAssertTrue(tapButton(app, "Delete", required: true))
    XCTAssertFalse(app.staticTexts[text].waitForExistence(timeout: 3))
    shot(app, "post-deleted")
    attachNotes("post-lifecycle")
  }

  @MainActor
  private func launch(larger: Bool) -> XCUIApplication {
    let app = XCUIApplication()
    if larger {
      app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]
    }
    app.launch()
    return app
  }

  @MainActor
  private func enter(_ app: XCUIApplication, prefix: String) {
    let start = app.buttons["Get started"]
    let home = app.buttons["tab.Shorts"]
    let entry = app.buttons["Enter Bibi"]
    let deadline = Date().addingTimeInterval(25)
    while Date() < deadline, !start.exists, !home.exists, !entry.exists {
      RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }
    if start.exists {
      shot(app, "\(prefix)-welcome")
      reveal(start, app)
      start.tap()
    }
    if !home.exists {
      let consent = app.buttons["Agree to the agreements"]
      if consent.waitForExistence(timeout: 4) {
        shot(app, "\(prefix)-agreements")
        reveal(consent, app)
        consent.tap()
      }
      XCTAssertTrue(entry.waitForExistence(timeout: 8), "Agreement confirmation did not appear")
      reveal(entry, app)
      shot(app, "\(prefix)-enter")
      entry.tap()
    }
    XCTAssertTrue(home.waitForExistence(timeout: 15), "Shorts did not appear after entry")
    XCTAssertTrue(home.isSelected, "Entering home must select Shorts")
    shot(app, "\(prefix)-shorts-home")
  }

  @MainActor
  private func walkShorts(_ app: XCUIApplication, prefix: String) {
    openTab(app, "Shorts")
    assertTitle(app, "Shorts")
    let like = app.buttons["Like"]
    XCTAssertTrue(like.waitForExistence(timeout: 8), "Short video like control is missing")
    XCTAssertTrue(app.buttons["Comments"].waitForExistence(timeout: 4))
    XCTAssertTrue(app.buttons["Save"].exists)
    XCTAssertTrue(app.buttons["Share"].exists)
    let likeBefore = (like.value as? String) ?? ""
    like.tap()
    XCTAssertTrue(waitUntil(like, format: "value != %@", likeBefore, timeout: 6), "Like must change its saved state")
    let likeChanged = (like.value as? String) ?? ""
    like.tap()
    _ = waitUntil(like, format: "value == %@", likeBefore, timeout: 6)
    if ((like.value as? String) ?? "") != likeBefore {
      gaps.append("Like did not return to \(likeBefore); last value \(like.value ?? "nil") after \(likeChanged)")
    }
    let save = app.buttons["Save"]
    let saveBefore = (save.value as? String) ?? ""
    save.tap()
    XCTAssertTrue(waitUntil(save, format: "value != %@", saveBefore, timeout: 6), "Save must change its saved state")
    save.tap()
    _ = waitUntil(save, format: "value == %@", saveBefore, timeout: 6)
    if ((save.value as? String) ?? "") != saveBefore {
      gaps.append("Save did not return to \(saveBefore)")
    }
    shot(app, "\(prefix)-shorts-reactions-restored")

    app.coordinate(withNormalizedOffset: CGVector(dx: 0.28, dy: 0.42)).tap()
    shot(app, "\(prefix)-shorts-playback-toggle")
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.28, dy: 0.42)).tap()

    if tapButton(app, "Comments", required: true) {
      shot(app, "\(prefix)-shorts-comments")
      let field = app.textFields["Write a comment"]
      if field.waitForExistence(timeout: 4) {
        field.tap()
        field.typeText("Local note")
        shot(app, "\(prefix)-shorts-comment-keyboard")
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10))
      } else {
        gaps.append("Comment field was not available")
      }
      if app.buttons["Close"].firstMatch.exists { closeSheet(app) }
      else { app.buttons["Close comments"].tap() }
    }

    if tapButton(app, "Share", required: true) {
      let sheet = app.staticTexts["Share with"]
      if sheet.waitForExistence(timeout: 4) {
        shot(app, "\(prefix)-shorts-share")
        if app.buttons["Close"].firstMatch.exists { closeSheet(app) }
        else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap() }
      } else {
        gaps.append("Share sheet did not appear")
      }
    }

    if tapButton(app, "More", required: true) {
      shot(app, "\(prefix)-shorts-safety")
      let report = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Report '")).firstMatch
      if report.waitForExistence(timeout: 4) {
        report.tap()
        shot(app, "\(prefix)-shorts-report-form")
        let localReport = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'not submitted'")).firstMatch
        if !localReport.waitForExistence(timeout: 4) {
          gaps.append("Local report copy was not visible")
        }
      }
      closeSheet(app)
    }

    if tapButton(app, "Search short videos", required: true) {
      let search = app.textFields["Search friends and videos"]
      if search.waitForExistence(timeout: 4) {
        search.tap()
        search.typeText("sky")
        shot(app, "\(prefix)-shorts-search")
        if app.buttons["Close search"].exists { app.buttons["Close search"].tap() }
      } else {
        gaps.append("Short video search field did not appear")
      }
    }

    let profile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open '")).firstMatch
    if profile.waitForExistence(timeout: 4), profile.isHittable {
      profile.tap()
      shot(app, "\(prefix)-shorts-creator")
      if tapButton(app, "Report or block", required: true) {
        shot(app, "\(prefix)-creator-safety")
        closeSheet(app)
      }
      closeSheet(app)
    } else {
      gaps.append("Short video creator profile control was not hittable")
    }

    if tapButton(app, "Create a short video", required: true) {
      shot(app, "\(prefix)-create-short")
      XCTAssertTrue(app.staticTexts["Every frame has a story."].waitForExistence(timeout: 4))
      XCTAssertTrue(app.textFields["Title"].exists)
      closeSheet(app)
    }

    let beforeSwipe = app.staticTexts.allElementsBoundByIndex.map(\.label)
    app.swipeUp()
    XCTAssertNotEqual(app.staticTexts.allElementsBoundByIndex.map(\.label), beforeSwipe, "Swiping must advance the short video")
    shot(app, "\(prefix)-shorts-next")
    app.swipeDown()
  }

  @MainActor
  private func walkCircles(_ app: XCUIApplication, prefix: String, mutate: Bool) {
    openTab(app, "Circles")
    assertTitle(app, "Circles")
    shot(app, "\(prefix)-circles")
    for filter in ["Joined", "Saved", "Discover"] {
      if tapButton(app, filter, required: false) { shot(app, "\(prefix)-circles-\(filter.lowercased())") }
    }
    let search = app.textFields["Search circles by name or topic"]
    if search.waitForExistence(timeout: 4) {
      reveal(search, app)
      search.tap()
      search.typeText("zzzz-no-match")
      shot(app, "\(prefix)-circles-search-empty")
      search.tap()
      let clears = String(repeating: XCUIKeyboardKey.delete.rawValue, count: 14)
      search.typeText(clears)
      dismissKeyboard(app)
    } else {
      gaps.append("Circle search field missing")
    }
    guard openFirst(app, predicate: "label == 'Explore circle' OR label == 'Open joined circle'", name: "circle", required: true) else { return }
    shot(app, "\(prefix)-circle-detail")
    if mutate, app.buttons["Join circle"].exists {
      app.buttons["Join circle"].tap()
      shot(app, "\(prefix)-circle-joined")
      if app.buttons["Write a post"].waitForExistence(timeout: 4) {
        app.buttons["Write a post"].tap()
        shot(app, "\(prefix)-circle-composer")
        back(app)
      }
      if tapButton(app, "Joined · Leave circle", required: false) {
        shot(app, "\(prefix)-circle-leave-confirm")
        if app.buttons["Cancel"].waitForExistence(timeout: 3) { app.buttons["Cancel"].tap() }
        if tapButton(app, "Joined · Leave circle", required: false), app.buttons["Leave"].waitForExistence(timeout: 3) {
          app.buttons["Leave"].tap()
          shot(app, "\(prefix)-circle-left")
        }
      }
    }
    guard openFirst(app, predicate: "label BEGINSWITH 'Read discussion'", name: "discussion", required: true) else {
      back(app)
      return
    }
    shot(app, "\(prefix)-discussion")
    let reply = app.textFields["Your reply"]
    if reply.waitForExistence(timeout: 4) {
      reveal(reply, app)
      reply.tap()
      if mutate {
        reply.typeText("Local coverage reply")
        shot(app, "\(prefix)-reply-draft")
        dismissKeyboard(app)
        if tapButton(app, "Save reply", required: true) {
          let own = app.buttons["Delete reply"]
          XCTAssertTrue(own.waitForExistence(timeout: 6), "Saved local reply did not appear")
          shot(app, "\(prefix)-reply-saved")
          reveal(own, app)
          own.tap()
        }
      } else {
        reply.typeText("Draft")
        shot(app, "\(prefix)-reply-keyboard")
        reply.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5))
      }
    }
    let safety = app.buttons.matching(identifier: "Report or block").firstMatch
    if safety.exists {
      reveal(safety, app)
      safety.tap()
      shot(app, "\(prefix)-post-safety")
      if !mutate { closeSheet(app) }
      else if tapButton(app, "Report circle post", required: false) {
        shot(app, "\(prefix)-post-report-form")
        let save = app.buttons["Save report"]
        reveal(save, app)
        if save.waitForExistence(timeout: 4) { save.tap() }
        _ = app.staticTexts["Report saved"].waitForExistence(timeout: 4)
        shot(app, "\(prefix)-report-saved-local")
      }
    }
    back(app)
    back(app)
  }

  @MainActor
  private func walkChallenges(_ app: XCUIApplication, prefix: String) {
    openTab(app, "Challenges")
    assertTitle(app, "Challenges")
    shot(app, "\(prefix)-challenges")
    for filter in ["Animation", "Cosplay", "Art", "All"] {
      if tapButton(app, filter, required: false) { shot(app, "\(prefix)-challenges-\(filter.lowercased())") }
    }
    if tapButton(app, "My challenge entries", required: true) {
      shot(app, "\(prefix)-my-challenges")
      back(app)
    }
    guard openFirst(app, predicate: "label == 'Explore challenge' OR label == 'View your entry'", name: "challenge", required: true) else { return }
    shot(app, "\(prefix)-challenge-detail")
    XCTAssertTrue(app.staticTexts["Your creative brief"].waitForExistence(timeout: 4))
    if tapButton(app, "Watch inspiration", required: false) {
      shot(app, "\(prefix)-challenge-inspiration")
      if app.buttons["More"].waitForExistence(timeout: 4) {
        app.buttons["More"].tap()
        shot(app, "\(prefix)-inspiration-safety")
        closeSheet(app)
      }
      if app.buttons["Close"].firstMatch.exists { closeSheet(app) }
    }
    if app.buttons["Choose one of my videos"].exists {
      reveal(app.buttons["Choose one of my videos"], app)
      shot(app, "\(prefix)-challenge-entry-actions")
    }
    back(app)
  }

  @MainActor
  private func walkChats(_ app: XCUIApplication, prefix: String, mutate: Bool) {
    openTab(app, "Chats")
    assertTitle(app, "Chats")
    shot(app, "\(prefix)-chats")
    for filter in ["Unread", "Pinned", "Drafts", "All"] {
      if tapButton(app, filter, required: false) { shot(app, "\(prefix)-chats-\(filter.lowercased())") }
    }
    if tapButton(app, "Search chats", required: true) {
      let field = app.textFields["Search chats"]
      if field.waitForExistence(timeout: 4) {
        field.tap()
        field.typeText("Maya")
        shot(app, "\(prefix)-chats-search")
        if app.buttons["Close search"].exists { app.buttons["Close search"].tap() }
      }
    }
    openChat(app, name: "Maya Chen", shotName: "\(prefix)-chat-maya")
    let message = app.textFields["Message"]
    if message.waitForExistence(timeout: 4) {
      message.tap()
      if mutate {
        message.typeText("Coverage draft stays local")
        shot(app, "\(prefix)-chat-draft")
        back(app)
        XCUIDevice.shared.press(.home)
        app.activate()
        openTab(app, "Chats")
        openChat(app, name: "Maya Chen", shotName: "\(prefix)-chat-draft-restored")
        let restored = app.textFields["Message"]
        XCTAssertTrue(restored.waitForExistence(timeout: 5))
        XCTAssertEqual(restored.value as? String, "Coverage draft stays local")
        restored.tap()
        restored.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 28))
        restored.typeText("Local coverage hello")
        if tapButton(app, "Send", required: true) {
          let pending = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Pending'")).firstMatch
          XCTAssertTrue(pending.waitForExistence(timeout: 6), "Local outbox did not show a pending message")
          shot(app, "\(prefix)-chat-pending-local")
        }
      } else {
        shot(app, "\(prefix)-chat-keyboard")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
      }
    } else {
      gaps.append("Chat message field missing")
    }
    if !mutate, tapButton(app, "Profile", required: false) {
      shot(app, "\(prefix)-chat-profile")
      back(app)
    }
    back(app)
    if tapButton(app, "Add a friend", required: true) {
      shot(app, "\(prefix)-add-friend-sheet")
      if tapButton(app, "Create a group", required: true) {
        shot(app, "\(prefix)-create-group")
        back(app)
      }
    }
    if tapButton(app, "Add a friend", required: true),
       tapButton(app, "Add a friend", required: true) {
      let id = app.textFields["Enter an ID"]
      XCTAssertTrue(id.waitForExistence(timeout: 8))
      id.tap()
      id.typeText("qa-no-matching-id")
      XCTAssertTrue(app.staticTexts["No friend matches that ID."].waitForExistence(timeout: 8))
      shot(app, "\(prefix)-friend-search-empty")
      back(app)
    }
  }

  @MainActor
  private func walkMe(_ app: XCUIApplication, prefix: String, mutate: Bool) {
    openTab(app, "Me")
    assertTitle(app, "Me")
    shot(app, "\(prefix)-me")
    for tab in ["Works", "Liked", "Saved", "Circles (", "Challenges (", "Uploads", "About"] {
      let chip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", tab)).firstMatch
      if chip.waitForExistence(timeout: 3) {
        for _ in 0..<5 where !chip.isHittable {
          if let strip = app.scrollViews.allElementsBoundByIndex.first(where: {
            $0.frame.height > 0 && $0.frame.height < 120 && $0.frame.width > 150 && $0.isHittable
          }) {
            strip.swipeLeft()
          } else {
            app.swipeUp()
          }
        }
        reveal(chip, app)
        if chip.isHittable {
          chip.tap()
          shot(app, "\(prefix)-me-\(tab.lowercased())")
        } else {
          gaps.append("Me category \(tab) could not be reached by scrolling")
        }
      } else {
        gaps.append("Me tab \(tab) missing")
      }
    }
    if tapButton(app, "Wallet", required: true) {
      shot(app, "\(prefix)-wallet")
      XCTAssertTrue(app.staticTexts["wallet.balance"].waitForExistence(timeout: 6))
      let notice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'App Store' OR label CONTAINS 'Diamonds'")).firstMatch
      _ = notice.waitForExistence(timeout: 8)
      shot(app, "\(prefix)-wallet-catalog")
      back(app)
    }
    guard tapButton(app, "Settings", required: true) else { return }
    shot(app, "\(prefix)-settings")
    if tapButton(app, "Edit profile", required: true) {
      shot(app, "\(prefix)-edit-profile")
      back(app)
    }
    if tapButton(app, "Bibi - Terms of Service", required: true) {
      shot(app, "\(prefix)-terms")
      back(app)
    }
    if tapButton(app, "Bibi - Privacy Policy", required: true) {
      shot(app, "\(prefix)-privacy")
      back(app)
    }
    if tapButton(app, "Artwork & Credits", required: true) {
      shot(app, "\(prefix)-credits")
      app.swipeUp()
      shot(app, "\(prefix)-credits-scrolled")
      back(app)
    }
    let blocked = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Blocked'")).firstMatch
    if blocked.waitForExistence(timeout: 3) {
      reveal(blocked, app)
      blocked.tap()
      shot(app, "\(prefix)-blocked")
      closeSheet(app)
    }
    let reported = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reported'")).firstMatch
    if reported.waitForExistence(timeout: 3) {
      reveal(reported, app)
      reported.tap()
      shot(app, "\(prefix)-reported")
      closeSheet(app)
    }
    if !mutate {
      reveal(app.buttons["Log out"], app)
      if app.buttons["Log out"].exists {
        app.buttons["Log out"].tap()
        shot(app, "\(prefix)-logout-confirm")
        if app.buttons["Cancel"].waitForExistence(timeout: 3) { app.buttons["Cancel"].tap() }
      }
      reveal(app.buttons["Delete account"], app)
      if app.buttons["Delete account"].exists {
        app.buttons["Delete account"].tap()
        shot(app, "\(prefix)-delete-confirm")
        if app.buttons["Cancel"].waitForExistence(timeout: 3) { app.buttons["Cancel"].tap() }
      }
    }
    back(app)
  }

  @MainActor
  private func walkSafety(_ app: XCUIApplication) {
    openTab(app, "Me")
    if tapButton(app, "Settings", required: true) {
      let reported = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reported'")).firstMatch
      if reported.waitForExistence(timeout: 4) {
        reveal(reported, app)
        reported.tap()
        shot(app, "isolated-reported-after-save")
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Circle post'")).firstMatch
        if card.waitForExistence(timeout: 4) {
          card.press(forDuration: 1.2)
          if app.buttons["Remove report"].waitForExistence(timeout: 3) {
            app.buttons["Remove report"].tap()
            shot(app, "isolated-report-removed")
          }
        } else {
          gaps.append("Saved report card was not listed")
        }
        closeSheet(app)
      }
      back(app)
    }
    openTab(app, "Shorts")
    let profile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open '")).firstMatch
    guard profile.waitForExistence(timeout: 6) else { return }
    profile.tap()
    guard tapButton(app, "Report or block", required: true) else { return }
    let block = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Block '")).firstMatch
    guard block.waitForExistence(timeout: 4) else { return }
    let creator = block.label
    block.tap()
    shot(app, "isolated-block-confirm")
    if app.buttons["Cancel"].waitForExistence(timeout: 2) {
      app.buttons["Cancel"].tap()
      block.tap()
    }
    XCTAssertTrue(tapButton(app, "Block", required: true))
    shot(app, "isolated-after-block")
    openTab(app, "Me")
    if tapButton(app, "Settings", required: true) {
      let blocked = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Blocked'")).firstMatch
      reveal(blocked, app)
      blocked.tap()
      shot(app, "isolated-blocked-list")
      let row = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", String(creator.dropFirst("Block ".count)))).firstMatch
      if row.waitForExistence(timeout: 3) { row.press(forDuration: 1.2) }
      if app.buttons["Unblock"].waitForExistence(timeout: 3) {
        app.buttons["Unblock"].tap()
        shot(app, "isolated-unblocked")
      } else {
        gaps.append("Could not unblock after \(creator)")
      }
      closeSheet(app)
      back(app)
    }
  }

  @MainActor
  private func walkPermissionsAndAccount(_ app: XCUIApplication) {
    openTab(app, "Chats")
    openChat(app, name: "Maya Chen", shotName: "isolated-call-entry")
    if tapButton(app, "Voice call", required: false) {
      let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
      let deny = springboard.buttons["Don’t Allow"]
      if deny.waitForExistence(timeout: 4) { deny.tap() }
      shot(app, "isolated-voice-call")
      if app.buttons["End call"].waitForExistence(timeout: 4) { app.buttons["End call"].tap() }
      else { back(app) }
    }
    back(app)
    if tapButton(app, "Add a friend", required: false), tapButton(app, "Scan", required: false) {
      let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
      let deny = springboard.buttons["Don’t Allow"]
      if deny.waitForExistence(timeout: 4) { deny.tap() }
      shot(app, "isolated-scan-camera")
      if app.buttons["Close"].firstMatch.exists { closeSheet(app) }
      else { back(app) }
    }
    openTab(app, "Me")
    guard tapButton(app, "Settings", required: true) else { return }
    reveal(app.buttons["Log out"], app)
    app.buttons["Log out"].tap()
    shot(app, "isolated-logout-confirm")
    XCTAssertTrue(tapButton(app, "Log out", required: true))
    XCTAssertTrue(app.buttons["Enter Bibi"].waitForExistence(timeout: 10), "Logout did not return to account entry")
    shot(app, "isolated-after-logout")
    enter(app, prefix: "isolated-reenter")
    openTab(app, "Chats")
    openChat(app, name: "Maya Chen", shotName: "isolated-chat-after-logout")
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Local coverage hello'")).firstMatch.waitForExistence(timeout: 5), "Local outbox did not survive logout")
    back(app)
    openTab(app, "Me")
    guard tapButton(app, "Settings", required: true) else { return }
    reveal(app.buttons["Delete account"], app)
    app.buttons["Delete account"].tap()
    shot(app, "isolated-delete-confirm")
    if app.buttons["Cancel"].waitForExistence(timeout: 3) { app.buttons["Cancel"].tap() }
    reveal(app.buttons["Delete account"], app)
    app.buttons["Delete account"].tap()
    XCTAssertTrue(tapButton(app, "Delete account", required: true))
    XCTAssertTrue(app.buttons["Enter Bibi"].waitForExistence(timeout: 12), "Deleting the local account did not return to account entry")
    shot(app, "isolated-after-delete")
    enter(app, prefix: "isolated-after-delete")
    openTab(app, "Chats")
    openChat(app, name: "Maya Chen", shotName: "isolated-chat-after-delete")
    XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Local coverage hello'")).firstMatch.exists, "Deleted account still shows the local outbox message")
  }

  @MainActor
  private func openChat(_ app: XCUIApplication, name: String, shotName: String) {
    let row = app.staticTexts[name]
    if !row.waitForExistence(timeout: 6) {
      gaps.append("Chat row \(name) missing")
      XCTFail("Missing chat \(name)")
      return
    }
    reveal(row, app)
    row.tap()
    XCTAssertTrue(app.textFields["Message"].waitForExistence(timeout: 6) || app.staticTexts[name].exists)
    shot(app, shotName)
  }

  @discardableResult
  @MainActor
  private func openFirst(_ app: XCUIApplication, predicate: String, name: String, required: Bool) -> Bool {
    dismissKeyboard(app)
    let button = app.buttons.matching(NSPredicate(format: predicate)).firstMatch
    if !button.waitForExistence(timeout: 6) {
      if required { XCTFail("Missing \(name)") }
      gaps.append("Missing \(name)")
      return false
    }
    reveal(button, app)
    guard button.isHittable else {
      gaps.append("\(name) was not hittable")
      return false
    }
    button.tap()
    return true
  }

  @discardableResult
  @MainActor
  private func tapButton(_ app: XCUIApplication, _ label: String, required: Bool) -> Bool {
    let matches = app.buttons.matching(identifier: label)
    let button = matches.allElementsBoundByIndex.reversed().first(where: { app.frame.contains($0.frame) && $0.isHittable }) ?? matches.firstMatch
    if !button.waitForExistence(timeout: 5) {
      if required { XCTFail("Missing button \(label)") }
      gaps.append("Missing button \(label)")
      return false
    }
    if !button.isHittable { reveal(button, app) }
    guard button.isHittable else {
      shot(app, "unreachable-" + label)
      if required { XCTFail("Button \(label) is not hittable") }
      gaps.append("Button \(label) is not hittable")
      return false
    }
    button.tap()
    return true
  }

  @MainActor
  private func openTab(_ app: XCUIApplication, _ title: String) {
    dismissKeyboard(app)
    for _ in 0..<6 {
      let back = app.buttons["Back"]
      if back.exists, back.isHittable { back.tap(); continue }
      let close = app.buttons.matching(identifier: "Close").allElementsBoundByIndex.reversed().first(where: { $0.isHittable })
      if let close, !app.buttons["tab.\(title)"].isHittable { close.tap(); continue }
      break
    }
    let tab = app.buttons["tab.\(title)"]
    if !tab.waitForExistence(timeout: 6) {
      gaps.append("Tab \(title) was not reachable")
      XCTFail("Tab \(title) was not reachable")
      return
    }
    if !tab.isSelected { tab.tap() }
  }

  @MainActor
  private func dismissKeyboard(_ app: XCUIApplication) {
    guard app.keyboards.firstMatch.exists else { return }
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.3))
    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.62))
    start.press(forDuration: 0.1, thenDragTo: end)
  }

  @MainActor
  private func closeSheet(_ app: XCUIApplication) {
    let close = app.buttons.matching(identifier: "Close").allElementsBoundByIndex.reversed().first(where: { $0.isHittable })
    if let close {
      close.tap()
      return
    }
    gaps.append("Close was not available for a sheet")
  }

  @MainActor
  private func back(_ app: XCUIApplication) {
    let back = app.buttons["Back"]
    if back.waitForExistence(timeout: 3), back.isHittable {
      back.tap()
      return
    }
    gaps.append("Back was not available")
  }

  @MainActor
  private func assertTitle(_ app: XCUIApplication, _ title: String) {
    let header = app.descendants(matching: .any).matching(identifier: "page-title.\(title)").firstMatch
    XCTAssertTrue(header.waitForExistence(timeout: 6), "Missing title \(title)")
    XCTAssertEqual(header.label, title)
    let tab = app.buttons["tab.\(title)"]
    if tab.exists, header.exists, header.frame.intersects(tab.frame) {
      gaps.append("Title \(title) overlaps its tab")
      XCTFail("Title \(title) overlaps its tab")
    }
    if header.exists, !app.frame.contains(header.frame.insetBy(dx: -1, dy: -1)) {
      gaps.append("Title \(title) is outside the window")
    }
  }

  @MainActor
  private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
    for _ in 0..<5 {
      let bottom = app.keyboards.firstMatch.exists
        ? app.keyboards.firstMatch.frame.minY - 8 : app.frame.maxY - 70
      if element.exists, element.isHittable,
         element.frame.minY >= app.frame.minY + 60, element.frame.maxY <= bottom { return }
      if element.exists, element.frame.midY < app.frame.midY {
        app.swipeDown()
      } else {
        app.swipeUp()
      }
    }
  }

  @MainActor
  private func waitUntil(_ element: XCUIElement, format: String, _ value: String, timeout: TimeInterval) -> Bool {
    let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: format, value), object: element)
    return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
  }

  @MainActor
  private func shot(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func attachNotes(_ name: String) {
    let attachment = XCTAttachment(string: gaps.isEmpty ? "No coverage gaps recorded." : gaps.joined(separator: "\n"))
    attachment.name = "coverage-notes-\(name)"
    attachment.lifetime = .keepAlways
    add(attachment)
    if !gaps.isEmpty {
      XCTFail("Coverage gaps:\n" + gaps.joined(separator: "\n"))
    }
  }
}
