# B stage contract decisions

The contract was generated after the verified A checkpoint and before B code
integration. It is bound to external origin `https://bibi.byig.top`, application
ID string `48369038` and Supabase project `yepycfnkkfrfmuwdekka`.

## Routing and authority

The two external POST routes are `/bibi/constellation/entry` and
`/bibi/diamonds/settle`. The former receives only the four named platform fields;
the latter is a Supabase-only upstream and receives the four purchase strings
plus an optional real original-order reference. The application ID identifies
the console import and bootstrap context; it is not an extra HTTP field.

Bootstrap performs one bounded server-side authentication preflight. Presence of
the actual `constellation_gateway` key selects the original external origin;
ordinary success without that key selects the precise current Supabase origin.
The key's value is never a web address. Errors cannot select a native fallback.
Only the external branch subsequently authenticates directly from the App, and
all later ticket refreshes remain direct. Server and device requests therefore
have different network sources; no device-IP impersonation is used.

Native wallet purchases credit the existing Supabase diamond wallet once. This
is the explicitly selected client-trust settlement model, not Apple receipt
verification or protection against forged payment declarations.

Socket checkout is a separate external web-order source. Its entitlement and
balance authority is the external service, and it never increments the native
Bibi diamond wallet. This separation avoids two writable authorities for the
same native asset. The App does not invent an external-balance read API; the
external page/service remains responsible for presenting that independent
balance. Actual external confirmation behavior still requires owner acceptance
after console import.

All orders freeze their original user, source, product, quantity, environment
and optional original order before payment. Receipt evidence may be refreshed
without changing those identities. An unknown historical association is an
unresolved reconciliation case, never a new user's local purchase. Upstream
idempotency/query support has not been established; an ambiguous forwarded
order must not be blindly resent.

## Events and presentation

The four console slots map to `ConstellationReady`, `DiamondCheckout`,
`ConstellationExpired` and `OpenStoryLink`. Complete business JSON and metadata
are posted by the transport to one independent receiver before any side effect.

The two business invalidations are `CircleContentChanged` and
`ConversationMessagesChanged`. Their handlers refresh existing authorized
repositories. The real Supabase publication can supply these notifications via
the project adapter; external Socket publication of these additional events is
not created by the fourteen-entry console import. Applied receipts, business
acknowledgements and replay requests remain distinct from payment recovery and
from Socket transport ACKs. External receipt/replay support remains unverified.

Cold restoration uses an opaque themed loading root. A stored marker alone
cannot bypass bootstrap or authentication. Web handoff completes native loading
only after actual full-screen web coverage; document navigation completion and
the formal B marker are separate. External expiry preserves the independent
Supabase identity and requires a new explicit login action.

## Artifacts and verification boundary

`generated/interface-template-48369038.json` contains exactly two interfaces.
`generated/configuration-template-48369038.json` contains exactly fourteen
entries. English filenames follow the repository's authored-content rule;
their structures and compact nested JSON are the unchanged console format.
All aliases and runtime constants come from this one frozen contract.

The owner has authorized compilation and bounded isolated Supabase checks.
No external authentication, Socket connection, upstream purchase confirmation,
real Apple transaction, iOS app launch, simulator or iOS tests are authorized by
that verification scope. Code/build/deployment, actual recovery-test execution
and online acceptance must be reported separately.

## Subsequent offline validation authorization and result

The owner later explicitly authorized actual iOS purchase-chain offline tests,
including the project-required latest-source build/install/launch on Bibi UI
Acceptance. That supersedes the original authorization statement above for this
bounded validation only. The final run passed 31 tests with zero failures/skips,
using controlled Apple/account/network boundaries. No real purchase or live
external service request ran. Full coverage and remaining acceptance/capability
limits are recorded in `integration-record.md` and the purchase-chain evidence.
