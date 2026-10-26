import Combine
import CoreText
import ImageIO
import UIKit

extension UIView {
  func pin(to other: UIView, insets: UIEdgeInsets = .zero) {
    translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.left),
      trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.right),
      topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
      bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom),
    ])
  }
  func rounded(_ radius: CGFloat = 18) {
    layer.cornerRadius = radius
    clipsToBounds = true
  }
  func height(_ value: CGFloat) { heightAnchor.constraint(equalToConstant: value).isActive = true }
}
@MainActor func label(
  _ text: String, _ size: CGFloat = 16, _ color: UIColor = BibiPalette.ink, title: Bool = false
) -> UILabel {
  let l = UILabel()
  l.text = text
  l.font = BibiPalette.font(size, title: title)
  l.textColor = color
  l.numberOfLines = 0
  l.adjustsFontForContentSizeCategory = true
  return l
}
@MainActor func stack(
  _ views: [UIView] = [], axis: NSLayoutConstraint.Axis = .vertical, spacing: CGFloat = 12
) -> UIStackView {
  let s = UIStackView(arrangedSubviews: views)
  s.axis = axis
  s.spacing = spacing
  return s
}
@MainActor func iconButton(
  _ icon: BibiIcon, _ name: String, color: UIColor = BibiPalette.accent, size: CGFloat = 26,
  action: @escaping () -> Void
) -> UIButton {
  let b = UIButton(type: .custom)
  b.setImage(icon.image(color, size: size), for: .normal)
  b.accessibilityLabel = name
  b.translatesAutoresizingMaskIntoConstraints = false
  b.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
  b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
  b.addAction(UIAction { _ in action() }, for: .touchUpInside)
  soften(b)
  return b
}
/// The 34-point Bibi mark used at the top left of each root tab.
@MainActor func bibiMark() -> UIView {
  let holder = UIView()
  holder.translatesAutoresizingMaskIntoConstraints = false
  holder.isAccessibilityElement = true
  holder.accessibilityLabel = "Bibi"
  let logo = UIImageView(image: BibiIcon.appMark)
  logo.contentMode = .scaleAspectFill
  logo.clipsToBounds = true
  logo.layer.cornerRadius = 8
  logo.layer.cornerCurve = .continuous
  logo.isAccessibilityElement = false
  holder.addSubview(logo)
  logo.pin(to: holder)
  NSLayoutConstraint.activate([
    holder.widthAnchor.constraint(equalToConstant: 34),
    holder.heightAnchor.constraint(equalToConstant: 34),
  ])
  return holder
}
/// Custom icons stay bare. iOS 26 otherwise draws a shared glass plate behind a bar button.
@MainActor func barButton(_ view: UIView) -> UIBarButtonItem {
  let item = UIBarButtonItem(customView: view)
  if #available(iOS 26.0, *) {
    item.hidesSharedBackground = true
    item.sharesBackground = false
  }
  return item
}
@MainActor func soften(_ button: UIButton) {
  button.addAction(
    UIAction { [weak button] _ in
      guard !UIAccessibility.isReduceMotionEnabled else { return }
      UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
        button?.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
      }
    }, for: .touchDown)
  button.addAction(
    UIAction { [weak button] _ in
      UIView.animate(
        withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.7,
        options: [.allowUserInteraction]
      ) {
        button?.transform = .identity
      }
    }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
}
enum BibiTone { case primary, quiet, lime, pink, danger }

