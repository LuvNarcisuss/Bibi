import UIKit

/// Attribution is shipped inside the app, not only in development documentation.
final class ArtworkCreditsController: StackScreen {
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    title = "Artwork & Credits"
    heading("Imagined together.")
    content.addArrangedSubview(label("Bibi characters, community illustrations, icons and the welcome artwork were created with OpenAI image generation for this app. All illustrated community personas are fictional. They do not represent the credited filmmakers.", 15, BibiPalette.muted))
    heading("Hero")
    content.addArrangedSubview(label("Hero © Blender Foundation. Directed by Daniel Martinez Lara. Licensed CC BY 4.0. Bibi includes selected excerpts, resized and encoded as H.264 with matching frame covers. Original playback speed and audio are preserved. No endorsement is implied.", 15))
    sourceLink("Hero · original film", "https://studio.blender.org/projects/hero/")
    sourceLink("CC BY 4.0", "https://creativecommons.org/licenses/by/4.0/")
    heading("Spring")
    content.addArrangedSubview(label("Spring © Blender Foundation. Directed by Andy Goralczyk. The project's release page specifies CC BY 4.0; the official video host additionally marks the download Attribution–ShareAlike. Bibi distributes its selected excerpts and extracted covers under CC BY-SA 4.0. Excerpts are resized and encoded as H.264; speed and audio are preserved. No endorsement is implied.", 15))
    sourceLink("Spring · original film", "https://studio.blender.org/projects/spring/pages/about/")
    sourceLink("CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0/")
    heading("On this device")
    content.addArrangedSubview(label("Shorts play local videos. Circle posts, replies and challenge entries are saved on this device. Chats and uploads remain pending. A video call shows your own camera. Online publishing, messaging delivery and challenge judging are not connected.", 15, BibiPalette.muted))
  }
  private func sourceLink(_ title: String, _ address: String) {
    content.addArrangedSubview(actionButton(title, icon: .share) {
      guard let url = URL(string: address) else { return }
      UIApplication.shared.open(url)
    })
  }
}
