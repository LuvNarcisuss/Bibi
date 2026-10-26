# Bibi implementation record

Paths to application source, configuration, scripts and `Design/` evidence in this report are relative to `BibiApp/` unless explicitly prefixed. `docs/` and `Assets/` refer to repository-root directories.

Date: 2026-10-26 (Asia/Shanghai).

The owner authorized removing Live and Voice rooms and adding Circles and Challenges. The native UIKit application now has five roots: Shorts, Circles, Challenges, Chats and Me. The existing signing configuration is preserved in project.yml and the generated Xcode project.

## Current feature paths

| Area | Source path | Capability boundary |
|---|---|---|
| Navigation | BibiTabController → five independent navigation stacks | Dock geometry derives from page count |
| Shorts | ShortsHomeController → VideoFeedController | Local media, search, social state and outbox creation |
| Circles | CirclesController → CircleDetailController → CirclePostController / CircleComposerController | Four editorial themes; local join, post, photo, attachment, reply, save and delete |
| Challenges | ChallengesController → ChallengeDetailController → video picker / CreationController | Four evergreen briefs; one replaceable local entry per challenge |
| Personal activity | Me → joined circles / saved posts / ChallengeEntriesController | Reads the same shared state |
| Chats | Conversation → relationship checks → atomic outbox | No delivered receipts; only Shorts shared links open |
| Creation | Form → permission declaration → media import → atomic submission and optional challenge entry | No automatic public release or review approval |
| Safety | Circle/video/comment report or creator block → persist → hide; Settings reversal | No server moderation submission |
| Wallet | StoreKit request/callback → idempotent ledger → finish after save | Local StoreKit Test purchases verified; App Store catalog and real-device sandbox unverified |
| Calls | Voice controls; local camera with permission/flip/lifecycle | No peer connection or microphone recording |
| Account | Consent, logout preserves, local account deletion removes storage root | No external account deletion |

## Diamond gifts on existing content

Circle discussions now open the existing gift picker. Shorts remains free and has no gift entry. No new root, store, currency, subscription, or decoration system is introduced. The nine existing gifts and 1/5/10 quantities remain available. Owned posts do not offer gifting; unavailable or moderated content is rechecked before spending.

The current deliverable is a local gift effect and durable activity record for the selected content, not a transfer to a creator. Both the picker and its cost confirmation disclose this boundary. Basic messages, posts and challenge entries remain free. Chats have no gift-delivery service, and challenge entries remain local, so neither receives a paid delivery control.

The wallet stores content kind, stable content ID, creator ID, title, gift ID and quantity with the debit in the same atomic wallet file. New fields are optional for older ledger compatibility. Gift debits share the StoreKit transaction queue with credits, and the wallet/picker reject overlapping user requests. Insufficient funds, cancellation, unavailable content and failed persistence do not publish a debit or play the gift animation. Account exit waits for wallet work already in progress.

## Typography and illustrated navigation

The typography revision bundles unmodified Fredoka and Nunito variable fonts with their SIL Open Font License texts. BibiPalette selects Fredoka at weight 600 for display text and Nunito at weight 500 for reading and controls, retaining UIFontMetrics scaling. UIAppFonts and the Xcode Resources phase register and ship both fonts. project.yml explicitly includes the font files from the repository-root Assets directory.

StudioTitle displays original generated transparent wordmarks for Shorts, Circles, Challenges, Chats and Me. Each title retains its English VoiceOver header name and aspect ratio. Secondary titles remain live Fredoka text. The flat Assets directory contains the typography- prefixed originals, manifest and exact prompts. The owner subsequently authorized a build and XCTest UI automation. Four tests passed on the Bibi QA iPhone 17 Pro simulator: runtime font families/weights, original title artwork and five-page navigation at default and larger text sizes. Ten original screenshots were visually reviewed without a title rendering defect. See TYPOGRAPHY-RUN-VERIFICATION.md for evidence and limits.

## Storage and ownership

CommunityState is optional in LocalLibrary, so older snapshots remain decodable. Mutations use AppStore.commit and the existing atomic, file-protected snapshot repository. A failed write never adopts the proposed state. The UI preserves post and reply text on failure. No separate community directory can escape account deletion.

Circle photos are downsampled to 1,200 pixels, encoded as JPEG and limited to 1 MB. A local library supports up to 100 authored posts and 2,000 replies. Only the local owner can remove authored posts/replies. Seed prompts are explicitly attributed to Bibi Editorial.

