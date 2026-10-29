# Backend integration: local runtime verification

Date: October 27, 2026 (Asia/Shanghai).

## Authorization and environment

The owner requested compilation, tests on **Bibi UI Acceptance**, direct fixes,
and retention of the disabled backend gate. Current repository rules and
implementation/audit records were read before execution.

- Xcode 26.0.1 (17A400), Debug simulator configuration, scheme `Bibi`.
- iPhone 17 Pro simulator, iOS 26.0.1 destination, x86_64.
- Device name: **Bibi UI Acceptance**.
- Device UUID: `0C3DC278-7663-4B7E-9FCD-10F2FF679569`.
- Bundle ID: `im.seex.sao2-neiku-30`; development team: `JPTS6M4T5B`.
- Derived data: `/private/tmp/bibi-backend-acceptance-derived`.
- Evidence: `BibiApp/Design/RunEvidence/backend-20261027/` (local, Git-ignored).

## Build and fixes

The first build reproduced a compiler error in the chat cursor filter:
`Int64` does not conform to the pinned SDK's `PostgrestFilterValue`. The filter
now passes the lossless decimal `String(cursor)` supported by that SDK.

A subsequent build exposed an AVFoundation non-Sendable capture warning in the
video export cancellation handler. A main-actor-owned cancellation wrapper now
keeps access to the export session on its owner actor. A split `return` in the
local catalog was also normalized to remove its compiler warning.

The final build completed successfully (`build-03.log`). It has no Swift source
warnings; Xcode still reports its informational App Intents metadata extraction
warning because the app does not link AppIntents. Supabase Swift 2.30.0 and its
transitive versions were resolved, and the generated `Package.resolved` is now
retained through a narrow ignore-rule exception.

The latest built app was installed and launched on the required device before
running XCTest. `simctl launch` returned process ID 99534, and `launch.png` was
visually inspected. Both source configuration and the built app Info.plist
retain `BibiBackendEnabled=false`.

## XCTest results

The `Bibi` test action builds current source and runs serially against the exact
device UUID above. The result bundle is `tests-01.xcresult` and the complete log
is `tests-01.log` in the evidence directory.

- `BibiTypographyTests`: 5 passed, zero failures. Runtime checks cover 138 image
  resources, colors and loose resources, all 16 video clips and covers, bundled
  agreement HTML, font weights and five illustrated title assets.
- `BibiBackendTests`: 3 passed, zero failures. Checks cover callback origin/path
  rejection, concurrent retry identity/account-cache isolation, and the disabled
  gate. The new gate check verifies that `AppStore` remains local, has no online
  coordinator, and `BackendServices` initialization returns unavailable.
- `BibiUITests`: 2 passed, zero failures. Both default and XXXL text flows enter
  through consent and visit Shorts, Circles, Challenges, Chats and Me. Assertions
  check tab availability/hit testing, header labels, dimensions, window bounds
  and header/tab separation.

The completed result summary reports **10 passed, 0 failed, 0 skipped**, and
`xcodebuild test` exited 0 with `TEST SUCCEEDED`. Ten screenshot attachments were
exported and reviewed in two contact sheets. No illustrated-header clipping or
navigation obstruction was observed. This is not an exhaustive accessibility or
screen-content audit. Shorts' continuous comment animations caused six 60-second
XCTest idle-wait warnings; the tests continued and all assertions passed.

Artifacts include `test-summary.json`, `attachments/manifest.json`, original PNG
attachments, `default-contact-sheet.jpg`, `larger-contact-sheet.jpg`, and
`source-sha256.json` for 71 source/test/configuration files. None of those files
changed after the successful build before verification finished. The verified
app was relaunched after XCTest with process ID 4172.

## Reproduction

From `BibiApp/`, with explicit runtime authorization:

```sh
xcodebuild -project Bibi.xcodeproj -scheme Bibi -configuration Debug \
  -destination 'platform=iOS Simulator,id=0C3DC278-7663-4B7E-9FCD-10F2FF679569' \
  -derivedDataPath /private/tmp/bibi-backend-acceptance-derived build
xcrun simctl install 0C3DC278-7663-4B7E-9FCD-10F2FF679569 \
  /private/tmp/bibi-backend-acceptance-derived/Build/Products/Debug-iphonesimulator/Bibi.app
xcrun simctl launch 0C3DC278-7663-4B7E-9FCD-10F2FF679569 im.seex.sao2-neiku-30
xcodebuild -project Bibi.xcodeproj -scheme Bibi -configuration Debug \
  -destination 'platform=iOS Simulator,id=0C3DC278-7663-4B7E-9FCD-10F2FF679569' \
  -derivedDataPath /private/tmp/bibi-backend-acceptance-derived \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -resultBundlePath /private/tmp/bibi-acceptance-new-run.xcresult test
```

Use a fresh result-bundle path for each run. Verify the named simulator exists,
boot it if needed, and do not substitute another device or an older build.

## Limits and remaining release gates

This run verifies compilation of the online source and selected runtime
boundaries with the backend disabled. It does not exercise live authentication,
SMTP delivery, RLS under user tokens, database/Edge acceptance scenarios, uploads,
remote chat, online wallet credits, refunds, deletion or load behavior. No cloud
configuration or backend switch was changed during this run.

The Bibi scheme uses local StoreKit configuration, but this run performs no
purchase transaction. Product responses in logs are not Apple catalog evidence.
The separate purchase suite, Apple Sandbox and production payments were not run.
The iOS 16 minimum deployment setting remains unchanged; execution on iOS 16,
physical devices, VoiceOver and the full accessibility/device matrix is pending.

SMTP, Apple server credentials/configuration, moderation operations, online
agreement review and end-to-end acceptance remain required before cutover. See
`BibiApp/Backend/RELEASE-CHECKLIST.md`. Keep `BibiBackendEnabled=false`.
