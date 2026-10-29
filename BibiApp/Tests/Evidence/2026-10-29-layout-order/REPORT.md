# Entry constraint hierarchy regression — October 29, 2026

## Result

The final targeted run passed all five tests with zero failures and zero skips.
Bibi was built from the current workspace, installed and launched on Bibi UI
Acceptance (`0C3DC278-7663-4B7E-9FCD-10F2FF679569`), an iPhone 17 Pro running
iOS 26.0.1. The installed executable hash matches this run's build product.
After restoring the original private state, the app was relaunched successfully
and the welcome screen was visually inspected again.

## Cause and repair

`EntryController.refresh()` activated the logo-to-content width constraint before
adding the logo's `mark` container to the content stack. At activation time the
image and stack had no common ancestor. The container now joins the stack before
constraint activation. The logo artwork, dimensions, consent flow and account
configuration remain unchanged.

The source review inventoried 108 direct constraint-activation sites in 12 Swift
files and inspected the shared `UIView.pin` helper and its callers. It included
cross-view aspect constraints, scroll layout guides, chat rows and empty states,
profile category reparenting, shared controls, grids, overlays and call layouts.
No additional instance of this ordering defect was found in the inspected code.
Constant-only and same-view aspect constraints do not require an external parent.
This review does not establish that every runtime branch has been exercised.

## Final runtime checks

| Test | Result |
| --- | --- |
| Entry stages build and refresh at compact and regular widths | Passed: welcome/login at widths 320, 393 and 430; three refreshes each; bounded square logo and unambiguous layout |
| Entry consent refresh keeps logo and actions available | Passed: three check/uncheck cycles, confirmation without consent, decline and return |
| Five illustrated titles | Passed: all five roots, header bounds, default Shorts and foreground return |
| Five illustrated titles with larger text | Passed: XXXL text and all five roots |
| Roots stay portrait when device rotates | Passed: all five roots retain portrait geometry |

The authoritative result is `final.xcresult`, summarized in `test-summary.json`.
`final-tests.log` ends with `TEST SUCCEEDED`; no common-ancestor exception occurs
in that final log. Exported screenshots and their mapping are in `attachments/`.
The actual default login screenshot was visually inspected after repeated consent
refresh, along with the initial and final welcome screenshots.

## Earlier attempts and limits

The baseline attempt built successfully but was interrupted before test execution:
an older Bibi process was suspended under an existing debugger and blocked device
operations. The dedicated simulator was restarted without erasing its data. That
attempt is not a successful red reproduction or a passing test result.

The first fixed run failed six assertions in the new detached-controller test.
The test incorrectly treated the optional 0.78 width preference as a required
equality. It now supplies an explicit viewport and checks required bounds, square
proportions and ambiguity instead. The same run's UI portion was interrupted
while XCTest waited for continuous floating-comment animations. Final test helpers
avoid tapping an already-selected tab; all five final cases passed together.
System motion and accessibility preferences were not changed. The retained logs
include the earlier attempts and must not be confused with the final result.

This is targeted simulator acceptance, not the full functional or purchase suite.
Live backend, real authentication, RTC, Apple Sandbox and production payments
were not tested. `BibiBackendEnabled` remains false in the installed application.
Build warnings include existing UIButton deprecation and skipped App Intents
metadata extraction; they are not reported as new layout failures.

## State preservation and static checks

Four original app state files were backed up before testing and atomically
restored afterward, including the library and wallet. All four hashes still match
the originals after the final relaunch. Backup contents are private local test
evidence. See `state-restoration.json` and `final-verification.json`.

543 static source/configuration/resource checks, plist/project syntax inspection
and whitespace inspection pass. The additional static guard checks that the entry
container joins the content hierarchy before cross-view constraints activate.
Source hashes, binary identity and launch PID are recorded in
`final-verification.json`; source-review sites are in
`constraint-site-inventory.json`.