/// Painted control. UIButton configuration adopts the system button chrome, so actions draw their own fill, type, and icon.
final class BibiButton: UIControl {
  let caption = UILabel()
  let iconView = UIImageView()
  private let tone: BibiTone
  private let compact: Bool
  private let vertical: Bool
  private let iconSize: CGFloat
  private let sidePad: CGFloat
  private let verticalPad: CGFloat
  init(
    title: String, icon: UIImage?, tone: BibiTone, axis: NSLayoutConstraint.Axis = .horizontal,
    compact: Bool = false, iconSize: CGFloat = 23
  ) {
    self.tone = tone
    self.compact = compact
    self.vertical = axis == .vertical
    self.iconSize = iconSize
    self.sidePad = compact ? 14 : 16
    self.verticalPad = compact ? 8 : 13
    super.init(frame: .zero)
    caption.text = title
    caption.font = BibiPalette.font(compact ? 14 : 16)
    caption.numberOfLines = 0
    caption.textAlignment = axis == .vertical || icon == nil ? .center : .natural
    caption.adjustsFontForContentSizeCategory = true
    iconView.image = icon
    iconView.contentMode = .scaleAspectFit
    iconView.isHidden = icon == nil
    let row = UIStackView(arrangedSubviews: [iconView, caption])
    row.axis = axis
    row.spacing = axis == .vertical ? 8 : 10
    row.alignment = .center
    row.isUserInteractionEnabled = false
    addSubview(row)
    row.translatesAutoresizingMaskIntoConstraints = false
    let pad = verticalPad
    let side = sidePad
    let pins = [
      row.topAnchor.constraint(equalTo: topAnchor, constant: pad),
      row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -pad),
      row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: side),
      row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -side),
    ]
    if axis == .vertical {
      caption.numberOfLines = 2
      caption.adjustsFontSizeToFitWidth = true
      caption.minimumScaleFactor = 0.7
    }
    NSLayoutConstraint.activate(pins)
    if icon != nil {
      iconView.widthAnchor.constraint(equalToConstant: iconSize).isActive = true
      iconView.heightAnchor.constraint(equalToConstant: iconSize).isActive = true
    }
    layer.cornerRadius = compact ? 16 : 22
    layer.cornerCurve = .continuous
    clipsToBounds = true
    if !compact {
      heightAnchor.constraint(greaterThanOrEqualToConstant: axis == .vertical ? 108 : 48).isActive = true
    }
    if compact {
      setContentHuggingPriority(.required, for: .horizontal)
      setContentCompressionResistancePriority(.required, for: .horizontal)
    } else if axis == .vertical {
      setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      caption.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
    paint()
    addTarget(self, action: #selector(pressDown), for: .touchDown)
    addTarget(self, action: #selector(pressUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    isAccessibilityElement = true
    accessibilityTraits = .button
    accessibilityLabel = title.replacingOccurrences(of: "\n", with: ", ")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override var intrinsicContentSize: CGSize {
    let text = caption.intrinsicContentSize
    let icon = iconView.isHidden ? 0 : iconSize + 10
    let width = ceil(text.width + icon + sidePad * 2)
    let minimum: CGFloat = compact ? 36 : (vertical ? 108 : 48)
    let extra: CGFloat = vertical && !iconView.isHidden ? iconSize + 8 : 0
    let height = max(minimum, ceil(text.height + verticalPad * 2 + extra))
    return CGSize(width: max(width, 72), height: height)
  }
  override var isEnabled: Bool {
    didSet {
      alpha = isEnabled ? 1 : 0.45
      if isEnabled {
        accessibilityTraits.remove(.notEnabled)
      } else {
        accessibilityTraits.insert(.notEnabled)
      }
    }
  }
  private func paint() {
    let fill: UIColor
    let ink: UIColor
    switch tone {
    case .primary:
      fill = BibiPalette.accent
      ink = .white
    case .quiet:
      fill = UIColor.white.withAlphaComponent(0.86)
      ink = BibiPalette.ink
    case .lime:
      fill = BibiPalette.selection
      ink = BibiPalette.ink
    case .pink:
      fill = BibiPalette.pink
      ink = .white
    case .danger:
      fill = BibiPalette.dangerFill
      ink = BibiPalette.dangerInk
    }
    backgroundColor = fill
    caption.textColor = ink
    layer.borderWidth = tone == .quiet ? 1 : 0
    layer.borderColor = BibiPalette.line.cgColor
  }
  @objc private func pressDown() {
    guard isEnabled, !UIAccessibility.isReduceMotionEnabled else { return }
    UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
      self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
    }
  }
  @objc private func pressUp() {
    UIView.animate(
      withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.7,
      options: [.allowUserInteraction]
    ) { self.transform = .identity }
  }
}

@MainActor func actionButton(
  _ text: String, icon: BibiIcon? = nil, primary: Bool = false, tone: BibiTone? = nil,
  axis: NSLayoutConstraint.Axis = .horizontal, compact: Bool = false, iconSize: CGFloat = 23,
  action: @escaping () -> Void
) -> BibiButton {
  let resolved = tone ?? (primary ? .primary : .quiet)
  let iconColor: UIColor
  switch resolved {
  case .primary, .pink: iconColor = .white
  case .danger: iconColor = BibiPalette.dangerInk
  case .quiet, .lime: iconColor = BibiPalette.accent
  }
  let button = BibiButton(
    title: text, icon: icon?.image(iconColor, size: iconSize), tone: resolved, axis: axis,
    compact: compact, iconSize: iconSize)
  button.addAction(UIAction { _ in action() }, for: .touchUpInside)
  return button
}

/// Illustrated root titles with accessible names; secondary screens use bundled display type.
final class StudioTitle: UIView {
  private static let illustratedTitles: Set<String> = ["Shorts", "Circles", "Challenges", "Chats", "Me"]
  private let caption = UILabel()
  private let mark = UIView()
  private let artwork = UIImageView()
  private var titleSize = CGSize(width: 88, height: 34)
  init(_ text: String) {
    super.init(frame: CGRect(x: 0, y: 0, width: 88, height: 34))
    isAccessibilityElement = true
    accessibilityTraits = .header
    caption.font = BibiPalette.font(18, title: true)
    caption.textColor = BibiPalette.ink
    caption.textAlignment = .center
    caption.adjustsFontForContentSizeCategory = true
    caption.isAccessibilityElement = false
    caption.adjustsFontSizeToFitWidth = true
    caption.minimumScaleFactor = 0.65
    caption.lineBreakMode = .byTruncatingTail
    mark.backgroundColor = BibiPalette.selection
    mark.layer.cornerRadius = 1.5
    artwork.contentMode = .scaleAspectFit
    artwork.isAccessibilityElement = false
    addSubview(caption)
    addSubview(mark)
    addSubview(artwork)
    setText(text)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  func setText(_ text: String) {
    caption.text = text
    accessibilityLabel = text
    accessibilityIdentifier = "page-title.\(text)"
    artwork.image = Self.illustratedTitles.contains(text)
      ? UIImage(named: "BibiTitle-\(text)")?.withRenderingMode(.alwaysOriginal) : nil
    let hasArtwork = artwork.image != nil
    artwork.isHidden = !hasArtwork
    caption.isHidden = hasArtwork
    mark.isHidden = hasArtwork
    if let image = artwork.image {
      let height: CGFloat = 40
      titleSize = CGSize(width: min(180, max(64, height * image.size.width / image.size.height)), height: height)
    } else {
      titleSize = CGSize(width: min(220, max(72, caption.intrinsicContentSize.width + 8)), height: 34)
    }
    frame.size = titleSize
    invalidateIntrinsicContentSize()
    setNeedsLayout()
  }
  override var intrinsicContentSize: CGSize { titleSize }
  override func layoutSubviews() {
    super.layoutSubviews()
    artwork.frame = bounds
    caption.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - 7)
    mark.frame = CGRect(x: (bounds.width - 22) / 2, y: bounds.height - 4, width: 22, height: 3)
  }
}

/// Horizontal pills for short choices. Replaces the system segmented control.
final class StudioChoice: UIView {
  private(set) var index: Int
  var onChange: ((Int) -> Void)?
  private var chips: [StudioChip] = []
  init(items: [String], index: Int = 0) {
    self.index = min(max(0, index), max(0, items.count - 1))
    super.init(frame: .zero)
    let scroller = UIScrollView()
    scroller.showsHorizontalScrollIndicator = false
    scroller.alwaysBounceHorizontal = true
    let row = UIStackView()
    row.axis = .horizontal
    row.spacing = 8
    row.alignment = .center
    addSubview(scroller)
    scroller.addSubview(row)
    scroller.translatesAutoresizingMaskIntoConstraints = false
    row.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      scroller.leadingAnchor.constraint(equalTo: leadingAnchor),
      scroller.trailingAnchor.constraint(equalTo: trailingAnchor),
      scroller.topAnchor.constraint(equalTo: topAnchor),
      scroller.bottomAnchor.constraint(equalTo: bottomAnchor),
      heightAnchor.constraint(equalToConstant: 44),
      row.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
      row.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
      row.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor),
      row.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor),
      row.heightAnchor.constraint(equalTo: scroller.frameLayoutGuide.heightAnchor),
    ])
    for (offset, title) in items.enumerated() {
      let chip = StudioChip(title, multiline: false)
      chip.addAction(UIAction { [weak self] _ in self?.select(offset) }, for: .touchUpInside)
      row.addArrangedSubview(chip)
      chips.append(chip)
    }
    restyle()
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  private func select(_ next: Int) {
    guard chips.indices.contains(next) else { return }
    index = next
    restyle()
    onChange?(next)
  }
  private func restyle() {
    for (offset, chip) in chips.enumerated() {
      chip.apply(selected: offset == index)
    }
  }
}

/// Full-width choice rows for longer labels.
final class StudioOptions: UIStackView {
  private(set) var index: Int
  var onChange: ((Int) -> Void)?
  private var chips: [StudioChip] = []
  init(items: [String], index: Int = 0) {
    self.index = min(max(0, index), max(0, items.count - 1))
    super.init(frame: .zero)
    axis = .vertical
    spacing = 8
    for (offset, title) in items.enumerated() {
      let chip = StudioChip(title, multiline: true)
      chip.addAction(UIAction { [weak self] _ in self?.select(offset) }, for: .touchUpInside)
      addArrangedSubview(chip)
      chips.append(chip)
    }
    restyle()
  }
  // UIStackView's coder initializer is non-failable, unlike UIView.
  required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  private func select(_ next: Int) {
    guard chips.indices.contains(next) else { return }
    index = next
    restyle()
    onChange?(next)
  }
  private func restyle() {
    for (offset, chip) in chips.enumerated() {
      chip.apply(selected: offset == index)
    }
  }
}

