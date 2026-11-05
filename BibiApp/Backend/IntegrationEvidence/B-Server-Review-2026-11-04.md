# B server review — November 4, 2026

Project: `yepycfnkkfrfmuwdekka`; bundle: `com.bibi.quadratic`; console application:
`48369038`; external origin: `https://bibi.byig.top`. The two console templates
and frozen contract were generated before this implementation. The contract
SHA-256 is `a82cec51c10dda9b2484613b2571a30fd4f512b43146428a21bf58fcef07104c`.
Its fourteen aliases were not renamed. Agreements, private content and the
disabled release gate are preserved. No live upstream business request was sent.

## Reviewable financial migration

`../b-settlement.sql` is frozen at SHA-256
`2b65b5e3e607838d35e18af24927748c858a7b78a297fd809d77b7484313f5f9`.
The owner explicitly approved this exact version and both companion functions.
It deployed as `20261104030119 bibi_dual_source_settlement`, followed by
`bibi-settlement` v1 and `bibi-begin` v2, both ACTIVE/JWT-protected. Exact
source/settings and privilege/catalog readback passed; see
`b-deployment-readback.json`. No live external or Apple acceptance is implied.

The migration adds the two already owner-selected product mappings and checks all
nine existing IDs/diamond amounts against the approved catalog. It does not
replace a conflicting existing mapping. It adds a private settlement table,
private helpers and one service-role-only public RPC. It adds explicit
`verification_source` provenance to the existing private transaction ledger and
a precise guard to the existing credit function. It does not change Apple's
verification algorithm, credentials, refunds or purchase product identifiers.

## Bootstrap preflight

The same `bibi-begin` validates the current Supabase session and reads the private
deployment bundle `functions/_shared/bibi-settings.json`, copied byte-for-byte
from `docs/backend-api/generated/supabase-server-settings.json`. The bootstrap
accepts the four contract aliases and reconstructs only those four fields:
`bibi_edition`, `bell_mark`, `starlight_installation`, `constellation_delivery`.
Push token may be empty; the delivery type must be integer 2. Device identity is
validated as an actual nonblank bounded string, without inventing another format.

It POSTs once to the fixed `/bibi/constellation/entry`, with a 15-second total
upstream deadline including response reads and a 1 MiB response cap. Redirects
are errors. No JWT, secret, caller-selected header, forwarded IP, URL or AppID is
sent upstream. AppID remains controlled deployment metadata and is not added to
the old request body. Self-origin and malformed destination configuration fail.

Responses require an object envelope, a lexically integer code, object `data`,
and HTTP 2xx or 401. An own `constellation_gateway` key selects the original
external origin even when its value is null, empty, false or zero. Only HTTP 2xx,
integer code zero and an absent key select the exact bound Supabase origin.
Both branches return the same string AppID through `constellation_origin` and
`constellation_app`. Upstream tickets/data are not forwarded. Missing/bad/oversize/
timed-out responses never become a native-success fallback. The external origin
is not overwritten by a prior native result; there is no automatic upstream retry.

## Purchase requests and responses

The sole B entry is `bibi-settlement`. It validates a live account/session before
using its own service-role RPC. The client cannot select the credited user,
amount, URL, confirmation path or database lease. Only explicit sources are
accepted: `bibi_wallet` and `constellation_order`. New quantity is exactly 1;
environment is exactly `Sandbox` or `Production`. Unknown/Xcode environments are
configuration failures, with no Production fallback.

Confirm requests contain `action:confirm`, the frozen contract ID
`bibi-48369038-v1`, environment, `diamond_origin`, `diamond_product`,
`diamond_count`, actual SK1 transaction string `diamond_reference`, raw App
receipt Base64 `diamond_proof`, original `bibi_edition` and
`starlight_installation`. `orbit_order` is included only when there is an actual
nonblank original order. Optional original `request_id`, `message_id`,
`external_attempt_id`, `context_origin` and `app_id` are frozen association
metadata. Their presence does not authorize another endpoint; any provided
origin/AppID must equal the controlled contract. Null/blank optional fields are
rejected rather than synthesized. Receipt bytes remain request-local; only a
SHA-256 fingerprint and evidence version are retained on the server.

Success is `{code:0,message:ok,state:confirmed,transaction_id,environment,source,
product_id,quantity,authority,balance?}` plus trusted `recovery` metadata. Only
local success has native `balance`. Errors have nonzero code, fixed sanitized
message, controlled category and state. Business states use HTTP 200 with
nonzero code; authentication/input failures use HTTP 401/400, and transient
server failures use HTTP 503 with the same error envelope. Code 202 processing
is not confirmed. Upstream bodies or free-text errors are never echoed.

Availability requests contain action, contract ID, source, product, quantity and
environment. They report adapter/catalog configuration; they do not claim Apple
product readiness, proof validation, real purchase or live upstream availability.
Status requests contain only action, contract ID, environment and transaction
reference. The server returns the original owner's frozen association/result,
not a new claim based on current device/login/source guesses. Recovery metadata
uses semantic `app_version`, `device_no`, `request_id`, `message_id`,
`external_attempt_id`, `context_origin`, `app_id`, `contract_id`,
`order_reference` and `provenance`, when actually retained.

