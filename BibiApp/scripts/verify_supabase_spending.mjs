// Isolated Sandbox-only backend fixture acceptance; never an Apple purchase test.
// The operator may fund only the exact newly created account after verifying
// the marker's baseline zero balance and temporary profile. No service key here.
import assert from 'node:assert/strict';
import { randomUUID, createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
const { createClient } = await import(process.env.BIBI_SUPABASE_JS_MODULE ?? '@supabase/supabase-js');
assert.ok(process.env.SUPABASE_PUBLISHABLE_KEY && process.env.BIBI_AGREEMENT_VERSION);
const client = createClient('https://yepycfnkkfrfmuwdekka.supabase.co', process.env.SUPABASE_PUBLISHABLE_KEY, {
 auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
 global: { fetch: (input, init) => fetch(input, { ...init, signal: AbortSignal.timeout(12_000) }) },
});
const marker = new URL('../Backend/IntegrationEvidence/spending-fixture-state.json', import.meta.url);
const checks = [];
let userID, failure, cleanup;
const unwrap = result => { assert.ok(!result.error, `Remote operation failed (${result.error?.code ?? 'service_error'}).`); return result.data; };
async function rows(table, column, value) {
 let query = client.from(table).select('*');
 return unwrap(await (column ? query.eq(column, value) : query));
}
async function command(action, payload, id = randomUUID()) {
 return unwrap(await client.rpc('bibi_command', { p_operation: id, p_action: action, p_payload: payload }));
}
async function balance(environment = 'Sandbox') { return Number((await rows('bibi_wallets', 'environment', environment))[0].balance); }
async function state() { return (await rows('bibi_cosmetics', 'environment', 'Sandbox'))[0]; }
async function waitFor(predicate, label) {
 const until = Date.now() + 55_000;
 while (Date.now() < until) {
  if (await predicate()) return;
  await new Promise(resolve => setTimeout(resolve, 1_500));
 }
 throw new Error(`Timed out awaiting scoped fixture preparation: ${label}.`);
}
try {
 const auth = unwrap(await client.auth.signInAnonymously());
 userID = auth.user.id;
 unwrap(await client.rpc('bibi_enroll', { p_version: process.env.BIBI_AGREEMENT_VERSION, p_adult: true, p_name: 'Acceptance Sandbox Spending' }));
 assert.equal(await balance(), 0);
 assert.equal(await balance('Production'), 0);
 const manifest = JSON.parse(await readFile(new URL('../Backend/catalog-migration/media-manifest.json', import.meta.url), 'utf8'));
 const source = manifest.objects.filter(item => item.mime_type === 'video/mp4').sort((a, b) => a.byte_count - b.byte_count)[0];
 const bytes = await readFile(new URL('../../' + source.source_paths[0], import.meta.url));
 assert.equal(createHash('sha256').update(bytes).digest('hex'), source.sha256);
 const media = await command('stage_media', { mime_type: 'video/mp4' });
 unwrap(await client.storage.from(media.bucket_id).upload(media.object_path, bytes, { contentType: 'video/mp4', upsert: false }));
 assert.equal(unwrap(await client.functions.invoke('media-finalize', { body: { media_id: media.id } })).status, 'ready');
 const video = await command('publish', { kind: 'video', title: 'Sandbox acceptance video', body: 'Temporary isolated backend verification.', media_id: media.id });
 const challenge = (await rows('bibi_challenges'))[0].id;
 await writeFile(marker, JSON.stringify({ phase: 'await_sandbox_fixture_funding', user_id: userID, profile: 'Acceptance Sandbox Spending', sandbox_baseline: 0, production_baseline: 0, requested_sandbox_test_balance: 1200, video_id: video.id }, null, 2));
 await waitFor(async () => (await balance()) === 1200, 'Sandbox-only 1200 test units');
 assert.equal(await balance('Production'), 0);
 assert.equal((await rows('bibi_wallet_activity')).length, 0);
 checks.push('isolated_sandbox_fixture_funding_no_apple_activity_or_production_change');
 const unlockID = randomUUID(), unlockPayload = { item_id: 'frame-sakura', environment: 'Sandbox' };
 await command('cosmetic_unlock', unlockPayload, unlockID);
 assert.equal(await balance(), 1000);
 assert.ok((await state()).owned_ids.includes('frame-sakura'));
 assert.equal((await state()).equipped.avatarFrame, 'frame-sakura');
 await command('cosmetic_unlock', unlockPayload, unlockID);
 await command('cosmetic_unlock', unlockPayload);
 assert.equal(await balance(), 1000);
 assert.equal((await rows('bibi_wallet_activity')).filter(item => item.kind === 'unlock').length, 1);
 await command('cosmetic_equip', { kind: 'avatarFrame', item_id: null, environment: 'Sandbox' });
 assert.equal((await state()).equipped.avatarFrame, undefined);
 await command('cosmetic_equip', { kind: 'avatarFrame', item_id: 'frame-sakura', environment: 'Sandbox' });
 assert.equal((await state()).equipped.avatarFrame, 'frame-sakura');
 assert.equal(await balance(), 1000);
 checks.push('unlock_atomic_debit_idempotency_owned_reuse_and_free_equip');
 const entryPayload = { target_id: video.id, challenge_id: challenge, environment: 'Sandbox' };
 const entryID = randomUUID();
 await command('challenge', entryPayload, entryID);
 assert.equal(await balance(), 900);
 await command('challenge', entryPayload, entryID);
 await command('challenge', entryPayload);
 assert.equal(await balance(), 900);
 assert.equal((await rows('bibi_entries')).length, 1);
 assert.ok((await state()).paid_challenge_ids.includes(challenge));
 const wrongEnvironment = await client.rpc('bibi_command', { p_operation: randomUUID(), p_action: 'challenge', p_payload: { challenge_id: challenge, selected: false, environment: 'Production' } });
 assert.match(wrongEnvironment.error?.message ?? '', /original wallet environment/);
 assert.equal(await balance(), 900);
 await command('challenge', { challenge_id: challenge, selected: false, environment: 'Sandbox' });
 assert.equal(await balance(), 1000);
 await command('challenge', { challenge_id: challenge, selected: false, environment: 'Sandbox' });
 assert.equal(await balance(), 1000);
 assert.equal((await rows('bibi_entries')).length, 0);
 checks.push('challenge_debit_replacement_retry_cross_environment_denial_and_once_refund');
 await command('challenge', entryPayload);
 assert.equal(await balance(), 900);
 await command('withdraw', { target_id: video.id });
 assert.equal(await balance(), 1000);
 assert.equal((await rows('bibi_entries')).length, 0);
 assert.equal((await state()).paid_challenge_ids.length, 0);
 checks.push('source_video_withdrawal_removes_entry_and_refunds_original_wallet');
 const deletedVideo = await command('publish', { kind: 'video', title: 'Sandbox deletion video', body: 'Temporary cascade refund verification.', media_id: media.id });
 await command('challenge', { ...entryPayload, target_id: deletedVideo.id });
 assert.equal(await balance(), 900);
 await writeFile(marker, JSON.stringify({ phase: 'await_exact_fixture_video_delete', user_id: userID, video_id: deletedVideo.id, sandbox_balance: 900, expected_balance: 1000 }, null, 2));
 await waitFor(async () => (await rows('bibi_content', 'id', deletedVideo.id)).length === 0, 'exact temporary source video deletion');
 assert.equal(await balance(), 1000);
 assert.equal(await balance('Production'), 0);
 assert.equal((await rows('bibi_entries')).length, 0);
 assert.equal((await state()).paid_challenge_ids.length, 0);
 const activity = await rows('bibi_wallet_activity');
 assert.equal(activity.filter(item => item.kind === 'challenge').length, 3);
 assert.equal(activity.filter(item => item.kind === 'refund').length, 3);
 assert.equal(activity.filter(item => ['credit', 'gift', 'reversal'].includes(item.kind)).length, 0);
 checks.push('source_video_delete_cascade_refund_and_exact_ledger_no_apple_credit');
} catch (error) { failure = error instanceof Error ? error.message : 'Unknown verification failure.'; }
finally {
 if (userID) {
  try {
   assert.equal(unwrap(await client.functions.invoke('delete-account', { body: { confirm_delete: true } })).status, 'deleted');
   cleanup = { user_id: userID, status: 'deleted' };
  } catch { cleanup = { user_id: userID, status: 'requires_scoped_admin_cleanup' }; }
 }
 await writeFile(marker, JSON.stringify({ phase: 'finished', user_id: userID, cleanup, failure: failure ?? null }, null, 2));
}
console.log(JSON.stringify({ project_ref: 'yepycfnkkfrfmuwdekka', checks, cleanup, failure: failure ?? null, limits: ['Sandbox test units only; no Apple purchase or verified credit.', 'No Production wallet funding.', 'No iOS runtime acceptance.'] }, null, 2));
if (failure || cleanup?.status !== 'deleted') process.exitCode = 1;
