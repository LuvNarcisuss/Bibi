# Bibi — Anime Social for iOS

A native anime social application built from the complete local feature baseline in the user-selected skill.

Open **BibiApp/Bibi.xcodeproj** and select the shared **Bibi** scheme. The stack is iOS 16+, Swift 5, UIKit, and AVFoundation. The user-selected bundle identifier is `im.seex.sao2-neiku-30` and signing team is `JPTS6M4T5B`. Both values are recorded in the Xcode project and `BibiApp/project.yml`.

The app supports iPhone only. For local purchase testing, select **Bibi UI Acceptance** and use Xcode **Product > Run** with **BibiDiamonds.storekit** selected under the scheme's Run options. A standalone `simctl launch` does not activate that scheme configuration. Use **BibiAppStore** only when verifying Apple's catalog; local test success does not establish App Store Connect availability.

## Repository layout

Repository rules, this README, Git ignore rules and `docs/` live at the repository root. `BibiApp/` contains the application sources, Xcode project, generator configuration, scripts, tests and design evidence. `Assets/` contains source assets.

## Implemented source flows

- **Shorts**: the default tab; vertical video feed, search, likes, saves, comments, floating comments, sharing and local upload submissions.
- **Circles**: four themed communities, search, joined and saved filters, membership, text/photo/video posts, replies, bookmarks, author profiles, report/block actions and deletion.
- **Challenges**: four creative briefs with category filters, editorial video inspiration, an existing personal video or a new upload as an entry, replacement and withdrawal, and a personal participation history.
- **Chats**: filters and search, pin/mute/read/hide actions, drafts, relationship limits, groups, friend QR scanning, and voice/video call screens.
- **Me**: profile, works/likes/saves/uploads, joined circles, saved posts, challenge entries, wallet, profile editing, reports and blocks, agreements, logout, and local account deletion.

Live discovery, playback mode, creation and shared-message routes are removed. Voice-room discovery, seats, chat and creation screens are removed. Retired serialized room drafts and submission kinds remain compatible with existing account snapshots. The short-video player and grids contain no room playback mode.

Posts and Shorts do not offer diamond tipping. Historical wallet activity and purchase crediting are preserved; new cosmetic spending options are proposals only.

Community data participates in the existing atomic library write and local account deletion. Removing a personal video also removes its challenge entries and detaches it from circle posts. Photos are downsampled to 1,200 pixels and limited to 1 MB; posts and replies retain drafts on a failed save. There is no Phrases feature.

## New visuals and media

- Violet, sakura pink, and ice blue; new gradient backgrounds, illustrated banners, topic ribbons, cards, and rounded typography.
- Original app icon, welcome artwork, 52 fictional character portraits, and eight room illustrations.
- 61 generated icon designs mapped to 70 semantic asset names, including status and gift icons.
- 18 credited clips: eight active animation Shorts, two active cosplay Shorts and eight retained legacy animation entries. Each cover is extracted from its corresponding video.
- Licensed photographic portraits and cosplay references mix with illustrated characters. Generated starlight profile cards and filter capsules carry the theme across collections.
- The original dance videos, photographic portraits, icons, fonts, merchant configuration, and agreement links are removed from runtime resources.

**Settings → Artwork & Credits** provides attribution, licenses, and source links. All asset sources, including development artwork and provenance records, live directly in the repository-root `Assets/` directory. Only runtime files are included in the app resource build phase.

`xcodegen generate --spec BibiApp/project.yml` regenerates the project from the repository root. Its pre-generation command and the app's pre-build phase recreate the ignored `BibiApp/.generated/Assets.xcassets` catalog from flat source files. This directory contains disposable metadata and links; edit the named files in `Assets/`, never the generated catalog. The app icon and launch color retain native asset-catalog compilation. No image editor or third-party Python package is needed to generate or build the project.

