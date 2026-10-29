# Deployment evidence — October 27, 2026

Project: `yepycfnkkfrfmuwdekka` (`Bibi`), organization `LuvNarcisuss's Org`,
Singapore. Dashboard: https://supabase.com/dashboard/project/yepycfnkkfrfmuwdekka

## Database receipts

The Supabase connector returned success for each migration below; a subsequent
migration inventory returned the same names and versions.

| Version | Name | Local source |
| --- | --- | --- |
| 20261027043618 | bibi_authoritative_backend | schema.sql |
| 20261027044111 | bibi_catalog_and_access_hardening | hardening.sql |
| 20261027052750 | bibi_client_read_policies | client-read-policies.sql |
| 20261027052819 | bibi_atomic_client_commands | atomic-client-commands.sql |
| 20261027052924 | bibi_refund_ordering | refund-ordering.sql |
| 20261027053557 | bibi_comment_threading | comment-threading.sql |

An early initial migration attempt was rejected by automatic approval review
because it changed schema-wide default grants. The global statement was removed;
the deployed implementation scopes changes to Bibi objects. No such broad change
was applied. Two later combined client-completion calls returned invalid/expired
request state; inventory confirmed no migration. The changes were then split
into the two separately successful migrations recorded above. There is no
outstanding approval rejection.

Metadata-only inspection counted 20 public Bibi tables and 6 private tables;
all 26 had row security enabled. The final security-advisor query returned an
empty `lints` array. This does not test application authorization under real
user tokens. Initial performance feedback about unused indexes is expected for
an unexercised schema; no load/performance claim follows from it.

## Function inventory

| Name | ID | Version | Returned status | JWT |
| --- | --- | --- | --- | --- |
| media-finalize | 0271bf05-cf8d-42ff-bb20-313b2f23b6b1 | 1 | ACTIVE | true |
| delete-account | 00716dda-f19b-4a11-8285-2830074b28b3 | 1 | ACTIVE | true |
| verify-purchase | b84c1d42-3144-4a1c-aba4-7d47de59638c | 1 | ACTIVE | true |
| apple-notifications | 1156bcc9-f84b-4be0-9e4f-3a1acd4ea146 | 1 | ACTIVE | false |

The webhook authenticates Apple's signature rather than a Supabase session.
Deployment inventory does not prove successful runtime initialization, external
Apple connectivity, receipt acceptance, Storage processing or account deletion.

## Local evidence and limits

- Supabase Swift 2.30.0 source APIs and package manifest were inspected against
  the official tagged source. The later authorized simulator build resolved
  dependencies successfully; the generated `Package.resolved` is retained.
- XcodeGen generated metadata. Plist/project format inspection and
  `git diff --check` completed without reported errors.
- Independent read-only review identified authentication generation races,
  stale message fallback, offset-page duplication, refund-before-credit loss,
  group duplicate retry, missing approved avatars and group controls, and local
  capability wording. The implementation was revised for each. This is static
  correction, not a reproduced-and-passed regression test.
- The later authorized build, installation and launch succeeded on **Bibi UI
  Acceptance** with the backend gate false. Callback/cache and disabled-gate
  boundary tests passed. See `docs/BACKEND-RUN-VERIFICATION.md` for the complete
  local run. Database/Edge acceptance, online requests, purchase transactions,
  Apple Sandbox and production remain unverified by this run.
- The existing user change to StoreKit1Purchasing.swift's unmatched-product
  error message is preserved. No commit, push, release or paid upgrade occurred.

## Guest authentication — October 28, 2026

The owner selected the Toti conversation's one-tap guest approach, replacing
email/password as the normal entry method. Bibi reuses its original illustrated
entry screen, one agreement checkbox and confirmation sheet. Online entry uses
`Log in`; the declaration explicitly includes 18+. Bibi's own agreement sources,
assets, identity, local data and empty-personal-account rules remain unchanged.

`BackendServices.signInAsGuest` verifies Keychain access before creating an
anonymous Supabase session, reuses an existing session when enrollment is retried,
and enters only after server enrollment and snapshot loading succeed. Existing
restore logic preserves the account across relaunch. Guest logout warns about
irrecoverable access loss. Guest deletion requires explicit confirmation without
a password and retains the session during interrupted media cleanup. Existing
email recovery links remain available for earlier email accounts.

Cloud evidence: `bibi_guest_auth` migration `20261028090404` is applied;
`delete-account`, `media-finalize`, and `verify-purchase` are ACTIVE version 2
with JWT verification retained. Auth settings returned
`external.anonymous_users=true`; email confirmation remains enabled for email
accounts. No accounts were created or deleted during this configuration work.

SQL readback confirms guest eligibility still checks live Auth sessions and adult
consent. All public Bibi tables retain RLS. The security advisor reports 27
anonymous-access warnings after enabling this intended authentication method;
they are not a clean-advisor result or proof of cross-account safety. The six
private-table policies were inspected and all retain `USING (false)`. Public and
Storage ownership policies still require live-session ownership/membership.
See [Supabase advisor guidance](https://supabase.com/docs/guides/database/database-advisors?queryGroups=lint&lint=0012_auth_allow_anonymous_sign_ins).

Verification: 532 static checks and whitespace inspection passed. A Keychain
round-trip regression was authored but not executed. This revision has not been
compiled, installed or runtime-tested; earlier runtime reports do not cover it.
Real guest creation, enrollment, relaunch, isolation and interrupted deletion
need end-to-end acceptance. Keep `BibiBackendEnabled=false`; the installed app
has not been switched to cloud login. SMTP is not a guest-login dependency.

