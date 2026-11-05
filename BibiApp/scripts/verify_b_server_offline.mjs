// Owner-authorized offline checks. No network, Apple transaction or live database.
// Dependencies are pinned in a temporary directory, outside the app/repository.
import assert from 'node:assert/strict';
import { readFile, writeFile, mkdir, cp } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { randomUUID, createHash } from 'node:crypto';
const runtime = process.env.BIBI_B_VALIDATION_RUNTIME ?? '/private/tmp/bibi-b-server-validation';
const { PGlite } = await import(pathToFileURL(`${runtime}/node_modules/@electric-sql/pglite/dist/index.js`).href);
const ts = (await import(pathToFileURL(`${runtime}/node_modules/typescript/lib/typescript.js`).href)).default;
const root = new URL('../../', import.meta.url), backend = new URL('../Backend/', import.meta.url);
const checks = [], pg = new PGlite();
const source = await readFile(new URL('schema.sql', backend), 'utf8');
function section(start, end) { return source.slice(source.indexOf(start), source.indexOf(end)); }
await pg.exec(`create role anon; create role authenticated; create role service_role;
 create schema auth; create schema bibi_private; create table auth.users(id uuid primary key);
 grant usage on schema bibi_private to authenticated,service_role;
 ${section('create table public.bibi_profiles', 'create table public.bibi_circles')}
 ${section('create table public.bibi_wallets', 'create table bibi_private.operations')}
 ${section('create table bibi_private.apple_transactions', 'create table bibi_private.gifts')}
 ${section('insert into bibi_private.products values', 'insert into bibi_private.gifts values')}`);
await pg.exec(await readFile(new URL('refund-ordering.sql', backend), 'utf8'));
await pg.exec(await readFile(new URL('b-settlement.sql', backend), 'utf8'));
checks.push('actual_postgresql_migration_executes');
const a = randomUUID(), b = randomUUID();
for (const user of [a, b]) await pg.query(`insert into auth.users values($1);
`, [user]);
await pg.query(`insert into public.bibi_profiles(id,display_name) values($1,'Offline A'),($2,'Offline B')`, [a, b]);
await pg.query(`insert into public.bibi_consents(user_id,agreement_version,adult_declared) values($1,'offline',true),($2,'offline',true)`, [a, b]);
await pg.query(`insert into public.bibi_wallets(user_id,environment) values($1,'Sandbox'),($1,'Production'),($2,'Sandbox'),($2,'Production')`, [a, b]);
const product = 'ldbsrbbhebevxdjf', env = 'Sandbox', contract = 'bibi-48369038-v1';
const base = { environment: env, source: 'bibi_wallet', product_id: product, quantity: 1, contract_id: contract,
 receipt_sha256: 'a'.repeat(64), context: { app_version: '1.0', device_no: 'offline-installation' } };
async function rpc(action, request, user = a) {
 return (await pg.query(`select public.bibi_settlement($1,$2,$3::jsonb) as value`, [user, action, JSON.stringify(request)])).rows[0].value;
}
async function balance(user = a, environment = env) {
 return Number((await pg.query(`select balance from public.bibi_wallets where user_id=$1 and environment=$2`, [user, environment])).rows[0].balance);
}
const first = await rpc('settle_local', { ...base, transaction_id: '10001' });
assert.equal(first.code, 0); assert.equal(first.balance, 400); assert.equal(first.authority, 'supabase');
assert.equal((await rpc('settle_local', { ...base, transaction_id: '10001' })).balance, 400);
assert.equal(await balance(), 400);
assert.equal((await rpc('settle_local', { ...base, transaction_id: '10001' }, b)).category, 'ownership_conflict');
assert.equal((await rpc('claim_remote', { ...base, transaction_id: '10001', source: 'constellation_order' })).category, 'ownership_conflict');
await pg.query(`select bibi_private.credit_purchase($1,'10001','Sandbox',$2,1)`, [a, product]);
assert.equal(await balance(), 400);
assert.equal((await pg.query(`select verification_source from bibi_private.apple_transactions where transaction_id='10001'`)).rows[0].verification_source, 'client_reported');
checks.push('local_atomic_once_cross_user_cross_source_and_legacy_adapter_deduplication');
assert.equal((await rpc('status', { environment: env, transaction_id: '10001' }, b)).category, 'association_missing');
const countBefore = (await pg.query(`select count(*)::int as n from bibi_private.settlements`)).rows[0].n;
assert.equal((await rpc('status', { environment: env, transaction_id: '99999' })).category, 'association_missing');
assert.equal((await pg.query(`select count(*)::int as n from bibi_private.settlements`)).rows[0].n, countBefore);
await pg.query(`select bibi_private.credit_purchase($1,'10002','Sandbox',$2,1)`, [a, product]);
assert.equal((await rpc('status', { environment: env, transaction_id: '10002' })).recovery.provenance, 'legacy_apple_server');
assert.equal(await balance(), 800);
checks.push('owner_scoped_unknown_status_never_claims_and_verified_legacy_local_recovery');
await pg.exec(`create function bibi_private.offline_fail_credit() returns trigger language plpgsql as $$ begin
 if new.transaction_id='10004' then raise exception 'offline credit persistence failure'; end if; return new; end $$;
 create trigger offline_fail_credit before insert on public.bibi_wallet_activity for each row execute function bibi_private.offline_fail_credit();`);
