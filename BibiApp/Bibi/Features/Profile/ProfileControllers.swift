import Combine
import PhotosUI
import UIKit
import UniformTypeIdentifiers

final class MeController: StackScreen, UIScrollViewDelegate {
  private var selection = 0
  private let profileHeader = stack(spacing: 18)
  private let body = stack(spacing: 18)
  private let categorySlot = UIView()
  private let categoryChrome = UIView()
  private let categoryWash = StarlightCanvas()
  private var categories: StudioChoice?
  private var categoryPins: [NSLayoutConstraint] = []
  private var categoryHeight: CGFloat {
    max(50, BibiPalette.font(14, title: true).lineHeight + 24)
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if isViewLoaded { refresh() }
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    placeCategoryBar()
  }
  override func build() {
    super.build()
    title = "Me"
    navigationItem.leftBarButtonItem = barButton(bibiMark())
    scroll.contentInset.bottom = 28
    scroll.delegate = self
    navigationItem.rightBarButtonItem = barButton(
      iconButton(.settings, "Settings") { [weak self] in
        guard let self else { return }
        self.push(SettingsController(store: self.store))
      })
    content.addArrangedSubview(profileHeader)
    categorySlot.translatesAutoresizingMaskIntoConstraints = false
    categorySlot.heightAnchor.constraint(equalToConstant: categoryHeight).isActive = true
    content.addArrangedSubview(categorySlot)
    content.addArrangedSubview(body)
    categoryChrome.backgroundColor = .clear
    categoryChrome.clipsToBounds = true
    categoryChrome.isHidden = true
    categoryChrome.translatesAutoresizingMaskIntoConstraints = true
    categoryWash.isUserInteractionEnabled = false
    categoryChrome.addSubview(categoryWash)
    scroll.addSubview(categoryChrome)
  }
  func scrollViewDidScroll(_ scrollView: UIScrollView) { placeCategoryBar() }
  override func refresh() {
    guard isViewLoaded else { return }
    updateHeader()
    ensureCategories()
    fillBody()
    placeCategoryBar()
  }
  private func updateHeader() {
    profileHeader.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let photo = BibiArtwork(size: 92, round: true)
    photo.image =
      store.ownerAvatarImage()
      ?? UIImage(named: CommunityArtwork.creatorAvatar(for: "local-owner"))
    if store.isOnline { photo.load(store.library.profile.remoteAvatarURL, fallback: "BibiMark") }
    paintAvatarFrame(photo, itemID: store.wallet.snapshot.cosmetics.avatarFrameID)
    let identity = stack([
      photo, label(store.library.profile.displayName, 26, title: true),
      label(store.library.profile.biography, 16, BibiPalette.muted),
    ])
    identity.alignment = .center
    let wash = CosmeticCatalog.item(store.wallet.snapshot.cosmetics.profileBackgroundID).map { BibiPalette.color($0.hex) }
    profileHeader.addArrangedSubview(starlightProfileCard([identity], wash: wash))
    profileHeader.addArrangedSubview(
      actionButton("Wallet", icon: .diamond, tone: .lime) { [weak self] in
        guard let self else { return }
        self.push(WalletController(store: self.store))
      })
  }
  private func categoryTitles() -> [String] {
    let works = store.personalWorks
    let posts = store.creatorPosts(for: CreatorProfile.signedIn(store.library.profile).id)
    let savedPosts = store.circlePosts(savedOnly: true)
    let joined = store.availableCircles.filter { store.community.joinedCircleIDs.contains($0.id) }
    return [
      "Works (\(works.count + posts.count))", "Liked (\(store.likedVideos.count))",
      "Saved (\(store.savedVideos.count + savedPosts.count))",
      "Circles (\(joined.count))", "Challenges (\(store.community.entries.count))",
      "Uploads (\(store.pendingSubmissions.count))", "About",
    ]
  }
  private func ensureCategories() {
    let titles = categoryTitles()
    if let categories {
      categories.updateTitles(titles)
      return
    }
    let tabs = StudioChoice(items: titles, index: selection)
    tabs.onChange = { [weak self] next in
      guard let self, next != self.selection else { return }
      self.selection = next
      self.fillBody()
      self.placeCategoryBar()
    }
    categories = tabs
    placeCategories(pinned: false)
  }
  /// The chips stay in the scrolling slot until the bar pins. A frame-only overlay
  /// stays at zero size through the first layout pass, so the chips would not appear
  /// until the next interaction.
  @discardableResult
  private func placeCategories(pinned: Bool) -> Bool {
    guard let tabs = categories else { return false }
    let host: UIView = pinned ? categoryChrome : categorySlot
    if tabs.superview === host { return false }
    NSLayoutConstraint.deactivate(categoryPins)
    tabs.removeFromSuperview()
    host.addSubview(tabs)
    let inset: CGFloat = pinned ? 16 : 0
    tabs.translatesAutoresizingMaskIntoConstraints = false
    categoryPins = [
      tabs.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: inset),
      tabs.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -inset),
      tabs.topAnchor.constraint(equalTo: host.topAnchor),
      tabs.bottomAnchor.constraint(equalTo: host.bottomAnchor),
    ]
    NSLayoutConstraint.activate(categoryPins)
    return true
  }
  private func placeCategoryBar() {
    guard categorySlot.bounds.height > 0, scroll.bounds.width > 0 else { return }
    let slot = categorySlot.convert(categorySlot.bounds, to: scroll)
    let pinned = slot.minY < scroll.contentOffset.y
    if pinned {
      categoryChrome.isHidden = false
      categoryChrome.frame = CGRect(
        x: 0, y: scroll.contentOffset.y, width: scroll.bounds.width, height: slot.height)
      categoryWash.frame = categoryChrome.convert(atmosphereFrame(), from: view)
      scroll.bringSubviewToFront(categoryChrome)
      if placeCategories(pinned: true) { categoryChrome.layoutIfNeeded() }
      return
    }
    if placeCategories(pinned: false) { categorySlot.layoutIfNeeded() }
    categoryChrome.isHidden = true
  }
  private func fillBody() {
    body.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let works = store.personalWorks
    let posts = store.creatorPosts(for: CreatorProfile.signedIn(store.library.profile).id)
    let liked = store.likedVideos
    let saved = store.savedVideos
    let savedPosts = store.circlePosts(savedOnly: true)
    let joined = store.availableCircles.filter { store.community.joinedCircleIDs.contains($0.id) }
    switch selection {
    case 1:
      showVideos(liked)
    case 2:
      showVideos(saved)
      showSavedPosts(savedPosts)
      if saved.isEmpty, savedPosts.isEmpty {
        body.addArrangedSubview(label("Saved videos and circle posts will appear here.", 16, BibiPalette.muted))
      }
    case 3:
      showJoinedCircles(joined)
    case 4:
      showChallengeEntries()
    case 5:
      showPending()
    case 6:
      heading("Your constellation", host: body)
      var shortCreate: BibiButton!
      shortCreate = actionButton("Create a short video", icon: .shorts) { [weak self] in
        guard let self else { return }
        self.presentExpanded(
          from: shortCreate, CreationController(store: self.store))
      }
      body.addArrangedSubview(shortCreate)
    default:
      showVideos(works)
      if !posts.isEmpty { heading("Posts", host: body); addProfilePosts(posts, host: body) }
      for video in works {
        body.addArrangedSubview(
          actionButton("Manage " + video.title, icon: .more) { [weak self] in self?.manage(video) })
      }
    }
  }
  private func showVideos(_ videos: [LocalVideo]) {
    guard !videos.isEmpty else { return }
    videoGrid(videos, host: body) { [weak self] video in
      guard let self else { return }
      self.presentScreen(
        VideoFeedController(store: self.store, videos: videos, initial: video.id),
        full: true)
    }
  }
  private func showSavedPosts(_ posts: [CirclePost]) {
    guard !posts.isEmpty else { return }
    let columns = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 1 : 2
    let spacing: CGFloat = 14
    for start in stride(from: 0, to: posts.count, by: columns) {
      let row = stack(axis: .horizontal, spacing: spacing)
      row.distribution = .fillEqually
      row.alignment = .fill
      row.setContentCompressionResistancePriority(.required, for: .vertical)
      row.setContentHuggingPriority(.required, for: .vertical)
      for post in posts[start..<min(start + columns, posts.count)] {
        let tile = ProfilePostTile()
        tile.configure(post, store: store)
        tile.accessibilityIdentifier = "profile.post." + post.id.uuidString
        tile.onTap = { [weak self] in
          guard let self else { return }
          self.push(CirclePostController(store: self.store, postID: post.id))
        }
        row.addArrangedSubview(tile)
      }
      if row.arrangedSubviews.count < columns { row.addArrangedSubview(UIView()) }
      body.addArrangedSubview(row)
      // Height follows the row width, matching the saved-video tiles.
      let height = row.heightAnchor.constraint(
        equalTo: body.widthAnchor,
        multiplier: 1.38 / CGFloat(columns),
        constant: -(spacing * 1.38 * CGFloat(columns - 1) / CGFloat(columns)))
      height.priority = .required
      height.isActive = true
    }
  }
  private func showJoinedCircles(_ circles: [InterestCircle]) {
    if circles.isEmpty {
      body.addArrangedSubview(label("Your joined circles will appear here.", 16, BibiPalette.muted))
      return
    }
    for circle in circles {
      let open: () -> Void = { [weak self] in
        guard let self else { return }
        self.push(CircleDetailController(store: self.store, circle: circle))
      }
      let title = label(circle.title, 18, title: true)
      title.numberOfLines = 2
      let subtitle = label(circle.subtitle, 14, BibiPalette.muted)
      subtitle.numberOfLines = 2
      body.addArrangedSubview(communityCard([title, subtitle], onOpen: open))
    }
  }
  private func showChallengeEntries() {
    let entries = store.community.entries.sorted { $0.createdAt > $1.createdAt }
    if entries.isEmpty {
      body.addArrangedSubview(label("You have not entered a challenge yet.", 16, BibiPalette.muted))
      return
    }
    for entry in entries {
      guard let challenge = store.availableChallenges.first(where: { $0.id == entry.challengeID }) else { continue }
      let video = store.communityVideo(entry.videoID)
      let open: () -> Void = { [weak self] in
        guard let self else { return }
        self.push(ChallengeDetailController(store: self.store, challenge: challenge))
      }
      body.addArrangedSubview(communityCard([
        label(challenge.title, 18, title: true),
        label(video?.title ?? "Video unavailable", 15, BibiPalette.muted),
        label(
          (store.isOnline ? "Submitted · " : "Saved locally · ")
            + entry.createdAt.formatted(date: .abbreviated, time: .omitted),
          13, BibiPalette.muted),
      ], onOpen: open))
    }
  }
  private func showPending() {
    if store.pendingSubmissions.isEmpty {
      heading("Make your next move.", host: body)
      body.addArrangedSubview(label("Your submitted works will appear here."))
    }
    for submission in store.pendingSubmissions {
      if let url = store.submissionCoverURL(submission) {
        let cover = BibiArtwork()
        cover.load(url)
        cover.height(140)
        cover.rounded(18)
        paintCoverTemplate(cover, itemID: submission.coverStyleID)
        body.addArrangedSubview(cover)
      }
      body.addArrangedSubview(label(submission.title, 20, title: true))
      body.addArrangedSubview(
        label(submission.kind.label + " · " + submission.category, 13, BibiPalette.muted))
      body.addArrangedSubview(label(submission.caption))
      body.addArrangedSubview(label(store.isOnline ? (submission.status == .rejected ? "Not approved · You can revise or remove this upload" : "Submitted · Awaiting review") : "Waiting to submit", 14, BibiPalette.accent))
      if let id = submission.videoID,
        let video = store.collectionVideos.first(where: { $0.id == id })
      {
        body.addArrangedSubview(
          actionButton("Watch video", icon: .play) { [weak self] in
            guard let self else { return }
            self.presentScreen(
              VideoFeedController(store: self.store, videos: [video], initial: id),
              full: true)
          })
      }
      body.addArrangedSubview(
        actionButton("Remove", icon: .trash) { [weak self] in
          guard let self else { return }
          self.confirm(
            "Remove this submission?",
            message: "Your original photos and videos will not be changed.", destructive: true,
            button: "Remove"
          ) { self.save { await self.store.removeSubmission(submission.id) } }
        })
    }
  }
  private func manage(_ video: LocalVideo) {
    let editor = field("Title", text: video.title)
    let save = actionButton("Save", icon: .check, primary: true) { [weak self] in
      guard let self else { return }
      let title = editor.text ?? ""
      self.dismissCard { self.save { await self.store.renameVideo(video.id, title: title) } }
    }
    let delete = actionButton("Delete", icon: .trash, tone: .danger) { [weak self] in
      guard let self else { return }
      self.dismissCard {
        self.confirm(
          "Delete this video?",
          message: "This removes the imported copy. Your original in Photos will stay unchanged.",
          destructive: true, button: "Delete"
        ) { self.save { await self.store.deleteVideo(video.id) } }
      }
    }
    let cancel = actionButton("Cancel") { [weak self] in self?.dismissCard() }
    showCard([label("Edit title", 22, title: true), editor, save, delete, cancel])
  }
}
final class CreatorController: StackScreen {
  private var workSelection = 0
  let creator: CreatorProfile
  init(store: AppStore, creator: CreatorProfile) {
    self.creator = creator
    super.init(store: store, title: creator.name)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    let header = stack(
      [
        ownerPortrait(size: 88), label(creator.name, 26, title: true),
      ], axis: .horizontal)
    header.alignment = .center
    let stats = store.statistics(for: creator)
    let row = stack(axis: .horizontal, spacing: 7)
    row.distribution = .fillEqually
    for (name, value) in [
      ("Likes", stats.likes), ("Saves", stats.saves), ("Following", stats.following),
      ("Followers", stats.followers),
    ] {
      let l = label("\(value)\n\(name)", 13)
      l.textAlignment = .center
      row.addArrangedSubview(l)
    }
    content.addArrangedSubview(starlightProfileCard([header, row, label(creator.biography, 15, BibiPalette.muted)]))
    if !creator.isLocalOwner {
      content.addArrangedSubview(profileActions())
      let safety = actionButton("Report or block", icon: .flag, compact: true) { [weak self] in
        guard let self else { return }
        let screen = SafetyController(store: self.store, target: ContentSafetyTarget(
          id: self.creator.id, title: self.creator.name, kind: .profile, creator: self.creator))
        screen.onResolved = { [weak self] in
          guard let self else { return }
          if self.store.isCreatorBlocked(self.creator.id) { self.leaveAfterBlock() }
          else { self.refresh() }
        }
        self.presentScreen(screen)
      }
      safety.accessibilityIdentifier = "profile.safety"
      content.addArrangedSubview(safety)
    }
    content.addArrangedSubview(
      label("IP: " + (creator.ipRegion ?? "Not shared"), 12, BibiPalette.muted))
    let videos = store.creatorWorks(for: creator.id)
    let posts = store.creatorPosts(for: creator.id)
    heading("Works (\(videos.count + posts.count))")
    let filters = StudioChoice(items: ["All", "Shorts (\(videos.count))", "Posts (\(posts.count))"], index: workSelection)
    filters.onChange = { [weak self] next in
      self?.workSelection = next
      self?.refresh()
    }
    content.addArrangedSubview(filters)
    let showVideos = workSelection != 2 && !videos.isEmpty
    let showPosts = workSelection != 1 && !posts.isEmpty
    if showVideos {
      if workSelection == 0 { heading("Shorts") }
      videoGrid(videos) { [weak self] video in
        guard let self else { return }
        self.presentScreen(
          VideoFeedController(store: self.store, videos: videos, initial: video.id), full: true)
      }
    }
    if showPosts {
      if workSelection == 0 { heading("Posts") }
      addProfilePosts(posts)
    }
    if !showVideos && !showPosts {
      content.addArrangedSubview(label("No works in this collection yet.", 16, BibiPalette.muted))
    }
  }
  /// Only mutual follows show Message. Otherwise Follow fills its former space.
  private func profileActions() -> UIView {
    let following = store.followsProfile(creator)
    let mutual = store.isMutualProfile(creator)
    let block = profileIconButton(.block, "Block") { [weak self] in self?.confirmBlock() }
    if !mutual {
      let follow = profileWideButton(
        following ? "Following" : "Follow", icon: following ? .check : .plus
      ) { [weak self] in self?.toggleFollow() }
      let row = stack([follow, block], axis: .horizontal, spacing: 8)
      // Keep Block at its original quarter width and give Follow all remaining width.
      block.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.25, constant: -4)
        .isActive = true
      row.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
      return row
    }
    let follow: UIView = profileIconButton(.check, "Following") { [weak self] in self?.toggleFollow() }
    let message: UIView = profileWideButton("Message", icon: .chats) { [weak self] in self?.openChat() }
    let row = UIView()
    for item in [follow, message, block] {
      item.translatesAutoresizingMaskIntoConstraints = false
      row.addSubview(item)
    }
    let followShare: CGFloat = 0.25
    let messageShare: CGFloat = 0.5
    NSLayoutConstraint.activate([
      follow.leadingAnchor.constraint(equalTo: row.leadingAnchor),
      follow.topAnchor.constraint(equalTo: row.topAnchor),
      follow.bottomAnchor.constraint(equalTo: row.bottomAnchor),
      message.leadingAnchor.constraint(equalTo: follow.trailingAnchor, constant: 8),
      message.topAnchor.constraint(equalTo: row.topAnchor),
      message.bottomAnchor.constraint(equalTo: row.bottomAnchor),
      block.leadingAnchor.constraint(equalTo: message.trailingAnchor, constant: 8),
      block.trailingAnchor.constraint(equalTo: row.trailingAnchor),
      block.topAnchor.constraint(equalTo: row.topAnchor),
      block.bottomAnchor.constraint(equalTo: row.bottomAnchor),
      follow.widthAnchor.constraint(
        equalTo: row.widthAnchor, multiplier: followShare, constant: -16 * followShare),
      message.widthAnchor.constraint(
        equalTo: row.widthAnchor, multiplier: messageShare, constant: -16 * messageShare),
      row.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
    ])
    return row
  }
  private func profileWideButton(
    _ title: String, icon: BibiIcon, action: @escaping () -> Void
  ) -> BibiButton {
    let button = actionButton(title, icon: icon, tone: .lime, action: action)
    button.setContentHuggingPriority(.defaultLow, for: .horizontal)
    button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    button.caption.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return button
  }
  private func profileIconButton(
    _ icon: BibiIcon, _ name: String, action: @escaping () -> Void
  ) -> UIButton {
    let button = UIButton(type: .custom)
    button.setImage(icon.image(BibiPalette.accent, size: 22), for: .normal)
    button.backgroundColor = UIColor.white.withAlphaComponent(0.86)
    button.layer.cornerRadius = 22
    button.layer.cornerCurve = .continuous
    button.layer.borderWidth = 1
    button.layer.borderColor = BibiPalette.line.cgColor
    button.clipsToBounds = true
    button.accessibilityLabel = name
    button.translatesAutoresizingMaskIntoConstraints = false
    button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
    button.setContentHuggingPriority(.defaultLow, for: .horizontal)
    button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    soften(button)
    return button
  }
  private func toggleFollow() {
    if store.isCreatorBlocked(creator.id) {
      message("Unblock this person from Blocked in Settings to follow them.")
      return
    }
    Task { await store.toggleProfileFollow(creator) }
  }
  private func confirmBlock() {
    confirm(
      "Block " + creator.name + "?",
      message:
        "Their videos, circle posts, replies, and chats will be hidden. You can unblock them from Blocked in Settings.",
      destructive: true, button: "Block"
    ) { [weak self] in
      guard let self else { return }
      Task {
        if await self.store.blockCreator(self.creator) {
          self.leaveAfterBlock()
        } else {
          self.message(self.store.lastSaveError ?? "Please try again.")
        }
      }
    }
  }
  private func leaveAfterBlock() {
    guard let nav = navigationController else {
      dismiss(animated: true)
      return
    }
    let previous = nav.viewControllers.dropLast().last
    if let chat = previous as? ConversationController,
      chat.conversation.id == creator.id || chat.conversation.creator?.id == creator.id
    {
      if nav.viewControllers.count > 2 {
        nav.popToViewController(nav.viewControllers[nav.viewControllers.count - 3], animated: true)
      } else {
        nav.popToRootViewController(animated: true)
      }
      return
    }
    if nav.viewControllers.first === self {
      dismiss(animated: true)
    } else {
      nav.popViewController(animated: true)
    }
  }
  private func openChat() {
    guard store.isMutualProfile(creator) else { return }
    if let nav = navigationController,
      nav.viewControllers.dropLast().last is ConversationController
    {
      nav.popViewController(animated: true)
      return
    }
    if let person = CommunityChatCatalog.people.first(where: { $0.id == creator.id }) {
      push(ConversationController(store: store, conversation: person))
      return
    }
    if store.isCreatorBlocked(creator.id) {
      message("Unblock this person from Blocked in Settings to send a message.")
      return
    }
    Task {
      if await store.openCreatorConversation(creator),
        let conversation = store.chatConversations.first(where: { $0.creator?.id == creator.id })
      {
        push(ConversationController(store: store, conversation: conversation))
      } else if store.isCreatorBlocked(creator.id) {
        message("Unblock this person from Blocked in Settings to send a message.")
      } else {
        message(store.lastSaveError ?? "This conversation could not be opened.")
      }
    }
  }
  private func ownerPortrait(size: CGFloat) -> BibiArtwork {
    let photo = BibiArtwork(
      asset: portraitAsset(creator.avatarAsset, personID: creator.id), size: size, round: true)
    if creator.isLocalOwner, let image = store.ownerAvatarImage() {
      photo.image = image
    }
    if store.isOnline { photo.load(creator.avatarURL, fallback: "BibiMark") }
    return photo
  }
}
final class EditProfileController: StackScreen, PHPickerViewControllerDelegate {
  private var name = field("Name"), bio = field("Biography")
  private let portrait = BibiArtwork(size: 96, round: true)
  private var chosenPhoto: Data?
  private var picking = false
  override func build() {
    super.build()
    title = "Edit profile"
    name.text = store.library.profile.displayName
    bio.text = store.library.profile.biography
    portrait.image =
      store.ownerAvatarImage()
      ?? UIImage(named: portraitAsset(nil, personID: "local-owner"))
    if store.isOnline { portrait.load(store.library.profile.remoteAvatarURL, fallback: "BibiMark") }
    portrait.isAccessibilityElement = false
    let ring = UIButton(type: .custom)
    ring.accessibilityLabel = "Change photo"
    ring.backgroundColor = BibiPalette.selection.withAlphaComponent(0.45)
    ring.layer.borderWidth = 2
    ring.layer.borderColor = BibiPalette.accent.cgColor
    ring.layer.cornerRadius = 52
    ring.clipsToBounds = true
    ring.translatesAutoresizingMaskIntoConstraints = false
    ring.addSubview(portrait)
    NSLayoutConstraint.activate([
      ring.widthAnchor.constraint(equalToConstant: 104),
      ring.heightAnchor.constraint(equalToConstant: 104),
      portrait.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
      portrait.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
    ])
    paintAvatarFrame(ring, itemID: store.wallet.snapshot.cosmetics.avatarFrameID, fallbackWidth: 2, fallbackColor: BibiPalette.accent)
    ring.addAction(UIAction { [weak self] _ in self?.choosePhoto() }, for: .touchUpInside)
    soften(ring)
    let change = actionButton("Change photo", icon: .photo) { [weak self] in self?.choosePhoto() }
    let looks = actionButton("Profile looks", icon: .sparkle) { [weak self] in
      guard let self else { return }
      self.push(CosmeticPickerController(store: self.store, kinds: [.avatarFrame, .profileBackground]))
    }
    let header = stack([ring, change, looks], spacing: 12)
    header.alignment = .center
    content.addArrangedSubview(header)
    content.addArrangedSubview(name)
    content.addArrangedSubview(bio)
    content.addArrangedSubview(
      actionButton("Save", icon: .check, primary: true) { [weak self] in
        guard let self else { return }
        var profile = self.store.library.profile
        profile.displayName = self.name.text ?? ""
        profile.biography = self.bio.text ?? ""
        let photo = self.chosenPhoto
        Task {
          if await self.store.saveProfile(profile, avatarJPEG: photo) {
            if self.navigationController?.viewControllers.first == self {
              self.dismiss(animated: true)
            } else {
              self.navigationController?.popViewController(animated: true)
            }
          } else {
            self.message(
              self.store.lastSaveError
                ?? "Use a name up to 30 characters and a biography up to 160 characters.")
          }
        }
      })
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    paintAvatarFrame(portrait.superview ?? portrait, itemID: store.wallet.snapshot.cosmetics.avatarFrameID, fallbackWidth: 2, fallbackColor: BibiPalette.accent)
  }
  private func choosePhoto() {
    guard !picking, !store.isBusy else { return }
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.selectionLimit = 1
    configuration.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    present(picker, animated: true)
  }
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let provider = results.first?.itemProvider else { return }
    picking = true
    provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) {
      [weak self] data, _ in
      let data = data
      Task { @MainActor in
        guard let self else { return }
        self.picking = false
        guard let data, data.count <= 30 * 1024 * 1024, UIImage(data: data) != nil else {
          self.message("Choose another photo.")
          return
        }
        self.chosenPhoto = data
        self.portrait.image = UIImage(data: data)
      }
    }
  }
}
final class SettingsController: StackScreen {
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    title = "Settings"
    content.addArrangedSubview(
      actionButton("Edit profile", icon: .me) { [weak self] in
        guard let self else { return }
        self.push(EditProfileController(store: self.store))
      })
    for document in AgreementDocument.allCases {
      content.addArrangedSubview(
        actionButton(document.title, icon: .info) { [weak self] in
          guard let self else { return }
          self.push(AgreementController(store: self.store, document: document))
        })
    }
    content.addArrangedSubview(actionButton("Artwork & Credits", icon: .sparkle) { [weak self] in
      guard let self else { return }
      self.push(ArtworkCreditsController(store: self.store))
    })
    if store.isOnline {
      content.addArrangedSubview(actionButton("Device archive", icon: .bookmark) { [weak self] in
        guard let self else { return }; self.push(LegacyArchiveController(store: self.store, title: "Device archive"))
      })
    }
    let blocked = store.library.contentSafety?.blockedCreators ?? [:]
    let blockedTitle = blocked.isEmpty ? "Blocked" : "Blocked (\(blocked.count))"
    let blockedButton = actionButton(blockedTitle, icon: .block) { [weak self] in
      guard let self else { return }
      self.presentScreen(BlockedCreatorsController(store: self.store))
    }
    content.addArrangedSubview(blockedButton)
    let reports = store.reportedContent()
    let reportedTitle = reports.isEmpty ? "Reported" : "Reported (\(reports.count))"
    let reportedButton = actionButton(reportedTitle, icon: .flag) { [weak self] in
      guard let self else { return }
      self.presentScreen(ReportedContentController(store: self.store))
    }
    content.addArrangedSubview(reportedButton)
    content.setCustomSpacing(44, after: reportedButton)
    let logout = actionButton("Log out", icon: .logout) { [weak self] in
      guard let self else { return }
      self.confirm(
        "Log out?", message: store.online?.services.isGuest == true ? "Your guest account cannot be recovered after logging out. Its cloud balance and data will no longer be accessible. Your separate device archive stays on this iPhone." : "Your saved videos and drafts will stay on this device.",
        button: "Log out"
      ) { self.save { await self.store.logOut() } }
    }
    let delete = actionButton("Delete account", icon: .trash) { [weak self] in
      guard let self else { return }
      if self.store.isOnline { self.push(OnlineDeletionController(store: self.store, title: "Delete account")); return }
      self.confirm(
        "Delete account?",
        message:
          "This permanently deletes your profile, imported media, likes, saved videos, comments and drafts from this device. Original files in Photos are kept.",
        destructive: true, button: "Delete account"
      ) { self.save { await self.store.deleteLocalAccount() } }
    }
    for button in [logout, delete] {
      button.widthAnchor.constraint(equalToConstant: 220).isActive = true
    }
    let account = stack([logout, delete], spacing: 14)
    account.alignment = .center
    content.addArrangedSubview(account)
  }
}

