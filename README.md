# Bibi — Anime Social for iOS

A native anime social application with server-backed community content and private account state. The release gate remains disabled pending acceptance.

Open **BibiApp/Bibi.xcodeproj** and select the shared **Bibi** scheme. The stack is iOS 16+, Swift 5, UIKit, and AVFoundation. The user-selected bundle identifier is `com.bibi.quadratic` and signing team is `JPTS6M4T5B`. Both values are recorded in the Xcode project and `BibiApp/project.yml`.

The app supports iPhone only. For local purchase testing, select **Bibi UI Acceptance** and use Xcode **Product > Run** with **BibiDiamonds.storekit** selected under the scheme's Run options. A standalone `simctl launch` does not activate that scheme configuration. Use **BibiAppStore** only when verifying Apple's catalog; local test success does not establish App Store Connect availability.

## Repository layout

Repository rules, this README, Git ignore rules and `docs/` live at the repository root. `BibiApp/` contains the application sources, Xcode project, generator configuration, scripts, tests and design evidence. `Assets/` contains source assets.

## Codemagic distribution

The root `codemagic.yaml` defines `bibi-ios-app-store`, using Xcode `26.5`,
the shared `Bibi` scheme in `BibiApp/Bibi.xcodeproj`, Bundle ID
`com.bibi.quadratic` and App Store Apple ID `6828253391`. Configure the Codemagic
App Store Connect integration with the exact name `Bibi`, access to this app and
App Store signing certificates/profiles for team `JPTS6M4T5B`.

The workflow restores build assets from the public Supabase Storage bucket
`bibi-build-assets` without a Codemagic secret, checks required files, prepares the
asset catalog, applies signing profiles and increments the build number above the latest
TestFlight build across versions. Publishing uses
`app_store_connect.auth: integration` to upload the IPA. Automatic TestFlight beta
review and App Store review submission remain disabled; these flags do not disable
the upload itself. Build success and failure notifications are sent to the
owner-selected address `2758057680@qq.com`.

Codemagic downloads only pinned public objects and verifies their size and SHA-256
before catalog generation. The one-time upload process uses a trusted Supabase
operator credential and never exposes that credential to Codemagic or the app.

The public build-assets bucket contains the pinned build resources. Current production packaging retains interface artwork and retires bundled business media. Codemagic execution, Apple signing, IPA upload and App Store Connect processing remain separate release operations.

## Implemented source flows

- **Shorts**: the default tab; vertical video feed, search, likes, saves, comments, floating comments, sharing and local upload submissions.
- **Circles**: four themed communities, search, joined and saved filters, membership, text/photo/video posts, replies, bookmarks, author profiles, report/block actions and deletion.
- **Challenges**: four creative briefs with category filters, editorial video inspiration, an existing personal video or a new upload as an entry, replacement and withdrawal, and a personal participation history.
- **Chats**: filters and search, pin/mute/read/hide actions, drafts, relationship limits, groups, friend QR scanning, and voice/video call screens.
- **Me**: profile, works/likes/saves/uploads, joined circles, saved posts, challenge entries, wallet, profile editing, reports and blocks, agreements, logout, and local account deletion.

Live discovery, playback mode, creation and shared-message routes are removed. Voice-room discovery, seats, chat and creation screens are removed. Retired serialized room drafts and submission kinds remain compatible with existing account snapshots. The short-video player and grids contain no room playback mode.

Posts and Shorts do not offer diamond tipping. Historical wallet activity and purchase crediting are preserved; server-authoritative cosmetic unlock/equip and 100-diamond challenge entry/refund are implemented and deployed in A. B purchase settlement is deployed; real Apple/external acceptance remains pending.

Community data participates in the existing atomic library write and local account deletion. Removing a personal video also removes its challenge entries and detaches it from circle posts. Photos are downsampled to 1,200 pixels and limited to 1 MB; posts and replies retain drafts on a failed save. There is no Phrases feature.

## New visuals and media

- Violet, sakura pink, and ice blue; new gradient backgrounds, illustrated banners, topic ribbons, cards, and rounded typography.
- Original app icon, welcome artwork, 52 fictional character portraits, and eight room illustrations.
- 61 generated icon designs mapped to 70 semantic asset names, including status and gift icons.
- Ten current community clips and their covers are served through private Supabase Storage. Original clips and older entries remain source/provenance assets outside the application target.
- Licensed photographic portraits and cosplay references mix with illustrated characters. Generated starlight profile cards and filter capsules carry the theme across collections.
- The original dance videos, photographic portraits, icons, fonts, merchant configuration, and agreement links are removed from runtime resources.

**Settings → Artwork & Credits** provides attribution, licenses, and source links. All asset sources, including development artwork and provenance records, live directly in the repository-root `Assets/` directory. Only runtime files are included in the app resource build phase.

`xcodegen generate --spec BibiApp/project.yml` regenerates the project from the repository root. Its pre-generation command and the app's pre-build phase recreate the ignored `BibiApp/.generated/Assets.xcassets` catalog from flat source files. This directory contains disposable metadata and links; edit the named files in `Assets/`, never the generated catalog. The app icon and launch color retain native asset-catalog compilation. No image editor or third-party Python package is needed to generate or build the project.

`Assets/asset-migration.json` maps every previous asset location to its flat filename and records original and migrated SHA-256 hashes. `Assets/asset-catalog-index.json` maps native asset names to metadata and image sources. `Assets/runtime-asset-inventory.json` lists resources that runtime tests expect in the app. New loose runtime files must also be added to `BibiApp/project.yml`.