await assert.rejects(rpc('settle_local', { ...base, transaction_id: '10004' }));
assert.equal(await balance(), 800);
assert.equal((await pg.query(`select count(*)::int as n from bibi_private.apple_transactions where transaction_id='10004'`)).rows[0].n, 0);
assert.equal((await pg.query(`select count(*)::int as n from bibi_private.settlements where transaction_id='10004'`)).rows[0].n, 0);
await pg.exec(`drop trigger offline_fail_credit on public.bibi_wallet_activity`);
checks.push('local_credit_ledger_failure_rolls_back_balance_transaction_and_settlement_atomically');
const remote = { ...base, source: 'constellation_order', product_id: 'external.only.sku', transaction_id: '20001', order_reference: 'offline-original-order' };
const claim = await rpc('claim_remote', remote);
assert.equal(claim.dispatch, true);
assert.equal((await rpc('claim_remote', remote)).state, 'processing');
assert.equal((await rpc('claim_remote', remote)).dispatch, undefined);
const lease = { environment: env, transaction_id: remote.transaction_id, lease_owner: claim.lease_owner };
assert.equal((await rpc('mark_forwarding', lease)).dispatch, true);
assert.equal((await rpc('record_upstream', lease)).state, 'upstreamConfirmed');
// Force only final-result persistence to fail, after upstream proof was committed.
await pg.exec(`create function bibi_private.offline_fail_finalize() returns trigger language plpgsql as $$ begin
 if new.state='confirmed' and old.state='upstreamConfirmed' then raise exception 'offline persistence failure'; end if; return new; end $$;
 create trigger offline_fail_finalize before update on bibi_private.settlements for each row execute function bibi_private.offline_fail_finalize();`);
