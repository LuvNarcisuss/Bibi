# Business WebView media permission boundary

## Current owner-selected behavior - November 6, 2026

The owner explicitly replaced the per-request/frame-origin grant policy below:
the media scope is the actual URL supplied by the authenticated Socket page event
when creating/replacing the WebView. Its current live WebView grants known camera,
microphone and combined media requests without origin/commit-timing denials.
Embedded HTTP(S) and inherited about:blank/about:srcdoc frames are accepted within
that page scope. Old instances, invalidated pages, ended sessions, background
scenes and unknown capture resources remain outside that scope. iOS system
permissions and WebKit's own secure-context/permissions rules still apply.

Permission and payment sheets can make the scene temporarily inactive; that
transition pauses loading feedback without destroying capture. Provisional loads
and redirects also retain the current document's tracks until WebKit replaces
that document. Canceled provisional loads can restore the committed document
without attempting to revive ended tracks.

The six-item follow-up changes real background handling from `.none` to `.muted`
for previously active capture: no audio/video is actively captured while muted,
but tracks are not deliberately ended. Only capture suspended by this owner can
resume on returning to the same live WebView; previously muted/inactive resources
are not activated. Per-resource mutations are serialized and completion rechecks
the latest desired state, including a foreground request followed immediately by
background or teardown. Replacement, abandoned-page failure and teardown still
request `.none`; error retry constructs a fresh WebView. No JS stream or synthetic
call is created. The main-document origin stays frozen to the Socket page origin;
popup permission remains a separate committed-origin rule.

Updated regression source covers this current contract, but is not compiled or
executed. Source/static inspection does not prove an actual RTC call. See
`B-SIDE-REPAIR-2026-11-06.md` for current work and remaining device acceptance.

## Historical November 5 policy - superseded for media grants

Date: November 5, 2026. Scope: the owner requested the P1 fix for unconditional webpage media authorization, following the updated integration skill's B origin policy.

## Root cause and changes

`BibiConfiguredWebController` previously completed every media request with `.grant`, admitted any HTTP(S) document and opened other schemes and HTTP(S) popups through the system. System camera/microphone permission alone did not constrain which webpage could request capture. Stopping loading also did not explicitly stop existing capture.

The controller now freezes the origin of the current, validated business page event and binds it to the page ID, Supabase session generation and WebView instance. `BibiWebOrigin` compares system-parsed scheme, normalized host and effective port. It rejects non-HTTP(S), credentials, missing hosts and invalid ports. Paths, queries and fragments do not broaden the origin.

`BibiWebPagePolicy` requires a committed same-origin main document in the current navigation, matching actual request origin and `frame.securityOrigin`, the current page/session, a live foreground WebView and a known camera/microphone resource. The real permission callback evaluates that policy once and returns grant or deny once. System permission settings remain effective. No grant is cached by the app, and unknown resource types are denied.

Both actual navigation action and final response delegates check the frozen document origin. Cross-origin documents and unknown schemes are cancelled. Popups require a current trusted document, actual trusted source frame and a same-origin destination before the original system-opening behavior is available; unknown/cross-origin popups do not fall back to the parent or browser. Independent authenticated `externalOpen` business events keep their existing contract. Image/script/style/media subresource loading is not treated as document navigation, and this delegate is not a network firewall.

Accepting a replacement event synchronously invalidates the old media policy and stops capture before asynchronous presentation. Pending replacements cannot acknowledge the old cover or persist the old page success. Capture authority is cleared when a real provisional load starts. Same-origin navigation actions alone retain the still-current document proof, so anchors (including repeat anchors) and same-document history changes do not wait for a nonexistent new commit. Actual provisional navigation identifies a new generation; same-navigation redirects are not retired as stale. A final allowed response plus `didCommit` establishes document authority; `didFinish` still controls existing page-loading completion and first-success persistence. Rejected main documents use the existing bounded error path; rejected iframe/popup/media requests do not fabricate main-document failure or login success.

Closing, replacement, failed navigation and foreground loss call both real capture-state APIs with `.none`. The local iOS SDK headers document that this stops capture. Page replacement also detaches delegates and releases the old WebView before constructing a fresh instance. Session teardown already calls page.stop before dismissal and release; every callback separately checks current session/instance state. Three existing playback settings and nonpersistent page storage are preserved.

## Verification and limits

Static inspection confirmed the old unconditional grant, traced the sole validated receiver through page creation/replacement, checked both delegate call sites and teardown paths, and verified API spelling/availability in the installed iPhoneOS WebKit headers. Whitespace checks pass. No new source file or project metadata change was needed.

Five XCTest methods were added to the existing BackendBoundaryTests source before the implementation. They cover default ports/path handling, foreign schemes/ports/subdomains/spoof suffixes, unknown origins, request/frame disagreement, document commit, stale page/session/navigation, invalidation and document-origin immutability. These XCTest cases have not been compiled or run. An independent read-only review checked the source and called out redirect/same-document lifecycle and the asynchronous replacement invalidation window; both were corrected in source before delivery.

No build, typecheck, app launch, simulator, Preview, browser media capture, live Socket/login or runtime test was performed. Source inspection does not establish that device permissions or WebKit iframe/redirect/capture behavior have passed acceptance. Authorized testing must build the latest workspace, install and launch on Bibi UI Acceptance and separately verify same-origin frames, foreign/opaque frames, redirect/fragment/back-forward/retry, rapid replacement/logout and stopping an already active camera/microphone. No online service or release gate was changed for this fix.

The previously authorized agreement publication is separate and remains frozen at the same two canonical URLs. This P1 change did not regenerate or republish either PDF.