private final class BlockedAuthorRow: UIControl {
  let creatorID: String
  init(creator: CreatorProfile) {
    creatorID = creator.id
    super.init(frame: .zero)
    let photo = roundPortrait(asset: creator.avatarAsset, size: 54, personID: creator.id)
    let name = label(creator.name, 17, title: true)
    name.numberOfLines = 1
    name.isUserInteractionEnabled = false
    photo.isUserInteractionEnabled = false
    let row = stack([photo, name], axis: .horizontal, spacing: 12)
    row.alignment = .center
    row.isUserInteractionEnabled = false
    let hairline = UIView()
    hairline.backgroundColor = BibiPalette.accent.withAlphaComponent(0.15)
    hairline.isUserInteractionEnabled = false
    hairline.translatesAutoresizingMaskIntoConstraints = false
    addSubview(row)
    addSubview(hairline)
    row.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
      row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
      row.topAnchor.constraint(equalTo: topAnchor, constant: 8),
      row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
      hairline.leadingAnchor.constraint(equalTo: name.leadingAnchor),
      hairline.trailingAnchor.constraint(equalTo: trailingAnchor),
      hairline.bottomAnchor.constraint(equalTo: bottomAnchor),
      hairline.heightAnchor.constraint(equalToConstant: 1),
      heightAnchor.constraint(greaterThanOrEqualToConstant: 70),
    ])
    isAccessibilityElement = true
    accessibilityLabel = creator.name
    accessibilityHint = "Long press to unblock"
    accessibilityTraits = .button
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