## Code differentiation

Dedicated `BibiPalette`, `StarlightCanvas`, `ConstellationBanner`, and `BibiConfiguration` components establish the new identity. The former catalog is archived with stable identifiers, credits and migration receipts. Runtime community records and media come from Supabase; private inbox entries arise only through actual activity. Branding, resource loading, agreements, and payment configuration follow Bibi requirements. Reliable persistence and interaction rules are reused; the project does not claim every business component was rewritten from scratch.

## Capability boundaries

A is deployed: 56 community records, seven non-Auth editorial profiles and 43 private media objects. Full authenticated media readback, real persistent Realtime chat, business API checks and isolated Sandbox spending/refunds passed, with temporary data cleaned. Device archives remain independent and are never automatically uploaded or credited. Retired bundled community sources are empty in production; while the release gate is false, the offline community catalog therefore remains empty. Actual private user data is preserved. RTC and moderation staffing are not provided by deployment.

B code now implements bootstrap preflight, App direct original authentication, native Socket events, full-screen web entry and dual-source StoreKit 1 confirmation recovery. Native diamond purchases use one Supabase balance writer with explicitly client-reported purchase trust, not Apple server verification. Socket orders use an independent original-service web entitlement authority and never credit native diamonds. The owner-approved B financial migration and both JWT-protected functions are deployed with exact source/privilege/catalog readback. Original Auth/Socket/web/Apple payment acceptance remains pending.

The wallet retains all nine Info.plist product IDs and localized StoreKit product prices. The two added IDs still require App Store Connect registration/validation; no real catalog or purchase availability is claimed. Unknown historical ownership, lost anonymous identities and ambiguous original-service confirmations have explicit recovery limits. See [integration record](docs/backend-api/integration-record.md), [purchase decisions](docs/backend-api/b-stage-decisions.md) and [release checklist](BibiApp/Backend/RELEASE-CHECKLIST.md).

## Verification scope

Generated test evidence under `BibiApp/Design/RunEvidence/`, including recordings, screenshots, logs and result bundles, is retained locally and excluded from Git. References to files in that directory describe local evidence and are not downloadable from a fresh Git checkout. XCTest result bundles and activity logs are also ignored wherever they are generated.

The Circles and Challenges revision passed a Debug simulator build and an explicitly authorized interactive check of all five modules. The static audit passed 426 checks. See `docs/COMMUNITY-RUN-VERIFICATION.md` for interaction coverage, fixes, screenshots and remaining limits, and `docs/STATIC-AUDIT.md` for static evidence.

`docs/RUN-VERIFICATION.md` describes a successful build and welcome-screen run of an earlier revision. It does not validate these new screens.

Implementation details: `docs/IMPLEMENTATION.md`. Resource processing: `BibiApp/scripts/package_artwork.py` and `BibiApp/scripts/prepare_media.py`.

## Language policy

All authored application and project content, including comments, explanations, documentation, scripts, and asset text, must be English. Only conversational replies to the user use Chinese. `AGENTS.md` records this requirement for future work.

## Agreements

The consent and Settings screens reference the public Supabase [Terms of Service PDF](https://yepycfnkkfrfmuwdekka.supabase.co/storage/v1/object/public/bibi-agreements/2026-10-29/TermsOfService.pdf) and [Privacy Policy PDF](https://yepycfnkkfrfmuwdekka.supabase.co/storage/v1/object/public/bibi-agreements/2026-10-29/PrivacyPolicy.pdf). Matching bundled PDFs provide offline fallback; online consent reads the pinned bundled copy. Public HTTP readback verified both documents as application/pdf with bytes identical to the bundled files. The seven canonical agreement files under Assets are tracked; other Assets remain ignored. Provenance is recorded in Assets/agreement-source-provenance.json. The owner selected the original 2026-10-29 URLs as stable public destinations. Update their PDF bytes, bundled copies, provenance and consent version together when revising the agreements.

## Backend integration

The owner-selected Supabase project is `yepycfnkkfrfmuwdekka`. The latest source passed an owner-authorized offline purchase-chain run: build/install/launch on Bibi UI Acceptance followed by 31 passing tests, zero failures/skips. Apple/account/network boundaries were controlled; no real purchase or live settlement ran. Historical runtime reports apply only to their named older revisions. `BibiBackendEnabled` remains false until the release checklist is satisfied.

For external console AppID `48369038`, import [interface template](docs/backend-api/generated/interface-template-48369038.json) in interface management and [configuration template](docs/backend-api/generated/configuration-template-48369038.json) in configuration management. Validate and save both before authorized online acceptance. These generated templates do not establish that the external service has imported or published them.

## Explicit online acceptance run

Use scheme **BibiOnlineAcceptance**, configuration **OnlineAcceptance**, on
**Bibi UI Acceptance** for the owner-authorized real B entry. The pre-build step
derives `.generated/OnlineAcceptance-Info.plist` from the canonical plist and
enables the existing backend gate for this configuration only. The default
Debug and Release configurations remain closed. Authentication and Socket events
must actually provide continuation and page data; this scheme does not force a
web destination or establish store/release readiness.

The November 5 signed online run reached and rendered the actual external B page
on Bibi UI Acceptance. Use `BibiApp/scripts/run_online_acceptance.sh`; simulator
Keychain requires local signing, so do not set `CODE_SIGNING_ALLOWED=NO` for this
interactive run. Real purchases/refunds remain separate acceptance.
