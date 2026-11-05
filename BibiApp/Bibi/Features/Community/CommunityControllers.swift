import Combine
import UIKit

final class CommentsController: BibiScreen, UITableViewDataSource, UITableViewDelegate {
  let video: LocalVideo, floating: Bool
  private let table = UITableView(frame: .zero, style: .plain), input = field("Write a comment")
  private let replyLabel = label("", 12, BibiPalette.muted)
  private var replyingTo: ShortComment?
  private var entries: [ShortComment] {
    (store.shortsSocial.comments[video.id] ?? []).filter {
      !store.isCommentReported($0.id.uuidString)
        && !store.isCreatorBlocked($0.remoteAuthorID ?? ("comment-author:" + $0.name))
    }
  }
  init(store: AppStore, video: LocalVideo, floating: Bool = false) {
    self.video = video
    self.floating = floating
    super.init(store: store, title: floating ? "On the video" : "Comments")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func build() {
    store.shortsSocial.prepareComments(for: video)
    table.dataSource = self
    table.delegate = self
    table.separatorStyle = .none
    table.keyboardDismissMode = .interactive
    view.backgroundColor = BibiPalette.background
    view.subviews.compactMap { $0 as? StarlightCanvas }.forEach { $0.isHidden = true }
    table.backgroundColor = BibiPalette.background
    table.backgroundView = nil
    table.contentInsetAdjustmentBehavior = .never
    table.sectionHeaderTopPadding = 0
    table.contentInset = .zero
    for constraint in input.constraints where constraint.firstAttribute == .height
      && constraint.relation == .equal && constraint.secondItem == nil
    {
      constraint.constant = 40
    }
    let send = iconButton(.send, "Send comment") { [weak self] in self?.send() }
    pack(send)
    input.setContentHuggingPriority(.defaultLow, for: .horizontal)
    input.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    let composer = stack([input, send], axis: .horizontal, spacing: 2)
    composer.alignment = .center
    replyLabel.isHidden = true
    let bottom = stack([replyLabel, composer])
    bottom.spacing = 0
    view.addSubview(table)
    view.addSubview(bottom)
    table.translatesAutoresizingMaskIntoConstraints = false
    bottom.translatesAutoresizingMaskIntoConstraints = false
    var pins = [
      table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      table.bottomAnchor.constraint(equalTo: bottom.topAnchor, constant: -2),
      bottom.leadingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
      bottom.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
      bottom.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
    ]
    if floating {
      let toggle = actionButton(bulletTitle, tone: .lime, compact: true) { [weak self] in
        guard let self else { return }
        self.store.shortsSocial.bulletsEnabled.toggle()
        self.bulletButton?.caption.text = self.bulletTitle
        self.bulletButton?.accessibilityLabel = self.bulletTitle
        self.bulletButton?.invalidateIntrinsicContentSize()
      }
      bulletButton = toggle
      view.addSubview(toggle)
      toggle.translatesAutoresizingMaskIntoConstraints = false
      pins.append(contentsOf: [
        toggle.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
        toggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
        table.topAnchor.constraint(equalTo: toggle.bottomAnchor, constant: 4),
      ])
    } else {
      pins.append(table.topAnchor.constraint(equalTo: view.topAnchor))
    }
    NSLayoutConstraint.activate(pins)
    replyLabel.isUserInteractionEnabled = true
    replyLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(clearReply)))
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    view.backgroundColor = BibiPalette.background
    view.clipsToBounds = true
    view.subviews.compactMap { $0 as? StarlightCanvas }.forEach {
      $0.isHidden = true
      $0.frame = view.bounds
    }
  }
  private var bulletButton: BibiButton?
  private var bulletTitle: String {
    store.shortsSocial.bulletsEnabled ? "Hide" : "Show"
  }
  override func refresh() {
    guard isViewLoaded else { return }
    table.reloadData()
  }
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    entries.count
  }
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let entry = entries[indexPath.row]
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.backgroundColor = BibiPalette.background
    cell.contentView.backgroundColor = BibiPalette.background
    cell.selectionStyle = .none
    let photo = roundPortrait(
      asset: entry.avatarAsset, size: 34, personID: entry.name,
      image: isOwnComment(entry) ? store.ownerAvatarImage() : nil, remoteURL: entry.remoteAvatarURL)
    let name = label(
      entry.name + (entry.replyToName.map { " → " + $0 } ?? ""), 14, BibiPalette.accent, title: true)
    let body = label(entry.text, 15)
    let text = stack([name, body], spacing: 3)
    let row = stack([photo, text], axis: .horizontal, spacing: 10)
    row.alignment = .top
    if !isOwnComment(entry) {
      let flag = iconButton(.flag, "Report or block", size: 20) { [weak self] in
        self?.report(entry)
      }
      flag.setContentHuggingPriority(.required, for: .horizontal)
      flag.setContentCompressionResistancePriority(.required, for: .horizontal)
      text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      row.addArrangedSubview(flag)
      cell.accessibilityCustomActions = [
        UIAccessibilityCustomAction(name: "Report or block") { [weak self] _ in
          self?.report(entry)
          return true
        },
      ]
    }
    cell.contentView.addSubview(row)
    row.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
      row.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
      row.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 10),
      row.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -10),
    ])
    cell.accessibilityHint =
      isOwnComment(entry) ? "Reply to this comment" : "Reply, report or block this author"
    return cell
  }
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    view.endEditing(true)
    let entry = entries[indexPath.row]
    var rows: [UIView] = [
      label(entry.name, 22, title: true), label(entry.text, 15, BibiPalette.muted),
    ]
    if !floating {
      rows.append(
        actionButton("Reply", icon: .comment) { [weak self] in
          guard let self else { return }
          self.dismissCard {
            self.replyingTo = entry
            self.replyLabel.text = "Replying to " + entry.name
            self.replyLabel.accessibilityLabel = "Clear reply to " + entry.name
            self.replyLabel.isHidden = false
            self.input.becomeFirstResponder()
          }
        })
    }
    if !isOwnComment(entry) {
      rows.append(
        actionButton("Report or block", icon: .flag, tone: .danger) { [weak self] in
          guard let self else { return }
          self.dismissCard {
            self.presentScreen(
              SafetyController(
                store: self.store,
                target: .comment(id: entry.id.uuidString, name: entry.name, text: entry.text, authorID: entry.remoteAuthorID),
                reporting: false))
          }
        })
    }
    rows.append(actionButton("Cancel") { [weak self] in self?.dismissCard() })
    showCard(rows)
  }
  private func isOwnComment(_ entry: ShortComment) -> Bool {
    if let authorID = entry.remoteAuthorID, let account = store.online?.services.accountID {
      return authorID.lowercased() == account.uuidString.lowercased()
    }
    return entry.name == "You"
  }

  private func report(_ entry: ShortComment) {
    let safety = SafetyController(
      store: store,
      target: .comment(id: entry.id.uuidString, name: entry.name, text: entry.text, authorID: entry.remoteAuthorID),
      reporting: false)
    safety.onResolved = { [weak self] in self?.refresh() }
    dismissCard { [weak self] in self?.presentScreen(safety) }
  }
  private func send() {
    let text = input.text ?? ""
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      text.count <= (floating ? 80 : 200), CreationValidation.isEnglish(text)
    else {
      message("Write a comment of up to \(floating ? 80 : 200) characters.")
      return
    }
    Task {
      if await store.shortsSocial.addComment(
        text, to: video.id, floating: floating, replyingTo: replyingTo)
      {
        input.text = ""
        replyingTo = nil
        replyLabel.text = ""
        replyLabel.accessibilityLabel = nil
        replyLabel.isHidden = true
        refresh()
        if !entries.isEmpty {
          table.scrollToRow(
            at: IndexPath(row: entries.count - 1, section: 0), at: .bottom,
            animated: !UIAccessibility.isReduceMotionEnabled)
        }
      } else {
        message(store.shortsSocial.storageError ?? "Your comment could not be saved.")
      }
    }
  }
  private func pack(_ view: UIView) {
    for constraint in view.constraints
      where (constraint.firstAttribute == .width || constraint.firstAttribute == .height)
      && constraint.relation == .greaterThanOrEqual && constraint.secondItem == nil
    {
      constraint.isActive = false
    }
    view.widthAnchor.constraint(equalToConstant: 36).isActive = true
    view.heightAnchor.constraint(equalToConstant: 36).isActive = true
    view.setContentHuggingPriority(.required, for: .horizontal)
    view.setContentCompressionResistancePriority(.required, for: .horizontal)
  }
  @objc private func clearReply() {
    replyingTo = nil
    replyLabel.text = ""
    replyLabel.isHidden = true
    replyLabel.accessibilityLabel = nil
  }
}
final class SafetyController: StackScreen {
  let target: ContentSafetyTarget
  private var reporting: Bool
  /// Keeps the reason and details while a report form is open. Store updates must not rebuild it.
  private var reportFormReady = false
  /// Runs after a saved block or report, once this screen has closed.
  var onResolved: (() -> Void)?
  init(store: AppStore, target: ContentSafetyTarget, reporting: Bool = false) {
    self.target = target
    self.reporting = reporting
    super.init(store: store, title: reporting ? "Report" : "More")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if reporting { expandReportSheet() }
  }
  override func refresh() {
    guard isViewLoaded, !reportFormReady else { return }
    clear()
    heading(target.title)
    if !reporting {
      content.addArrangedSubview(
        actionButton("Report " + target.kind.rawValue.lowercased(), icon: .flag) { [weak self] in
          guard let self else { return }
          self.reporting = true
          self.title = "Report"
          self.installStudioChrome()
          self.reportFormReady = false
          self.refresh()
        })
      if !store.isOnline || UUID(uuidString: target.creator.id) != nil {
        content.addArrangedSubview(
          actionButton("Block " + target.creator.name, icon: .block) { [weak self] in
          guard let self else { return }
          self.confirm(
            "Block this creator?",
            message:
              "Their videos, circle posts, replies, and chats will be hidden. You can unblock them from Blocked in Settings.",
            destructive: true, button: "Block"
          ) { [weak self] in
            guard let self else { return }
            Task {
              if await self.store.blockCreator(self.target.creator) {
                self.closeAfterAction()
              } else {
                self.message(self.store.lastSaveError ?? "Please try again.")
              }
            }
          }
          })
      }
      return
    }
    let reasons = StudioOptions(items: ContentReportReason.allCases.map(\.rawValue))
    var selected = ContentReportReason.allCases[reasons.index]
    reasons.onChange = { selected = ContentReportReason.allCases[$0] }
    content.addArrangedSubview(reasons)
    let details = field("Additional details (optional)")
    content.addArrangedSubview(details)
    content.addArrangedSubview(
      label(
        store.isOnline ? "Reports are submitted for review. Showing content again does not withdraw a submitted report." : "Reports stay on this device and are not submitted. Remove one from Reported in Settings.",
        14, BibiPalette.muted))
    content.addArrangedSubview(
      actionButton(store.isOnline ? "Submit report" : "Save report", icon: .flag, primary: true) { [weak self] in
        guard let self else { return }
        let reason = selected
        let note = details.text ?? ""
        Task {
          if await self.store.saveContentReport(self.target, reason: reason, details: note) {
            self.view.endEditing(true)
            self.closeAfterAction(note: "Report saved")
          } else {
            self.message(self.store.lastSaveError ?? "Your report could not be saved. Please try again.")
          }
        }
      })
    reportFormReady = true
    expandReportSheet()
  }
  /// The reason list is taller than the half sheet, so Save report has to be on screen.
  private func expandReportSheet() {
    guard let sheet = navigationController?.sheetPresentationController else { return }
    sheet.animateChanges { sheet.selectedDetentIdentifier = .large }
  }
  private func closeAfterAction(note: String? = nil) {
    let next = onResolved
    let host = navigationController ?? self
    let window = view.window
    host.dismiss(animated: true) {
      if let note { StudioNotice.show(note, in: window) }
      next?()
    }
  }
}
final class WalletController: StackScreen {
  override func build() {
    super.build()
    title = "Wallet"
    store.wallet.prepareProducts()
    store.wallet.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
      self?.refresh()
    }.store(in: &tokens)
  }
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    let image = UIImageView(image: BibiIcon.diamond.image(size: 76))
    image.contentMode = .scaleAspectFit
    image.height(76)
    content.addArrangedSubview(image)
    let balanceUnavailable = store.isOnline && (store.wallet.balanceLoading || store.wallet.balanceError != nil)
    let balance = heading(balanceUnavailable
      ? (store.wallet.balanceLoading ? "Loading balance…" : "Balance unavailable")
      : "\(store.wallet.snapshot.diamonds.formatted()) Diamonds")
    balance.accessibilityIdentifier = "wallet.balance"
    balance.accessibilityValue = balanceUnavailable ? nil : String(store.wallet.snapshot.diamonds)
    if let error = store.wallet.balanceError, store.isOnline {
      content.addArrangedSubview(label(error, 15, BibiPalette.muted))
      content.addArrangedSubview(actionButton("Retry balance", icon: .refresh) { [weak self] in self?.store.wallet.retryBalance() })
    }
    if let notice = store.wallet.recoveryNotice {
      content.addArrangedSubview(label(notice, 15, BibiPalette.muted))
      content.addArrangedSubview(actionButton("Retry purchase confirmation", icon: .refresh) { [weak self] in self?.store.wallet.retryPurchaseConfirmations() })
    }
    content.addArrangedSubview(
      label(
        "Your diamond balance is preserved. Post gifts are no longer available. Profile looks, chat styles and cover frames are optional. Joining a challenge uses 100 diamonds. Messages, posts, comments, reports and blocks stay free.",
        15, BibiPalette.muted))
    let packages = WalletCatalog.packages(for: .diamonds)
    if let notice = store.wallet.catalog.notice {
      content.addArrangedSubview(label(notice, 15, BibiPalette.muted))
    }
    if store.wallet.catalog.canRetry {
      let retry = actionButton("Retry App Store", primary: true) { [weak self] in
        self?.store.wallet.retryProducts()
      }
      retry.isEnabled = !store.wallet.isBusy
      content.addArrangedSubview(retry)
    }
    #if DEBUG
    if store.wallet.catalog.phase != .ready && store.wallet.catalog.phase != .loading {
      content.addArrangedSubview(actionButton("Copy Store Diagnostics") { [weak self] in
        guard let self else { return }
        UIPasteboard.general.string = self.store.wallet.diagnostics
        self.message("Store diagnostics copied.")
      })
    }
    #endif
    for start in stride(from: 0, to: packages.count, by: 3) {
      let row = stack(axis: .horizontal, spacing: 8)
      row.distribution = .fillEqually
      let end = min(start + 3, packages.count)
      for package in packages[start..<end] {
        let price = store.wallet.priceText(for: package)
        let priceNote = "Price: \(price)"
        let b = actionButton(
          package.amountText + "\n" + price, icon: .diamond, axis: .vertical
        ) { [weak self] in
          guard let self else { return }
          self.confirm(
            "Add \(package.amountText) diamonds", message: priceNote,
            button: "Continue"
          ) { [weak self] in
            guard let self else { return }
            Task {
              if let error = await self.store.wallet.purchase(package) { self.message(error) }
            }
          }
        }
        b.isEnabled = !store.wallet.isBusy && store.wallet.isAvailable(package)
        b.accessibilityIdentifier = "wallet.package.\(package.amount)"
        row.addArrangedSubview(b)
      }
      for _ in 0..<(3 - (end - start)) {
        let spacer = UIView()
        spacer.isAccessibilityElement = false
        row.addArrangedSubview(spacer)
      }
      content.addArrangedSubview(row)
    }
    heading("Activity")
    if store.wallet.snapshot.activity.isEmpty {
      content.addArrangedSubview(label("No transactions yet.", 15, BibiPalette.muted))
    }
    for item in store.wallet.snapshot.activity {
      content.addArrangedSubview(label(item.title))
    }
  }
}
func giftIcon(for gift: StarGift) -> BibiIcon {
  switch gift.id {
  case "rose": return .flower
  case "balloons": return .balloon
  case "heart": return .heart
  case "beat": return .wand
  case "spotlight": return .sparkle
  case "bouquet": return .flower
  case "crown": return .crown
  case "encore": return .comet
  default: return .planet
  }
}