final class StudioChip: UIControl {
  private let caption = UILabel()
  init(_ text: String, multiline: Bool) {
    super.init(frame: .zero)
    caption.text = text
    caption.font = BibiPalette.font(14)
    caption.numberOfLines = multiline ? 0 : 1
    caption.textAlignment = multiline ? .natural : .center
    caption.adjustsFontForContentSizeCategory = true
    caption.isUserInteractionEnabled = false
    addSubview(caption)
    caption.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      caption.topAnchor.constraint(equalTo: topAnchor, constant: 10),
      caption.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
      caption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
      caption.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
      heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
    ])
    layer.cornerRadius = 20
    layer.cornerCurve = .continuous
    clipsToBounds = true
    isAccessibilityElement = true
    accessibilityLabel = text
    accessibilityTraits = .button
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  func apply(selected: Bool) {
    backgroundColor = selected ? BibiPalette.selection : UIColor.white.withAlphaComponent(0.86)
    caption.textColor = selected ? BibiPalette.ink : BibiPalette.muted
    layer.borderWidth = selected ? 0 : 1
    layer.borderColor = BibiPalette.line.cgColor
    accessibilityTraits = selected ? [.button, .selected] : .button
  }
}

/// Painted toggle. Replaces the system switch.
final class StudioSwitch: UIControl {
  var isOn = false {
    didSet {
      accessibilityValue = isOn ? "On" : "Off"
      setNeedsLayout()
    }
  }
  private let track = UIView()
  private let knob = UIView()
  override init(frame: CGRect) {
    super.init(frame: frame)
    track.isUserInteractionEnabled = false
    knob.isUserInteractionEnabled = false
    knob.backgroundColor = .white
    knob.layer.cornerRadius = 12
    addSubview(track)
    addSubview(knob)
    addTarget(self, action: #selector(toggle), for: .touchUpInside)
    isAccessibilityElement = true
    accessibilityLabel = "Switch"
    accessibilityTraits = .button
    accessibilityValue = "Off"
    translatesAutoresizingMaskIntoConstraints = false
    widthAnchor.constraint(equalToConstant: 52).isActive = true
    heightAnchor.constraint(equalToConstant: 32).isActive = true
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func layoutSubviews() {
    super.layoutSubviews()
    track.frame = bounds
    track.layer.cornerRadius = bounds.height / 2
    let x: CGFloat = isOn ? bounds.width - 28 : 4
    knob.frame = CGRect(x: x, y: 4, width: 24, height: 24)
    track.backgroundColor = isOn ? BibiPalette.accent : BibiPalette.soft
    track.layer.borderWidth = 1
    track.layer.borderColor = (isOn ? BibiPalette.accent : BibiPalette.line).cgColor
  }
  @objc private func toggle() {
    isOn.toggle()
    sendActions(for: .valueChanged)
    guard !UIAccessibility.isReduceMotionEnabled else { return }
    UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.4) {
      self.layoutIfNeeded()
    }
  }
}

/// Icon stacked over a count. Used on the video rail, without a system button label.
final class StudioCounter: UIControl {
  let iconView = UIImageView()
  private let caption = UILabel()
  init(name: String) {
    super.init(frame: .zero)
    iconView.contentMode = .scaleAspectFit
    caption.font = BibiPalette.font(12)
    caption.textColor = .white
    caption.textAlignment = .center
    caption.isUserInteractionEnabled = false
    iconView.isUserInteractionEnabled = false
    let column = UIStackView(arrangedSubviews: [iconView, caption])
    column.axis = .vertical
    column.alignment = .center
    column.spacing = 2
    column.isUserInteractionEnabled = false
    addSubview(column)
    column.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      column.topAnchor.constraint(equalTo: topAnchor),
      column.bottomAnchor.constraint(equalTo: bottomAnchor),
      column.leadingAnchor.constraint(equalTo: leadingAnchor),
      column.trailingAnchor.constraint(equalTo: trailingAnchor),
      iconView.widthAnchor.constraint(equalToConstant: 32),
      iconView.heightAnchor.constraint(equalToConstant: 32),
      widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
      heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
    ])
    isAccessibilityElement = true
    accessibilityLabel = name
    accessibilityTraits = .button
    addTarget(self, action: #selector(pressDown), for: .touchDown)
    addTarget(self, action: #selector(pressUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  func setIcon(_ image: UIImage?) { iconView.image = image }
  /// Lets a long count stay inside a narrow video control.
  func compressCount() {
    caption.adjustsFontSizeToFitWidth = true
    caption.minimumScaleFactor = 0.6
  }
  /// Hides the number under the icon. The control keeps its name for accessibility.
  func hideCount() {
    caption.isHidden = true
    caption.text = nil
    for constraint in constraints where constraint.firstAttribute == .height
      && constraint.relation == .greaterThanOrEqual && constraint.secondItem == nil
    {
      constraint.constant = 36
    }
  }
  func setCount(_ text: String, selected: Bool) {
    caption.textColor = selected ? BibiPalette.selection : .white
    if caption.isHidden {
      accessibilityValue = selected ? "Selected" : nil
      return
    }
    caption.text = text
    accessibilityValue = text + (selected ? ", selected" : "")
  }
  @objc private func pressDown() {
    guard !UIAccessibility.isReduceMotionEnabled else { return }
    UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction]) {
      self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
    }
  }
  @objc private func pressUp() {
    UIView.animate(
      withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.7,
      options: [.allowUserInteraction]
    ) { self.transform = .identity }
  }
}
@MainActor func field(_ placeholder: String, text: String = "") -> UITextField {
  let f = UITextField()
  f.placeholder = placeholder
  f.text = text
  f.font = BibiPalette.font()
  f.textColor = BibiPalette.ink
  f.backgroundColor = .white
  f.layer.cornerRadius = 14
  f.height(52)
  let pad = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 10))
  f.leftView = pad
  f.leftViewMode = .always
  f.autocorrectionType = .no
  f.accessibilityLabel = placeholder
  return f
}
/// A portrait that is present in the asset catalog. Missing names fall back to a stable photograph.
@MainActor func portraitAsset(_ asset: String?, personID: String) -> String {
  if let asset {
    let mapped = CommunityArtwork.avatar(asset)
    if UIImage(named: mapped) != nil { return mapped }
  }
  let fallback = CommunityArtwork.creatorAvatar(for: personID)
  if UIImage(named: fallback) != nil { return fallback }
  return "Portrait1"
}