final class BlockedCreatorsController: StackScreen {
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    title = "Blocked"
    if store.isOnline {
      content.addArrangedSubview(actionButton("Device archive", icon: .bookmark) { [weak self] in
        guard let self else { return }; self.push(LegacyArchiveController(store: self.store, title: "Device archive"))
      })
    }
    let blocked = store.library.contentSafety?.blockedCreators ?? [:]
    if blocked.isEmpty {
      content.addArrangedSubview(label("No blocked creators.", 15, BibiPalette.muted))
      return
    }
    content.addArrangedSubview(
      label("Long press a member to unblock them.", 14, BibiPalette.muted))
    for creator in blocked.values.sorted(by: { $0.name < $1.name }) {
      let row = BlockedAuthorRow(creator: creator)
      row.addGestureRecognizer(
        UILongPressGestureRecognizer(target: self, action: #selector(longPressAuthor(_:))))
      row.accessibilityCustomActions = [
        UIAccessibilityCustomAction(name: "Unblock") { [weak self] _ in
          self?.askToUnblock(creatorID: row.creatorID)
          return true
        },
      ]
      content.addArrangedSubview(row)
    }
  }
  @objc private func longPressAuthor(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began, let row = gesture.view as? BlockedAuthorRow else { return }
    askToUnblock(creatorID: row.creatorID)
  }
  private func askToUnblock(creatorID: String) {
    if store.isOnline {
      content.addArrangedSubview(actionButton("Device archive", icon: .bookmark) { [weak self] in
        guard let self else { return }; self.push(LegacyArchiveController(store: self.store, title: "Device archive"))
      })
    }
    let blocked = store.library.contentSafety?.blockedCreators ?? [:]
    guard let creator = blocked[creatorID] else { return }
    confirm(
      "Unblock " + creator.name + "?",
      message: "Their videos, circle posts, and replies can show again. This stays on this device.",
      button: "Unblock"
    ) { [weak self] in
      guard let self else { return }
      self.save { await self.store.unblockCreator(creator.id) }
    }
  }
}

private final class ReportedCard: UIControl {
  let contentID: String
  let kind: ContentSafetyTarget.Kind
  init(item: ReportedContentItem, store: AppStore) {
    contentID = item.contentID
    kind = item.kind
    super.init(frame: .zero)
    let visual = Self.visual(for: item, store: store)
    visual.isUserInteractionEnabled = false
    addSubview(visual)
    visual.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      visual.leadingAnchor.constraint(equalTo: leadingAnchor),
      visual.trailingAnchor.constraint(equalTo: trailingAnchor),
      visual.topAnchor.constraint(equalTo: topAnchor),
      visual.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    isAccessibilityElement = true
    accessibilityLabel = item.kind.rawValue + ", " + item.title
    accessibilityHint = "Long press to remove this report"
    accessibilityTraits = .button
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  private static func visual(for item: ReportedContentItem, store: AppStore) -> UIView {
    switch item.kind {
    case .live, .shortVideo:
      if let video = video(for: item, store: store) {
        let tile = VideoTile()
        tile.configureStatic(video, store: store)
        return tile
      }
    case .party, .phrase, .circlePost, .profile:
      return commentRow(item)
    case .comment:
      return commentRow(item)
    }
    return missing(item)
  }

  private static func video(for item: ReportedContentItem, store: AppStore) -> LocalVideo? {
    guard let id = UUID(uuidString: item.contentID) else { return nil }
    return store.collectionVideos.first { $0.id == id }
  }

  private static func commentRow(_ item: ReportedContentItem) -> UIView {
    let photo = roundPortrait(asset: nil, size: 44, personID: item.creatorName)
    let name = label(item.creatorName, 15, BibiPalette.accent, title: true)
    name.numberOfLines = 1
    let body = label(item.title, 16)
    body.numberOfLines = 4
    let text = stack([name, body], spacing: 3)
    let row = stack([photo, text], axis: .horizontal, spacing: 12)
    row.alignment = .top
    return Self.note(row)
  }

  private static func missing(_ item: ReportedContentItem) -> UIView {
    let text = label(item.title + "\n" + item.kind.rawValue, 16, title: true)
    return Self.note(text, fill: BibiPalette.soft)
  }

  private static func note(_ body: UIView, fill: UIColor = UIColor.white.withAlphaComponent(0.9)) -> UIView {
    let box = UIView()
    box.backgroundColor = fill
    box.layer.cornerRadius = 18
    box.layer.cornerCurve = .continuous
    box.clipsToBounds = true
    box.addSubview(body)
    body.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      body.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
      body.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
      body.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
      body.bottomAnchor.constraint(lessThanOrEqualTo: box.bottomAnchor, constant: -12),
    ])
    return box
  }
}

