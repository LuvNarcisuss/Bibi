# Flat asset migration verification

Paths to application source, configuration, scripts and `Design/` evidence in this report are relative to `BibiApp/` unless explicitly prefixed. `docs/` and `Assets/` refer to repository-root directories.

Date: October 26, 2026.

## Result

All 422 existing asset, metadata, provenance and design-reference files were migrated into the repository-root `Assets/` directory. That directory has no subdirectories. Three new inventory files document the migration, the native catalog mapping and the runtime resource allowlist.

The original `BibiApp/Bibi/Resources`, `BibiApp/Design`, `BibiApp/Agreements` and `design-system` directories were removed after successful pre-cleanup tests. Every original SHA-256 and destination SHA-256 was rechecked before any deletion. All 255 binary image, video and font files retain their exact original bytes. Some documentation/provenance text changed only to reflect the new locations. Existing uncommitted typography work was preserved.

## Naming and project integration

- Runtime images keep their semantic names: `Portrait1.png`, `BibiIcon-heart.png`, `BibiTitle-Shorts.png`, `AppIcon.png`, and so on.
- Runtime videos, covers, fonts and HTML agreements retain their filenames.
- Design source files use `generated-`, `original-`, `typography-`, `review-` and `run-` prefixes; historical manifests use descriptive prefixes.
- Native catalog metadata is stored as flat `catalog-*.json` files. `asset-catalog-index.json` maps it to runtime identifiers.
- `prepare_asset_catalog.py` creates ignored `.generated/Assets.xcassets` metadata and relative image symlinks. Both the XcodeGen pre-generation command and the app pre-build phase run it. This disposable directory is not an additional source collection.
- `project.yml` and the regenerated Xcode project directly reference the runtime files in `../Assets`. Original films, source atlases, design screenshots and historical metadata are excluded from the application bundle.
- Agreement fallback now reads HTML from the bundle root. Video lookup uses the same flat bundle root. UIImage names, font registrations, app icon and launch color remain unchanged.
- Artwork packaging, media preparation, static auditing and current documentation use the new paths. Artwork packaging preserves unrelated title artwork and font registrations.

## Verification

| Check | Result |
| --- | --- |
| Pre-cleanup simulator build and full XCTest suite | 7 passed, 0 failed, 0 skipped |
| Five-page UI at default and larger text sizes | Both cases passed; ten screenshot attachments retained in the result bundle |
| Clean build without the generated catalog or prior build cache; resource/font tests completed with all originals absent | 5 passed, 0 failed, 0 skipped |
| Python migration/catalog suite after cleanup | 5 passed |
| Static source/configuration/resource audit | 431 passed, 0 failures |
| Artwork packaging and media path smoke checks in an isolated temporary copy | Passed; flat output and preserved title/font sources |
| XcodeGen regeneration using only migrated sources | Passed |
| Info.plist and project plist validation | Passed |
| Whitespace diff check | Passed |
| Independent source review | No actionable findings |

Runtime tests load all 138 named images, the launch color and the compiled app icon. They verify every loose runtime resource, decode a frame from each of the 16 videos, check durations and covers, read both agreement fallbacks, and verify the existing title artwork and font families/weights. Development media is explicitly checked as absent from the app bundle.

The generator regression suite covers missing input without destroying prior output, idempotent generation, stale-output cleanup and relative links under macOS temporary-directory aliases. The alias regression was observed failing before the path-resolution fix and passing afterward.

Environment: Xcode 26.0.1, Bibi QA iPhone 17 Pro simulator, iOS 26.0.1. Device ID `6AF30F68-29BB-4CFD-91FF-24CD39712A4A`. Bundle `im.seex.sao2-neiku-30`, signing team `JPTS6M4T5B`, iOS deployment target 16.0 and Swift 5 remain unchanged. Simulator commands use `CODE_SIGNING_ALLOWED=NO`.

## Reproduction and evidence

Run from the repository root:

```sh
xcodegen generate --spec BibiApp/project.yml
python3 BibiApp/scripts/test_flat_assets.py
python3 BibiApp/scripts/static_audit.py
xcodebuild test -project BibiApp/Bibi.xcodeproj -scheme Bibi \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=6AF30F68-29BB-4CFD-91FF-24CD39712A4A' \
  -derivedDataPath /private/tmp/BibiFlatAssetsDerivedData \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

The cold-build verification used the saved Xcode project directly, after removing the generated catalog, with `clean test`, a fresh derived-data directory and `-only-testing:BibiTypographyTests`. Xcode recreated the catalog automatically. The pre-cleanup run included both UI cases; the final cold build reran all five resource/typography cases.

Durable machine-readable summaries: [asset-migration-test-results.json](asset-migration-test-results.json). File mapping and cleanup gate: [asset-migration.json](../Assets/asset-migration.json).

Full local results and logs:

- `/private/tmp/BibiFlatAssets-BeforeCleanup.xcresult`
- `/private/tmp/bibi-flat-assets-before.log`
- `/private/tmp/BibiFlatAssets-AfterCleanup.xcresult`
- `/private/tmp/bibi-flat-assets-after.log`

The logs contain the existing AppIntents metadata-extraction warning because this app has no AppIntents dependency. UI tests encounter animation-idle waits on Shorts and then pass. No physical-device or App Store archive validation was performed for this directory migration.
