import ImageIO
import PhotosUI
import UIKit
import UniformTypeIdentifiers

final class CircleComposerController: StackScreen, PHPickerViewControllerDelegate {
  private let circle: InterestCircle
  private let body = UITextView()
  private let photoPreview = BibiArtwork()
  private let mediaStatus = label("No attachments", 14, BibiPalette.muted)
  private let errorLabel = label("", 14, BibiPalette.dangerInk)
  private var photo: Data?
  private var imageProgress: Progress?
  private var videoID: UUID?
  private var selecting = false
  private var saving = false
  private var submit: BibiButton?
  init(store: AppStore, circle: InterestCircle) {
    self.circle = circle
    super.init(store: store, title: "New post")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func build() {
    super.build()
    heading(circle.title)
    content.addArrangedSubview(
      label("Your story · English, up to 1,000 characters", 14, BibiPalette.muted))
    body.font = BibiPalette.font(17)
    body.adjustsFontForContentSizeCategory = true
    body.textColor = BibiPalette.ink
    body.backgroundColor = .white
    body.rounded(18)
    body.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
    body.height(180)
    body.accessibilityLabel = "Post text"
    content.addArrangedSubview(body)
    photoPreview.height(170)
    photoPreview.rounded(18)
    photoPreview.isHidden = true
    photoPreview.accessibilityLabel = "Selected post photo"
    content.addArrangedSubview(photoPreview)
    content.addArrangedSubview(mediaStatus)
    content.addArrangedSubview(
      actionButton("Choose photo", icon: .photo) { [weak self] in self?.choosePhoto() })
    content.addArrangedSubview(
      actionButton("Attach a short video", icon: .shorts) { [weak self] in
        guard let self, !self.saving, !self.selecting else { return }
        self.push(
          CommunityVideoPickerController(store: self.store, personalOnly: false) {
            [weak self] video in
            self?.videoID = video.id
            self?.updateAttachments()
          })
      })
    content.addArrangedSubview(
      actionButton("Remove attachments", icon: .trash) { [weak self] in
        guard let self, !self.selecting, !self.saving else { return }
        self.photo = nil
        self.videoID = nil
        self.updateAttachments()
      })
    content.addArrangedSubview(
      label(
        "Only attach media you have permission to share. Posts stay on this device until online publishing is available.",
        13, BibiPalette.muted))
    errorLabel.isHidden = true
    content.addArrangedSubview(errorLabel)
    let button = actionButton("Save post", icon: .send, primary: true) { [weak self] in
      self?.savePost()
    }
    submit = button
    content.addArrangedSubview(button)
  }
  private func updateAttachments() {
    photoPreview.image = photo.flatMap { UIImage(data: $0) }
    photoPreview.isHidden = photo == nil
    let videoTitle = videoID.flatMap { store.communityVideo($0)?.title }
    mediaStatus.text =
      ([photo == nil ? nil : "Photo attached", videoTitle.map { "Video: " + $0 }].compactMap { $0 })
      .joined(separator: " · ")
    if mediaStatus.text?.isEmpty != false { mediaStatus.text = "No attachments" }
  }
  private func choosePhoto() {
    guard !selecting, !saving else { return }
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.selectionLimit = 1
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    present(picker, animated: true)
  }
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let provider = results.first?.itemProvider else { return }
    selecting = true
    submit?.isEnabled = false
    mediaStatus.text = "Preparing photo…"
    imageProgress = provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) {
      [weak self] url, _ in
      // Inspect the temporary file before reading pixels; downsample inside its valid callback lifetime.
      var jpeg: Data?
      if let url, let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
        let size = values.fileSize, size > 0, size <= 30 * 1024 * 1024,
        let source = CGImageSourceCreateWithURL(
          url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
        let image = CGImageSourceCreateThumbnailAtIndex(
          source, 0,
          [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1200,
          ] as CFDictionary)
      {
        jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.65)
      }
      let prepared = jpeg
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.imageProgress = nil
        self.selecting = false
        self.submit?.isEnabled = true
        if let prepared, prepared.count <= 1_000_000 {
          self.photo = prepared
          self.errorLabel.isHidden = true
        } else {
          self.errorLabel.text = "This photo could not be prepared. Choose a smaller image."
          self.errorLabel.isHidden = false
        }
        self.updateAttachments()
      }
    }
  }
  private func savePost() {
    guard !saving, !selecting else { return }
    saving = true
    body.isEditable = false
    submit?.isEnabled = false
    let text = body.text ?? ""
    Task {
      let saved = await store.createCirclePost(
        circleID: circle.id, body: text, photo: photo, videoID: videoID)
      saving = false
      body.isEditable = true
      submit?.isEnabled = true
      if saved {
        if navigationController?.topViewController === self {
          navigationController?.popViewController(animated: true)
        }
      } else {
        errorLabel.text =
          store.lastSaveError ?? "Your post could not be saved. Your draft is still here."
        errorLabel.isHidden = false
        UIAccessibility.post(notification: .announcement, argument: errorLabel.text)
      }
    }
  }
  deinit { imageProgress?.cancel() }
}

final class CommunityVideoPickerController: StackScreen {
  private let personalOnly: Bool
  private let onSelect: (LocalVideo) -> Void
  init(store: AppStore, personalOnly: Bool, onSelect: @escaping (LocalVideo) -> Void) {
    self.personalOnly = personalOnly
    self.onSelect = onSelect
    super.init(store: store, title: personalOnly ? "Your short videos" : "Attach video")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    let videos =
      personalOnly
      ? store.eligibleChallengeVideos
      : store.collectionVideos.filter { store.communityVideo($0.id) != nil && $0.duration <= 180 }
    content.addArrangedSubview(
      label(
        personalOnly
          ? "Choose your own video. Selecting another replaces the current entry."
          : "Choose a short video to attach to your post.", 16, BibiPalette.muted))
    if videos.isEmpty {
      content.addArrangedSubview(
        label("No eligible videos yet. Add a short video from the creation screen."))
    }
    for video in videos {
      content.addArrangedSubview(
        actionButton(video.title + " · " + video.durationLabel, icon: .shorts) { [weak self] in
          guard let self else { return }
          guard self.store.communityVideo(video.id) != nil else {
            self.message("This video is no longer available.")
            return
          }
          self.onSelect(video)
          self.navigationController?.popViewController(animated: true)
        })
    }
  }
}
