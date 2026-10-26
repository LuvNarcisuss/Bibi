import UIKit

@MainActor final class VideoTile: UIControl {
  private let cover = BibiArtwork()
  private let caption = label("", 15, .white)
  var onTap: (() -> Void)?
  var onAvatar: (() -> Void)? {
    didSet {
      accessibilityCustomActions =
        onAvatar == nil
        ? nil
        : [
          UIAccessibilityCustomAction(name: "Open creator profile") { [weak self] _ in
            self?.onAvatar?()
            return true
          }
        ]
    }
  }
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
  func configure(_ video: LocalVideo, store: AppStore, showDuration: Bool) {
    cover.load(store.coverURL(video))
    caption.text = video.title + (showDuration ? "\n" + video.durationLabel : "")
    accessibilityLabel = video.title + ", " + video.creatorName(profile: store.library.profile)
  }
  func configureStatic(_ video: LocalVideo, store: AppStore) {
    configure(video, store: store, showDuration: true)
    onTap = nil
  }
}

extension StackScreen {
  @discardableResult
  func videoGrid(
    _ videos: [LocalVideo], duration: Bool = true,
    onCreator: ((LocalVideo) -> Void)? = nil,
    onSelect: @escaping (LocalVideo) -> Void
  ) -> [VideoTile] {
    guard !videos.isEmpty else {
      content.addArrangedSubview(
        label("Your next favorite story is waiting.", 17, BibiPalette.muted))
      return []
    }
    var tiles: [VideoTile] = []
    let columns = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 1 : 2
    let spacing: CGFloat = 14
    for start in stride(from: 0, to: videos.count, by: columns) {
      let row = stack(axis: .horizontal, spacing: spacing)
      row.distribution = .fillEqually
      row.alignment = .fill
      row.setContentCompressionResistancePriority(.required, for: .vertical)
      row.setContentHuggingPriority(.required, for: .vertical)
      for video in videos[start..<min(start + columns, videos.count)] {
        let tile = VideoTile()
        tile.configure(video, store: store, showDuration: duration)
        tile.onTap = { onSelect(video) }
        if let onCreator {
          tile.onAvatar = { onCreator(video) }
        }
        row.addArrangedSubview(tile)
        tiles.append(tile)
      }
      if row.arrangedSubviews.count < columns { row.addArrangedSubview(UIView()) }
      content.addArrangedSubview(row)
      // Height follows the row width. A tile aspect constraint can lose to the stack and drop a row.
      let height = row.heightAnchor.constraint(
        equalTo: content.widthAnchor,
        multiplier: 1.38 / CGFloat(columns),
        constant: -(spacing * 1.38 * CGFloat(columns - 1) / CGFloat(columns)))
      height.priority = .required
      height.isActive = true
    }
    return tiles
  }
}
