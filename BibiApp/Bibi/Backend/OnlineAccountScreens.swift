import UIKit

final class OnlineInvitationsController: StackScreen {
    override func refresh() {
        guard isViewLoaded, let online = store.online else { return }
        clear()
        let invitations = online.members.filter { $0.user_id == online.services.accountID && $0.status == "invited" }
        if invitations.isEmpty { content.addArrangedSubview(label("No group invitations yet.", 17)) }
        for invitation in invitations {
            guard let room = online.conversations.first(where: { $0.id == invitation.conversation_id }) else { continue }
            content.addArrangedSubview(label(room.title, 20, title: true))
            content.addArrangedSubview(actionButton("Join group", icon: .plus) { [weak self] in
                guard let self else { return }
                self.save { await self.store.remoteMutation("accept_invite", payload: ["target_id": .string(room.id.uuidString)]) }
            })
            content.addArrangedSubview(actionButton("Decline", icon: .close) { [weak self] in
                guard let self else { return }
                self.save { await self.store.remoteMutation("leave", payload: ["target_id": .string(room.id.uuidString)]) }
            })
        }
    }
}

final class OnlineDeletionController: StackScreen {
    private let password = UITextField()
    private var working = false
    override func build() {
        super.build()
        content.addArrangedSubview(label("Delete your online account", 25, title: true))
        let detail = label("This permanently removes your profile, uploaded media and account data. Messages may remain without your profile. Your original photos and the separate device archive are kept. Apple purchase records required for reconciliation are retained. This does not request an Apple refund.", 16)
        detail.numberOfLines = 0; content.addArrangedSubview(detail)
        password.isSecureTextEntry = true; password.textContentType = .password
        password.placeholder = "Confirm your password"; password.borderStyle = .roundedRect
        if store.online?.services.isGuest != true { content.addArrangedSubview(password) }
        content.addArrangedSubview(actionButton("Permanently delete account", icon: .trash) { [weak self] in
            guard let self, !self.working else { return }
            self.confirm("Delete account?", message: "This cannot be undone. If cleanup is interrupted, use Resume account deletion on the sign-in screen.", destructive: true, button: "Delete account") {
                self.working = true
                Task { @MainActor in
                    defer { self.working = false; self.password.text = "" }
                    do { try await self.store.online?.services.deleteAccount(password: self.password.text ?? "") }
                    catch { self.store.notice = AppNotice(title: "Deletion incomplete", message: error.localizedDescription + " Sign in and resume account deletion.") }
                }
            }
        })
    }
    override func refresh() {}
}

/// Reads legacy snapshots directly: repository loading performs migrations and cleanup.
final class LegacyArchiveController: StackScreen {
    private var loaded = false
    override func refresh() {
        guard isViewLoaded, !loaded else { return }; loaded = true
        content.addArrangedSubview(label("Device archive", 26, title: true))
        let note = label("These items are stored only on this iPhone. They are separate from your online account. Nothing is uploaded automatically, and legacy diamonds do not become an online balance.", 16)
        note.numberOfLines = 0; content.addArrangedSubview(note)
        let root = store.storageRoot
        Task { @MainActor in
            do {
                let library: LocalLibrary? = try await Task.detached {
                    let file = root.appendingPathComponent("library-v1.json")
                    guard FileManager.default.fileExists(atPath: file.path) else { return nil }
                    return try JSONDecoder().decode(LocalLibrary.self, from: Data(contentsOf: file))
                }.value
                guard let library else { content.addArrangedSubview(label("No archived library on this iPhone.", 17)); return }
                content.addArrangedSubview(label("Saved profile: " + library.profile.displayName, 18))
                content.addArrangedSubview(label("Archived videos: \(library.videos.count)", 17))
                for video in library.videos {
                    content.addArrangedSubview(actionButton("Import “\(video.title)”", icon: .plus) { [weak self] in
                        guard let self else { return }
                        self.confirm("Upload this archived video?", message: "A separate copy will be uploaded for review. The original archive will be kept.", button: "Upload") {
                            Task { @MainActor in
                                let source = root.appendingPathComponent("Media/\(video.id.uuidString).\(video.fileExtension)")
                                guard ["mp4", "mov", "m4v"].contains(video.fileExtension) else { self.message("This file format is unavailable."); return }
                                let id = await self.store.queueCreation(kind: .shortVideo, title: video.title, caption: "", category: .anime, videoURL: source)
                                self.message(id == nil ? (self.store.lastSaveError ?? "The import could not finish.") : "Uploaded for review. Your archived file is unchanged.")
                            }
                        }
                    })
                }
                for post in library.community?.posts ?? [] {
                    let text = label(post.body, 16); text.numberOfLines = 0; content.addArrangedSubview(text)
                }
                let walletFile = root.appendingPathComponent("wallet-v1.json")
                if let data = try? Data(contentsOf: walletFile), let ledger = try? JSONDecoder().decode(WalletLedger.self, from: data) {
                    content.addArrangedSubview(label("Archived diamond balance: \(ledger.diamonds)", 17))
                }
            } catch { message("The archive could not be read. Its files have been kept.") }
        }
    }
}

final class OnlineGroupController: StackScreen {
    let groupID: UUID
    init(store: AppStore, groupID: UUID) { self.groupID = groupID; super.init(store: store, title: "Group members") }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func refresh() {
        guard isViewLoaded, let online = store.online else { return }; clear()
        guard let room = online.conversations.first(where: { $0.id == groupID }),
              online.members.contains(where: { $0.conversation_id == groupID && $0.user_id == online.services.accountID && $0.status == "active" }) else {
            content.addArrangedSubview(label("You are no longer a member of this group.", 17)); return
        }
        let owner = room.owner_id == online.services.accountID
        let members = online.members.filter { $0.conversation_id == groupID && $0.status != "left" }
        for member in members {
            let person = online.creator(member.user_id)
            content.addArrangedSubview(label(person.name + (member.status == "invited" ? " · Invited" : ""), 18))
            if !person.isLocalOwner {
                content.addArrangedSubview(actionButton("Report or block " + person.name, icon: .flag, compact: true) { [weak self] in
                    self?.presentCommunitySafety(ContentSafetyTarget(
                        id: person.id, title: person.name, kind: .profile, creator: person))
                })
            }
            if owner, member.user_id != online.services.accountID {
                content.addArrangedSubview(actionButton("Remove " + person.name, icon: .trash) { [weak self] in
                    guard let self else { return }
                    self.save { await self.store.remoteMutation("remove_member", payload: ["target_id": .string(self.groupID.uuidString), "user_id": .string(member.user_id.uuidString)]) }
                })
            }
        }
        if owner {
            for person in store.chatDirectory where person.creator.map({ store.isMutualProfile($0) }) == true
                && !members.contains(where: { $0.user_id.uuidString == person.creator?.id }) {
                content.addArrangedSubview(actionButton("Invite " + person.name, icon: .plus) { [weak self] in
                    guard let self, let id = person.creator?.id else { return }
                    self.save { await self.store.remoteMutation("invite", payload: ["target_id": .string(self.groupID.uuidString), "user_id": .string(id)]) }
                })
            }
        }
        content.addArrangedSubview(actionButton("Leave group", icon: .logout) { [weak self] in
            guard let self else { return }
            self.confirm("Leave group?", message: "You will lose access to this conversation. A new invitation is required to return.", destructive: true, button: "Leave") {
                self.save { await self.store.remoteMutation("leave", payload: ["target_id": .string(self.groupID.uuidString)]) }
            }
        })
    }
}