/// A local gift animation that does not intercept taps.
enum GiftBurst {
  static func show(gift: StarGift, quantity: Int, in host: UIView) {
    let canvas = host.window ?? host
    let stage = UIView(frame: canvas.bounds)
    stage.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    stage.isUserInteractionEnabled = false
    stage.backgroundColor = .clear
    stage.isAccessibilityElement = true
    stage.accessibilityLabel = quantity > 1 ? "\(gift.name), \(quantity)" : gift.name
    canvas.addSubview(stage)
    let icon = giftIcon(for: gift)
    let main = UIImageView(image: icon.image(size: 148))
    main.contentMode = .scaleAspectFit
    let caption = UILabel()
    caption.text = quantity > 1 ? "\(gift.name) × \(quantity)" : gift.name
    caption.font = BibiPalette.font(28, title: true)
    caption.textColor = .white
    caption.textAlignment = .center
    caption.layer.shadowColor = UIColor.black.cgColor
    caption.layer.shadowOpacity = 0.45
    caption.layer.shadowRadius = 6
    caption.layer.shadowOffset = CGSize(width: 0, height: 2)
    stage.addSubview(main)
    stage.addSubview(caption)
    let center = CGPoint(x: stage.bounds.midX, y: stage.bounds.height * 0.30)
    main.bounds = CGRect(x: 0, y: 0, width: 148, height: 148)
    main.center = CGPoint(x: center.x, y: center.y + 70)
    caption.sizeToFit()
    caption.center = CGPoint(x: center.x, y: main.center.y + 96)
    var satellites: [UIImageView] = []
    let offsets: [(CGFloat, CGFloat)] = [(-78, -36), (84, -28), (-46, 54), (58, 62), (0, -78)]
    for offset in offsets {
      let small = UIImageView(image: icon.image(size: 54))
      small.bounds = CGRect(x: 0, y: 0, width: 54, height: 54)
      small.center = main.center
      small.alpha = 0
      stage.addSubview(small)
      satellites.append(small)
      small.tag = Int(offset.0 * 10 + offset.1)
    }
    let reduce = UIAccessibility.isReduceMotionEnabled
    main.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
    main.alpha = 0
    caption.alpha = 0
    UIView.animate(
      withDuration: reduce ? 0.2 : 0.55, delay: 0, usingSpringWithDamping: 0.62,
      initialSpringVelocity: 0.6
    ) {
      main.transform = .identity
      main.alpha = 1
      caption.alpha = 1
      if !reduce {
        main.center = center
        caption.center = CGPoint(x: center.x, y: center.y + 96)
      }
    }
    if !reduce {
      for (index, small) in satellites.enumerated() {
        let offset = offsets[index]
        UIView.animate(
          withDuration: 0.7, delay: 0.08, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.4
        ) {
          small.alpha = 1
          small.center = CGPoint(x: center.x + offset.0, y: center.y + offset.1)
        }
      }
    }
    UIView.animate(withDuration: 0.45, delay: reduce ? 0.8 : 1.35, options: [.curveEaseIn]) {
      main.alpha = 0
      caption.alpha = 0
      if !reduce { main.center.y -= 28 }
      for small in satellites { small.alpha = 0 }
    } completion: { _ in
      stage.removeFromSuperview()
    }
  }
}

