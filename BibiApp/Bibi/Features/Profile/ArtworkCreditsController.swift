import UIKit

/// Attribution is shipped inside the app, not only in development documentation.
final class ArtworkCreditsController: StackScreen {
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    title = "Artwork & Credits"
    heading("Imagined together.")
    content.addArrangedSubview(label("The Bibi app logo was supplied by the app owner. Its pink character and Hi speech bubble are used in the app icon and entry screens.", 15, BibiPalette.muted))
    content.addArrangedSubview(label("Bibi characters, community illustrations, icons and the welcome artwork were created with OpenAI image generation for this app. All built-in community personas are fictional. They do not represent the credited filmmakers or people shown in reference photos.", 15, BibiPalette.muted))
    heading("Hero")
    content.addArrangedSubview(label("Hero © Blender Foundation. Directed by Daniel Martinez Lara. Licensed CC BY 4.0. Bibi includes selected excerpts, resized and encoded as H.264 with matching frame covers. Original playback speed and audio are preserved. No endorsement is implied.", 15))
    sourceLink("Hero · original film", "https://studio.blender.org/projects/hero/")
    sourceLink("CC BY 4.0", "https://creativecommons.org/licenses/by/4.0/")
    heading("Spring")
    content.addArrangedSubview(label("Spring © Blender Foundation. Directed by Andy Goralczyk. The project's release page specifies CC BY 4.0; the official video host additionally marks the download Attribution–ShareAlike. Bibi distributes its selected excerpts and extracted covers under CC BY-SA 4.0. Excerpts are resized and encoded as H.264; speed and audio are preserved. No endorsement is implied.", 15))
    sourceLink("Spring · original film", "https://studio.blender.org/projects/spring/pages/about/")
    sourceLink("CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0/")
    heading("Circle reference photography")
    content.addArrangedSubview(label("Challenge covers and circle discussions use licensed cosplay photographs from Pexels. The photographs are not uploads by the fictional characters; depicted people do not endorse Bibi.", 15, BibiPalette.muted))
    let photoCredits = CommunityCatalog.storyMedia.merging(CommunityCatalog.challengeMedia) { current, _ in current }
    for asset in photoCredits.keys.sorted() {
      guard let media = photoCredits[asset], media.source.contains("pexels.com") else { continue }
      sourceLink(media.credit, media.source)
    }
    sourceLink("Pexels License", "https://www.pexels.com/license/")
    heading("Profile photography")
    content.addArrangedSubview(label("Some fictional profiles use licensed portrait and cosplay photographs from Pexels. The pictured people are not Bibi users, did not author the displayed stories, and do not endorse this app.", 15, BibiPalette.muted))
    sourceLink("Adriana Hernandez · portrait photograph", "https://www.pexels.com/photo/portrait-of-woman-cosplaying-anime-character-13190257/")
    sourceLink("fauxels · portrait photograph", "https://www.pexels.com/photo/portrait-photo-of-man-wearing-eyeglasses-3228892/")
    sourceLink("Murat IŞIK · portrait photograph", "https://www.pexels.com/photo/candid-portrait-of-a-young-woman-in-urban-setting-31546395/")
    sourceLink("Vika Glitter · portrait photograph", "https://www.pexels.com/photo/a-woman-wearing-a-steampunk-costume-9849182/")
    sourceLink("cottonbro studio · cosplay portrait", "https://www.pexels.com/photo/man-wearing-black-hat-7792284/")
    heading("Cosplay video references")
    content.addArrangedSubview(label("Selected licensed Pexels videos by TBD Tuyen are shortened, resized and presented without audio. The displayed community profiles are fictional curators, not the depicted performers. No endorsement is implied.", 15))
    sourceLink("Lavender costume details · original video", "https://www.pexels.com/video/cosplay-portrait-with-detailed-costume-in-indoor-setting-31038234/")
    sourceLink("Silver and blue costume study · original video", "https://www.pexels.com/video/elegant-woman-in-intricate-cosplay-costume-30794058/")
    heading("Lettering & Fonts")
    content.addArrangedSubview(label("The five illustrated page titles were created with OpenAI image generation for Bibi. Display text uses Kalam Bold by Indian Type Foundry. Reading and controls use Comic Neue by the Comic Neue Project Authors. Both fonts are distributed unchanged under the SIL Open Font License 1.1. Their full licenses are included in the app bundle.", 15))
    sourceLink("Kalam · font & license", "https://github.com/google/fonts/tree/main/ofl/kalam")
    sourceLink("Comic Neue · font & license", "https://github.com/google/fonts/tree/main/ofl/comicneue")
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
