import UIKit

/// Bibi's semantic palette. Product components consume roles rather than brand color names.
enum BibiPalette {
  static let background = color(0xF8F5FF)
  static let ink = color(0x28213F)
  static let accent = color(0x6943BD)
  static let selection = color(0xE4D5FF)
  static let muted = color(0x6C627F)
  static let pink = color(0xE74F92)
  static let cyan = color(0xAEEBF2)
  static let soft = color(0xF0EAFA)
  static let line = color(0xDED3EE)
  static let dangerInk = color(0x912C51)
  static let dangerFill = color(0xFDE2EC)
  static func color(_ hex: UInt32) -> UIColor {
    UIColor(red: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
  }
  static func font(_ size: CGFloat = 16, title: Bool = false) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: title ? .bold : .medium)
    let rounded = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
    return UIFontMetrics(forTextStyle: title ? .title2 : .body)
      .scaledFont(for: UIFont(descriptor: rounded, size: size))
  }
}

/// Decorative full-window aurora; never used to draw interface icons.
final class StarlightCanvas: UIView {
  private let aurora = CAGradientLayer()
  private let glow = CAGradientLayer()
  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    isAccessibilityElement = false
    clipsToBounds = true
    backgroundColor = BibiPalette.background
    aurora.colors = [BibiPalette.color(0xE4D7FF).cgColor,
                     BibiPalette.background.cgColor, BibiPalette.color(0xFCE6F1).cgColor]
    aurora.locations = [0, 0.45, 1]
    aurora.startPoint = CGPoint(x: 0, y: 0)
    aurora.endPoint = CGPoint(x: 1, y: 1)
    glow.type = .radial
    glow.colors = [BibiPalette.cyan.withAlphaComponent(0.45).cgColor,
                   BibiPalette.cyan.withAlphaComponent(0).cgColor]
    glow.startPoint = CGPoint(x: 0.9, y: 0.2)
    glow.endPoint = CGPoint(x: 0, y: 1)
    layer.addSublayer(aurora)
    layer.addSublayer(glow)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func layoutSubviews() {
    super.layoutSubviews()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    aurora.frame = bounds
    glow.frame = bounds
    CATransaction.commit()
  }
}
