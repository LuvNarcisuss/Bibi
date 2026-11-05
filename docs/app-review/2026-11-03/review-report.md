# Bibi App Review information-request diagnosis

Date: 2026-11-03. Source revision: db3466ab50cdab40c654ea8ade1f4010453744ee (clean before this report).

## Conclusion

Apple explicitly requests additional review information. One submission blocker is confirmed from the notice; disabled-backend mismatch is conditional and is not established as Apple's reason.

The general reminders at the end of the notice are not individual findings against this app. The notice does not establish a crash, a 4.3 spam rejection, infringement, or a missing delete-account button.

## Requested response package

1. Record the actual submitted build on a physical iPhone running the latest OS. Start with launch, show normal account access, all five roots, content creation, report/block, any paid feature access, and finish with account deletion where supported. Include device, OS, version and build. Simulator footage cannot meet this particular request.
2. Describe the actual purpose and audience: the project targets adults aged 18+ interested in anime-themed short videos and creative communities. Explain the practical value and only claim capabilities implemented in the submitted build.
3. Give exact feature paths, prerequisites and valid credentials where required. For genuine no-password guest access, explain that flow clearly instead of inventing a shared password. Guest account deletion remains applicable.
4. List services actually used at runtime. Distinguish Supabase public agreement hosting from gated Auth, database, storage and Realtime functionality. Identify Apple StoreKit purchases. Offline AI-generated artwork does not by itself establish an in-app AI service. Build-time CI hosting is separate from core runtime services.
5. Confirm regional consistency only after checking actual distribution and feature rules; explain any real differences.
6. Provide applicable content-rights documentation. Provenance and credits exist for generated artwork, Blender films and Pexels media; those records are starting evidence, not a fresh license-compliance determination. State regulated-industry items are not applicable only when accurate.

Put the requested information in App Review Information > Notes and provide an accessible video link and supporting attachments before resubmitting. If only information is missing and the submitted app is complete, this notice does not itself demand a new binary. If functionality needs repair, submit the repaired build.

## Findings

### AR-001 — Apple requires additional review information before completing review

Priority: P1 (engineering priority, not an Apple rating). Status: confirmed. Confidence: high.

**Path:** App Store Connect submission to App Review; reviewer requests completion of the App Review Information Notes field.

**Condition:** The supplied Guideline 2.1 Information Needed notice requests six categories of information and resubmission.

**Impact:** Review cannot be completed until the requested evidence is supplied. The notice does not identify a specific crash, infringement or screenshot violation.

**Evidence:**

- `User-supplied App Review notice in this chat`: Requests physical-device recording, purpose/audience, access instructions, external services, regional behavior and applicable rights or regulated-industry documents. Original submission materials were not inspected.

**Remediation:**

- Add all six responses to App Review Information > Notes, based on the actual submitted build.
- Include an accessible physical-iPhone recording from launch through the main workflow, account access/deletion, report/block and any paid feature flows. Record device model, OS version, app version and build.
- Explain no-password guest access if that is the actual shipped authentication flow; provide valid credentials for any flow that requires them.
- Supply applicable asset permissions and licensing evidence, and accurately identify non-applicable regulated-industry requirements.

**Validation:**

- Open the recording link without owner authentication and verify all required steps are visible.
- Reproduce review instructions on the submitted build and compare Notes, screenshots, description and actual functionality.

**Remaining uncertainty:**

- No existing ASC Notes or attachments were supplied; cannot identify which requested items were previously omitted or inadequate.
- Internal reviewer rationale beyond the notice is unknown.

**Owner:** App owner / release manager **Effort:** S for documentation; physical-device evidence and any defects may increase scope.

**Applicable rules:** [2.1 and complete-review information](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review)

### AR-002 — Submitted online-social claims may conflict with the disabled business backend

Priority: P1 (engineering priority, not an Apple rating). Status: needs_verification. Confidence: medium.

**Path:** Info.plist BibiBackendEnabled=false -> BackendConfiguration.isEnabled -> AppStore initialization sets online=nil -> local session, chat outbox and report persistence.

**Condition:** Applies if the submitted binary retains this gate and its listing or review notes promise functional online social features.

**Impact:** Under those conditions, reviewers cannot complete genuine online authentication, message delivery or server-side report processing as advertised. Source behavior alone does not establish the submitted-binary state or the reason Apple sent this notice.

**Evidence:**

