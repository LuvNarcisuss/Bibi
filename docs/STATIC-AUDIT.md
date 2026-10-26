# Static audit — Bibi

Paths to application source, configuration, scripts and `Design/` evidence in this report are relative to `BibiApp/` unless explicitly prefixed. `docs/` and `Assets/` refer to repository-root directories.

Date: 2026-10-26. Revision: Circle-post diamond gifts.

## Current evidence

- `python3 BibiApp/scripts/static_audit.py`: 436 source/configuration/resource checks passed, zero failures. Details: `static-audit.json`. The purchase follow-up replaces the obsolete blanket prohibition on StoreKit fixtures with explicit local-scheme, Apple-catalog-scheme and Bibi product checks.
- `plutil -lint Bibi/Support/Info.plist Bibi.xcodeproj/project.pbxproj`: both files passed.
- XcodeGen regenerated project metadata successfully. New community and Shorts sources are present in the source build phase; removed room controllers/stores are absent.
- The shared scheme XML is parsed by the static audit. The bundle ID remains `im.seex.sao2-neiku-30`, team `JPTS6M4T5B`, deployment target iOS 16 and Swift version 5.
- Five roots are wired in order: Shorts, Circles, Challenges, Chats, Me. Dock sizing and drag selection derive from the number of pages.
- All declared icon assets and referenced community artwork resolve. Media provenance hashes remain unchanged. Eight Shorts clips are active; eight legacy catalog entries remain retained resources with no Live route.
- Old snapshots decode community state as an optional field. Retired room/submission data is retained without active navigation. Community mutations use the existing atomic library commit.
- Source inspection traced video and pending-upload removal through challenge deletion and post attachment cleanup, creator blocking/reporting through new lists, and local account deletion through the common storage root.

## Independent source review

A read-only reviewer inspected the new models, controllers, navigation, creation and related routes. Three findings were verified against the source and corrected:

1. The Shorts creation button overlapped More. It is now in the navigation bar; the player rail has no overlay from the home screen.
2. Circle photo import loaded the whole source before checking its size. It now checks a file representation before URL-based ImageIO downsampling, and cancels the import Progress when the composer is released.
3. Pending challenge videos could generate unopenable published links. Their share control is disabled, the player displays local/unpublished status, and the share handler independently rejects pending uploads.

The reviewer found no remaining reachable Live/Voice room controllers or obvious new Swift API mismatch in the inspected source. This was static review, not compiler verification. A focused review during simulator QA found a search overlay that survived navigation into a chat. The issue was reproduced, fixed and rechecked in the simulator. The reviewer found no further concrete regression in the lifecycle fix.

## Runtime evidence and limits

The owner subsequently authorized runtime verification. A Debug simulator build and interactive checks of all five modules were completed; see `COMMUNITY-RUN-VERIFICATION.md`. These were tool-driven manual interactions, not an automated XCTest suite. Backend integration, StoreKit transactions, storage-failure injection and a full device/accessibility matrix were not run. Static checks alone do not prove runtime correctness.

`RUN-VERIFICATION.md` records an earlier revision's authorized build and welcome-screen launch. It is historical evidence, not validation of Circles and Challenges.

The circle-post gift follow-up passed one focused XCTest UI case on Bibi UI Acceptance using local StoreKit Test. It covers purchase crediting, gift spending, cancellation, insufficient balance and persistence. See `PURCHASES-RUN-VERIFICATION.md` for the current evidence and remaining limits. Shorts has no gift entry.

## Flat asset migration

All asset sources now live directly in the repository-root Assets directory. The audit reads the flat catalog metadata and verifies the same icon, artwork and media invariants. Generated Xcode catalog metadata links to these files; original films and design evidence are excluded from app resources. See ASSET-MIGRATION.md for migration-specific runtime verification.