/// Group artwork is composed from actual members, never the first member alone.
@MainActor func conversationPortrait(_ conversation: CommunityConversation, size: CGFloat) -> UIView {
  guard conversation.kind == .group else {
    return roundPortrait(
      asset: conversation.avatars.first ?? conversation.creator?.avatarAsset,
      size: size, personID: conversation.creator?.id ?? conversation.id)
  }
  var seen = Set<String>()
  let assets = Array(conversation.avatars.map { CommunityArtwork.avatar($0) }
    .filter { UIImage(named: $0) != nil && seen.insert($0).inserted }.prefix(9))
  let frame = UIView()
  frame.translatesAutoresizingMaskIntoConstraints = false
  frame.backgroundColor = BibiPalette.soft
  frame.layer.cornerRadius = size * 0.22
  frame.layer.cornerCurve = .continuous
  frame.layer.borderWidth = 2
  frame.layer.borderColor = BibiPalette.accent.cgColor
  frame.clipsToBounds = true
  frame.isAccessibilityElement = true
  frame.accessibilityLabel = conversation.name + ", group members"
  NSLayoutConstraint.activate([
    frame.widthAnchor.constraint(equalToConstant: size),
    frame.heightAnchor.constraint(equalToConstant: size),
  ])
  if assets.isEmpty {
    let mark = UIImageView(image: BibiIcon.chats.image(size: size * 0.55))
    mark.contentMode = .scaleAspectFit
    mark.translatesAutoresizingMaskIntoConstraints = false
    mark.isAccessibilityElement = false
    frame.addSubview(mark)
    NSLayoutConstraint.activate([
      mark.centerXAnchor.constraint(equalTo: frame.centerXAnchor),
      mark.centerYAnchor.constraint(equalTo: frame.centerYAnchor),
      mark.widthAnchor.constraint(equalToConstant: size * 0.55),
      mark.heightAnchor.constraint(equalTo: mark.widthAnchor),
    ])
    return frame
  }
  let columns = assets.count <= 4 ? 2 : 3
  let rows = max(1, (assets.count + columns - 1) / columns)
  let gap: CGFloat = 2
  let inset: CGFloat = 4
  let tile = (size - 2 * inset - CGFloat(columns - 1) * gap) / CGFloat(columns)
  let top = (size - CGFloat(rows) * tile - CGFloat(rows - 1) * gap) / 2
  for (index, asset) in assets.enumerated() {
    let row = index / columns
    let countInRow = min(columns, assets.count - row * columns)
    let left = (size - CGFloat(countInRow) * tile - CGFloat(countInRow - 1) * gap) / 2
    let photo = BibiArtwork(asset: asset)
    photo.translatesAutoresizingMaskIntoConstraints = false
    photo.layer.cornerRadius = 2
    photo.clipsToBounds = true
    photo.isAccessibilityElement = false
    frame.addSubview(photo)
    NSLayoutConstraint.activate([
      photo.leadingAnchor.constraint(equalTo: frame.leadingAnchor,
        constant: left + CGFloat(index % columns) * (tile + gap)),
      photo.topAnchor.constraint(equalTo: frame.topAnchor, constant: top + CGFloat(row) * (tile + gap)),
      photo.widthAnchor.constraint(equalToConstant: tile),
      photo.heightAnchor.constraint(equalToConstant: tile),
    ])
  }
  return frame
}

/// Circular portrait with an evergreen frame for an individual account.
@MainActor func roundPortrait(
  asset: String?, size: CGFloat, personID: String = "dancer", image: UIImage? = nil
) -> UIView {
  let ring = UIView()
  ring.translatesAutoresizingMaskIntoConstraints = false
  ring.backgroundColor = BibiPalette.selection.withAlphaComponent(0.45)
  ring.layer.cornerRadius = size / 2
  ring.layer.borderWidth = 2
  ring.layer.borderColor = BibiPalette.accent.cgColor
  ring.clipsToBounds = true
  let photo = BibiArtwork(
    asset: image == nil ? portraitAsset(asset, personID: personID) : nil, size: size - 6, round: true)
  if let image { photo.image = image }
  ring.addSubview(photo)
  NSLayoutConstraint.activate([
    ring.widthAnchor.constraint(equalToConstant: size),
    ring.heightAnchor.constraint(equalToConstant: size),
    photo.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
    photo.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
  ])
  return ring
}

final class BibiArtwork: UIImageView {
  private static let coverCache: NSCache<NSURL, UIImage> = {
    let cache = NSCache<NSURL, UIImage>()
    cache.countLimit = 48
    return cache
  }()
  private var request: UUID?
  init(asset: String? = nil, size: CGFloat? = nil, round: Bool = false) {
    super.init(frame: .zero)
    contentMode = .scaleAspectFill
    clipsToBounds = true
    backgroundColor = BibiPalette.soft
    if let asset { image = UIImage(named: CommunityArtwork.avatar(asset)) }
    if let size {
      translatesAutoresizingMaskIntoConstraints = false
      widthAnchor.constraint(equalToConstant: size).isActive = true
      height(size)
      layer.cornerRadius = round ? size / 2 : 14
    }
    isAccessibilityElement = false
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  func load(_ url: URL?) {
    let id = UUID()
    request = id
    guard let url else {
      image = BibiIcon.photo.image(size: 64)
      return
    }
    let key = url as NSURL
    if let cached = Self.coverCache.object(forKey: key) {
      image = cached
      return
    }
    image = BibiIcon.photo.image(size: 64)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      let loaded = CoverDecoding.image(at: url)
      DispatchQueue.main.async {
        guard let self, self.request == id else { return }
        if let loaded {
          Self.coverCache.setObject(loaded, forKey: key)
          self.image = loaded
        }
      }
    }
  }
}

/// Downsamples a cover off the main thread so the first screen can paint without waiting for a tap.
private enum CoverDecoding {
  static func image(at url: URL) -> UIImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: 720,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
    ] as CFDictionary
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
    return UIImage(cgImage: cgImage)
  }
}

/// A short note on the window. It leaves by itself and does not ask for a tap.
@MainActor enum StudioNotice {
  private static var hide: DispatchWorkItem?
  private static var token = 0
  private static let tag = 814_022

  static func show(_ text: String, seconds: TimeInterval = 3, in window: UIWindow? = nil) {
    let host = window
      ?? UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }?
        .windows.first { $0.isKeyWindow }
    guard let host else { return }
    token += 1
    let current = token
    hide?.cancel()
    host.viewWithTag(tag)?.removeFromSuperview()
    let box = UIView()
    box.tag = tag
    box.isUserInteractionEnabled = false
    box.backgroundColor = BibiPalette.background
    box.layer.cornerRadius = 18
    box.layer.cornerCurve = .continuous
    box.layer.shadowColor = BibiPalette.ink.cgColor
    box.layer.shadowOpacity = 0.16
    box.layer.shadowRadius = 16
    box.layer.shadowOffset = CGSize(width: 0, height: 8)
    box.accessibilityViewIsModal = false
    box.isAccessibilityElement = true
    box.accessibilityLabel = text
    let title = label(text, 17, BibiPalette.ink, title: true)
    title.textAlignment = .center
    title.isAccessibilityElement = false
    title.translatesAutoresizingMaskIntoConstraints = false
    box.addSubview(title)
    box.translatesAutoresizingMaskIntoConstraints = false
    host.addSubview(box)
    NSLayoutConstraint.activate([
      title.topAnchor.constraint(equalTo: box.topAnchor, constant: 14),
      title.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -14),
      title.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 22),
      title.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -22),
      box.centerXAnchor.constraint(equalTo: host.centerXAnchor),
      box.centerYAnchor.constraint(equalTo: host.centerYAnchor, constant: -24),
      box.leadingAnchor.constraint(greaterThanOrEqualTo: host.leadingAnchor, constant: 32),
      box.trailingAnchor.constraint(lessThanOrEqualTo: host.trailingAnchor, constant: -32),
    ])
    host.bringSubviewToFront(box)
    box.alpha = 0
    box.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
    UIAccessibility.post(notification: .announcement, argument: text)
    UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction]) {
      box.alpha = 1
      box.transform = .identity
    }
    let work = DispatchWorkItem {
      guard current == token else { return }
      hide = nil
      UIView.animate(withDuration: 0.25, delay: 0, options: [.allowUserInteraction]) {
        box.alpha = 0
      } completion: { _ in
        box.removeFromSuperview()
      }
    }
    hide = work
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
  }
}

