# B native review — November 4, 2026

Scope: final native Auth/Socket/web lifecycle and dual-source StoreKit 1 recovery.
A fresh read-only reviewer found and the implementation corrected early payment
startup, stale entry callbacks, late notice mutations, unsubmitted payment UI
authorization surviving entry failure, and stale wallet read errors across
account changes. The last targeted review confirmed no remaining P1/P2 in the
final lifecycle/generation changes. This is a scoped review, not proof that no
undiscovered issue exists.

The final current-source unsigned Debug generic iOS Simulator build succeeded.
`b-build-and-resources.json` contains its exact source/log hashes and compiled
identity/resource checks. No installation, App/simulator launch, Preview or iOS
tests ran. Nine authored purchase recovery tests are not executed evidence.

Static checks confirm one resident SKPaymentQueue observer, no active StoreKit 2
purchase/update flow, frozen source-specific settlement and protected recovery
journals. Actual Apple UI/callback timing, media prompts, original Socket/web
protocols and external business ack/replay remain pending online/device acceptance.
Lost/unknown historical purchase ownership and upstream ambiguous confirmations
remain explicit recovery limits; no guessed credit or blind resend fills them.

## Subsequent purchase-chain review

The owner subsequently authorized actual iOS offline chain validation. The final
31-test run supersedes the initial unexecuted-test scope above. Failure-first
runs drove callback/storage and removal/finish recovery fixes; a repeated-object
lifecycle regression reproduced a bare-address deduplication bug, corrected with
weak live-object pointer identity. Final targeted read-only review found no new
P1/P2. See B-Purchase-Chain-Verification-2026-11-04.md for actual execution evidence
and the limits of injected Apple/network/account behavior.