extension BibiScreen {
  func presentGifts(for target: GiftTarget) {
    guard store.canGift(target) else { return }
    let picker = GiftsController(store: store, target: target)
    let navigation = UINavigationController(rootViewController: picker)
    BibiNavigation.style(navigation)
    navigation.modalPresentationStyle = .pageSheet
    if let sheet = navigation.sheetPresentationController {
      sheet.detents = [.custom(identifier: .init("compactGifts")) { context in
        min(480, context.maximumDetentValue * 0.62)
      }]
      sheet.prefersGrabberVisible = true
      sheet.preferredCornerRadius = 26
      sheet.prefersScrollingExpandsWhenScrolledToEdge = false
      sheet.prefersEdgeAttachedInCompactHeight = true
      sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
    }
    navigation.preferredContentSize = CGSize(width: 430, height: 480)
    picker.navigationItem.rightBarButtonItem = barButton(
      iconButton(.close, "Close gifts") { [weak picker] in picker?.closePicker() })
    present(navigation, animated: true)
  }
}

final class GiftsController: StackScreen {
  private var quantity = 1
  private var sending = false
  private var observation: AnyCancellable?
  let target: GiftTarget

  init(store: AppStore, target: GiftTarget) {
    self.target = target
    super.init(store: store, title: "Gifts")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func build() {
    super.build()
    content.spacing = 10
    view.accessibilityIdentifier = "gift.sheet"
    observation = store.wallet.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
      self?.refresh()
    }
  }
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    navigationController?.isModalInPresentation = sending || store.wallet.isBusy
    let context = label(target.title, 13, BibiPalette.muted)
    context.numberOfLines = 1
    context.lineBreakMode = .byTruncatingTail
    content.addArrangedSubview(context)
    let balance = label("\(store.wallet.snapshot.diamonds.formatted()) Diamonds", 17, title: true)
    balance.accessibilityIdentifier = "gift.balance"
    balance.accessibilityValue = String(store.wallet.snapshot.diamonds)
    let topUp = actionButton("Add", icon: .diamond, compact: true) { [weak self] in
      guard let self else { return }
      self.push(WalletController(store: self.store))
    }
    topUp.isEnabled = !sending && !store.wallet.isBusy
    topUp.accessibilityLabel = "Add diamonds"
    topUp.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    let walletRow = stack([balance, UIView(), topUp], axis: .horizontal, spacing: 8)
    walletRow.alignment = .center
    content.addArrangedSubview(walletRow)
    guard store.canGift(target) else {
      content.addArrangedSubview(label("This content is no longer available.", 16))
      return
    }
    let quantities = StudioChoice(items: ["1 gift", "5 gifts", "10 gifts"],
                                 index: [1, 5, 10].firstIndex(of: quantity) ?? 0)
    quantities.isUserInteractionEnabled = !sending && !store.wallet.isBusy
    quantities.onChange = { [weak self] next in
      self?.quantity = [1, 5, 10][next]
      self?.refresh()
    }
    content.addArrangedSubview(quantities)
    for i in stride(from: 0, to: StarGift.catalog.count, by: 3) {
      let row = stack(axis: .horizontal, spacing: 8)
      row.distribution = .fillEqually
      for gift in StarGift.catalog[i..<min(i + 3, StarGift.catalog.count)] {
        let button = actionButton(
          "\(gift.name)\n\((gift.diamonds * quantity).formatted())\ndiamonds",
          icon: giftIcon(for: gift), axis: .vertical, compact: true, iconSize: 28
        ) { [weak self] in self?.choose(gift) }
        button.caption.numberOfLines = 0
        button.caption.adjustsFontSizeToFitWidth = false
        button.caption.font = BibiPalette.font(12)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.caption.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.isEnabled = !sending && !store.wallet.isBusy
        button.accessibilityIdentifier = "gift.item.\(gift.id)"
        row.addArrangedSubview(button)
      }
      content.addArrangedSubview(row)
    }
    content.addArrangedSubview(label(
      store.isOnline ? "Gifts add an effect and an account record. No money is transferred to the creator." : "Gifts add an effect and a record on this device. No gift or money is sent to the creator.",
      12, BibiPalette.muted))
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    view.clipsToBounds = true
    navigationController?.view.clipsToBounds = true
  }
  fileprivate func closePicker() {
    guard !sending, !store.wallet.isBusy else { return }
    dismiss(animated: true)
  }
  private func choose(_ gift: StarGift) {
    guard !sending, !store.wallet.isBusy, store.canGift(target) else { return }
    let count = quantity
    let cost = gift.diamonds * count
    guard store.wallet.snapshot.diamonds >= cost else {
      confirm("Not enough diamonds", message: "This gift costs \(cost.formatted()) diamonds. No diamonds were spent.",
              button: "Add diamonds") { [weak self] in
        guard let self else { return }
        self.push(WalletController(store: self.store))
      }
      return
    }
    confirm("Use \(cost.formatted()) diamonds?",
            message: "\(count) × \(gift.name) for \(target.title). " + (store.isOnline ? "This records the gift in your account and plays its animation. The creator does not receive a transfer." : "This saves a local gift and plays its animation. The creator does not receive a transfer."),
            button: "Use diamonds") { [weak self] in
      guard let self, !self.sending else { return }
      self.sending = true
      self.refresh()
      Task { @MainActor in
        let error = await self.store.wallet.send(gift, quantity: count, target: self.target) { [weak self] in
          guard let self else { return false }
          return self.store.canGift(self.target)
        }
        self.sending = false
        self.refresh()
        if let error { self.message(error) } else {
          GiftBurst.show(gift: gift, quantity: count, in: self.view)
          UIAccessibility.post(notification: .announcement,
                               argument: self.store.isOnline ? "Gift recorded. \(cost) diamonds used." : "Gift saved on this device. \(cost) diamonds used.")
        }
      }
    }
  }
}