await assert.rejects(rpc('finalize_remote', lease));
await pg.exec(`drop trigger offline_fail_finalize on bibi_private.settlements`);
assert.equal((await rpc('status', { environment: env, transaction_id: remote.transaction_id })).state, 'confirmed');
assert.equal((await rpc('claim_remote', remote)).state, 'confirmed');
assert.equal(await balance(), 800);
await assert.rejects(pg.query(`select bibi_private.credit_purchase($1,'20001','Sandbox',$2,1)`, [a, product]));
checks.push('external_only_authority_and_upstream_confirmed_persistence_recovery_without_forwarding');
const unknown = { ...remote, transaction_id: '20002' };
const uncertain = await rpc('claim_remote', unknown);
await rpc('mark_forwarding', { ...lease, transaction_id: '20002', lease_owner: uncertain.lease_owner });
await pg.exec(`update bibi_private.settlements set lease_until=now()-interval '1 second' where transaction_id='20002'`);
assert.equal((await rpc('claim_remote', unknown)).state, 'needsReconciliation');
assert.equal((await rpc('claim_remote', { ...unknown, receipt_sha256: 'b'.repeat(64) })).dispatch, undefined);
assert.equal((await pg.query(`select evidence_version from bibi_private.settlements where transaction_id='20002'`)).rows[0].evidence_version, 2);
const unsent = { ...remote, transaction_id: '20003' };
const unsentFirst = await rpc('claim_remote', unsent);
await pg.exec(`update bibi_private.settlements set lease_until=now()-interval '1 second' where transaction_id='20003'`);
const unsentNext = await rpc('claim_remote', unsent);
assert.notEqual(unsentNext.lease_owner, unsentFirst.lease_owner);
assert.notEqual((await rpc('mark_forwarding', { ...lease, transaction_id: '20003', lease_owner: unsentFirst.lease_owner })).code, 0);
checks.push('expired_sent_lease_never_blindly_resends_unsent_lease_reclaims_and_old_CAS_fails');
const rejectedRequest = { ...remote, transaction_id: '20005' };
const rejectedClaim = await rpc('claim_remote', rejectedRequest);
const rejectedLease = { ...lease, transaction_id: '20005', lease_owner: rejectedClaim.lease_owner };
await rpc('mark_forwarding', rejectedLease);
assert.equal((await rpc('record_outcome', { ...rejectedLease, outcome: 'rejected' })).state, 'rejected');
assert.equal((await rpc('claim_remote', { ...rejectedRequest, receipt_sha256: 'c'.repeat(64) })).state, 'rejected');
assert.equal((await rpc('claim_remote', { ...rejectedRequest, context: { ...base.context, device_no: 'changed-device' } })).category, 'ownership_conflict');
assert.equal((await pg.query(`select evidence_version from bibi_private.settlements where transaction_id='20005'`)).rows[0].evidence_version, 2);
await pg.query(`select bibi_private.revoke_purchase('10001','Sandbox')`);
assert.equal(await balance(), 400);
assert.equal((await rpc('status', { environment: env, transaction_id: '10001' })).category, 'ownership_conflict');
assert.equal((await rpc('settle_local', { ...base, transaction_id: '10001' })).category, 'ownership_conflict');
await assert.rejects(pg.query(`select bibi_private.credit_purchase($1,'10001','Sandbox',$2,1)`, [a, product]));
assert.equal((await rpc('settle_local', { ...base, environment: 'Production', transaction_id: '10001' })).state, 'confirmed');
assert.equal(await balance(a, 'Production'), 400);
checks.push('rejected_evidence_updates_without_business_rebinding_and_existing_revocation_compatibility');
await pg.exec(`set role authenticated`);
await assert.rejects(rpc('status', { environment: env, transaction_id: '10001' }));
await assert.rejects(pg.query(`select * from bibi_private.settlements`));
await pg.exec(`reset role`);
checks.push('authenticated_role_cannot_call_service_rpc_or_read_private_settlements');

// Transpile the actual deployable Edge sources into an isolated import tree.
const compiled = `${runtime}/compiled-${randomUUID()}`;
await mkdir(`${compiled}/_shared`, { recursive: true });
await writeFile(`${compiled}/package.json`, '{"type":"module"}');
for (const name of ['_shared/http.ts', '_shared/bibi-config.ts', '_shared/bibi-upstream.ts', 'bibi-begin/index.ts', 'bibi-settlement/index.ts']) {
 const target = `${compiled}/${name.replace(/\.ts$/, '.js')}`;
 await mkdir(target.slice(0, target.lastIndexOf('/')), { recursive: true });
 const text = (await readFile(new URL(`functions/${name}`, backend), 'utf8'))
  .replaceAll('npm:@supabase/supabase-js@2.57.4', 'file:///private/tmp/bibi-a-validation-runtime/node_modules/@supabase/supabase-js/dist/main/index.js')
  .replaceAll(/from "(\.\.?\/[^\"]+)\.ts"/g, 'from "$1.js"');
 const result = ts.transpileModule(text, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext }, reportDiagnostics: true });
 assert.equal(result.diagnostics?.filter(item => item.category === ts.DiagnosticCategory.Error).length ?? 0, 0);
 await writeFile(target, result.outputText);
}
await cp(new URL('functions/_shared/bibi-settings.json', backend), `${compiled}/_shared/bibi-settings.json`);
assert.equal(await readFile(new URL('functions/_shared/bibi-settings.json', backend), 'utf8'),
 await readFile(new URL('docs/backend-api/generated/supabase-server-settings.json', root), 'utf8'));
