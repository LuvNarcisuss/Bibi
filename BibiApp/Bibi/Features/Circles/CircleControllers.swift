import UIKit

/// Taps on card whitespace and copy navigate; embedded controls keep their own actions.
@MainActor private final class CommunityNavigationCard: UIView, UIGestureRecognizerDelegate {
  private let onOpen: () -> Void
  init(onOpen: @escaping () -> Void) {
    self.onOpen = onOpen
    super.init(frame: .zero)
    let tap = UITapGestureRecognizer(target: self, action: #selector(openContent))
    tap.delegate = self
    addGestureRecognizer(tap)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  @objc private func openContent() { onOpen() }
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    var node = touch.view
    while let view = node, view !== self {
      if view is UIControl || view is UITextView { return false }
      node = view.superview
    }
    return true
  }
}

@MainActor func communityCard(_ rows: [UIView], onOpen: (() -> Void)? = nil, compact: Bool = false) -> UIView {
  let card: UIView
  if let onOpen { card = CommunityNavigationCard(onOpen: onOpen) }
  else { card = UIView() }
  card.backgroundColor = BibiPalette.soft
  card.rounded(compact ? 18 : 24)
  let column = stack(rows, spacing: compact ? 8 : 12)
  card.addSubview(column)
  let pad: CGFloat = compact ? 10 : 18
  column.pin(to: card, insets: UIEdgeInsets(top: pad, left: pad, bottom: pad, right: pad))
  return card
}

/// Places home cards in two equal columns. A short last row keeps the left card at half width.
@MainActor func addTwoColumns(_ cards: [UIView], to results: UIStackView) {
  var index = 0
  while index < cards.count {
    let left = cards[index]
    let right: UIView
    if index + 1 < cards.count {
      right = cards[index + 1]
    } else {
      right = UIView()
      right.isAccessibilityElement = false
    }
    let row = stack([left, right], axis: .horizontal, spacing: 12)
    row.distribution = .fillEqually
    row.alignment = .fill
    results.addArrangedSubview(row)
    index += 2
  }
}

/// A short primary action for a half-width home card. The label stays unchanged.
@MainActor func gridActionButton(_ title: String, icon: BibiIcon, action: @escaping () -> Void) -> BibiButton {
  let button = actionButton(title, icon: icon, primary: true, compact: true, iconSize: 14, action: action)
  button.caption.font = BibiPalette.font(12)
  button.caption.numberOfLines = 2
  button.caption.adjustsFontSizeToFitWidth = true
  button.caption.minimumScaleFactor = 0.8
  button.setContentHuggingPriority(.defaultLow, for: .horizontal)
  button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
  button.caption.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
  return button
}

/// Makes visual content an accessible navigation target without nesting its credit link.
@MainActor func communityMediaLink(
  _ artwork: UIView, label: String, identifier: String, action: @escaping () -> Void
) -> UIControl {
  let control = UIControl()
  artwork.isUserInteractionEnabled = false
  artwork.isAccessibilityElement = false
  control.addSubview(artwork)
  artwork.pin(to: control)
  control.isAccessibilityElement = true
  control.accessibilityLabel = label
  control.accessibilityIdentifier = identifier
  control.accessibilityTraits = .button
  control.addAction(UIAction { _ in action() }, for: .touchUpInside)
  return control
}

@MainActor private func circleAuthorRow(
  _ post: CirclePost, store: AppStore, onOpen: @escaping (CreatorProfile) -> Void
) -> UIView {
  let author = post.author.isLocalOwner ? CreatorProfile.signedIn(store.library.profile) : post.author
  let portrait = roundPortrait(asset: author.avatarAsset, size: 44,
                               personID: author.id, remoteURL: author.avatarURL)
  let profile = communityMediaLink(
    portrait, label: "View " + author.name + "'s profile",
    identifier: "circle.author." + post.id.uuidString
  ) { onOpen(author) }
  var details: [UIView] = [label(author.name, 16, BibiPalette.accent)]
  if post.isCharacterStory {
    details.append(label("Bibi Stories · Fictional character", 12, BibiPalette.muted))
  } else if post.isEditorial {
    details.append(label("Creative prompt", 12, BibiPalette.muted))
  }
  let row = stack([profile, stack(details, spacing: 3)], axis: .horizontal, spacing: 10)
  row.alignment = .center
  return row
}

@MainActor func circleStoryArtwork(_ asset: String, postID: UUID? = nil, onOpen: (() -> Void)? = nil) -> UIView {
  let image = BibiArtwork(asset: asset)
  image.contentMode = .scaleAspectFit
  image.translatesAutoresizingMaskIntoConstraints = false
  let size = image.image?.size ?? CGSize(width: 4, height: 3)
  let ratio = min(1.25, max(0.55, size.height / max(size.width, 1)))
  image.heightAnchor.constraint(equalTo: image.widthAnchor, multiplier: ratio).isActive = true
  image.rounded(18)
  image.isAccessibilityElement = true
  let media = CommunityCatalog.storyMedia[asset]
  image.accessibilityLabel = media?.description ?? "Post cover"
  let artwork: UIView
  if let onOpen, let postID {
    artwork = communityMediaLink(image, label: "Read discussion. " + (media?.description ?? "Post cover"),
                                 identifier: "circle.cover." + postID.uuidString, action: onOpen)
  } else {
    artwork = image
  }
  guard let media else { return artwork }
  let credit = actionButton(media.credit, icon: .share, compact: true, iconSize: 14) {
    guard let url = URL(string: media.source) else { return }
    UIApplication.shared.open(url)
  }
  credit.caption.font = BibiPalette.font(11)
  credit.accessibilityLabel = "View source. " + media.credit
  credit.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
  return stack([artwork, credit], spacing: 5)
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
        subtitle: "Join a circle. Start a conversation.", artwork: "PostCover-PinkArmor"))
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
      addTwoColumns(posts.map { postSummary($0) }, to: results)
      return
    }
    let circles = store.availableCircles.filter {
      (filter != 1 || store.community.joinedCircleIDs.contains($0.id))
        && (text.isEmpty || ($0.title + " " + $0.subtitle).localizedCaseInsensitiveContains(text))
    }
    if circles.isEmpty {
      results.addArrangedSubview(
        label(
          filter == 1 ? "Your joined circles will appear here." : "No circles match your search.",
          16, BibiPalette.muted))
    }
    var cards: [UIView] = []
    for circle in circles {
      let joined = store.community.joinedCircleIDs.contains(circle.id)
      let art = BibiArtwork(asset: circle.artwork)
      art.translatesAutoresizingMaskIntoConstraints = false
      art.heightAnchor.constraint(equalTo: art.widthAnchor).isActive = true
      art.rounded(14)
      let openCircle: () -> Void = { [weak self] in
        guard let self else { return }
        self.push(CircleDetailController(store: self.store, circle: circle))
      }
      let cover = communityMediaLink(art, label: "Explore " + circle.title,
                                    identifier: "circle.cover." + circle.id, action: openCircle)
      let title = label(circle.title, 16, title: true)
      title.numberOfLines = 2
      let subtitle = label(circle.subtitle, 13, BibiPalette.muted)
      subtitle.numberOfLines = 2
      cards.append(
        communityCard([
          cover, title, subtitle,
          gridActionButton(
            joined ? "Open joined circle" : "Explore circle", icon: .planet, action: openCircle),
        ], onOpen: openCircle, compact: true))
    }
    addTwoColumns(cards, to: results)
  }
  private func postSummary(_ post: CirclePost) -> UIView {
    let body = label(post.body, 16)
    body.numberOfLines = 4
    var rows: [UIView] = [
      circleAuthorRow(post, store: store) { [weak self] author in
        guard let self else { return }
        self.push(CreatorController(store: self.store, creator: author))
      }, body,
      gridActionButton("Read discussion", icon: .comment) { [weak self] in
        guard let self else { return }
        self.push(CirclePostController(store: self.store, postID: post.id))
      },
    ]
    if !post.author.isLocalOwner { rows.append(communitySafetyButton(post)) }
    return communityCard(rows, onOpen: { [weak self] in
      guard let self else { return }
      self.push(CirclePostController(store: self.store, postID: post.id))
    })
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
            message: self.store.isOnline ? "Your posts and saved discussions will remain in your account." : "Your posts and saved discussions will stay on this device.", button: "Leave"
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
        store.isOnline ? "Posts are reviewed before publication. Replies appear after they are saved online." : "Bibi Stories features fictional characters and prewritten conversations. Your posts and replies stay on this device. Online publishing is not connected.", 13,
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
        circleAuthorRow(post, store: store) { [weak self] author in
          guard let self else { return }
          self.push(CreatorController(store: self.store, creator: author))
        }, body,
      ]
      if let asset = post.bundledArtwork {
        rows.append(circleStoryArtwork(asset, postID: post.id) { [weak self] in
          guard let self else { return }
          self.push(CirclePostController(store: self.store, postID: post.id))
        })
      }
      if let url = post.remotePhotoURL {
        let art = BibiArtwork(); art.load(url); art.contentMode = .scaleAspectFit
        art.height(260); art.rounded(20); art.accessibilityLabel = "Photo attached to post"
        rows.append(communityMediaLink(art, label: "Read discussion", identifier: "circle.cover." + post.id.uuidString) { [weak self] in
          guard let self else { return }
          self.push(CirclePostController(store: self.store, postID: post.id))
        })
      }
      if let data = post.photo, let image = UIImage(data: data) {
        let art = BibiArtwork()
        art.image = image
        art.height(180)
        art.rounded(18)
        paintCoverTemplate(art, itemID: post.coverStyleID)
        art.accessibilityLabel = "Photo attached to post"
        rows.append(communityMediaLink(art, label: "Read discussion", identifier: "circle.cover." + post.id.uuidString) { [weak self] in
          guard let self else { return }
          self.push(CirclePostController(store: self.store, postID: post.id))
        })
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
      if !post.author.isLocalOwner { rows.append(communitySafetyButton(post)) }
      let counts = store.circlePostCounts(for: post)
      rows.append(label("\(counts.likes) likes · \(counts.saves) saves", 12, BibiPalette.muted))
      content.addArrangedSubview(communityCard(rows, onOpen: { [weak self] in
        guard let self else { return }
        self.push(CirclePostController(store: self.store, postID: post.id))
      }))
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
      circleAuthorRow(post, store: store) { [weak self] author in
        guard let self else { return }
        self.push(CreatorController(store: self.store, creator: author))
      })
    content.addArrangedSubview(
      label(post.isCharacterStory ? "Bibi Stories · Fictional characters and a prewritten conversation" : post.isEditorial ? "Creative prompt" : (store.isOnline ? (post.remoteStatus == "pending" ? "Awaiting review" : post.remoteStatus == "rejected" ? "Not approved" : "Community post") : "Saved on this device"), 13, BibiPalette.muted))
    content.addArrangedSubview(label(post.body, 19))
    let counts = store.circlePostCounts(for: post)
    content.addArrangedSubview(label("\(counts.likes) likes · \(counts.saves) saves", 12, BibiPalette.muted))
    if let asset = post.bundledArtwork {
      content.addArrangedSubview(circleStoryArtwork(asset))
    }
    if let url = post.remotePhotoURL {
      let art = BibiArtwork(); art.load(url); art.contentMode = .scaleAspectFit
      art.height(260); art.rounded(20); art.accessibilityLabel = "Photo attached to post"
      content.addArrangedSubview(art)
    }
    if let data = post.photo, let image = UIImage(data: data) {
      let art = BibiArtwork()
      art.image = image
      art.contentMode = .scaleAspectFit
      art.height(260)
      art.rounded(20)
      paintCoverTemplate(art, itemID: post.coverStyleID)
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
        actionButton("Report or block", icon: .flag) { [weak self] in
          guard let self else { return }
          self.presentCommunitySafety(ContentSafetyTarget(
            id: post.id.uuidString, title: post.body, kind: .circlePost, creator: author))
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
          actionButton("Report or block", icon: .flag, compact: true) { [weak self] in
            guard let self else { return }
            self.presentCommunitySafety(ContentSafetyTarget(
              id: comment.id.uuidString, title: comment.text, kind: .comment, creator: comment.author))
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


extension BibiScreen {
  func communitySafetyButton(_ post: CirclePost) -> UIView {
    let button = actionButton("Report or block", icon: .flag, compact: true) { [weak self] in
      guard let self else { return }
      let safety = SafetyController(store: self.store, target: ContentSafetyTarget(
        id: post.id.uuidString, title: String(post.body.prefix(100)), kind: .circlePost, creator: post.author))
      safety.onResolved = { [weak self] in self?.refresh() }
      self.presentScreen(safety)
    }
    button.accessibilityIdentifier = "circle.safety." + post.id.uuidString
    return button
  }
}

@MainActor extension BibiScreen {
  func presentCommunitySafety(_ target: ContentSafetyTarget) {
    guard !target.creator.isLocalOwner else { return }
    let screen = SafetyController(store: store, target: target)
    screen.onResolved = { [weak self] in self?.refresh() }
    presentScreen(screen)
  }
}