@MainActor class BibiScreen: UIViewController, UIAdaptivePresentationControllerDelegate {
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    onDismiss?()
  }
  let store: AppStore
  var tokens = Set<AnyCancellable>()
  var onDismiss: (() -> Void)?
  /// The control this screen grew from. Closing shrinks back to it.
  weak var collapseTarget: UIView?
  private let canvas = StarlightCanvas()
  private var shownNotice: UUID?
  private var cardLayer: UIView?
  private var cardDismiss: (() -> Void)?
  var activeSearch: ExpandingSearchBar?
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    activeSearch?.dismiss(animated: false)
  }
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if isBeingDismissed || navigationController?.isBeingDismissed == true { onDismiss?() }
  }
  init(store: AppStore, title: String = "") {
    self.store = store
    super.init(nibName: nil, bundle: nil)
    self.title = title
    // The background extends beneath system bars; content keeps its safe-area constraints.
    edgesForExtendedLayout = .all
    extendedLayoutIncludesOpaqueBars = true
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    view.clipsToBounds = false
    canvas.isUserInteractionEnabled = false
    view.addSubview(canvas)
    overrideUserInterfaceStyle = .light
    build()
    refresh()
    store.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
      guard let self else { return }
      self.refresh()
      self.installStudioChrome()
      if let notice = self.store.notice, notice.id != self.shownNotice, self.view.window != nil,
        self.presentedViewController == nil
      {
        self.shownNotice = notice.id
        self.message(notice.message, title: notice.title)
        self.store.notice = nil
      }
    }
    .store(in: &tokens)
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    installStudioChrome()
  }
  /// Custom title and back control. The system title and back button stay out of the bar.
  func installStudioChrome() {
    guard let nav = navigationController, !nav.isNavigationBarHidden else { return }
    nav.navigationBar.prefersLargeTitles = false
    navigationItem.largeTitleDisplayMode = .never
    if !(navigationItem.titleView is BubbleTrack) {
      let text = title ?? ""
      if text.isEmpty {
        if navigationItem.titleView is StudioTitle { navigationItem.titleView = nil }
      } else if let studio = navigationItem.titleView as? StudioTitle {
        studio.setText(text)
      } else if navigationItem.titleView == nil {
        navigationItem.titleView = StudioTitle(text)
      }
    }
    let rooted = nav.viewControllers.first === self
    if !rooted, navigationItem.leftBarButtonItem == nil {
      navigationItem.hidesBackButton = true
      navigationItem.leftBarButtonItem = barButton(
        iconButton(.back, "Back") { [weak self] in
          self?.navigationController?.popViewController(animated: true)
        })
    }
  }
  func build() {}
  func refresh() {}
  /// Artwork frame covering the physical screen, including the status bar and home indicator.
  /// Sheets stay inside their own bounds so the artwork does not spill over the page behind them.
  func coverFrame() -> CGRect {
    let style = navigationController?.modalPresentationStyle ?? modalPresentationStyle
    if style == .pageSheet || style == .formSheet || style == .popover { return view.bounds }
    guard let window = view.window else { return view.bounds }
    return view.convert(window.bounds, from: window)
  }
  func insertAtmosphere(_ extra: UIView) {
    extra.isUserInteractionEnabled = false
    view.insertSubview(extra, aboveSubview: canvas)
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    var node: UIView? = view
    while let current = node, !(current is UIWindow) {
      current.clipsToBounds = false
      node = current.superview
    }
    canvas.frame = coverFrame()
  }
  func presentScreen(
    _ screen: UIViewController, full: Bool = false, animated: Bool = true, collapseTo: UIView? = nil
  ) {
    let nav = UINavigationController(rootViewController: screen)
    BibiNavigation.style(nav)
    if full {
      nav.modalPresentationStyle = .fullScreen
    } else {
      nav.modalPresentationStyle = .pageSheet
      nav.sheetPresentationController?.detents = [.medium(), .large()]
      nav.sheetPresentationController?.prefersGrabberVisible = true
      nav.presentationController?.delegate = screen as? UIAdaptivePresentationControllerDelegate
    }
    if let collapseTo, let screen = screen as? BibiScreen {
      screen.collapseTarget = collapseTo
    }
    screen.navigationItem.leftBarButtonItem = barButton(
      iconButton(.close, "Close") { [weak screen] in
        if let screen = screen as? BibiScreen {
          screen.dismissCollapsed()
        } else {
          screen?.dismiss(animated: true)
        }
      })
    present(nav, animated: animated)
  }
  /// Shrinks the whole presented page into the control that opened it.
  func dismissCollapsed() {
    let presented = navigationController ?? self
    let notify = onDismiss
    let target = collapseTarget
    guard target != nil else {
      presented.dismiss(animated: true) { notify?() }
      return
    }
    guard !UIAccessibility.isReduceMotionEnabled, let host = presented.view.window else {
      presented.dismiss(animated: false) { notify?() }
      return
    }
    let start = presented.view.convert(presented.view.bounds, to: host)
    let snapshot =
      presented.view.snapshotView(afterScreenUpdates: false) ?? StarlightCanvas(frame: start)
    snapshot.frame = start
    snapshot.clipsToBounds = true
    snapshot.layer.cornerCurve = .continuous
    snapshot.isUserInteractionEnabled = false
    host.addSubview(snapshot)
    presented.view.isHidden = true
    presented.dismiss(animated: false) {
      let end: CGRect
      if let target, let window = target.window {
        end = target.convert(target.bounds, to: window)
      } else {
        end = CGRect(x: start.midX - 26, y: start.maxY - 90, width: 52, height: 52)
      }
      UIView.animate(
        withDuration: 0.48, delay: 0, usingSpringWithDamping: 0.96, initialSpringVelocity: 0.15,
        options: [.curveEaseInOut]
      ) {
        snapshot.frame = end
        snapshot.layer.cornerRadius = min(end.width, end.height) / 2
      } completion: { _ in
        snapshot.removeFromSuperview()
        notify?()
      }
    }
  }
  /// Grows the studio background from the tapped control, then opens the next page on that same field.
  func presentExpanded(from source: UIView, _ screen: UIViewController) {
    let reveal = { [weak self] in
      self?.presentScreen(screen, full: true, animated: false, collapseTo: source)
    }
    guard !UIAccessibility.isReduceMotionEnabled, let host = view.window else {
      presentScreen(screen, full: true, collapseTo: source)
      return
    }
    let start = source.convert(source.bounds, to: host)
    guard start.width > 2, start.height > 2 else {
      presentScreen(screen, full: true, collapseTo: source)
      return
    }
    let cover = StarlightCanvas(frame: start)
    cover.isUserInteractionEnabled = true
    cover.layer.cornerRadius = 22
    cover.layer.cornerCurve = .continuous
    cover.clipsToBounds = true
    host.addSubview(cover)
    UIView.animate(
      withDuration: 0.48, delay: 0, usingSpringWithDamping: 0.96, initialSpringVelocity: 0.15,
      options: [.curveEaseInOut, .allowUserInteraction]
    ) {
      cover.frame = host.bounds
      cover.layer.cornerRadius = 0
    } completion: { _ in
      reveal()
      host.bringSubviewToFront(cover)
      DispatchQueue.main.async { cover.removeFromSuperview() }
    }
  }
  func expandSearch(
    from source: UIView, placeholder: String, dark: Bool = false,
    onChange: @escaping (String) -> Void, onClose: @escaping () -> Void
  ) {
    if activeSearch != nil {
      activeSearch?.dismiss()
      return
    }
    let bar = ExpandingSearchBar()
    activeSearch = bar
    bar.onChange = { [weak bar] text in
      onChange(text)
      bar?.setFiltering(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    bar.onClose = { [weak self] in
      self?.activeSearch = nil
      onClose()
    }
    let host: UIView
    if let navigationView = navigationController?.view {
      host = navigationView
    } else {
      host = view
    }
    bar.present(from: source, in: host, placeholder: placeholder, dark: dark)
  }
  func push(_ screen: UIViewController) {
    navigationController?.pushViewController(screen, animated: true)
  }
  func message(_ text: String, title: String = "Bibi") {
    guard presentedViewController == nil else { return }
    let ok = actionButton("OK", primary: true) { [weak self] in self?.dismissCard() }
    showCard([label(title, 22, title: true), label(text, 15, BibiPalette.muted), ok])
  }
  func confirm(
    _ title: String, message: String, destructive: Bool = false, button: String = "Continue",
    action: @escaping () -> Void
  ) {
    guard presentedViewController == nil else { return }
    let yes = actionButton(button, primary: !destructive, tone: destructive ? .danger : nil) {
      [weak self] in self?.dismissCard { action() }
    }
    let no = actionButton("Cancel") { [weak self] in self?.dismissCard() }
    showCard([label(title, 22, title: true), label(message, 15, BibiPalette.muted), yes, no])
  }
  /// Shared by short videos and community surfaces. Saving a message only writes the local outbox.
  func showContentShare(
    text: String, address: String, onShared: @escaping () -> Void = {},
    onClose: @escaping () -> Void = {}
  ) {
    view.endEditing(true)
    var selected = false
    let finish: (@escaping () -> Void) -> Void = { [weak self] action in
      guard !selected, let self else { return }
      selected = true
      self.dismissCard {
        onClose()
        action()
      }
    }
    let title = label("Share with", 22, title: true)
    let close = iconButton(.close, "Close") { [weak self] in self?.dismissCard() }
    let header = stack([title, UIView(), close], axis: .horizontal, spacing: 8)
    header.alignment = .center
    let people = store.chatConversations.filter {
      $0.kind == .person && $0.creator?.isLocalOwner != true && store.followsChatPartner($0)
    }
    let row = UIStackView()
    row.axis = .horizontal
    row.alignment = .top
    row.spacing = 14
    let scroller = UIScrollView()
    scroller.showsHorizontalScrollIndicator = false
    scroller.translatesAutoresizingMaskIntoConstraints = false
    scroller.heightAnchor.constraint(equalToConstant: 96).isActive = true
    if people.isEmpty {
      let empty = label("Add a friend in Chats before sharing with someone.", 14, BibiPalette.muted)
      scroller.addSubview(empty)
      empty.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        empty.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
        empty.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
        empty.centerYAnchor.constraint(equalTo: scroller.frameLayoutGuide.centerYAnchor),
        empty.widthAnchor.constraint(equalTo: scroller.frameLayoutGuide.widthAnchor),
      ])
    } else {
      scroller.addSubview(row)
      row.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        row.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
        row.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
        row.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor),
        row.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor),
        row.heightAnchor.constraint(equalTo: scroller.frameLayoutGuide.heightAnchor),
      ])
      for person in people {
        row.addArrangedSubview(contentSharePerson(person) { [weak self] in
          finish { [weak self] in
            guard let self else { return }
            Task { [weak self] in
              guard let self else { return }
              if await self.store.sendChatMessage(text, to: person) {
                onShared()
                self.message("Saved in your chat with \(person.name). It stays on this device.")
              } else {
                self.message(self.store.lastSaveError ?? "That message could not be saved.")
              }
            }
          }
        })
      }
    }
    let link = contentShareLink {
      finish { [weak self] in
        UIPasteboard.general.string = address
        onShared()
        self?.message("Link copied. This is a Bibi address, not a public web page.")
      }
    }
    let linkRow = stack([link, UIView()], axis: .horizontal, spacing: 8)
    linkRow.alignment = .top
    showBottomPanel(stack([header, scroller, linkRow], spacing: 16))
    cardDismiss = onClose
  }
  private func contentSharePerson(_ person: CommunityConversation, action: @escaping () -> Void) -> UIView {
    let item = UIButton(type: .custom)
    let photo = conversationPortrait(person, size: 56)
    let nickname = person.name.components(separatedBy: " ").first ?? person.name
    let name = label(nickname, 12)
    name.textAlignment = .center
    name.numberOfLines = 1
    name.adjustsFontSizeToFitWidth = true
    name.minimumScaleFactor = 0.8
    name.isAccessibilityElement = false
    let column = stack([photo, name], spacing: 6)
    column.alignment = .center
    column.isUserInteractionEnabled = false
    item.addSubview(column)
    column.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      item.widthAnchor.constraint(equalToConstant: 68),
      column.topAnchor.constraint(equalTo: item.topAnchor),
      column.bottomAnchor.constraint(equalTo: item.bottomAnchor),
      column.centerXAnchor.constraint(equalTo: item.centerXAnchor),
      column.widthAnchor.constraint(equalTo: item.widthAnchor),
      column.leadingAnchor.constraint(greaterThanOrEqualTo: item.leadingAnchor),
      column.trailingAnchor.constraint(lessThanOrEqualTo: item.trailingAnchor),
    ])
    item.accessibilityLabel = person.name
    item.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return item
  }
  private func contentShareLink(action: @escaping () -> Void) -> UIView {
    let item = UIButton(type: .custom)
    let circle = UIView()
    circle.isUserInteractionEnabled = false
    circle.backgroundColor = UIColor.white.withAlphaComponent(0.92)
    circle.layer.cornerRadius = 28
    circle.layer.borderWidth = 1.5
    circle.layer.borderColor = BibiPalette.selection.cgColor
    let icon = UIImageView(image: BibiIcon.share.image(size: 26))
    icon.contentMode = .scaleAspectFit
    icon.translatesAutoresizingMaskIntoConstraints = false
    circle.addSubview(icon)
    circle.translatesAutoresizingMaskIntoConstraints = false
    let caption = label("Share link", 12)
    caption.textAlignment = .center
    caption.isAccessibilityElement = false
    let column = stack([circle, caption], spacing: 6)
    column.alignment = .center
    column.isUserInteractionEnabled = false
    item.addSubview(column)
    column.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      item.widthAnchor.constraint(equalToConstant: 76),
      circle.widthAnchor.constraint(equalToConstant: 56),
      circle.heightAnchor.constraint(equalToConstant: 56),
      icon.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 26),
      icon.heightAnchor.constraint(equalToConstant: 26),
      column.topAnchor.constraint(equalTo: item.topAnchor),
      column.bottomAnchor.constraint(equalTo: item.bottomAnchor),
      column.centerXAnchor.constraint(equalTo: item.centerXAnchor),
      column.widthAnchor.constraint(equalTo: item.widthAnchor),
    ])
    item.accessibilityLabel = "Share link"
    item.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return item
  }
  func share(_ text: String, completion: ((Bool) -> Void)? = nil) {
    let copy = actionButton("Copy", icon: .share, primary: true) { [weak self] in
      UIPasteboard.general.string = text
      self?.dismissCard {
        completion?(true)
        self?.message("Copied.")
      }
    }
    let close = actionButton("Close") { [weak self] in self?.dismissCard() }
    showCard([
      label("Share", 22, title: true), label(text, 16, BibiPalette.muted), copy, close,
    ])
    cardDismiss = { completion?(false) }
  }
  func choice(
    _ title: String, message: String, accept: String, decline: String,
    onAccept: @escaping () -> Void
  ) {
    let yes = actionButton(accept, primary: true) { [weak self] in
      self?.dismissCard { onAccept() }
    }
    let no = actionButton(decline, tone: .danger) { [weak self] in self?.dismissCard() }
    showCard([label(title, 22, title: true), label(message, 15, BibiPalette.muted), yes, no])
  }
  /// Bottom sheet on the window so it sits above the tab dock. The fill is the studio background.
  func showBottomPanel(_ body: UIView) {
    dismissCard()
    let host: UIView = view.window ?? view
    let dim = UIControl(frame: host.bounds)
    dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    dim.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    dim.alpha = 0
    dim.addAction(UIAction { [weak self] _ in self?.dismissCard() }, for: .touchUpInside)
    let panel = UIView()
    panel.backgroundColor = BibiPalette.background
    panel.layer.cornerRadius = 28
    panel.layer.cornerCurve = .continuous
    panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    panel.clipsToBounds = true
    panel.translatesAutoresizingMaskIntoConstraints = false
    let canvas = StarlightCanvas()
    canvas.translatesAutoresizingMaskIntoConstraints = false
    panel.addSubview(canvas)
    body.translatesAutoresizingMaskIntoConstraints = false
    panel.addSubview(body)
    dim.addSubview(panel)
    host.addSubview(dim)
    NSLayoutConstraint.activate([
      canvas.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
      canvas.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
      canvas.topAnchor.constraint(equalTo: panel.topAnchor),
      canvas.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
      panel.leadingAnchor.constraint(equalTo: dim.leadingAnchor),
      panel.trailingAnchor.constraint(equalTo: dim.trailingAnchor),
      panel.bottomAnchor.constraint(equalTo: dim.bottomAnchor),
      body.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18),
      body.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
      body.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
      body.bottomAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.bottomAnchor, constant: -12),
    ])
    cardLayer = dim
    panel.transform = CGAffineTransform(translationX: 0, y: 48)
    UIView.animate(
      withDuration: 0.34, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0.4
    ) {
      dim.alpha = 1
      panel.transform = .identity
    }
  }
  func showCard(_ lines: [UIView]) {
    dismissCard()
    let dim = UIControl(frame: view.bounds)
    dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    dim.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    dim.alpha = 0
    dim.addAction(UIAction { [weak self] _ in self?.dismissCard() }, for: .touchUpInside)
    let card = UIView()
    card.backgroundColor = BibiPalette.background
    card.layer.cornerRadius = 24
    card.clipsToBounds = true
    card.translatesAutoresizingMaskIntoConstraints = false
    let column = stack(lines, spacing: 14)
    column.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(column)
    dim.addSubview(card)
    view.addSubview(dim)
    NSLayoutConstraint.activate([
      card.centerXAnchor.constraint(equalTo: dim.centerXAnchor),
      card.centerYAnchor.constraint(equalTo: dim.centerYAnchor),
      card.widthAnchor.constraint(equalToConstant: 320),
      column.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
      column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
      column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
      column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
    ])
    cardLayer = dim
    card.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
    UIView.animate(
      withDuration: 0.34, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4
    ) {
      dim.alpha = 1
      card.transform = .identity
    }
  }
  func dismissCard(then: (() -> Void)? = nil) {
    let fallback = cardDismiss
    cardDismiss = nil
    guard let dim = cardLayer else {
      (then ?? fallback)?()
      return
    }
    cardLayer = nil
    let finish = {
      dim.removeFromSuperview()
      (then ?? fallback)?()
    }
    if UIAccessibility.isReduceMotionEnabled {
      finish()
      return
    }
    UIView.animate(withDuration: 0.18, animations: { dim.alpha = 0 }) { _ in finish() }
  }
  func save(_ operation: @escaping () async -> Bool) {
    Task {
      if !(await operation()) {
        message(store.lastSaveError ?? "Your changes could not be saved. Please try again.")
      }
    }
  }
}