`Assets/asset-migration.json` maps every previous asset location to its flat filename and records original and migrated SHA-256 hashes. `Assets/asset-catalog-index.json` maps native asset names to metadata and image sources. `Assets/runtime-asset-inventory.json` lists resources that runtime tests expect in the app. New loose runtime files must also be added to `BibiApp/project.yml`.

## Code differentiation

Dedicated `BibiPalette`, `StarlightCanvas`, `ConstellationBanner`, and `BibiConfiguration` components establish the new identity. The animation catalog uses JSON with independent UUIDs, surface assignments, and credits. Default rooms, chats, and discussions are rewritten; branding, resource loading, local agreements, and payment configuration are reorganized. Reliable persistence and interaction rules are reused; the project does not claim every business component was rewritten from scratch.

## Capability boundaries

Shorts plays local media. Circle posts, replies, memberships and challenge entries are stored on this device. New uploads remain in a local outbox. Chats stores local pending messages; video calls display the device camera. Authentication, online publishing, challenge judging, RTC, IM delivery and server moderation are not connected.

The wallet offers nine tiers in a three-by-three grid, configured in the Info.plist `BibiDiamondProducts` dictionary. The seven owner-supplied product IDs remain unchanged; the owner approved two new 16-letter IDs for 16,800 diamonds at reference USD 29.99 and 42,700 diamonds at reference USD 69.99. It starts at zero diamonds and uses StoreKit product requests, localized prices, payment confirmation, and idempotent local credits. The two new IDs require App Store Connect registration. The supplemental backend catalog source is prepared but not deployed. App Store Connect product registration and sandbox transactions have not been verified. See `docs/PURCHASES.md` for the mapping and integration limits. Release also requires real services, signing, and store configuration.

## Verification scope

Generated test evidence under `BibiApp/Design/RunEvidence/`, including recordings, screenshots, logs and result bundles, is retained locally and excluded from Git. References to files in that directory describe local evidence and are not downloadable from a fresh Git checkout. XCTest result bundles and activity logs are also ignored wherever they are generated.

The Circles and Challenges revision passed a Debug simulator build and an explicitly authorized interactive check of all five modules. The static audit passed 426 checks. See `docs/COMMUNITY-RUN-VERIFICATION.md` for interaction coverage, fixes, screenshots and remaining limits, and `docs/STATIC-AUDIT.md` for static evidence.

`docs/RUN-VERIFICATION.md` describes a successful build and welcome-screen run of an earlier revision. It does not validate these new screens.

Implementation details: `docs/IMPLEMENTATION.md`. Resource processing: `BibiApp/scripts/package_artwork.py` and `BibiApp/scripts/prepare_media.py`.

## Language policy

All authored application and project content, including comments, explanations, documentation, scripts, and asset text, must be English. Only conversational replies to the user use Chinese. `AGENTS.md` records this requirement for future work.

## Agreements

The consent and Settings screens open the user-provided [Terms of Service](https://docs.google.com/document/d/1Ht9y4vdWhBqBMEWh-TyDDkoelD4ovlfqnayIwr-b_4I) and [Privacy Policy](https://docs.google.com/document/d/1tdj2Xd4VnOVLbFCgk-k65m8ONo3obRoFT1xddWTtY5c). Bundled English snapshots provide a Saved copy fallback for network or access failures. Snapshot provenance is in Assets/agreement-source-provenance.json. Cloud edits require resynchronizing the bundled snapshots. Connected-account readability was verified; anonymous access was not.

## Backend integration

The Supabase backend is deployed, while the app retains its disabled single-cutover gate. See [backend implementation](BibiApp/Backend/README.md) and [release dependencies](BibiApp/Backend/RELEASE-CHECKLIST.md). An earlier backend-integration revision built and ran on **Bibi UI Acceptance** with the gate disabled. The current safety/media/theme revision has static verification only. See [local runtime evidence](docs/BACKEND-RUN-VERIFICATION.md) for test coverage; live backend acceptance remains pending.
