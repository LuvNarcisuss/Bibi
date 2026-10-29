import UIKit

final class ChallengesController: StackScreen {
  private var selection = 0
  private let results = stack()
  override func build() {
    super.build()
    title = "Challenges"
    navigationItem.leftBarButtonItem = barButton(bibiMark())
    content.addArrangedSubview(
      ConstellationBanner(
        eyebrow: "Make something yours", title: "Small prompts.\nNew possibilities.",
        subtitle: "Start whenever inspiration finds you.", artwork: "ChallengeCover-GothicPair"))
    let filters = StudioChoice(items: ["All", "Animation", "Cosplay", "Art"])
    filters.onChange = { [weak self] next in
      self?.selection = next
      self?.refresh()
    }
    content.addArrangedSubview(filters)
    content.addArrangedSubview(
      actionButton("My challenge entries", icon: .crown) { [weak self] in
        guard let self else { return }
        self.push(ChallengeEntriesController(store: self.store, title: "My challenges"))
      })
    content.addArrangedSubview(results)
  }
  override func refresh() {
    guard isViewLoaded else { return }
    results.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let categories = ["All", "Animation", "Cosplay", "Art"]
    var cards: [UIView] = []
    for challenge in store.availableChallenges
    where selection == 0 || challenge.category == categories[selection] {
      let entered = store.community.entries.contains { $0.challengeID == challenge.id }
      let art = BibiArtwork(asset: challenge.artwork)
      art.translatesAutoresizingMaskIntoConstraints = false
      art.heightAnchor.constraint(equalTo: art.widthAnchor).isActive = true
      art.rounded(14)
      let openChallenge: () -> Void = { [weak self] in
        guard let self else { return }
        self.push(ChallengeDetailController(store: self.store, challenge: challenge))
      }
      let cover = communityMediaLink(art, label: "Explore " + challenge.title,
                                    identifier: "challenge.cover." + challenge.id, action: openChallenge)
      let eyebrow = label(challenge.category.uppercased(), 11, BibiPalette.accent)
      eyebrow.numberOfLines = 1
      let title = label(challenge.title, 16, title: true)
      title.numberOfLines = 2
      let summary = label(challenge.summary, 13, BibiPalette.muted)
      summary.numberOfLines = 3
      cards.append(
        communityCard([
          cover, eyebrow, title, summary,
          gridActionButton(
            entered ? "View your entry" : "Explore challenge", icon: .comet, action: openChallenge),
        ], onOpen: openChallenge, compact: true))
    }
    addTwoColumns(cards, to: results)
  }
}

