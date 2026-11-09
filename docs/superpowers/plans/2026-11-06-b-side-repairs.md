# B Side Interaction and Purchase Repair Plan

> **For agentic workers:** Use superpowers:executing-plans for parent-owned WebView/lifecycle changes; payment work is delegated to a scoped implementer. Runtime execution remains unauthorized.

**Goal:** Correct the owner's five B-side 0.1.2 findings while preserving real authentication, payment authority, personal data and the single online-enabled Bibi scheme.

**Architecture:** Keep the existing Socket receiver, full-screen WKWebView and StoreKit 1 observer. Scope web media grants to the current WebView created from the actual Socket page URL, without the superseded frame-origin grant restrictions. Centralize unsupported-payment interaction rules and keep payment diagnostics in the visible B page.

**Tech Stack:** iOS 16+, Swift 5, UIKit, WebKit, StoreKit 1.

**Spec:** Owner's November 6 five-issue report and subsequent instruction to grant webpage camera/microphone requests for the URL supplied by the Socket page event. System permissions still apply.

## Constraints and evidence

- No builds, typechecks, app/simulator launches, runtime tests or actual purchases are authorized. Added XCTest cases remain unexecuted; verification is static.
- Preserve the pre-existing project.pbxproj identity edits to im.seex.sao2 / JPTS6M4T5B. Do not regenerate or overwrite that project during this repair.
- Source confirms native back/forward gestures, transparent elastic web edges, inactive-time capture teardown, unrestricted Socket externalOpen, collapsed product-query errors and failed-order deduplication. Runtime root causes and Apple catalog availability remain unverified.
- Public B origin returned only a two-byte health response, so it supplies no frontend checkout DOM or actual payment redirect URLs. Use the owner's exact provider labels and verified paytmmp/phonepe URL schemes; do not invent payment hosts.

## Tasks

- [x] Repair WebView interaction in BibiConfiguredWebController.swift: disable history gestures and elastic edges, constrain root horizontal overflow, suppress Paytm/PhonePe controls and known provider links before handlers navigate, and handle rejected payment navigation without a home/error fallback.
- [x] Apply the owner-authorized media policy from the Socket-supplied URL. Preserve current session/WebView checks; remove the old request/frame-origin grant restrictions. Separate transient inactive state from actual background capture shutdown through BibiApplication.swift and BibiConfiguredSession.swift.
- [x] Repair payment in StoreKit1Purchasing.swift and BibiPurchaseRuntime.swift: preserve structured lookup and failed-transaction evidence, expose bounded non-secret context, and permit a fresh checkout event after an explicitly failed attempt without replaying an old message or duplicating unknown/paid orders. Add focused regression cases without executing them.
- [x] Present purchase failures above the B WebView and enforce unsupported provider filtering in BibiConfiguredReceiver.swift, covering Socket externalOpen in addition to navigation/popup paths.
- [x] Update relevant boundary XCTest cases, current media/implementation/audit documentation and static checks. Inspect Swift call sites, embedded JavaScript syntax, policy/selector references, unchanged payment authority and the preserved project diff. Request independent read-only review of final changes; report code completion separately from runtime and Apple acceptance.

## Verification record

Swift formatter parsing succeeded for the eight changed Swift files without
compilation or typechecking. Node syntax inspection succeeded for both extracted
embedded scripts. Whitespace checks passed. Source/generator/CI/plist/scheme
invariants and the byte-for-byte pre-existing pbxproj snapshot were checked.
Independent read-only review found no substantiated P1/P2; its icon-only button
coverage observation was addressed by examining branded descendants of the
nearest interactive control. Regression tests remain unexecuted.

Ruling: no application build or runtime test is run because project rules require
an explicit request for those operations. Code completion is not a claim that
the five live findings or Apple's external catalog/payment sheet passed.
