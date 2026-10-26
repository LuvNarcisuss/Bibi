# Historical template decisions and scope

Snapshot: October 23, 2026, Asia/Shanghai. The template author derived this specification from paginated project conversations, source, resource records, and development notes. The latest explicit user requirement overrides earlier requests; source establishes implementation, not product authority.

This is historical Teto context. Bibi's newer requirements supersede its theme, brand, assets, and language exceptions. **All Bibi project content, comments, and documentation must be English; only assistant replies use Chinese.**

| Topic | Final template decision | Superseded or excluded |
|---|---|---|
| Product | Dance social: Live, Shorts, Voice, Chats, supporting Me | Commerce, drawing, dating, food, games, the full Nana feature set |
| Navigation | Four tabs; Shorts inside Live; no Phrases | Original five tabs or moving Phrases inside Live |
| Framework | UIKit, Swift 5, AVFoundation, iOS 16 | Earlier SwiftUI/iOS 17/Preview, Objective-C, cross-platform migration |
| Identity | Teto, teto scheme/target, com.teto.dance | inslive, InsLive, com.example.teto, im.seex.sao2-neiku-30 |
| Historical language policy | English app; Chinese documentation/conversation was allowed in the template | This exception does not apply to Bibi |
| Entry | Welcome, local entry, unchecked consent, save before entering | Arbitrary credentials represented as successful authentication |
| Style | Fresh Studio throughout | Dark Soul palette, old pink creator pages, blank solid backgrounds |
| Branding | Latest user-supplied logo unchanged; paired-dancer illustration | Redesigning the selected logo without a new request |
| Icons/photos | Generated transparent raster icons, real portraits, member collages | System icon replacements, generated human portraits, first-member-only group avatars |
| Live/Shorts | One catalog type, distinct assets/surfaces, list-to-room Live and vertical Shorts | Identical home flows or duplicated clips |
| Media count | 39 clips after removing seven Phrases clips from 46 | Earlier counts of 2, 12, or 24 |
| Live cards | Silent first-second loop while visible; no duration/play badge; reported cards static | Full-length card looping or still galleries passed off as videos |
| Live comments | Current UIKit scheduler: 1–3/s, up to seven outlined transparent bubbles, about one-third screen height, 50-character input | 20 ms, 200 ms, 3–5/s, solid bubbles, single-line truncation; legacy LiveRoomStore timing |
| Shorts comments | Attempts 1–5/s, constant 96 pt/s, 80-character input | Length-dependent speed or player recreation |
| Likes/saves | Shared Shorts persistence; independent Live likes excluded from Me Liked | All likes populating Me Liked |
| Counts | Small editorial bases around 10–30; creator Likes/Saves sum works | Thousands or extra random creator totals |
| Profiles | Round avatar, no wide cover, Message only for mutual follows | Nonmutual Message button or old wide cover |
| Conversations | Existing chats accessible; one lifetime nonmutual greeting; mutual unlimited; groups exempt | Automatically assuming follow-back or resetting allowance on restart |
| Sharing | Friend portraits plus Share link; local video messages open after validation | System sharing as the default flow or internal URLs claimed public |
| Safety | Saved reports hide targets and can be removed; source data retained | Record-only reports without filtering or claimed server submission |
| Creation | Dedicated forms, Waiting to submit, Me Pending review | Immediate picker, fabricated approval, or fabricated broadcasting |
| Wallet | Nine StoreKit 1 tiers, credit after transaction persistence, local gift spending/effect | Claims all purchasing/gifting is absent, seven tiers, or obsolete placeholder IDs |
| Calls | Call screens and real device camera; microphone/speaker state is local | Fake connection/timer, remote media, or removal of real permission errors |
| Verification | Static inspection for the template task | Reusing historical builds/typechecks as proof of the new package |

## Source/document disagreements

Historical implementation-status files, READMEs, and module notes contain superseded architectures, cards, counts, and payment descriptions. `WalletStore.send` calls `StoreKit1Purchasing.spend`, deducting the local ledger and showing an effect. Remote gift receipt does not exist. Voice recipient selection does not reach the ledger/network layer.

Original source injected 400 diamonds into an empty simulator wallet. The template removes that logic and starts at zero. The source project was not modified; see template-changes.patch.

`DancePhrase.swift`, `DancePhraseCatalog.swift`, `PhraseBook.swift`, and legacy report enums remain solely for decoding, validation, and private-media reference protection. Controllers, routes, seven videos, and chat open actions are absent. Old private data remains; new installations do not create this feature.

## Historical evidence coverage

The template author paginated 13 Teto/inslive Codex conversations, including one archived thread, and consulted the purchase-information ChatGPT conversation. Two identity-only ChatGPT conversations were irrelevant. Guardian automated reviews were not treated as user requirements.

Some turns failed or were interrupted, and some attachments returned only placeholders. Shared-web-chat analysis recovered only part of an answer. These are not complete visual evidence. Existing project resources and UIKit source support details unavailable from attachments; source levels are recorded in session-index.md. Missing attachments did not justify invented features or redesigns.
