import UIKit

final class ShortsHomeController: BibiScreen {
  private var shorts: VideoFeedController?
  private var createButton: UIButton?
  private var searchButton: UIButton?
  override func build() {
    title = "Shorts"
    navigationItem.leftBarButtonItem = barButton(bibiMark())
    let search = iconButton(.search, "Search short videos") { [weak self] in
      self?.shorts?.openSearch(from: self?.searchButton)
    }
    searchButton = search
    let child = VideoFeedController(
      store: store, videos: store.shortsDiscoveryVideos, initial: nil, discovery: true)
    shorts = child
    addChild(child)
    view.addSubview(child.view)
    child.view.pin(to: view)
    child.didMove(toParent: self)
    let create = iconButton(.plus, "Create a short video") { [weak self] in
      guard let self else { return }
      let screen = CreationController(store: self.store)
      if let create = self.createButton {
        self.presentExpanded(from: create, screen)
      } else {
        self.presentScreen(screen)
      }
    }
    createButton = create
    navigationItem.rightBarButtonItems = [barButton(create), barButton(search)]
    child.onCommentChrome = { [weak self] open in
      self?.createButton?.isHidden = open
      self?.tabHost()?.setCommentOverlayActive(open)
    }
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    navigationController?.navigationBar.standardAppearance = appearance
    navigationController?.navigationBar.scrollEdgeAppearance = appearance
    navigationController?.navigationBar.compactAppearance = appearance
  }
  private func tabHost() -> BibiTabController? {
    var node = parent
    while let current = node {
      if let tabs = current as? BibiTabController { return tabs }
      node = current.parent
    }
    return nil
  }
}
