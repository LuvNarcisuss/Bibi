import UIKit

/// Shared search overlay for Shorts and Chats.
final class ExpandingSearchBar: UIView {
  var onChange: ((String) -> Void)?
  var onClose: (() -> Void)?
  private let blur = UIVisualEffectView(effect: nil)
  private let dim = UIView()
  private let capsule = UIView()
  private let field = UITextField()
  private let closeButton = UIButton(type: .custom)
  private var startFrame: CGRect = .zero
  private var dark = false
  private var placed = false
  private var closing = false
  private var filtering = false

  func present(from source: UIView, in host: UIView, placeholder: String, dark: Bool) {
    self.dark = dark
    frame = host.bounds
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    backgroundColor = .clear
    blur.isUserInteractionEnabled = false
    dim.isUserInteractionEnabled = false
    dim.backgroundColor = (dark ? UIColor.black : UIColor.white).withAlphaComponent(dark ? 0.28 : 0.22)
    dim.alpha = 0
    addSubview(blur)
    addSubview(dim)
    capsule.backgroundColor = UIColor.white.withAlphaComponent(0.96)
    capsule.clipsToBounds = true
    addSubview(capsule)
    field.placeholder = placeholder
    field.font = BibiPalette.font(16)
    field.textColor = BibiPalette.ink
    field.tintColor = BibiPalette.accent
    field.autocorrectionType = .no
    field.autocapitalizationType = .none
    field.returnKeyType = .search
    field.accessibilityLabel = placeholder
    field.alpha = 0
    field.addAction(
      UIAction { [weak self] _ in self?.onChange?(self?.field.text ?? "") }, for: .editingChanged)
    closeButton.setImage(BibiIcon.close.image(size: 18), for: .normal)
    closeButton.accessibilityLabel = "Close search"
    closeButton.alpha = 0
    closeButton.addAction(UIAction { [weak self] _ in self?.dismiss() }, for: .touchUpInside)
    soften(closeButton)
    capsule.addSubview(field)
    capsule.addSubview(closeButton)
    host.addSubview(self)
    startFrame = source.convert(source.bounds, to: host)
    if startFrame.width < 8 {
      startFrame = CGRect(x: host.bounds.width - 56, y: host.safeAreaInsets.top + 8, width: 44, height: 44)
    }
    capsule.frame = startFrame
    capsule.layer.cornerRadius = min(startFrame.width, startFrame.height) / 2
    blur.frame = bounds
    dim.frame = bounds
    let changes = {
      self.placeBar()
      self.blur.effect = UIBlurEffect(
        style: dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
      self.dim.alpha = 1
      self.field.alpha = 1
      self.closeButton.alpha = 1
    }
    if UIAccessibility.isReduceMotionEnabled {
      changes()
      placed = true
    } else {
      UIView.animate(
        withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0.35,
        options: [.allowUserInteraction]
      ) {
        changes()
      } completion: { _ in
        self.placed = true
      }
    }
    field.becomeFirstResponder()
  }

  func setFiltering(_ active: Bool) {
    filtering = active
    let style: UIBlurEffect.Style = dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight
    UIView.animate(withDuration: 0.25) {
      self.blur.effect = active ? nil : UIBlurEffect(style: style)
      self.dim.alpha = active ? 0.08 : 1
    }
  }

  func dismiss(animated: Bool = true) {
    guard !closing else { return }
    closing = true
    field.resignFirstResponder()
    placed = false
    let finish = { [weak self] in
      guard let self else { return }
      self.removeFromSuperview()
      self.onClose?()
    }
    if !animated || UIAccessibility.isReduceMotionEnabled {
      finish()
      return
    }
    UIView.animate(withDuration: 0.32, delay: 0, options: [.curveEaseInOut]) {
      self.capsule.frame = self.startFrame
      self.capsule.layer.cornerRadius = min(self.startFrame.width, self.startFrame.height) / 2
      self.field.alpha = 0
      self.closeButton.alpha = 0
      self.blur.effect = nil
      self.dim.alpha = 0
    } completion: { _ in
      finish()
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    blur.frame = bounds
    dim.frame = bounds
    if placed { placeBar() }
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hit = super.hitTest(point, with: event)
    if hit === self || hit === blur || hit === dim { return filtering ? nil : self }
    return hit
  }

  private func placeBar() {
    let top = (superview?.safeAreaInsets.top ?? safeAreaInsets.top) + 8
    capsule.frame = CGRect(x: 12, y: top, width: max(0, bounds.width - 24), height: 52)
    capsule.layer.cornerRadius = 26
    let height = capsule.bounds.height
    closeButton.frame = CGRect(x: capsule.bounds.width - height, y: 0, width: height, height: height)
    field.frame = CGRect(x: 18, y: 0, width: max(0, capsule.bounds.width - height - 12), height: height)
  }
}