final class ChallengeDetailController: StackScreen {
  private let challenge: CreativeChallenge
  init(store: AppStore, challenge: CreativeChallenge) {
    self.challenge = challenge
    super.init(store: store, title: "Challenge")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    content.addArrangedSubview(
      ConstellationBanner(
        eyebrow: challenge.category + " / Open prompt", title: challenge.title,
        subtitle: challenge.summary, artwork: challenge.artwork))
    if let media = CommunityCatalog.challengeMedia[challenge.artwork] {
      content.addArrangedSubview(actionButton(media.credit, icon: .share, compact: true) {
        guard let url = URL(string: media.source) else { return }
        UIApplication.shared.open(url)
      })
    }
    heading("Your creative brief")
    for (index, step) in challenge.steps.enumerated() {
      content.addArrangedSubview(
        communityCard([
          label("0\(index + 1)", 20, BibiPalette.accent, title: true), label(step, 17),
        ]))
    }
    content.addArrangedSubview(
      label(
        store.isOnline ? "Use your own work or media you have permission to share. Videos must be up to 3 minutes and uploads below 50 MB. One entry per challenge; you can replace or withdraw it." : "Use your own work or media you have permission to share. Videos must be up to 3 minutes and 250 MB. One local entry per challenge; you can replace or withdraw it.",
        14, BibiPalette.muted))
    let examples = store.bundledVideos.filter {
      $0.bundledClip?.surface == .shorts && !store.hidesVideo($0, live: false)
        && ($0.bundledClip?.caption.contains("#Cosplay") == true) == (challenge.category == "Cosplay")
    }
    if !examples.isEmpty {
      let video = examples[challenge.exampleIndex % examples.count]
      content.addArrangedSubview(
        actionButton("Watch inspiration", icon: .play) { [weak self] in
          self?.watchCommunityVideo(video.id)
        })
      content.addArrangedSubview(
        label(
          "An editorial reference, not a challenge submission.", 13,
          BibiPalette.muted))
      let author = CreatorProfile.from(video: video, profile: store.library.profile, coverURL: store.coverURL(video))
      content.addArrangedSubview(actionButton("Report or block", icon: .flag, compact: true) { [weak self] in
        self?.presentCommunitySafety(ContentSafetyTarget(
          id: video.id.uuidString, title: video.title, kind: .shortVideo, creator: author))
      })
    }
    if let entry = store.community.entries.first(where: { $0.challengeID == challenge.id }) {
      heading("Your entry")
      if let video = store.communityVideo(entry.videoID) {
        content.addArrangedSubview(label(video.title, 20, title: true))
        content.addArrangedSubview(
          actionButton("Watch your entry", icon: .play) { [weak self] in
            self?.watchCommunityVideo(entry.videoID)
          })
      } else {
        content.addArrangedSubview(
          label("Your entry's video is unavailable. Replace or withdraw it."))
      }
      content.addArrangedSubview(
        label(store.isOnline ? "Submitted · Subject to content review" : "Saved on this device · Not published", 14, BibiPalette.muted))
      content.addArrangedSubview(
        actionButton("Withdraw entry", icon: .trash) { [weak self] in
          guard let self else { return }
          let paid = self.store.wallet.snapshot.cosmetics.paidChallengeIDs.contains(self.challenge.id)
          self.confirm(
            "Withdraw this entry?",
            message: paid
              ? "The video will stay in your library. \(CosmeticCatalog.challengeEntryDiamonds.formatted()) diamonds return to your balance."
              : "The video will stay in your library.",
            button: "Withdraw"
          ) {
            self.save { await self.store.withdrawChallenge(self.challenge.id) }
          }
        })
    }
    let fee = CosmeticCatalog.challengeEntryDiamonds
    let enteredAlready = store.community.entries.contains { $0.challengeID == challenge.id }
    let paid = store.wallet.snapshot.cosmetics.paidChallengeIDs.contains(challenge.id)
    let feeNote = enteredAlready
      ? (paid
        ? "Replacing this entry stays free. Withdrawing it returns \(fee.formatted()) diamonds."
        : "Replacing this entry stays free.")
      : "Joining this challenge uses \(fee.formatted()) diamonds. You have \(store.wallet.snapshot.diamonds.formatted()) diamonds. Replacing the entry stays free, and withdrawing it returns the diamonds."
    content.addArrangedSubview(label(feeNote, 14, BibiPalette.muted))
    content.addArrangedSubview(
      actionButton("Choose one of my videos", icon: .shorts, primary: true) { [weak self] in
        guard let self else { return }
        self.push(
          CommunityVideoPickerController(store: self.store, personalOnly: true) {
            [weak self] video in
            guard let self else { return }
            self.save { await self.store.enterChallenge(self.challenge.id, videoID: video.id) }
          })
      })
    content.addArrangedSubview(
      actionButton("Upload a new entry", icon: .plus) { [weak self] in
        guard let self else { return }
        self.presentScreen(CreationController(store: self.store, challengeID: self.challenge.id))
      })
    content.addArrangedSubview(
      label(
        store.isOnline ? "Entries use your account videos. Community judging and rankings are not available." : "Entries are saved locally. Online submission, community judging and rankings are not connected.",
        13, BibiPalette.muted))
  }
}

final class ChallengeEntriesController: StackScreen {
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    heading("Stories you started")
    if store.community.entries.isEmpty {
      content.addArrangedSubview(
        label(
          "You have not entered a challenge yet. Pick a creative prompt to get started.", 16,
          BibiPalette.muted))
      for challenge in store.availableChallenges { add(challenge, title: challenge.title) }
    } else {
      for entry in store.community.entries.sorted(by: { $0.createdAt > $1.createdAt }) {
        guard
          let challenge = store.availableChallenges.first(where: { $0.id == entry.challengeID })
        else { continue }
        let video = store.communityVideo(entry.videoID)
        content.addArrangedSubview(label(challenge.title, 22, title: true))
        content.addArrangedSubview(
          label(video?.title ?? "Video unavailable", 16, BibiPalette.muted))
        content.addArrangedSubview(
          label(
            (store.isOnline ? "Submitted · " : "Saved locally · ") + entry.createdAt.formatted(date: .abbreviated, time: .omitted), 13,
            BibiPalette.muted))
        add(challenge, title: "Manage entry")
      }
    }
  }
  private func add(_ challenge: CreativeChallenge, title: String) {
    content.addArrangedSubview(
      actionButton(title, icon: .crown) { [weak self] in
        guard let self else { return }
        self.push(ChallengeDetailController(store: self.store, challenge: challenge))
      })
  }
}