final class ReportedContentController: StackScreen {
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    title = "Reported"
    let reports = store.reportedContent()
    if reports.isEmpty {
      content.addArrangedSubview(label("No reports yet.", 15, BibiPalette.muted))
      return
    }
    content.addArrangedSubview(
      label("Long press a card to remove it. Reports stay on this device.", 14, BibiPalette.muted))
    let columns = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 1 : 2
    let spacing: CGFloat = 12
    for start in stride(from: 0, to: reports.count, by: columns) {
      let row = stack(axis: .horizontal, spacing: spacing)
      row.distribution = .fillEqually
      row.alignment = .fill
      row.setContentCompressionResistancePriority(.required, for: .vertical)
      row.setContentHuggingPriority(.required, for: .vertical)
      for item in reports[start..<min(start + columns, reports.count)] {
        row.addArrangedSubview(reportCard(item))
      }
      if row.arrangedSubviews.count < columns { row.addArrangedSubview(UIView()) }
      content.addArrangedSubview(row)
      // Height follows the row width, matching the home video grid.
      let height = row.heightAnchor.constraint(
        equalTo: content.widthAnchor,
        multiplier: 1.25 / CGFloat(columns),
        constant: -(spacing * 1.25 * CGFloat(columns - 1) / CGFloat(columns)))
      height.priority = .required
      height.isActive = true
    }
  }
  private func reportCard(_ item: ReportedContentItem) -> ReportedCard {
    let card = ReportedCard(item: item, store: store)
    card.addGestureRecognizer(
      UILongPressGestureRecognizer(target: self, action: #selector(longPressReport(_:))))
    card.accessibilityCustomActions = [
      UIAccessibilityCustomAction(name: "Remove this report") { [weak self] _ in
        self?.askToRemove(contentID: card.contentID, kind: card.kind)
        return true
      },
    ]
    return card
  }
  @objc private func longPressReport(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began, let row = gesture.view as? ReportedCard else { return }
    askToRemove(contentID: row.contentID, kind: row.kind)
  }
  private func askToRemove(contentID: String, kind: ContentSafetyTarget.Kind) {
    confirm(
      "Remove this report?",
      message: "It can show in the app again. This change stays on this device.",
      button: "Remove report"
    ) { [weak self] in
      guard let self else { return }
      self.save { await self.store.removeReports(contentID: contentID, kind: kind) }
    }
  }
}




/// Saved circle posts use the same cover tile as saved videos.
private final class ProfilePostTile: UIControl {
  private let cover = BibiArtwork()
  private let caption = label("", 15, .white)
  var onTap: (() -> Void)?
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = BibiPalette.soft
    rounded(20)
    addSubview(cover)
    cover.pin(to: self)
    let shade = UIView()
    shade.backgroundColor = UIColor.black.withAlphaComponent(0.65)
    shade.isUserInteractionEnabled = false
    addSubview(shade)
    shade.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      shade.leadingAnchor.constraint(equalTo: leadingAnchor),
      shade.trailingAnchor.constraint(equalTo: trailingAnchor),
      shade.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    caption.numberOfLines = 3
    shade.addSubview(caption)
    caption.pin(to: shade, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
    cover.isUserInteractionEnabled = false
    isAccessibilityElement = true
    accessibilityTraits = .button
    addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  func configure(_ post: CirclePost, store: AppStore) {
    if let asset = post.bundledArtwork {
      cover.image = UIImage(named: CommunityArtwork.avatar(asset))
    } else if let url = post.remotePhotoURL {
      cover.load(url)
    } else if let data = post.photo, let image = UIImage(data: data) {
      cover.image = image
    } else {
      cover.image = nil
    }
    paintCoverTemplate(self, itemID: post.coverStyleID)
    caption.text = post.body
    let author = post.author.isLocalOwner
      ? CreatorProfile.signedIn(store.library.profile).name
      : post.author.name
    accessibilityLabel = post.body + ", " + author
  }
}

extension StackScreen {
  func addProfilePosts(_ posts: [CirclePost], host: UIStackView? = nil) {
    let column = host ?? content
    for post in posts {
      let openPost: () -> Void = { [weak self] in
        guard let self else { return }
        self.push(CirclePostController(store: self.store, postID: post.id))
      }
      let excerpt = label(post.body, 16)
      excerpt.numberOfLines = 4
      var rows: [UIView] = []
      if let asset = post.bundledArtwork {
        rows.append(circleStoryArtwork(asset, postID: post.id, onOpen: openPost))
      } else if post.remotePhotoURL != nil || post.photo != nil {
        let art = BibiArtwork()
        if let url = post.remotePhotoURL { art.load(url) }
        else if let data = post.photo { art.image = UIImage(data: data) }
        art.contentMode = .scaleAspectFit
        art.height(180)
        art.rounded(18)
        paintCoverTemplate(art, itemID: post.coverStyleID)
        rows.append(communityMediaLink(art, label: "Read discussion",
                                      identifier: "profile.post.cover." + post.id.uuidString, action: openPost))
      }
      let counts = store.circlePostCounts(for: post)
      rows.append(excerpt)
      rows.append(label("\(counts.likes) likes · \(counts.saves) saves", 12, BibiPalette.muted))
      rows.append(actionButton("Read discussion", icon: .comment, action: openPost))
      if !post.author.isLocalOwner { rows.append(communitySafetyButton(post)) }
      let card = communityCard(rows, onOpen: openPost)
      card.accessibilityIdentifier = "profile.post." + post.id.uuidString
      column.addArrangedSubview(card)
    }
  }
}

final class CosmeticPickerController: StackScreen {
  private let kinds: [CosmeticKind]
  init(store: AppStore, kinds: [CosmeticKind]) {
    self.kinds = kinds
    super.init(store: store, title: "Looks")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func build() {
    super.build()
    store.wallet.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
      self?.refresh()
    }.store(in: &tokens)
  }
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    let balance = store.wallet.snapshot.diamonds
    content.addArrangedSubview(label("\(balance.formatted()) diamonds", 16, BibiPalette.muted))
    content.addArrangedSubview(label("Looks stay on this device. Publishing, messages, comments, reports and blocks stay free.", 14, BibiPalette.muted))
    let owned = store.wallet.snapshot.cosmetics
    for kind in kinds {
      heading(Self.heading(kind))
      let classic = actionButton(owned.equippedID(kind) == nil ? "Classic · Using" : "Classic · Use", icon: .check, primary: owned.equippedID(kind) == nil) { [weak self] in
        self?.equip(kind, id: nil)
      }
      content.addArrangedSubview(classic)
      for item in CosmeticCatalog.items(kind) {
        let isOwned = owned.ownedIDs.contains(item.id)
        let isUsing = owned.equippedID(kind) == item.id
        let title = isUsing ? "\(item.name) · Using" : isOwned ? "\(item.name) · Use" : "\(item.name) · \(item.diamonds.formatted()) diamonds"
        let button = actionButton(title, icon: .sparkle, primary: isUsing) { [weak self] in
          guard let self else { return }
          if isOwned { self.equip(kind, id: item.id); return }
          guard self.store.wallet.snapshot.diamonds >= item.diamonds else {
            self.confirm(
              "Not enough diamonds",
              message: "\(item.name) costs \(item.diamonds.formatted()) diamonds. No diamonds were spent.",
              button: "Add diamonds"
            ) { [weak self] in
              guard let self else { return }
              self.push(WalletController(store: self.store))
            }
            return
          }
          self.confirm(
            "Use \(item.diamonds.formatted()) diamonds?",
            message: "\(item.name) stays yours. You can switch back to Classic at any time.",
            button: "Use diamonds"
          ) { [weak self] in
            Task { @MainActor in
              guard let self else { return }
              if let error = await self.store.wallet.unlock(item) {
                self.message(error)
              }
            }
          }
        }
        let swatch = UIView()
        swatch.backgroundColor = BibiPalette.color(item.hex)
        swatch.rounded(8)
        swatch.translatesAutoresizingMaskIntoConstraints = false
        swatch.widthAnchor.constraint(equalToConstant: 28).isActive = true
        swatch.heightAnchor.constraint(equalToConstant: 28).isActive = true
        swatch.isAccessibilityElement = false
        let row = stack([swatch, button], axis: .horizontal, spacing: 10)
        row.alignment = .center
        content.addArrangedSubview(row)
      }
    }
  }
  private func equip(_ kind: CosmeticKind, id: String?) {
    Task { @MainActor in
      if let error = await store.wallet.equip(kind, id: id) { message(error) }
    }
  }
  private static func heading(_ kind: CosmeticKind) -> String {
    switch kind {
    case .avatarFrame: return "Avatar frames"
    case .profileBackground: return "Profile headers"
    case .chatBubble: return "Chat bubbles"
    case .chatBackground: return "Chat rooms"
    case .coverTemplate: return "Cover frames"
    }
  }
}