## Authorities, atomicity and history

Local B settlement trusts the client's purchase declaration. It is not Apple
server verification: a malicious client may fabricate a transaction or source.
JWT, Base64 syntax, product lookup and deduplication do not prove payment. This
chosen boundary is explicitly represented by `verification_source:client_reported`.
No new p8, Apple key, Apple API call or constant-success verifier was introduced.

The local branch atomically freezes ownership and invokes the existing wallet /
transaction / activity credit transaction using the server product catalog.
An exception rolls back the settlement, transaction, balance and ledger together.
It never calls external authentication or confirmation. The app only refreshes
its native Supabase balance after confirmation and must not increment it again.

The existing A ledger is the shared transaction fence. An existing credited A
transaction cannot credit again through B. A legacy Apple-server record can be
restored only for its known user/product/quantity/native source. Unknown records,
other owners, revoked transactions and missing source associations remain
unclaimable. New B client-reported records cannot be promoted into trusted
historical Apple-server evidence. The old `verify-purchase` path retains genuine
Apple verification but cannot bypass a frozen external-source settlement. The
existing signed-revocation path still recognizes client-reported local credits
through the shared ledger and revokes them without another credit.

Settlement uniqueness is `(bundle_id,environment,transaction_id)`; neither user
nor source is part of that key. The first user/source/SKU/quantity/order/context
are immutable. Repeated confirmed requests return the saved result. Evidence
fingerprints may change without changing the business association or permitting
a second external effect. Financial ownership evidence is retained across
account deletion, matching the existing A reconciliation ledger; a new account
cannot acquire it by knowing an old device or transaction ID.

Socket orders use a clearly separate external web entitlement/balance authority.
They do not represent Bibi's native diamond asset and never write its wallet or
Apple transaction ledger. The original service confirms and owns that web
balance. No external balance-read API was supplied or invented; it remains
visible/refreshable through the original web service, not the native diamond
display. This avoids two independent writers for the same native asset.

## External confirmation and recovery limits

Only Socket-source orders POST to fixed `/bibi/diamonds/settle`. The outgoing
whitelist is the four original string fields: version, device, transaction and
App receipt, plus a real optional original order. Source/product/quantity,
push/delivery fields, Supabase JWT, caller headers and authentication requests
are not forwarded. Socket Apple SKUs can be outside the nine native products.
HTTP 2xx plus lexically integer code zero is required. A static console response
template describes format and is not evidence of actual Apple validation.

The database first records a 45-second processing lease/owner/generation, then
durably marks forwarding before the HTTP request. Duplicates do not forward
while processing. An expired unsent lease can be reclaimed; a lease that might
have sent becomes `needsReconciliation`, not a new HTTP operation. CAS prevents
an old lease from overwriting a newer one. Confirmed repeats never forward.

Known upstream success is persisted as `upstreamConfirmed` before final result
commit. Only that local persistence may be retried once in the same request.
After a final-result database failure, owner status/confirm can finalize the
persisted success without calling upstream again. A crash after upstream success
but before its first durable proof remains an unknown-outcome limitation.

No verified upstream idempotency or order-status query was supplied. Therefore
timeouts, ambiguous HTTP/JSON, and expired potentially-sent requests remain
`needsReconciliation`. Explicit nonzero business responses are retained as
`rejected`; receipt fingerprints may be updated but unknown rejection codes are
not automatically resent. There are no confirmed machine-code mappings for
receipt-staleness or safe rejection replay, so none are invented. Such orders
need actual original-service reconciliation/capability evidence before retrying
a side effect. Missing historical associations are a real recovery limitation,
not a successfully restored order or an ordinary network retry.

## Checks and deployment boundary

`b-server-offline-verification.json` records actual in-memory PostgreSQL/PLpgSQL
execution of the migration and deployable Edge handlers with offline fetch
fixtures. Checks cover transaction uniqueness, ledger-failure rollback, old A
dedup/recovery/revocation, cross-user/source denial, private-role denial, external
authority, CAS leases, unknown-outcome no-resend, updated evidence without
rebinding, known-upstream persistence recovery, strict code literals, bootstrap
branches, self-origin rejection, byte cap, timeout and exact no-JWT whitelists.
The first test attempt had an offline fixture routing mistake in the self-origin
case; it is preserved separately and corrected in the final passing run. No
production database was used for those tests. PGlite uses one exclusive
connection, so these results do not claim concurrency load acceptance.

The app's original observer/journal/receipt/finish chain is implemented and
verified separately by the purchase client agent. These backend checks alone
do not establish that client chain or iOS UI behavior. Real external auth,
Socket delivery, confirmation, original-service IP compatibility, Apple catalog,
Sandbox/production purchasing, and WebView balance behavior remain untested.
The owner imports the generated console templates and performs live integration
after delivery; no real external business HTTP or purchase was triggered here.