let serve, activeUser = a, upstreamCalls = [], upstreamResponse = { status: 200, body: '{"code":0,"data":{}}' };
let failPersistenceOnce;
const deploymentEnv = { SUPABASE_URL: 'https://yepycfnkkfrfmuwdekka.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'offline-admin', SUPABASE_ANON_KEY: 'offline-public' };
globalThis.Deno = { env: { get: name => deploymentEnv[name] }, serve: handler => { serve = handler; } };
globalThis.fetch = async (input, init = {}) => {
 const url = new URL(typeof input === 'string' ? input : input.url ?? input.toString());
 if (url.origin === 'https://bibi.byig.top') {
  upstreamCalls.push({ path: url.pathname, headers: new Headers(init.headers), body: JSON.parse(init.body), redirect: init.redirect });
  return new Response(upstreamResponse.body, { status: upstreamResponse.status });
 }
 assert.equal(url.origin, deploymentEnv.SUPABASE_URL, 'An unapproved external host was requested.');
 if (url.pathname === '/auth/v1/user') return Response.json({ id: activeUser, is_anonymous: true });
 if (url.pathname === '/rest/v1/bibi_profiles') return Response.json([{ id: activeUser, account_status: 'active' }]);
 if (url.pathname === '/rest/v1/rpc/bibi_settlement') {
  const payload = JSON.parse(init.body);
  if (failPersistenceOnce === payload.p_action) { failPersistenceOnce = undefined; return Response.json({ message: 'offline persistence failure' }, { status: 503 }); }
  return Response.json(await rpc(payload.p_action, payload.p_request, payload.p_user));
 }
 throw new Error('Unexpected offline network route.');
};
const helpers = await import(pathToFileURL(`${compiled}/_shared/bibi-upstream.js`).href);
for (const raw of ['true', '"0"', '0.0', '0e0', '0.1']) assert.throws(() => helpers.integerField(`{"code":${raw}}`, 'code'));
assert.equal(helpers.integerField('{"code":0}', 'code'), 0);
assert.throws(() => helpers.integerField('{"code":0,"code":1}', 'code'));
checks.push('literal_integer_code_rejects_bool_string_decimal_exponent_and_duplicate');
await import(pathToFileURL(`${compiled}/bibi-begin/index.js`).href);
const bootstrap = serve;
const device = { bibi_edition: '1.0', bell_mark: '', starlight_installation: 'offline-installation', constellation_delivery: 2 };
const request = payload => new Request('https://yepycfnkkfrfmuwdekka.supabase.co/functions/v1/offline', {
 method: 'POST', headers: { Authorization: 'Bearer offline-user-token', 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
});
for (const value of [null, '', false, 0]) {
 upstreamResponse = { status: 401, body: JSON.stringify({ code: 8, data: { constellation_gateway: value } }) };
 const result = await (await bootstrap(request(device))).json();
 assert.equal(result.data.constellation_origin, 'https://bibi.byig.top');
}
upstreamResponse = { status: 200, body: '{"code":0,"data":{}}' };
assert.equal((await (await bootstrap(request(device))).json()).data.constellation_origin, deploymentEnv.SUPABASE_URL);
for (const response of [{ status: 401, body: '{"code":0,"data":{}}' }, { status: 200, body: '{"code":4,"data":{}}' }, { status: 200, body: 'broken' }, { status: 200, body: '{"code":0}' }]) {
 upstreamResponse = response;
 assert.notEqual((await bootstrap(request(device))).status, 200);
}
for (const call of upstreamCalls) {
 assert.equal(call.path, '/bibi/constellation/entry');
 assert.deepEqual(Object.keys(call.body).sort(), Object.keys(device).sort());
 assert.equal(call.headers.has('Authorization'), false); assert.equal(call.headers.has('X-Forwarded-For'), false);
 assert.equal(call.redirect, 'error');
}
const priorCalls = upstreamCalls.length;
const configHelpers = await import(pathToFileURL(`${compiled}/_shared/bibi-config.js`).href);
deploymentEnv.SUPABASE_URL = 'https://bibi.byig.top';
assert.throws(() => configHelpers.configuration());
assert.equal(upstreamCalls.length, priorCalls);
deploymentEnv.SUPABASE_URL = 'https://yepycfnkkfrfmuwdekka.supabase.co';
await assert.rejects(helpers.fixedPost(new URL('https://offline.invalid'), {}, async () => new Response('x'.repeat(100)), 20, 5));
await assert.rejects(helpers.fixedPost(new URL('https://offline.invalid'), {}, async (_url, init) => new Promise((_resolve, reject) => init.signal.addEventListener('abort', () => reject(new Error('offline timeout')))), 5));
checks.push('actual_bootstrap_key_presence_native_error_branches_whitelist_self_origin_limits_and_timeout');

await import(pathToFileURL(`${compiled}/bibi-settlement/index.js`).href);
const settlement = serve;
const confirm = { action: 'confirm', environment: env, contract_id: contract, diamond_origin: 'bibi_wallet',
 diamond_product: product, diamond_count: 1, diamond_reference: '30001', diamond_proof: 'AQID', bibi_edition: '1.0', starlight_installation: 'offline-installation' };
upstreamCalls = [];
const localResult = await (await settlement(request(confirm))).json();
assert.equal(localResult.state, 'confirmed'); assert.equal(localResult.authority, 'supabase');
assert.equal(upstreamCalls.length, 0);
const externalConfirm = { ...confirm, diamond_origin: 'constellation_order', diamond_product: 'external.sku.outside.native.catalog', diamond_reference: '30002', orbit_order: 'original-offline-order' };
upstreamResponse = { status: 200, body: '{"code":0,"message":"offline format fixture"}' };
failPersistenceOnce = 'record_upstream';
const externalResult = await (await settlement(request(externalConfirm))).json();
assert.equal(externalResult.state, 'confirmed'); assert.equal(externalResult.authority, 'external');
assert.equal(externalResult.balance, undefined); assert.equal(upstreamCalls.length, 1);
assert.deepEqual(Object.keys(upstreamCalls[0].body).sort(), ['bibi_edition', 'starlight_installation', 'diamond_reference', 'diamond_proof', 'orbit_order'].sort());
assert.equal(upstreamCalls[0].headers.has('Authorization'), false);
assert.equal((await (await settlement(request(externalConfirm))).json()).state, 'confirmed');
assert.equal(upstreamCalls.length, 1);
assert.equal((await (await settlement(request({ ...externalConfirm, diamond_reference: '30003', orbit_order: null }))).json()).category, 'invalid_input');
assert.equal((await (await settlement(request({ ...confirm, diamond_origin: undefined }))).json()).category, 'invalid_input');
const unknownConfirm = { ...externalConfirm, diamond_reference: '30004' };
upstreamResponse = { status: 503, body: '{"code":0}' };
assert.equal((await (await settlement(request(unknownConfirm))).json()).state, 'needsReconciliation');
const callsAfterUnknown = upstreamCalls.length;
assert.equal((await (await settlement(request({ ...unknownConfirm, diamond_proof: 'BAUG' }))).json()).state, 'needsReconciliation');
assert.equal(upstreamCalls.length, callsAfterUnknown);
checks.push('actual_edge_local_never_forwards_external_whitelist_confirmation_persistence_retry_and_unknown_no_resend');
await pg.close();
const sql = await readFile(new URL('b-settlement.sql', backend));
console.log(JSON.stringify({ mode: 'offline_only', checks, sql_sha256: createHash('sha256').update(sql).digest('hex'),
 limits: ['No real external authentication, Socket, confirmation or Apple request.', 'PGlite uses actual PostgreSQL/PLpgSQL but one exclusive connection; not a concurrency load test.', 'Offline transaction and receipt values are fixtures, never production records.'] }, null, 2));