Challenge selection accepts only personal videos up to 180 seconds. New imports retain the existing 250 MB validation and local pending status. The video, submission and challenge entry commit together; a failed import/write removes only the new app-owned copy. Replacing an entry keeps the previous video. Withdrawing an entry leaves its video untouched. Removing a video or pending upload removes its entries and detaches circle references in the same snapshot update.

All attached-media routes re-check video existence and safety state. Existing private media is never converted into a remote upload. Reported posts and blocked authors disappear from both circle and saved-post lists. Local reporting does not imply server processing.

## Retired functionality

Live discovery, player branches, live creation, room store/playback and chat deep links are removed. Voice-room screens, discovery store, seating and message scripts are removed. Shared category values now live in VideoCategory. Legacy room drafts, report kinds, submission kinds and catalog surface markers remain only for data compatibility and attribution. Hidden archived submissions are retained without destructive migration.

## Verification boundary

The owner subsequently authorized compilation, simulator launch, interaction checks and direct fixes for this revision. The Debug build and core flows across all five modules passed on the Bibi QA iPhone 17 Pro simulator. See `COMMUNITY-RUN-VERIFICATION.md` for exact coverage and evidence. Storage-failure injection, device-matrix testing, real services and transactions remain unverified.

## Resource provenance

The `Assets/generated-` prefixed files preserve the seven image-model outputs. `scripts/package_artwork.py` extracts the atlases using alpha gutters, writes named flat images and native asset metadata and preserves transparency. Fifty-two different character drawings map to fifty named members, the local owner and the fictional Animation Club curator. Source filmmakers are credited separately, and no portrait claims to depict them.

`Assets/original-hero.mp4` and `Assets/original-spring.mp4` preserve the downloaded full original videos. `Assets/media-provenance.json` records download/source/credit/license, original and runtime SHA-256, exact intervals, output metadata and cover hashes. `scripts/prepare_media.py` produces sixteen nonoverlapping excerpts at original speed, proportionally resized to 960px width, H.264/AAC encoded. The app's aspect-fill viewport may crop the frame; no stretched source was produced. They are sixteen excerpts from two films, not sixteen independently produced films.

Hero: Blender Foundation, Daniel Martinez Lara, CC BY 4.0. Spring: Blender Foundation, Andy Goralczyk. Its project release specifies CC BY 4.0 while its official video-host metadata says Attribution–ShareAlike; these Spring derivatives and covers are distributed under CC BY-SA 4.0. Source/licensing links are shipped in Settings. No endorsement is implied.

`docs/template-history/` records the inherited specifications only; counts, identities and old URLs there are not the Bibi configuration.

## Configuration before public distribution

No public backend or merchant account was created. The product owner must supply a unique registered bundle identifier if different, signing team, authenticated services, server-authoritative balances/relationships/moderation, registered diamond products, receipt verification, operator identity and support contact, and reviewed public agreements. Existing local capability text must be updated only when actual integrations exist.

Native layout, playback lifecycle, keyboard behavior, Dynamic Type, VoiceOver, camera permissions, persistence failures and real App Store transactions remain outside the verified purchase scope. Local StoreKit Test coverage is recorded in PURCHASES-RUN-VERIFICATION.md. No statement in this record substitutes static inspection for those checks.

## Agreement links supplied on October 26, 2026

Welcome/consent and Settings share AgreementDocument and AgreementController. Terms uses https://docs.google.com/document/d/1Ht9y4vdWhBqBMEWh-TyDDkoelD4ovlfqnayIwr-b_4I and Privacy uses https://docs.google.com/document/d/1tdj2Xd4VnOVLbFCgk-k65m8ONo3obRoFT1xddWTtY5c. The reader requests Google's English preview in a nonpersistent WKWebView and restricts top-level navigation to the selected document.

The user-supplied documents were read through the connected Google Drive account. Their text is retained in Assets/agreement-source-PrivacyPolicy.txt and Assets/agreement-source-TermsOfService.txt with hashes and retrieval provenance. Bundled HTML preserves that wording with local reader formatting. No cloud document or sharing permission was modified. Anonymous access has not been verified; a failed web lookup is not proof that the documents are private.

Network errors, HTTP failures, authentication redirects, a 15-second loading deadline, and recognized English access-denied pages switch to the bundled version, labeled Saved copy. Acceptance versions include source URLs and bundled content hashes. Later cloud edits require refreshing these snapshots; the app does not claim to hash mutable remote content at acceptance time.

The provided Terms specify age 18+, while the Privacy Policy specifies 17+. These source statements are preserved rather than silently reconciled. The documents' service descriptions do not establish implementation of remote services; capability boundaries above still apply.
