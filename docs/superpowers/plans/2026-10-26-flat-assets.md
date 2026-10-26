# Flat Assets Migration Implementation Plan

**Goal:** Put every existing project asset and its provenance in the repository-root Assets directory, with no source subdirectories, update resource references, and delete originals only after tests pass.

**Architecture:** Preserve runtime asset identifiers and binary bytes. Give catalog images their semantic names and prefix design originals, screenshots, metadata and prompts by purpose. Recreate Xcode's required catalog structure in an ignored generated directory using links to the flat sources. Only runtime resources enter the app bundle.

**Tech Stack:** UIKit, AVFoundation, Python standard library, XcodeGen, XCTest.

**Spec:** The owner's October 26 request in this chat explicitly authorizes migration, reference changes, tests and post-test deletion.

## Constraints and decisions

- Keep iOS 16+, Swift 5, bundle im.seex.sao2-neiku-30 and team JPTS6M4T5B.
- Preserve all current uncommitted changes and all binary asset bytes.
- All authored project text remains English.
- Work in the current workspace because it contains the owner's latest uncommitted assets and typography work.
- Preserve the old-to-new file mapping and original hashes for verification and traceability.
- Generated Xcode catalog directories are disposable build metadata, not asset source locations.
- The explicit implementation request supplies authorization; no additional design approval is needed for this directory-only migration.

## Tasks

- [x] Record every source file and hash; add migration and catalog-generation tests and observe the missing-flat-assets failure.
- [x] Copy assets into Assets with collision-free names. Keep originals intact. Update current provenance paths, scripts, documentation, project configuration and agreement loading.
- [x] Generate the Xcode project; run migration checks, the existing static audit, and simulator XCTest covering images, launch color, video, covers, fonts, agreements and the five root pages.
- [x] After successful tests, verify each original against the baseline and its destination, then delete only verified originals and empty asset directories.
- [x] Regenerate from flat sources, perform a clean build and rerun tests after deletion. Record results and inspect the final diff.

## Review focus

- Colliding art.png, Contents.json, manifest.json and welcome.png names must retain distinct contents.
- Clean checkouts must regenerate the catalog without original folders.
- Raw films, review screenshots and historical metadata must stay out of the application bundle.
- UIImage asset names, font registration, app icon, launch color, catalog IDs and agreement fallback must keep working.
- Cleanup must refuse changed originals or mismatched destinations.

## Progress

- Initial inspection: existing local typography changes are present and will be preserved. The Bibi QA simulator is available with authorized simulator access.

- Five Python migration/generator tests and 431 static checks pass. Five runtime XCTest tests pass; the full UI suite is still running. A regression test exposed macOS /var alias resolution in relative symlinks; resolving the destination parent fixed it.

- Pre-cleanup xcodebuild test exited 0: seven XCTest cases passed, zero failures. All 422 original and destination hashes were rechecked before deleting any original. Original directories are now removed. Isolated artwork/media tool smoke tests also passed.

- Completed: a cold direct-Xcode build recreated the removed generated catalog, and all five resource/typography tests passed with originals absent. Final Python tests, 431 static checks, XcodeGen regeneration, plist validation and git diff --check passed. Independent review found no actionable issues. Full report: ../../ASSET-MIGRATION.md.
