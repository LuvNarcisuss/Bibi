# B Side Checkout and Call Recovery Plan

> **For agentic workers:** Use superpowers:executing-plans for parent-owned web and UI changes, with scoped parallel payment implementation and read-only lifecycle review.

**Goal:** Address the owner's six follow-up findings for Bibi 0.1.2: history swipes, checkout latency, subsequent payments after offline delivery, blocking payment feedback, foreground/relaunch recovery and repeated-call camera capture.

**Architecture:** Preserve the existing Socket receiver, scoped WKWebView and single StoreKit 1 observer. Separate Apple presentation ownership from durable business delivery. Preserve current-document capture across provisional navigation and suspend existing streams during background entry. Add bounded, scene-scoped checkout interaction ownership.

**Tech Stack:** iOS 16+, Swift 5, UIKit, WebKit, StoreKit 1.

**Spec:** Owner's November 6 six-issue follow-up in this chat, following the original five-issue report. The actual Socket page URL remains the media grant scope.

## Constraints and evidence

- No build, typecheck, application/simulator launch, runtime test or real purchase is authorized. Regression source and static inspection do not establish device acceptance.
- Preserve current user edits and the project.pbxproj identity snapshot. Do not regenerate the project, change IDs, clear journals or alter online routing.
- Runtime reproduction is unavailable under the current execution restriction. Trace concrete state transitions and retain the six original scenarios as pending acceptance; do not claim reproduced failures or verified fixes.

## Review focus

- A root-page swipe must never dismiss B or expose the native home.
- A paid order awaiting network delivery must remain durable while a genuinely new checkout can proceed.
- A delayed callback from an old page/session must not release or acquire another checkout's overlay.
- Background/foreground transitions must not convert an existing live media track into a permanently ended track.
- Payment cancellation, unknown Apple outcomes and logout must retain their existing deduplication and account boundaries.

## Tasks

- [x] Restore same-origin back/forward history through edge gestures without interactive snapshot dragging or elastic edges. Add source regression cases for history eligibility and retain root no-op behavior.
- [x] Add synchronous checkout UI ownership in BibiConfiguredSession/BibiConfiguredReceiver and a full-screen accessible loading overlay in BibiConfiguredWebController. Release by token in every task exit, page teardown and session stop; do not queue a second purchase.
- [x] Audit provisional-navigation and background capture transitions. Preserve existing tracks during canceled provisional loads; mute active capture in the background and restore only previously active capture in the same live WebView. Stop capture on actual teardown/replacement/error.
- [x] Repair StoreKit presentation ownership, product resolution latency and durable foreground/relaunch recovery; add regression XCTest source for each concrete state transition without executing it.
- [x] Update current documentation and the acceptance matrix; statically inspect Swift/JavaScript syntax, ownership call sites, unchanged configuration and whitespace. Obtain independent read-only review.

## Execution record

Planning: the latest user requests authorize source repairs. Project rules prohibit runtime execution without a separate explicit request, so red/green tests and device acceptance remain pending. Existing uncommitted repairs are part of the starting state and must be retained.

Implementation: edge history traversal does not drag WebKit snapshots, enter
document loading for a same-document change or invoke native-root dismissal.
Cache-backed history may commit without a new HTTP response. Error retry replaces
the failed WebView while retaining that same page's ephemeral website store;
Socket page replacements retain their fresh nonpersistent-store behavior.

Payment: independent catalog/readiness reads run concurrently; actual returned
products are cached for at most five minutes. A real terminal callback releases
Apple presentation ownership independently of business settlement. Unfinished
paid records for the same SKU/environment prevent another submission until
delivery/finish completes. Different SKU orders are independent. Ordinary resume
restores eligible original-account evidence work and transient retry opportunity.

Static verification: nine changed Swift files parsed through swift-format;
two extracted embedded scripts passed Node syntax checks. git diff --check
passed. The original pbxproj SHA-256 snapshot matches; the canonical online gate
is true and the only shared scheme is Bibi. Independent read-only review found
no substantiated P1/P2 in the completed state transitions. A later narrow retry
change preserves the existing ephemeral website store during fresh-WebView retry;
Socket replacements still receive a new store. Added source includes four history,
eight media lifecycle and six payment follow-up tests. None were compiled or run.

Remaining: all six original runtime scenarios require an authorized latest-source
build, install and launch on Bibi UI Acceptance, with physical-device RTC and
Apple sandbox/production evidence recorded separately. Static checks are not
device acceptance or measured performance. No commit, push, packaging or upload
is performed by this follow-up.