@MainActor class StackScreen: BibiScreen {
  let scroll = UIScrollView()
  let content = UIStackView()
  private var scrollBottomConstraint: NSLayoutConstraint?
  private var listFollowsScreenBottom = false
  override func build() {
    content.axis = .vertical
    content.spacing = 18
    scroll.keyboardDismissMode = .interactive
    // This scroll view is already constrained to safe-area / keyboard guides.
    // Do not apply the navigation and dock insets a second time.
    scroll.contentInsetAdjustmentBehavior = .never
    scroll.automaticallyAdjustsScrollIndicatorInsets = false
    scroll.backgroundColor = .clear
    content.backgroundColor = .clear
    view.addSubview(scroll)
    scroll.translatesAutoresizingMaskIntoConstraints = false
    let bottom = scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
    scrollBottomConstraint = bottom
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      bottom,
    ])
    scroll.addSubview(content)
    content.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
      content.bottomAnchor.constraint(
        equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
      content.leadingAnchor.constraint(
        equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
      content.trailingAnchor.constraint(
        equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
      content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
    ])
    NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification).receive(
      on: DispatchQueue.main
    ).sink { [weak self] _ in
      guard let self, let active = self.view.firstResponderView else { return }
      self.scroll.scrollRectToVisible(
        active.convert(active.bounds, to: self.scroll).insetBy(dx: 0, dy: -18), animated: true)
    }.store(in: &tokens)
  }
  /// Lets this list reach the screen bottom, under the tab dock. The keyboard still lifts it.
  func pinListUnderDock() {
    if #available(iOS 17.0, *) {
      view.keyboardLayoutGuide.usesBottomSafeArea = false
      return
    }
    guard !listFollowsScreenBottom else { return }
    listFollowsScreenBottom = true
    scrollBottomConstraint?.isActive = false
    let bottom = scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    bottom.isActive = true
    scrollBottomConstraint = bottom
    NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] note in self?.liftListForKeyboard(note) }
      .store(in: &tokens)
  }
  private func liftListForKeyboard(_ note: Notification) {
    guard listFollowsScreenBottom, let bottom = scrollBottomConstraint, view.window != nil else {
      return
    }
    let info = note.userInfo
    let raw = (info?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
    let end = view.convert(raw, from: nil)
    let overlap = min(view.bounds.height, max(0, view.bounds.maxY - end.minY))
    let duration =
      (info?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
    let curve = (info?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 0
    let options = UIView.AnimationOptions(rawValue: curve << 16).union(.beginFromCurrentState)
    bottom.constant = -overlap
    UIView.animate(withDuration: duration, delay: 0, options: options) {
      self.view.layoutIfNeeded()
    }
  }
  func clear() { content.arrangedSubviews.forEach { $0.removeFromSuperview() } }
  @discardableResult
  func heading(_ text: String) -> UILabel {
    let title = label(text, 26, title: true)
    let mark = UIView()
    mark.backgroundColor = BibiPalette.selection
    mark.layer.cornerRadius = 2
    mark.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      mark.widthAnchor.constraint(equalToConstant: 28),
      mark.heightAnchor.constraint(equalToConstant: 4),
    ])
    let column = stack([title, mark], spacing: 6)
    column.alignment = .leading
    content.addArrangedSubview(column)
    return title
  }
}
extension UIView {
  var firstResponderView: UIView? {
    if isFirstResponder { return self }
    return subviews.lazy.compactMap { $0.firstResponderView }.first
  }
}
private final class StudioPopGesture: NSObject, UIGestureRecognizerDelegate {
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let nav = gestureRecognizer.view?.next as? UINavigationController else { return false }
    return nav.viewControllers.count > 1
  }
}

