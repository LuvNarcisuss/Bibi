import UIKit

/// Editorial art is separate from controls, so native text remains accessible and scalable.
final class ConstellationBanner: UIView {
  init(eyebrow: String, title: String, subtitle: String, artwork: String) {
    super.init(frame: .zero)
    backgroundColor = BibiPalette.color(0x302248)
    layer.cornerRadius = 26
    layer.cornerCurve = .continuous
    clipsToBounds = true
    let art = UIImageView(image: UIImage(named: artwork))
    art.contentMode = .scaleAspectFill
    art.isAccessibilityElement = false
    art.alpha = 0.48
    // Decorative image dimensions must not expand the text-sized banner.
    art.frame = bounds
    art.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(art)
    let category = label(eyebrow.uppercased(), 11, BibiPalette.cyan)
    let heading = label(title, 27, .white, title: true)
    heading.accessibilityTraits = .header
    let detail = label(subtitle, 13, .white)
    let copy = stack([category, heading, detail], spacing: 7)
    addSubview(copy)
    copy.pin(to: self, insets: UIEdgeInsets(top: 22, left: 22, bottom: 22, right: 22))
    heightAnchor.constraint(greaterThanOrEqualToConstant: 176).isActive = true
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

/// A compact reading cue; chips do not pretend to be interactive filters.
@MainActor func topicRibbon(_ topics: [String]) -> UIView {
  let scroll = UIScrollView()
  scroll.showsHorizontalScrollIndicator = false
  let row = stack(axis: .horizontal, spacing: 8)
  for topic in topics {
    let text = label("  " + topic + "  ", 12, BibiPalette.accent)
    text.backgroundColor = .white.withAlphaComponent(0.85)
    text.rounded(12)
    text.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
    row.addArrangedSubview(text)
  }
  scroll.addSubview(row)
  row.translatesAutoresizingMaskIntoConstraints = false
  NSLayoutConstraint.activate([
    row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
    row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
    row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
    row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
    row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
  ])
  scroll.heightAnchor.constraint(equalToConstant: max(30, BibiPalette.font(12).lineHeight + 14)).isActive = true
  return scroll
}
