# B Side Repair Record

## Six-item follow-up

The owner later reported missing history returns, delayed checkout presentation,
an offline first purchase blocking later checkout, missing payment loading,
background/relaunch delivery gaps and a blank camera in a second call. This section
supersedes the initial history and background-stop implementation recorded below.

| Finding | Follow-up source change | Acceptance still needed |
|---|---|---|
| Cannot swipe to the previous page | Validated left-edge back and right-edge forward traversal; root no-op, no interactive page dragging | Real SPA history, document/cache navigation, canceled drags and carousels |
| Checkout sheet is slow | Concurrent independent settlement/product reads; brief cache of actual returned Apple products | Cold/warm catalog and network timing on the real B SKU |
| Later checkout remains blocked after offline paid order | Release Apple UI ownership on observed terminal evidence; resume original delivery independently; guard same-SKU unfinished paid orders without duplicate submission | Paid offline first order, reconnect, automatic confirmation and subsequent same/different SKU checkout without restarting |
| Other page operations remain usable during payment | Synchronous checkout token and accessible full-screen interaction overlay, deferred token-matched removal | Double taps, system sheet, cancellation, timeout, background and session/page replacement |
| Returning from background/relaunch misses delivery | Rescan Apple queue, restore eligible original-account receipt evidence work and retry transient status/confirmation | Background immediately after charge; forced process termination, relaunch and original-account recovery |
| Second call has no camera picture | Remove provisional-navigation capture termination; serialize background mute/resume and real teardown per WebView | Two consecutive calls, hangup/reacquisition, originally muted resources, rapid foreground/background and replacement |

The actual authenticated frontend/RTC implementation and tester trace are not
available locally. Native lifetime corrections cannot prove that a remote page
reacquires ended tracks or reattaches video elements. Do not claim verified call
media, measured sheet latency or actual delivery from these source changes.

Follow-up static verification parsed nine changed Swift files and both embedded
scripts, checked whitespace and confirmed the existing pbxproj hash, enabled
online gate and single shared scheme. The new follow-up regression source has
four history, eight media lifecycle and six payment cases; none are executed.
Read-only review found no substantiated P1/P2 in the inspected transitions.
Changes remain local source; this task does not package or upload a new IPA.

## Request and implementation

The owner reported five failures in Bibi 0.1.2 and confirmed all occur on the B
page. The Apple interaction is a native in-app purchase sheet, not a PassKit
card checkout. The later media instruction authorizes app-level grants for the
WebView opened from the real Socket page URL; system permissions remain required.

| Finding | Client correction | Acceptance still needed |
|---|---|---|
| Horizontal white edges or blank screen | Disable native web history gestures and elastic bounce; constrain root horizontal overflow and set the under-page background | Swipe the actual B page, including internal carousels and long content |
| Checkout does not reopen | Permit a fresh event after explicitly known unpaid failure; retain replay/unknown/paid association guards | Real B checkout retry with actual event IDs and StoreKit state |
| Camera/microphone consent without working call media | Grant known media requests for the current Socket-created WebView and its embedded frames; stop capture on background rather than transient inactivity | First permission prompts, foreground/background, actual local/remote audio/video and page replacement |
| Paytm/PhonePe returns to native home | Suppress identified provider controls before their handlers and block verified provider URL schemes across action/response/popup/Socket paths | Actual checkout DOM, branded controls, redirect/popup/external-open events and retained B page |
| Apple sheet content fails | Preserve distinct lookup and actual StoreKit failure evidence; present errors above B with Copy diagnostics | Actual B SKU, installation Bundle ID, Apple catalog/status/account/storefront and native sheet response |

The static fixes do not establish that every reported failure has passed runtime
acceptance. Apple-hosted payment-sheet content and catalog setup cannot be
repaired by substituting a local SKU, hardcoded price or fake success.

## Boundaries

- The Socket page event still controls the actual page URL; no URL, ticket,
  authentication result or purchase result is synthesized.
- Top-level navigation retains the accepted page origin. Embedded web documents
  and inherited empty/srcdoc frames remain scoped to that current page instance.
- System capture permissions, WebKit secure-context rules and the web service's
  actual RTC implementation remain effective. This adds no simulated call media.
- Paytm/PhonePe labels are matched exactly after case/whitespace normalization;
  native URL filtering matches the verified schemes paytmmp and phonepe. Query,
  path and host substrings do not classify a payment. No unobserved host allowlist
  or arbitrary third-party URL pattern was invented.
- The public B origin supplied only a two-byte health response. Its actual
  authenticated checkout HTML, alias labels and redirect payloads were not
  available for live inspection; those are explicit remaining coverage items.
- Replayed checkout messages never automatically reprompt. A fresh event may
  retry only a terminal record known to be unpaid and without a transaction ID;
  any unresolved or paid association continues through its original recovery path.
- Product/transaction diagnostics retain bounded identity and error-code fields,
  excluding receipts, tickets, credentials, account data and unrestricted NSError
  payloads. Technical details are available through an explicit copy action.

## Environment and verification

The owner had existing uncommitted pbxproj edits to im.seex.sao2 / JPTS6M4T5B.
They were snapshotted and preserved byte-for-byte. Generator/CI identity remains
the selected com.bibi.quadratic / 93BX5X327N. Do not attribute the distribution
failure to a local development identity without reading the tested artifact.

The previously inspected distribution IPA is 0.1.2 (28), Bundle ID
com.bibi.quadratic, with BibiBackendEnabled=true. That artifact predates these
repairs and is not modified by editing source.

This task performs static source/configuration inspection, embedded JavaScript
syntax checks and read-only review. Added/updated XCTest cases are unexecuted;
no compilation, typecheck, app/simulator launch, live payment, backend mutation,
upload or release is part of this task. A later authorized acceptance must build
the latest workspace, install and launch it on Bibi UI Acceptance as project rules
require, then record physical-device/media and Apple sandbox/production evidence
separately. Do not reset accounts, private media or purchase journals for convenience.