@MainActor enum BibiNavigation {
  private static let pop = StudioPopGesture()
  static func style(_ nav: UINavigationController) {
    let a = UINavigationBarAppearance()
    a.configureWithTransparentBackground()
    a.backgroundColor = .clear
    a.backgroundEffect = nil
    a.shadowColor = .clear
    a.titleTextAttributes = [
      .font: BibiPalette.font(19, title: true), .foregroundColor: BibiPalette.ink,
    ]
    a.setBackIndicatorImage(BibiIcon.back.image(), transitionMaskImage: BibiIcon.back.image())
    nav.navigationBar.standardAppearance = a
    nav.navigationBar.scrollEdgeAppearance = a
    nav.navigationBar.compactAppearance = a
    nav.navigationBar.compactScrollEdgeAppearance = a
    nav.navigationBar.isTranslucent = true
    nav.navigationBar.tintColor = BibiPalette.accent
    nav.navigationBar.prefersLargeTitles = false
    nav.view.backgroundColor = .clear
    nav.view.clipsToBounds = false
    nav.interactivePopGestureRecognizer?.delegate = pop
    nav.interactivePopGestureRecognizer?.isEnabled = true
  }
}

/// Title inside a mode track. A label keeps the system button chrome off the word.
private final class TrackTitle: UIControl {
  let caption = UILabel()
  init(_ title: String) {
    super.init(frame: .zero)
    caption.text = title
    caption.font = BibiPalette.font(13)
    caption.textAlignment = .center
    caption.adjustsFontSizeToFitWidth = true
    caption.minimumScaleFactor = 0.6
    caption.lineBreakMode = .byClipping
    caption.isUserInteractionEnabled = false
    addSubview(caption)
    caption.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      caption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      caption.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      caption.topAnchor.constraint(equalTo: topAnchor),
      caption.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    isAccessibilityElement = true
    accessibilityLabel = title
    accessibilityTraits = .button
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

/// Transparent selection bubble. A drag follows the finger, then the bubble springs into place.
final class BubbleTrack: UIView, UIGestureRecognizerDelegate {
  private let bubble = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
  private let wash = UIView()
  private let row = UIStackView()
  private let barHeight: CGFloat
  private(set) var index: Int
  var onSelect: ((Int) -> Void)?
  private var tracking = false
  private var settling = false
  private var onDark = false
  private let preferredWidth: CGFloat?

  init(titles: [String], index: Int = 0, barHeight: CGFloat = 40, lockedWidth: CGFloat? = nil) {
    self.index = index
    self.barHeight = barHeight
    self.preferredWidth = lockedWidth
    super.init(frame: CGRect(x: 0, y: 0, width: lockedWidth ?? 240, height: barHeight))
    backgroundColor = UIColor.white.withAlphaComponent(0.12)
    layer.borderWidth = 1
    layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
    clipsToBounds = true
    bubble.isUserInteractionEnabled = false
    bubble.clipsToBounds = true
    bubble.layer.borderWidth = 1
    bubble.layer.borderColor = UIColor.white.withAlphaComponent(0.75).cgColor
    wash.backgroundColor = BibiPalette.selection.withAlphaComponent(0.36)
    wash.isUserInteractionEnabled = false
    wash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    bubble.contentView.addSubview(wash)
    addSubview(bubble)
    row.axis = .horizontal
    row.distribution = .fillEqually
    row.frame = bounds
    row.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(row)
    for (i, title) in titles.enumerated() {
      let button = TrackTitle(title)
      button.addAction(
        UIAction { [weak self] _ in self?.select(i, notify: true) }, for: .touchUpInside)
      row.addArrangedSubview(button)
    }
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)
    if lockedWidth != nil {
      setContentHuggingPriority(.required, for: .horizontal)
      setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    let pan = UIPanGestureRecognizer(target: self, action: #selector(slide(_:)))
    pan.delegate = self
    addGestureRecognizer(pan)
    updateStyles()
  }

  func setOnDark(_ value: Bool) {
    onDark = value
    updateStyles()
  }

  override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
    let velocity = pan.velocity(in: self)
    return abs(velocity.x) > abs(velocity.y)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  override var intrinsicContentSize: CGSize {
    CGSize(width: preferredWidth ?? UIView.noIntrinsicMetric, height: barHeight)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil else { return }
    if bounds.width < 1, let preferredWidth {
      frame.size = CGSize(width: preferredWidth, height: barHeight)
    }
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height / 2
    guard !tracking, !settling else {
      fitBubble()
      return
    }
    place(index, animated: false)
  }

  func ensureSelectionVisible() {
    guard bounds.width > 1, bounds.height > 1, !tracking else { return }
    place(index, animated: false)
  }

  func select(_ next: Int, notify: Bool) {
    guard row.arrangedSubviews.indices.contains(next) else { return }
    index = next
    tracking = false
    place(next, animated: true)
    updateStyles()
    if notify { onSelect?(index) }
  }

  private func place(_ next: Int, animated: Bool) {
    let count = row.arrangedSubviews.count
    guard count > 0, row.arrangedSubviews.indices.contains(next), bounds.width > 1,
      bounds.height > 1
    else { return }
    let slot = bounds.width / CGFloat(count)
    let rect = CGRect(x: slot * CGFloat(next), y: 0, width: slot, height: bounds.height)
      .insetBy(dx: 3, dy: 4)
    guard rect.width > 1, rect.height > 1 else { return }
    let updates = {
      self.bubble.transform = .identity
      self.bubble.bounds = CGRect(origin: .zero, size: rect.size)
      self.bubble.center = CGPoint(x: rect.midX, y: rect.midY)
      self.fitBubble()
    }
    if animated, bubble.bounds.width > 1, !UIAccessibility.isReduceMotionEnabled {
      settling = true
      bubble.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
      UIView.animate(
        withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.68, initialSpringVelocity: 0.6,
        animations: updates
      ) { _ in
        self.settling = false
      }
    } else {
      updates()
    }
  }

  private func fitBubble() {
    bubble.layer.cornerRadius = bubble.bounds.height / 2
    wash.frame = bubble.bounds
  }

  private func updateStyles() {
    for (i, view) in row.arrangedSubviews.enumerated() {
      guard let button = view as? TrackTitle else { continue }
      let selected = i == index
      button.caption.textColor =
        selected ? BibiPalette.ink : (onDark ? UIColor.white.withAlphaComponent(0.9) : BibiPalette.muted)
      button.accessibilityTraits = selected ? [.button, .selected] : .button
    }
  }

  @objc private func slide(_ gesture: UIPanGestureRecognizer) {
    let count = row.arrangedSubviews.count
    guard count > 0, bounds.width > 0 else { return }
    let width = bounds.width / CGFloat(count)
    let x = min(bounds.width - width, max(0, gesture.location(in: self).x - width / 2))
    switch gesture.state {
    case .began, .changed:
      tracking = true
      bubble.transform = .identity
      let size = CGSize(width: width - 6, height: bounds.height - 8)
      bubble.bounds = CGRect(origin: .zero, size: size)
      bubble.center = CGPoint(x: x + 3 + size.width / 2, y: bounds.midY)
      bubble.transform = CGAffineTransform(scaleX: 1.04, y: 0.96)
      fitBubble()
    case .ended, .cancelled, .failed:
      tracking = false
      bubble.transform = .identity
      let next = min(count - 1, max(0, Int((x / width).rounded())))
      select(next, notify: true)
    default:
      break
    }
  }
}

