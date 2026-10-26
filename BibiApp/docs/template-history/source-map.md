# Historical source map and reuse order

Paths refer to the unpacked Teto template and do not depend on /Users/apple/Desktop/Teto. Bibi renames and replaces several components; see ../IMPLEMENTATION.md for the current architecture.

| Requirement | First source to inspect |
|---|---|
| Startup, consent UI, four tabs, dock lifecycle | Teto/App/TetoApplication.swift |
| Shared business/persistence operations | Teto/App/AppStore.swift |
| Theme, buttons, sheets, bubble selection, search, sharing, portrait collages | Teto/DesignSystem/TetoUIKit.swift |
| Raster icons and branding | Teto/DesignSystem/TetoIcons.swift |
| Photographic portrait assignment | Teto/DesignSystem/FreshStudioPhotos.swift; Teto/Domain/DancerPortraits.swift |
| Live/Shorts catalog and stable IDs | Teto/Domain/DanceVideoCatalog.swift |
| Recommendations and history | Teto/Domain/VideoRecommendations.swift; Teto/Data/VideoViewingHistory.swift |
| Live discovery and first-second card playback | Teto/Features/Live/VideoDiscoveryController.swift |
| Current rooms, gestures, floating comments, sharing, comment overlays | Teto/Features/Shorts/VideoFeedController.swift |
| Playback | Teto/Platform/Media/LocalVideoPlayback.swift; LiveRoomPlayback.swift; ShortsPlayback.swift |
| Live models and 152 authored English lines | Teto/Features/LiveRoom/LiveRoomModels.swift |
| Legacy LiveRoomStore interface, not the current UIKit comment scheduler | Teto/Features/LiveRoom/LiveRoomStore.swift |
| Counts, likes/comments/replies, shares, Live migration | Teto/Features/Shorts/ShortsInteractionStore.swift |
| Separate interaction persistence | Teto/Data/ShortsInteractionRepository.swift |
| Per-video authored discussion | Teto/Domain/DanceDiscussionContent.swift |
| Creation forms and submission state | Teto/Features/Creation/CreationController.swift; CreationSubmission.swift |
| Voice list/cards/seats/messages/invites/creation | Teto/Features/Parties/PartyControllers.swift |
| Voice rooms, categories, eight member lists | Teto/Features/Parties/PartyModels.swift; PartyDiscoveryStore.swift |
| Voice message script | Teto/Features/Parties/VoiceRoomChatScript.swift |
| Inbox actions, search, friends, groups, scan, conversation | Teto/Features/Chats/ChatControllers.swift |
| Authored history, relationships, persistent models | Teto/Features/Chats/ChatModels.swift |
| Creator identities and local statistics | Teto/Features/Creators/CreatorProfile.swift |
| Me, creator profiles, editing, settings, reports/blocks | Teto/Features/Profile/ProfileControllers.swift |
| Comments, reporting, wallet, gifts/effects | Teto/Features/Community/CommunityControllers.swift |
| Safety targets, reports, blocks | Teto/Features/Safety/ContentSafety.swift |
| Calls and camera lifecycle | Teto/Features/Calls/CallController.swift; CallCameraController.swift; CallCameraSurface.swift |
| Transactions, prices, idempotent credits/deductions | Teto/Features/Wallet/StoreKit1Purchasing.swift; WalletStore.swift; WalletModels.swift |
| Library snapshots and atomic repository | Teto/Domain/LocalLibrary.swift; Teto/Data/LocalLibraryRepository.swift |
| Agreement models/hashes and offline documents | Teto/Features/Authentication/UserAgreement.swift; Agreements/ |
| Metadata, English localization, permissions | project.yml; Teto/Support/Info.plist; Teto.xcodeproj/xcshareddata/xcschemes/teto.xcscheme |

## Implementation order

Instantiate the included template and inspect the full specification rather than rebuilding a smaller MVP. When porting, proceed through entry/design/data, Live list-to-room, Shorts/shared interactions, Voice list-to-room, Chats/relationships, creators/Me, creation/safety, and wallet/agreements/permissions. Establish shared state first instead of separate page-level likes, relationships, or drafts.

## Cross-entry call chains

- Likes: VideoFeedController chooses Live/Shorts → addLiveLike/toggleLike → ShortsInteractionRepository → AppStore/Me/creator notifications.
- Saves: toggleSaved → LocalLibraryRepository → savedVideos and counts(for:).isSaved.
- Messages: creatorID → canonical conversation → openCreatorConversation → ConversationController → canSendChatMessage → atomic sendChatMessage.
- Shares: showContentShare → sendChatMessage or URL copy → successful Shorts count increment → validated sharedVideo opening in ConversationController.
- Creation: CreationController → queueCreation → video/cover import → submissions.awaitingSubmission → Me Pending review.
- Reports: SafetyController → saveContentReport → successful save closes/refreshes → filters hide → removing the report in Settings restores visibility.
- Purchases: WalletController → WalletStore → StoreKit1Purchasing → repository.saveWallet persistence closure → finishTransaction.
- Gifts: GiftsController → WalletStore.send → spend → atomic wallet save → GiftBurst. No network gift service exists.

## Template/source differences

Only the template copy changed: five tabs became four with matching geometry/indices; Phrases controllers, business extensions, creator lists, chat actions, seven videos, and catalog entries were removed; legacy decoding remained; simulator diamond injection was removed; signing/CI account details were excluded. template-changes.patch records primary text differences and the manifest records the complete final file set. Other modules reuse the source snapshot. Existing source-project modifications were preserved.
