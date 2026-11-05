# Bibi engineering constraints

The latest user request is the authority: maintain an anime-themed native iOS app focused on Shorts, Circles, Challenges, Chats and Me.

- iOS 16+, Swift 5, UIKit and AVFoundation. No SwiftUI, Objective-C or hybrid frameworks.
- Main app screens are portrait-only, as selected by the owner on October 28, 2026. Rotation acceptance must verify that all five roots retain portrait geometry.
- Support iPhone only. Keep BibiApp/project.yml and the generated project aligned: device family 1, Mac Catalyst disabled, Designed for iPhone/iPad on Mac disabled, and Apple Vision compatibility disabled.
- Five tabs: Shorts / Circles / Challenges / Chats / Me. Shorts is the default root. Live and Voice rooms are retired; retain old serialized fields only for compatibility. No Phrases feature.
- New accounts start without personal works, likes, saves, joined circles, entries, friends, followers or conversations. Keep the community catalog populated; personal state and inbox entries must come from explicit user activity. QA fixtures must be installed explicitly rather than seeded at application launch.
- All authored project content must be English: application text, identifiers, filenames, code comments, explanations, documentation, scripts, asset text, and commit messages. Only conversational replies to the user use Chinese. This rule also applies to copied reference documents; historical language exceptions do not apply.
- Do not label the product as a demo or mock.
- Original generated raster icons and fictional anime artwork. Palette and composition live in BibiApp/Bibi/DesignSystem.
- Product/scheme: Bibi. The user selected bundle com.bibi.quadratic on October 29, 2026; the selected team remains JPTS6M4T5B. Preserve these values and keep BibiApp/project.yml aligned with the Xcode project. Never replace user-selected account configuration with template values.
- Preserve atomic persistence, stable IDs, moderation, relationship limits and private-media ownership. Legacy Codable keys are compatibility details.
- Terms and Privacy use the owner-selected fixed public PDF URLs under Supabase Storage `bibi-agreements/2026-10-29/`, with matching bundled PDF fallback. Replace these objects in place when updating agreements; do not change their public URLs unless the owner requests it. Do not restore Google document links. Keep source text, PDFs, provenance, resource references and consent versions aligned.
- Normal online entry uses one-tap Supabase anonymous sign-in, selected on October 28, 2026. Preserve 18+ consent, secure session restoration, guest access-loss warnings and the disabled cutover gate.
- Supabase project `yepycfnkkfrfmuwdekka` is provisioned. The single `BibiBackendEnabled` gate remains false until `BibiApp/Backend/RELEASE-CHECKLIST.md` is satisfied. Do not claim runtime verification, RTC, moderation staffing, or real store availability from code or deployment alone.
- The owner authorized the explicit `BibiOnlineAcceptance` scheme / `OnlineAcceptance` configuration on November 5, 2026 to exercise real B entry on `Bibi UI Acceptance`. Its generated plist enables the same backend gate for this run configuration only; Debug and Release source defaults stay false. Actual external authentication, Socket and page results determine entry; do not force a page or invent a ticket.
- Shorts and circle posts must not offer diamond tipping. Extend diamond spending within existing features; do not introduce a shop or other new feature module for monetization.
- No build, typecheck, app launch, simulator, preview or tests without an explicit user request. Static file/config/resource inspection is permitted. XcodeGen may regenerate metadata.
- Every test run must include building Bibi from the latest source in the current workspace, installing that build on the simulator named `Bibi UI Acceptance`, and launching it there. A user request to run tests also authorizes these required build, simulator, installation and launch steps. Verify that the newly built app launches successfully; if any required step fails or the named simulator is unavailable, report the blocker and treat the test run as incomplete.
- docs/IMPLEMENTATION.md and docs/STATIC-AUDIT.md are current; docs/template-history is historical reference only.

## Repository layout

- Keep `AGENTS.md`, `README.md`, `.gitignore` and `docs/` at the repository root. Application sources, Xcode configuration, scripts and test evidence remain under `BibiApp/`; source assets remain under `Assets/`.
- Read `docs/IMPLEMENTATION.md` and `docs/STATIC-AUDIT.md` before implementation or verification work.
