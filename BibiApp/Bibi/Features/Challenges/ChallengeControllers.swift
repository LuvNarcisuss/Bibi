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
        subtitle: "Start whenever inspiration finds you.", artwork: "BibiRoom6"))
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
    for challenge in CommunityCatalog.challenges
    where selection == 0 || challenge.category == categories[selection] {
      let entered = store.community.entries.contains { $0.challengeID == challenge.id }
      let art = BibiArtwork(asset: challenge.artwork)
      art.height(150)
      art.rounded(18)
      results.addArrangedSubview(
        communityCard([
          art, label(challenge.category.uppercased() + " · OPEN PROMPT", 12, BibiPalette.accent),
          label(challenge.title, 24, title: true), label(challenge.summary, 16, BibiPalette.muted),
          actionButton(
            entered ? "View your entry" : "Explore challenge", icon: .comet, primary: true
          ) { [weak self] in
            guard let self else { return }
            self.push(ChallengeDetailController(store: self.store, challenge: challenge))
          },
        ]))
    }
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
    heading("Your creative brief")
    for (index, step) in challenge.steps.enumerated() {
      content.addArrangedSubview(
        communityCard([
          label("0\(index + 1)", 20, BibiPalette.accent, title: true), label(step, 17),
        ]))
    }
    content.addArrangedSubview(
      label(
        "Use your own work or media you have permission to share. Videos must be up to 3 minutes and 250 MB. One local entry per challenge; you can replace or withdraw it.",
        14, BibiPalette.muted))
    let examples = store.bundledVideos.filter {
      $0.bundledClip?.surface == .shorts && !store.hidesVideo($0, live: false)
    }
    if !examples.isEmpty {
      let video = examples[challenge.exampleIndex % examples.count]
      content.addArrangedSubview(
        actionButton("Watch animation inspiration", icon: .play) { [weak self] in
          self?.watchCommunityVideo(video.id)
        })
      content.addArrangedSubview(
        label(
          "An editorial reference from the animation library, not a challenge submission.", 13,
          BibiPalette.muted))
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
        label("Saved on this device · Not published", 14, BibiPalette.muted))
      content.addArrangedSubview(
        actionButton("Withdraw entry", icon: .trash) { [weak self] in
          guard let self else { return }
          self.confirm(
            "Withdraw this entry?", message: "The video will stay in your library.",
            button: "Withdraw"
          ) {
            self.save { await self.store.withdrawChallenge(self.challenge.id) }
          }
        })
    }
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
        "Entries are saved locally. Online submission, community judging and rankings are not connected.",
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
      for challenge in CommunityCatalog.challenges { add(challenge, title: challenge.title) }
    } else {
      for entry in store.community.entries.sorted(by: { $0.createdAt > $1.createdAt }) {
        guard
          let challenge = CommunityCatalog.challenges.first(where: { $0.id == entry.challengeID })
        else { continue }
        let video = store.communityVideo(entry.videoID)
        content.addArrangedSubview(label(challenge.title, 22, title: true))
        content.addArrangedSubview(
          label(video?.title ?? "Video unavailable", 16, BibiPalette.muted))
        content.addArrangedSubview(
          label(
            "Saved locally · " + entry.createdAt.formatted(date: .abbreviated, time: .omitted), 13,
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