- `BibiApp/Bibi/Support/Info.plist`:84: Business-backend gate is false in current source.
- `BibiApp/Bibi/Backend/BackendConfiguration.swift`:5: Gate reads the bundled plist and defaults to false.
- `BibiApp/Bibi/App/AppStore.swift`:99: Online service initialization is gated; disabled path sets online=nil.
- `BibiApp/Bibi/App/AppStore.swift`:119: Local entry records agreement acceptance, not remote authentication.
- `BibiApp/Bibi/App/AppStore.swift`:667: Without online services, messages are stored in the local outbox; persistence does not prove delivery.
- `BibiApp/Bibi/App/AppStore.swift`:1010: Reports use a remote operation only online; otherwise persisted locally.
- `BibiApp/Backend/RELEASE-CHECKLIST.md`:3: Explicitly retains disabled gate pending release acceptance and external dependencies.

**Remediation:**

- Inspect the exact submitted artifact and listing before treating this conditional issue as confirmed.
- If online functionality is part of the shipped product, complete the existing release checklist and genuine service acceptance before enabling the gate and uploading a replacement build. Do not simply flip the gate.
- Make review notes and listing accurately describe the actual approved product scope; documentation cannot substitute for unfinished advertised functionality.

**Validation:**

- Inspect the submitted build plist and its source/CI revision correspondence.
- On physical iPhones, verify real cross-account content, message delivery, report handling and account deletion for features claimed online.

**Remaining uncertainty:**

- Submitted binary, CI logs and listing not available.
- No live backend or physical-device actions were executed.
- Not asserted as the confirmed cause of the Apple notice.

**Owner:** Release manager / iOS / backend / moderation operations **Effort:** M-L if online cutover is required; depends on actual submitted scope.

**Applicable rules:** [2.1(a), 2.3 and conditional 1.2](https://developer.apple.com/app-store/review/guidelines/)

## Account deletion distinction

`BibiApp/Bibi/Features/Profile/ProfileControllers.swift:705` already provides Delete account. The local branch clears device-owned account data through `AppStore.deleteLocalAccount`; the online branch routes to a separate deletion controller. No deletion was executed. A button does not prove remote account deletion, but its presence rules out claiming the current source has no deletion entry.

## Evidence gaps

- **GAP-001 / P1:** Which build and runtime scope were submitted? Exact version/build, matching IPA or archive, CI revision, current ASC description, screenshots and Notes. Owner: Release manager.
- **GAP-002 / P1:** Can the requested physical-device flow be reproduced? Recording on a physical iPhone running the latest OS, starting with launch; device/build identification and actual QA results. Owner: Owner / QA.
- **GAP-003 / P1:** Are paid features reviewable in the submitted app? ASC product states, availability and association with this submission; physical-device Apple sandbox evidence and actual diamond uses. Local StoreKit fixtures are insufficient. Owner: Owner / payments.
- **GAP-004 / P2:** Are regional statements and content rights accurate? Actual distribution regions and differences; applicable licenses and attribution for submitted films, photographs, music and artwork. Owner: Owner / content.

## Coverage and limits

- **Release configuration (checked):** Source plist disables the business backend; project.yml uses that plist. No submitted IPA or final build inspected.
- **Launch and completeness (needs_evidence):** No physical-device execution, submitted build identity or current crash evidence provided.
- **Accounts (checked):** Traced local consent/session entry and Settings deletion dispatch. Remote deletion not executed.
- **Privacy (needs_evidence):** ASC privacy declarations and submitted-build data flows not inspected.
- **Payments (needs_evidence):** StoreKit implementation and purchase documentation exist; real product availability and submission association unknown.
- **Content safety (checked):** Traced local report persistence and remote branch; moderation staffing remains unchecked in release checklist. No live UGC acceptance.
- **Web and remote behavior (checked):** Business-backend gate traced to service initialization. Public agreement hosting is separate from business-backend activation. No general environment-routing audit performed.
- **Dependencies and platform APIs (needs_evidence):** No final archive, SDK inventory or privacy aggregation audited in this focused diagnosis.
- **Product and rights (needs_evidence):** Asset provenance and credits exist; actual submitted assets and license compliance not independently established.
- **Submission materials (checked):** User supplied the Apple information request; existing ASC Notes, recording and metadata were not provided.

Inspection was limited to project rules, current implementation/audit records, source configuration, selected account/chat/report paths, release checklist, purchase documentation and provenance references. No build, typecheck, preview, simulator, app launch, runtime test, account mutation, backend call, ASC edit or resubmission was performed. Report schema validation is document validation only. No claim is made that current source matches the submitted binary.

## Official sources

Relevant text was reviewed online on 2026-11-03; this is the check date, not an Apple publication date.

- [App Review](https://developer.apple.com/distribute/app-review/) — Review access, incomplete information, physical-device preparation.
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — Sections 2.1, 2.3 and 1.2; completeness, accurate metadata and UGC safeguards.
- [Provide information for a complete review](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review) — Purpose, audience, access, external services, regions and rights documentation.
- [Offering account deletion](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion) — Guest accounts also require deletion; logout is insufficient.
- [Submit an In-App Purchase](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase) — First submission of each purchase type and app-version association.
