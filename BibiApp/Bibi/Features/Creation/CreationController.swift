import PhotosUI
import UIKit
import UniformTypeIdentifiers

final class CreationController: StackScreen, PHPickerViewControllerDelegate {
  private let challengeID: String?
  private let name = field("Title"), caption = field("Tell us about your story")
  private let mediaLabel = label("", 14, BibiPalette.muted)
  private let category = StudioChoice(items: VideoCategory.allCases.map(\.title))
  private let consent = StudioSwitch()
  private var temporaryVideo: URL?
  private var selecting = false
  private var submitting = false
  init(store: AppStore, challengeID: String? = nil) {
    self.challengeID = challengeID
    super.init(
      store: store, title: challengeID == nil ? "Create a short video" : "New challenge entry")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func build() {
    super.build()
    content.addArrangedSubview(
      label(
        "Every frame has a story.", 27, title: true))
    content.addArrangedSubview(label("Title · Up to 80 characters", 14, BibiPalette.muted))
    content.addArrangedSubview(name)
    content.addArrangedSubview(label("Caption · Up to 500 characters", 14, BibiPalette.muted))
    content.addArrangedSubview(caption)
    content.addArrangedSubview(category)
    content.addArrangedSubview(
      actionButton("Cover style", icon: .sparkle) { [weak self] in
        guard let self else { return }
        self.push(CosmeticPickerController(store: self.store, kinds: [.coverTemplate]))
      })
    content.addArrangedSubview(
      actionButton(
        "Choose an anime video", icon: .shorts
      ) { [weak self] in self?.chooseMedia() })
    content.addArrangedSubview(mediaLabel)
    content.addArrangedSubview(
      label(
        store.isOnline ? "Anime videos up to 3 minutes. Uploads are compressed below 50 MB and submitted for review." : "Anime videos up to 3 minutes and 250 MB. Uploads are saved on this device; online publishing is not connected.",
        13, BibiPalette.muted))
    if challengeID != nil {
      content.addArrangedSubview(
        label(
          "A new entry uses \(CosmeticCatalog.challengeEntryDiamonds.formatted()) diamonds. Replacing an entry you already joined stays free.",
          13, BibiPalette.muted))
    }
    let row = stack(
      [label("This is anime-related content and I have permission to share it.", 14), consent],
      axis: .horizontal)
    row.alignment = .center
    consent.accessibilityLabel = "This is anime-related content and I have permission to share it."
    content.addArrangedSubview(row)
    content.addArrangedSubview(
      actionButton(
        challengeID == nil ? "Save upload" : "Save challenge entry", icon: .send, primary: true
      ) { [weak self] in
        self?.submitContent()
      })
    mediaLabel.text =
      "Choose your video to continue."
  }
  private func chooseMedia() {
    guard !selecting, !submitting, !store.isBusy else { return }
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .videos
    configuration.selectionLimit = 1
    configuration.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    present(picker, animated: true)
  }
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let provider = results.first?.itemProvider else { return }
    selecting = true
    mediaLabel.text = "Opening media…"
    provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) {
      [weak self] url, error in
      var destination: URL?
      var failure: String?
      do {
        guard let url else { throw LocalLibraryError.importFailed }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 250 * 1024 * 1024 else { throw LocalLibraryError.videoTooLarge }
        let target = FileManager.default.temporaryDirectory.appendingPathComponent(
          "bibi-upload-" + UUID().uuidString
        ).appendingPathExtension(url.pathExtension)
        try FileManager.default.copyItem(at: url, to: target)
        destination = target
      } catch {
        failure =
          (error as? LocalLibraryError)?.errorDescription
          ?? "This video could not be opened. Please choose another video."
      }
      Task { @MainActor in
        guard let self else {
          if let destination { try? FileManager.default.removeItem(at: destination) }
          return
        }
        self.selecting = false
        if let destination {
          if let old = self.temporaryVideo { try? FileManager.default.removeItem(at: old) }
          self.temporaryVideo = destination
          self.mediaLabel.text = "Video selected"
        } else {
          self.mediaLabel.text = failure ?? "This video could not be opened."
        }
      }
    }
  }
  private func submitContent() {
    guard !submitting else { return }
    guard consent.isOn else {
      message("Please confirm this is anime-related content that you have permission to share.")
      return
    }
    guard CreationValidation.valid(title: name.text ?? "", caption: caption.text ?? "") else {
      message(
        "Write a title up to 80 characters and a description up to 500 characters in English.")
      return
    }
    guard !selecting, !store.isBusy, temporaryVideo != nil else {
      message("Choose an anime video first.")
      return
    }
    submitting = true
    isModalInPresentation = true
    Task {
      let id = await store.queueCreation(
        kind: .shortVideo, title: name.text ?? "", caption: caption.text ?? "",
        category: VideoCategory.allCases[max(0, category.index)],
        videoURL: temporaryVideo, challengeID: challengeID)
      submitting = false
      isModalInPresentation = false
      if id != nil {
        dismissCollapsed()
      } else {
        message(store.lastSaveError ?? "Your content could not be saved. Please try again.")
      }
    }
  }
  deinit { if let temporaryVideo { try? FileManager.default.removeItem(at: temporaryVideo) } }
}
