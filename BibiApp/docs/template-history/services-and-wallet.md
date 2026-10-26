# Historical services, wallet, gifts, and release configuration

This English reference describes the original Teto template. Its account, product IDs, contact, and document URLs are historical records, not Bibi configuration. Bibi uses its own identity and requires its own registered products; see ../IMPLEMENTATION.md.

## Capability boundaries

| Capability | Template implementation | Unsupported claim |
|---|---|---|
| Entry | Open the local library after consent | Online authentication, phone verification, account tokens |
| Live | Immersive recorded dance playback and room interactions | Broadcasting or real hosts online |
| Shorts | Local feed, interactions, pending submissions | Public upload, server recommendations, moderation approval |
| Voice | Authored rooms/members, local messages, mute/speaking animation | RTC connection or people actually speaking |
| Chats | Authored history, atomic local outbox, drafts, follow rules | Delivery/read receipts, cross-device sync, remote automatic replies |
| Calls | Voice layout and local camera/flipping | Audio capture, remote connection, recording/upload |
| Scan | Real camera QR recognition and local ID matching | Network friend search or nearby matching |
| Reports | Local records, filtering, removal | Platform review submission or account bans |
| Purchases | StoreKit 1 requests/callbacks and idempotent local credit | Current-store product registration or verified production transactions |
| Gifts | Local deduction, record, and effect when funded | Remote receipt, server delivery, actual selected-member payment |
| Sharing | Local messages and copied internal URLs | Public access or cross-device media transfer |

Preserve real loading, error, and permission-denial states. Do not replace missing services with fabricated success. Saved, Pending, and Waiting to submit must correspond to actual local operations. Product UI need not carry development demonstration labels.

## Nine diamond tiers

Wallet is accessed from Me. Diamonds are the only currency. Use a 3×3 grid and StoreKit localized prices, with See price before loading. Selection opens confirmation; Continue waits for the product before submitting SKPayment. USD below is historical reference, not a current charge promise.

| Diamonds | Reference USD | Historical Teto product ID |
|---:|---:|---|
| 400 | 0.99 | hoewtkchclzkuruf |
| 800 | 1.99 | qbfuucwaccetjljs |
| 2,450 | 4.99 | mdnrsibqccschjcg |
| 5,150 | 9.99 | olfouxazhsdntxzs |
| 10,800 | 19.99 | ejtvapyfnomaimlf |
| 16,800 | 29.99 | mwkqplvxbtdrjcsn |
| 29,400 | 49.99 | uficsdpshzadegnz |
| 42,600 | 69.99 | hycnfrwzqmkplvtd |
| 63,700 | 99.99 | cbhpozbwbvfwgqxp |

These IDs apply only to the original Teto identity. A new app must use products registered to its own bundle. Generating plausible 16-letter strings does not register products. Older qlrpflukqugckska/zhkxxppfqwqfwhcp IDs were retired. The Tati Coins formatting example is not a Teto feature requirement.

Flow: SKProductsRequest → SKProduct → SKPaymentQueue. Only purchased/restored catalog transactions can be credited. Deduplicate transactionIdentifier and associated original IDs. Atomically save the wallet before finishTransaction. Save failures leave transactions unfinished for retry. Cancellation, missing products, and failures never credit diamonds. Deferred transactions await approval and must not be finished or shown as successful. Guard concurrent purchases, negative balances, and arithmetic overflow. Do not add a Restore button for consumables.

Activity reflects actual local ledger operations; empty state is No transactions yet. Logout preserves the wallet. Local account deletion removes its file, but unfinished Apple transactions can callback later; it does not erase Apple records. The template removes simulator-only 400-diamond grants and starts with no unearned balance.

## Gifts

| Historical gift | Diamonds per unit |
|---|---:|
| Rose | 10 |
| Balloons | 50 |
| Heart | 100 |
| Beat Drop | 200 |
| Spotlight | 500 |
| Bouquet | 1,000 |
| Dance Crown | 2,000 |
| Encore | 5,000 |
| Dance Galaxy | 10,000 |

Use three columns and transparent raster artwork. Show balance and Add more to Wallet. Quantity UI offers 1/5/10; business validation accepts 1–99. Total equals unit price times quantity. Insufficient funds leave state unchanged and show no success animation. With sufficient funds, save the deduction and kind=gift activity, publish the balance, then display a nonblocking full-screen gift/particles/name/quantity effect and remove it after completion. Reduce Motion simplifies effects. Display up to 40 activity entries while retaining the complete transaction deduplication set.

Live and Voice support the flow. Voice has Everyone/member selection, but the selected recipient ID does not reach spend. It is not revenue sharing or remote delivery. Future service integration must carry recipient identity and use server transactions without double-charging the existing local deduction.

Explain that diamonds fund room gifts. Messages, ordinary comments, and floating comments are free. Do not add coins, message charges, paid AI chat, or arbitrary consumption features.

## Historical agreements

The original template retained `Agreements/TermsOfService.html` and `PrivacyPolicy.html`, with Teto contact `18781461148@163.com` and these recorded document IDs:

- Terms: https://docs.google.com/document/d/1PBHnF3UNjCBkEuzOyETCUOWgMEz4eiPfGj_PooGJM4c
- Privacy: https://docs.google.com/document/d/1BGNLMpwOFa8_6Fz3S4zv9xkKELYTBEx3KXi3DLVBSj0

These were conversation-confirmed identifiers, not newly verified public links. Earlier records indicated owner-only access. AgreementController used a nonpersistent WKWebView with restricted main-frame navigation. HTTP/network failures and Google sign-in redirects fell back to local HTML with Saved copy. HTTP 200 permission pages might escape detection. New branding must replace agreements and contacts with its own legitimate information and service obligations.

## Packaging/release only after explicit request

Historical Teto workflow: Xcode 26.5, App Store Connect integration Teto, Apple App ID 6826151569, bundle com.teto.dance, project Teto.xcodeproj and scheme teto. Git LFS videos must be real files, not pointers. Commit shared schemes despite global *.xcscheme ignores.

If requested, the Codemagic flow validates project/scheme/bundle, pulls LFS, uses existing distribution credentials, finds the highest TestFlight build across versions, chooses the next number or larger CI number, archives/exports, and uploads using publishing.app_store_connect.auth: integration. Authentication failures stop the flow instead of silently reusing build numbers. Automatic beta/App Store review defaults to false. Historical upload authorization does not authorize a new release.

The template excludes personal notification recipients, certificates, keys, remotes, and CI credentials. Instantiation is not packaging, upload, or review. Compilation and cloud builds still require an explicit request.
