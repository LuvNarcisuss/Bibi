# Bibi agreement rewrite

Historical record: agreement delivery below was superseded on October 29, 2026.
Current agreements use public Supabase PDFs and matching bundled PDF fallback.
See IMPLEMENTATION.md for the active delivery and verification record.

Date: October 27, 2026 (Asia/Shanghai).

The owner requested a more specific and accurate English Terms of Service and Privacy Policy, based on the existing agreements and actual app behavior. The two existing Google Docs were rewritten in place through the Google Drive plugin. The contact email is intentionally blank. The operator's legal identity was not supplied and is also blank; both documents explicitly remain drafts.

## Scope and decisions

- Preserve Bibi's name, existing document IDs and sharing permissions.
- Use the existing Terms' 18+ requirement in both documents, resolving the previous Privacy Policy's conflicting 17+ text. This is a contractual eligibility statement, not an implemented age check.
- Describe local operations without implying public publication, message delivery, staff review, cloud synchronization or recovery.
- Explain Google Docs web requests and Apple StoreKit separately from local app records. Do not make a blanket claim that no data ever leaves the device.
- Explain optional camera preview and QR scanning, user-selected Photos items, imported audio and potentially retained file metadata.
- Explain account deletion, logout, retained original Photos items, backup limits, local wallet deletion and non-restorable finished consumables.
- Remove unsupported location collection, advertising/analytics SDKs, subscriptions, blanket content licensing and guaranteed 24-hour enforcement. Preserve mandatory consumer rights without inventing an operator jurisdiction.
- Keep Apple and Google privacy links and Apple's refund instructions in the agreements. No business logic, permission strings or purchase implementation was changed.

## Implementation evidence

Paths below are relative to the repository root. These are static source observations, not runtime test results.

| Subject | Evidence |
| --- | --- |
| Local profile and consent; logout and account deletion | BibiApp/Bibi/App/AppStore.swift; BibiApp/Bibi/Domain/LocalLibrary.swift; BibiApp/Bibi/Features/Profile/ProfileControllers.swift |
| Atomic storage, file protection, original media ownership and deletion marker | BibiApp/Bibi/Data/LocalLibraryRepository.swift |
| Local viewing history and 2,000-record bound | BibiApp/Bibi/Data/VideoViewingHistory.swift |
| Likes, comments and local share counts | BibiApp/Bibi/Data/ShortsInteractionRepository.swift |
| Circle posts, author snapshots and challenge-video references | BibiApp/Bibi/Features/Circles/CommunityModels.swift; BibiApp/Bibi/Features/Circles/AppStore+Community.swift |
| Local outbox and conversation preferences | BibiApp/Bibi/Features/Chats/ChatModels.swift; BibiApp/Bibi/Features/Chats/ChatControllers.swift |
| Report contents and local blocking | BibiApp/Bibi/Features/Safety/ContentSafety.swift |
| Camera preview without audio capture or transport; local QR matching | BibiApp/Bibi/Features/Calls/CallCameraController.swift; BibiApp/Bibi/Features/Chats/ChatControllers.swift |
| Selected media, captions and local submission status | BibiApp/Bibi/Features/Creation/CreationController.swift; BibiApp/Bibi/Features/Creation/CreationSubmission.swift |
| Wallet records and StoreKit callbacks | BibiApp/Bibi/Features/Wallet/WalletModels.swift; BibiApp/Bibi/Features/Wallet/StoreKit1Purchasing.swift |
| Online agreement requests, nonpersistent web storage and fallback | BibiApp/Bibi/App/BibiApplication.swift; BibiApp/Bibi/Features/Authentication/UserAgreement.swift |

## External references

Reviewed on October 27, 2026. These sources inform the third-party descriptions and drafting choices; they do not certify the app's compliance.

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): privacy notices, retention/deletion and user-generated content requirements.
- [Apple App Store and Privacy](https://www.apple.com/legal/privacy/data/en/app-store/): Apple's account, purchasing and network processing.
- [Google Privacy Policy](https://policies.google.com/privacy): web requests and Google's own processing.
- [Apple purchase restoration](https://support.apple.com/en-us/108096): limits of restoring consumables.
- [Apple refund requests](https://support.apple.com/en-us/118223): Apple-managed refund requests.

## Verification and remaining dependencies

Both Google Docs were read back after the edits; their complete body text matched the authored text, ignoring only the final document newline. Native heading structure was present. Local HTML text, source text and provenance hashes were checked for consistency. The asset migration manifest retains original hashes and records revised current hashes for the five agreement files. Its existing verification script now treats HTML like other editable text, while retaining current-file hash checks and original-hash protection for binary assets. The script was not executed. Only static content inspection was performed; no build, typecheck, simulator, app launch or runtime test was requested or performed for this rewrite. No rendered-layout or anonymous-access verification is claimed.

Before public release, supply the legal operator identity and a monitored contact email, finalize the support provider and retention details, and review applicability to the actual distribution regions. The terms do not resolve missing receipt validation, server-side moderation or other implementation gaps. Refer to STATIC-AUDIT.md for those existing limitations.

The updated HTML changes the existing content-derived acceptance version in a future build. An already installed build retains its older bundled fallback until updated, even though the live Google Docs now contain the rewrite. Future changes to data practices or contact details must be reflected in both the live documents and bundled copies.

## Subsequent delivery change

The owner subsequently selected bundled local HTML in the new repository-root `Agreements/` directory on October 27, 2026. The latest Google text was read through the connected tool and adapted only where it described online agreement delivery or related request records. The app now reads these files without contacting Google or R2. The cloud documents were not edited during this migration. `Agreements/provenance.json` records their source revisions and final HTML hashes. Retained `Assets/` copies and old R2 agreement objects are unused. This supersedes the delivery and fallback descriptions above. See `R2-ASSETS.md` for current verification.
