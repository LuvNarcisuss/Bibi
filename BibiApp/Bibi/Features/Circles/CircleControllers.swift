import UIKit

@MainActor func communityCard(_ rows: [UIView]) -> UIView {
  let card = UIView()
  card.backgroundColor = BibiPalette.soft
  card.rounded(24)
  let column = stack(rows, spacing: 12)
  card.addSubview(column)
  column.pin(to: card, insets: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18))
  return card
}

final class CirclesController: StackScreen {
  private let query = field("Search circles")
  private let results = stack()
  private var filter: Int
  init(store: AppStore, filter: Int = 0) {
    self.filter = filter
    super.init(store: store, title: "Circles")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func build() {
    super.build()
    if navigationController?.viewControllers.first === self {
      navigationItem.leftBarButtonItem = barButton(bibiMark())
    }
    content.addArrangedSubview(
      ConstellationBanner(
        eyebrow: "Find your people", title: "A place for every\nimagination.",
        subtitle: "Join a circle. Start a conversation.", artwork: "BibiRoom4"))
    query.accessibilityLabel = "Search circles by name or topic"
    query.addAction(UIAction { [weak self] _ in self?.refresh() }, for: .editingChanged)
    content.addArrangedSubview(query)
    let tabs = StudioChoice(items: ["Discover", "Joined", "Saved"], index: filter)
    tabs.onChange = { [weak self] next in
      self?.filter = next
      self?.refresh()
    }
    content.addArrangedSubview(tabs)
    content.addArrangedSubview(results)
  }
  override func refresh() {
    guard isViewLoaded else { return }
    results.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let text = (query.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if filter == 2 {
      let posts = store.circlePosts(savedOnly: true).filter {
        text.isEmpty || $0.body.localizedCaseInsensitiveContains(text)
      }
      if posts.isEmpty {
        results.addArrangedSubview(
          label("Save a post to keep the conversation close.", 16, BibiPalette.muted))
      }
      for post in posts { results.addArrangedSubview(postSummary(post)) }
      return
    }
    let circles = CommunityCatalog.circles.filter {
      (filter != 1 || store.community.joinedCircleIDs.contains($0.id))
        && (text.isEmpty || ($0.title + " " + $0.subtitle).localizedCaseInsensitiveContains(text))
    }
    if circles.isEmpty {
      results.addArrangedSubview(
        label(
          filter == 1 ? "Your joined circles will appear here." : "No circles match your search.",
          16, BibiPalette.muted))
    }
    for circle in circles {
      let joined = store.community.joinedCircleIDs.contains(circle.id)
      let art = BibiArtwork(asset: circle.artwork)
      art.height(130)
      art.rounded(18)
      art.isAccessibilityElement = false
      results.addArrangedSubview(
        communityCard([
          art, label(circle.title, 23, title: true), label(circle.subtitle, 16, BibiPalette.muted),
          actionButton(
            joined ? "Open joined circle" : "Explore circle", icon: .planet, primary: true
          ) { [weak self] in
            guard let self else { return }
            self.push(CircleDetailController(store: self.store, circle: circle))
          },
        ]))
    }
  }
  private func postSummary(_ post: CirclePost) -> UIView {
    let body = label(post.body, 16)
    body.numberOfLines = 4
    return communityCard([
      label(post.author.name, 14, BibiPalette.accent), body,
      actionButton("Read discussion", icon: .comment) { [weak self] in
        guard let self else { return }
        self.push(CirclePostController(store: self.store, postID: post.id))
      },
    ])
  }
}

final class CircleDetailController: StackScreen {
  let circle: InterestCircle
  init(store: AppStore, circle: InterestCircle) {
    self.circle = circle
    super.init(store: store, title: circle.title)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    let joined = store.community.joinedCircleIDs.contains(circle.id)
    content.addArrangedSubview(
      ConstellationBanner(
        eyebrow: "Interest circle", title: circle.title, subtitle: circle.subtitle,
        artwork: circle.artwork))
    content.addArrangedSubview(
      actionButton(
        joined ? "Joined · Leave circle" : "Join circle", icon: joined ? .check : .plus,
        primary: !joined
      ) { [weak self] in
        guard let self else { return }
        if joined {
          self.confirm(
            "Leave this circle?",
            message: "Your posts and saved discussions will stay on this device.", button: "Leave"
          ) {
            self.save { await self.store.toggleCircle(self.circle.id) }
          }
        } else {
          self.save { await self.store.toggleCircle(self.circle.id) }
        }
      })
    if joined {
      content.addArrangedSubview(
        actionButton("Write a post", icon: .plus, primary: true) { [weak self] in
          guard let self else { return }
          self.push(CircleComposerController(store: self.store, circle: self.circle))
        })
    }
    content.addArrangedSubview(
      label(
        "Posts and replies are saved on this device. Online publishing is not connected.", 13,
        BibiPalette.muted))
    heading("Conversations")
    let posts = store.circlePosts(in: circle.id)
    if posts.isEmpty {
      content.addArrangedSubview(
        label("No conversations yet. Start with a thought or a work in progress."))
    }
    for post in posts {
      let body = label(post.body, 16)
      body.numberOfLines = 5
      var rows: [UIView] = [
        label(
          post.isEditorial ? "Bibi Editorial · Creative prompt" : post.author.name, 14,
          BibiPalette.accent), body,
      ]
      if let data = post.photo, let image = UIImage(data: data) {
        let art = BibiArtwork()
        art.image = image
        art.height(180)
        art.rounded(18)
        art.accessibilityLabel = "Photo attached to post"
        rows.append(art)
      }
      let replyCount = store.circleReplies(for: post.id).count
      let replyLabel = replyCount == 1 ? "reply" : "replies"
      rows.append(
        actionButton(
          "Read discussion · \(replyCount) \(replyLabel)", icon: .comment
        ) { [weak self] in
          guard let self else { return }
          self.push(CirclePostController(store: self.store, postID: post.id))
        })
      content.addArrangedSubview(communityCard(rows))
    }
  }
}

final class CirclePostController: StackScreen {
  private let postID: UUID
  private let reply = field("Write a reply")
  private var sending = false
  init(store: AppStore, postID: UUID) {
    self.postID = postID
    super.init(store: store, title: "Discussion")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func refresh() {
    guard isViewLoaded else { return }
    // Keep the same field instance so a save or safety refresh never discards a draft.
    clear()
    guard let post = store.circlePosts().first(where: { $0.id == postID }) else {
      content.addArrangedSubview(label("This post is no longer available.", 20, title: true))
      return
    }
    let author =
      post.author.isLocalOwner ? CreatorProfile.signedIn(store.library.profile) : post.author
    content.addArrangedSubview(
      actionButton(author.name, icon: .me) { [weak self] in
        guard let self else { return }
        self.push(CreatorController(store: self.store, creator: author))
      })
    content.addArrangedSubview(
      label(post.isEditorial ? "Creative prompt" : "Saved on this device", 13, BibiPalette.muted))
    content.addArrangedSubview(label(post.body, 19))
    if let data = post.photo, let image = UIImage(data: data) {
      let art = BibiArtwork()
      art.image = image
      art.contentMode = .scaleAspectFit
      art.height(260)
      art.rounded(20)
      art.accessibilityLabel = "Photo attached to post"
      content.addArrangedSubview(art)
    }
    if let id = post.videoID {
      if let video = store.communityVideo(id) {
        content.addArrangedSubview(
          actionButton("Watch · " + video.title, icon: .play) { [weak self] in
            self?.watchCommunityVideo(id)
          })
      } else {
        content.addArrangedSubview(
          label("The attached video is unavailable.", 14, BibiPalette.muted))
      }
    }
    let saved = store.community.savedPostIDs.contains(post.id)
    content.addArrangedSubview(
      actionButton(
        saved ? "Saved · Remove bookmark" : "Save post", icon: saved ? .starFill : .bookmark
      ) { [weak self] in
        guard let self else { return }
        self.save { await self.store.togglePostSaved(post.id) }
      })
    if author.isLocalOwner {
      content.addArrangedSubview(
        actionButton("Delete post", icon: .trash, tone: .danger) { [weak self] in
          guard let self else { return }
          self.confirm(
            "Delete this post?",
            message:
              "Its photo and replies will also be removed. Attached videos remain in your library.",
            destructive: true, button: "Delete"
          ) {
            self.save { await self.store.deleteCirclePost(post.id) }
          }
        })
    } else {
      content.addArrangedSubview(
        actionButton("Report post", icon: .flag) { [weak self] in
          guard let self else { return }
          self.presentScreen(
            SafetyController(
              store: self.store,
              target: ContentSafetyTarget(
                id: post.id.uuidString, title: post.body, kind: .circlePost, creator: author),
              reporting: true))
        })
    }
    heading("Discussion")
    for comment in store.circleReplies(for: post.id) {
      var rows: [UIView] = [
        label(
          comment.author.isLocalOwner ? store.library.profile.displayName : comment.author.name, 14,
          BibiPalette.accent), label(comment.text),
      ]
      if comment.author.isLocalOwner {
        rows.append(
          actionButton("Delete reply", icon: .trash, compact: true) { [weak self] in
            guard let self else { return }
            self.save { await self.store.deleteCircleReply(comment.id) }
          })
      } else {
        rows.append(
          actionButton("Report reply", icon: .flag, compact: true) { [weak self] in
            guard let self else { return }
            self.presentScreen(
              SafetyController(
                store: self.store,
                target: ContentSafetyTarget(
                  id: comment.id.uuidString, title: comment.text, kind: .comment,
                  creator: comment.author), reporting: true))
          })
      }
      content.addArrangedSubview(communityCard(rows))
    }
    content.addArrangedSubview(
      label("Your reply · English, up to 500 characters", 13, BibiPalette.muted))
    reply.accessibilityLabel = "Your reply"
    reply.isEnabled = !sending
    content.addArrangedSubview(reply)
    let send = actionButton(sending ? "Saving…" : "Save reply", icon: .send, primary: true) {
      [weak self] in self?.sendReply()
    }
    send.isEnabled = !sending && !store.isBusy
    content.addArrangedSubview(send)
  }
  private func sendReply() {
    guard !sending else { return }
    let text = reply.text ?? ""
    sending = true
    Task {
      let saved = await store.addCircleReply(postID: postID, text: text)
      sending = false
      if saved {
        if reply.text == text { reply.text = "" }
        reply.resignFirstResponder()
      } else {
        message(store.lastSaveError ?? "Your reply could not be saved.")
      }
      refresh()
    }
  }
}

extension BibiScreen {
  func watchCommunityVideo(_ id: UUID) {
    guard let video = store.communityVideo(id) else {
      message("This video is no longer available.")
      return
    }
    presentScreen(VideoFeedController(store: store, videos: [video], initial: id), full: true)
  }
}
