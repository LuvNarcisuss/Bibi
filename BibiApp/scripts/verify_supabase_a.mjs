// Explicitly authorized, bounded remote acceptance. Never runs an iOS app.
// Use @supabase/supabase-js 2.57.4, matching the existing Edge dependency.
// Provide BIBI_SUPABASE_JS_MODULE as a file URL when installed outside this repo.
// Required: SUPABASE_PUBLISHABLE_KEY and BIBI_AGREEMENT_VERSION.
import assert from 'node:assert/strict';
import { randomUUID, createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';

const { createClient } = await import(process.env.BIBI_SUPABASE_JS_MODULE ?? '@supabase/supabase-js');
const url = process.env.SUPABASE_URL ?? 'https://yepycfnkkfrfmuwdekka.supabase.co';
assert.equal(url, 'https://yepycfnkkfrfmuwdekka.supabase.co', 'Only the authorized Bibi project is allowed.');
const key = process.env.SUPABASE_PUBLISHABLE_KEY;
const agreement = process.env.BIBI_AGREEMENT_VERSION;
assert.ok(key && agreement, 'Provide the public API key and current agreement version.');
const clients = [], channels = [], checks = [], cleanup = [], fixtureConversations = [];
const diagnostics = [];
const chatOnly = process.argv.includes('--chat-only');
const businessOnly = process.argv.includes('--business-only');
const deadline = Date.now() + 180_000;
function check(name) { checks.push(name); }
function unwrap(result) {
  assert.ok(!result.error, `Remote operation failed (${result.error?.code ?? 'service_error'}).`);
  return result.data;
}
function budget() { assert.ok(Date.now() < deadline, 'Acceptance deadline exceeded.'); }
async function command(client, action, payload, id = randomUUID()) {
  budget();
  return unwrap(await client.rpc('bibi_command', { p_operation: id, p_action: action, p_payload: payload }));
}
async function denied(promise) { assert.ok((await promise).error, 'Unauthorized operation unexpectedly succeeded.'); }
async function rows(client, table, column, value) {
  budget();
  const query = client.from(table).select('*');
  return unwrap(await (column ? query.eq(column, value) : query));
}
async function makeAccount(label) {
  budget();
  const client = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    global: { fetch: (input, init) => fetch(input, { ...init, signal: AbortSignal.timeout(12_000) }) },
    realtime: { timeout: 8_000 },
  });
  const auth = unwrap(await client.auth.signInAnonymously());
  const item = { client, id: auth.user.id, label };
  clients.push(item);
  unwrap(await client.rpc('bibi_enroll', { p_version: agreement, p_adult: true, p_name: `Acceptance ${label}` }));
  return item;
}
async function watch(client, conversation) {
  const events = [], waiting = new Map();
  const session = unwrap(await client.auth.getSession()).session;
  diagnostics.push({ phase: 'before_subscribe', hasSession: Boolean(session), hasSessionToken: Boolean(session?.access_token), hasRealtimeToken: Boolean(client.realtime.accessTokenValue) });
  assert.ok(session?.access_token, 'An authenticated session is required before Realtime.');
  await client.realtime.setAuth(session.access_token);
  diagnostics.push({ phase: 'authenticated_before_join', hasRealtimeToken: Boolean(client.realtime.accessTokenValue) });
  const channel = client.channel(`acceptance:${randomUUID()}`).on('postgres_changes', {
    event: 'INSERT', schema: 'public', table: 'bibi_messages', filter: `conversation_id=eq.${conversation}`,
  }, event => {
    const id = event.new.id;
    events.push(id);
    waiting.get(id)?.();
  });
  channels.push({ client, channel });
  await new Promise((resolve, reject) => {
    let joined = false, extensionReady = false;
    const ready = () => { if (joined && extensionReady) { clearTimeout(timer); resolve(); } };
    const timer = setTimeout(() => reject(new Error(`Realtime subscription timed out (joined=${joined}, postgresReady=${extensionReady}).`)), 12_000);
    channel.on('system', {}, event => {
      const message = String(event.message ?? '').replace(/https?:\/\/\S+/g, '[url]').replace(/eyJ[A-Za-z0-9_.-]+/g, '[token]');
      diagnostics.push({ phase: 'system', status: event.status, extension: event.extension, message });
      if (event.extension === 'postgres_changes' && event.status === 'ok') { extensionReady = true; ready(); }
      if (event.extension === 'postgres_changes' && event.status === 'error') {
        clearTimeout(timer); reject(new Error('Postgres Changes extension rejected subscription.'));
      }
    });
    channel.subscribe(status => {
      diagnostics.push({ phase: 'channel_status', status, postgresBindings: (channel.bindings.postgres_changes ?? []).map(binding => ({ hasServerID: binding.id !== undefined, event: binding.filter.event, schema: binding.filter.schema, table: binding.filter.table })) });
      if (status === 'SUBSCRIBED') { joined = true; ready(); }
      if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
        clearTimeout(timer); reject(new Error(`Realtime subscription failed (${status}).`));
      }
    });
  });
  return {
    events,
    async receive(id) {
      if (events.includes(id)) return;
      await new Promise((resolve, reject) => {
        const timer = setTimeout(() => { waiting.delete(id); reject(new Error('Persistent message event timed out.')); }, 10_000);
        waiting.set(id, () => { clearTimeout(timer); waiting.delete(id); resolve(); });
      });
    },
    async stop() { await client.removeChannel(channel); },
  };
}

let failure;
try {
  const a = await makeAccount('A'), b = await makeAccount('B'), c = await makeAccount('C');
  for (const table of ['bibi_saved', 'bibi_likes', 'bibi_entries', 'bibi_circle_members', 'bibi_follows', 'bibi_blocks', 'bibi_conversation_members', 'bibi_messages']) {
    assert.equal((await rows(a.client, table)).length, 0, `New account has personal rows in ${table}.`);
  }
  check('new_account_personal_state_empty');
  assert.ok((await rows(a.client, 'bibi_circles')).length > 0);
  assert.ok((await rows(a.client, 'bibi_challenges')).length > 0);
  check('authenticated_catalog_read');
  const bootstrap = unwrap(await a.client.functions.invoke('bibi-begin', { body: {
    appVersion: '0.1.0', pushToken: '', deviceNo: randomUUID(), roomPushMsgType: 2, action: 'bootstrap',
  } }));
  assert.equal(bootstrap.code, 0);
  assert.deepEqual(bootstrap.data, {});
  check('authenticated_a_bootstrap_empty_configuration');
  const exported = JSON.parse(await readFile(new URL('../Backend/catalog-migration/catalog.json', import.meta.url), 'utf8'));
  const manifest = JSON.parse(await readFile(new URL('../Backend/catalog-migration/media-manifest.json', import.meta.url), 'utf8'));
  const catalog = await rows(a.client, 'bibi_content');
  assert.equal(catalog.length, 56);
  assert.equal((await rows(a.client, 'bibi_editorial_profiles')).length, 7);
  assert.equal((await rows(a.client, 'bibi_media')).length, manifest.objects.length);
  assert.ok(exported);
  check('new_user_complete_content_editorial_and_media_visibility');
  if (!chatOnly && !businessOnly) {
  let shortSignature;
  for (const object of manifest.objects) {
    budget();
    const signed = unwrap(await a.client.storage.from(object.bucket_id).createSignedUrl(object.object_path, 30)).signedUrl;
    const response = await fetch(signed, { signal: AbortSignal.timeout(15_000), cache: 'no-store' });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('content-type')?.split(';')[0], object.mime_type);
    const bytes = Buffer.from(await response.arrayBuffer());
    assert.equal(bytes.length, object.byte_count);
    assert.equal(createHash('sha256').update(bytes).digest('hex'), object.sha256);
    if (object.mime_type === 'video/mp4' && !shortSignature) {
      const ranged = await fetch(signed, { headers: { Range: 'bytes=0-63' }, signal: AbortSignal.timeout(10_000) });
      assert.equal(ranged.status, 206);
      assert.equal((await ranged.arrayBuffer()).byteLength, 64);
      shortSignature = { object, url: unwrap(await a.client.storage.from(object.bucket_id).createSignedUrl(object.object_path, 1)).signedUrl };
    }
  }
  check('all_43_private_media_objects_user_download_hash_mime_and_video_range');
  assert.ok(shortSignature);
  await new Promise(resolve => setTimeout(resolve, 2_500));
  const expired = await fetch(shortSignature.url, { cache: 'no-store', signal: AbortSignal.timeout(10_000) });
  assert.ok(!expired.ok, 'An expired private-media signature was accepted.');
  const renewed = unwrap(await a.client.storage.from(shortSignature.object.bucket_id).createSignedUrl(shortSignature.object.object_path, 30)).signedUrl;
  assert.equal((await fetch(renewed, { headers: { Range: 'bytes=0-63' }, signal: AbortSignal.timeout(10_000) })).status, 206);
  check('expired_private_signature_denied_and_new_signature_restores_access');
  }

  if (businessOnly) {
    await command(a.client, 'profile', { display_name: 'Acceptance profile', biography: 'Temporary verification profile.' });
    assert.equal((await rows(a.client, 'bibi_profiles', 'id', a.id))[0].display_name, 'Acceptance profile');
    assert.equal((await rows(b.client, 'bibi_profiles', 'id', a.id))[0].biography, 'Temporary verification profile.');
    check('profile_update_and_cross_user_public_readback');
    const circleID = (await rows(a.client, 'bibi_circles'))[0].id;
    await command(a.client, 'circle', { circle_id: circleID });
    assert.ok((await rows(a.client, 'bibi_circle_members')).some(item => item.circle_id === circleID));
    check('circle_join_persisted');
    const publicVideo = catalog.find(item => item.kind === 'video' && item.approved_revision);
    const publicPost = catalog.find(item => item.kind === 'post' && item.approved_revision);
    assert.ok(publicVideo && publicPost);
    for (const [action, table] of [['save', 'bibi_saved'], ['like', 'bibi_likes']]) {
      await command(a.client, action, { target_id: publicVideo.id, selected: true });
      assert.equal((await rows(a.client, table, 'content_id', publicVideo.id)).length, 1);
      assert.equal((await rows(b.client, table, 'content_id', publicVideo.id)).length, 0);
      await command(a.client, action, { target_id: publicVideo.id, selected: false });
      assert.equal((await rows(a.client, table, 'content_id', publicVideo.id)).length, 0);
    }
    check('save_and_like_add_remove_owner_readback');
    const reportID = randomUUID();
    await command(a.client, 'report', { target_id: publicVideo.id, reason: 'Other', details: 'Temporary verification report.' }, reportID);
    assert.equal((await rows(a.client, 'bibi_reports', 'id', reportID))[0].hidden, true);
    assert.equal((await rows(a.client, 'bibi_content', 'id', publicVideo.id)).length, 0);
    await command(a.client, 'unhide_report', { target_id: publicVideo.id });
    assert.equal((await rows(a.client, 'bibi_reports', 'id', reportID))[0].hidden, false);
    assert.equal((await rows(a.client, 'bibi_content', 'id', publicVideo.id)).length, 1);
    const profileReportID = randomUUID();
    await command(a.client, 'report', { user_id: b.id, reason: 'Other', details: 'Temporary profile report.' }, profileReportID);
    await command(a.client, 'unhide_report', { user_id: b.id });
    assert.equal((await rows(a.client, 'bibi_reports', 'id', profileReportID))[0].hidden, false);
    check('content_and_profile_reports_unhide_preserves_report');
    const ownPost = await command(a.client, 'publish', { kind: 'post', circle_id: circleID, body: 'Temporary pending post.' });
    assert.equal(ownPost.status, 'pending');
    assert.equal((await rows(a.client, 'bibi_content_revisions', 'id', ownPost.revision_id))[0].status, 'pending');
    assert.equal((await rows(b.client, 'bibi_content', 'id', ownPost.id)).length, 0);
    assert.equal((await rows(b.client, 'bibi_content_revisions', 'content_id', ownPost.id)).length, 0);
    const editPost = await command(a.client, 'publish', { kind: 'post', target_id: ownPost.id, circle_id: circleID, body: 'Temporary edited pending post.' });
    assert.equal(editPost.id, ownPost.id);
    assert.notEqual(editPost.revision_id, ownPost.revision_id);
    assert.equal((await rows(a.client, 'bibi_content_revisions', 'id', editPost.revision_id))[0].body, 'Temporary edited pending post.');
    await command(a.client, 'withdraw', { target_id: ownPost.id });
    assert.equal((await rows(a.client, 'bibi_content', 'id', ownPost.id))[0].withdrawn, true);
    check('post_publish_edit_withdraw_pending_status_and_nonowner_draft_denial');
    for (const [kind, parent] of [['comment', publicVideo.id], ['reply', publicPost.id]]) {
      const created = await command(a.client, 'publish', { kind, parent_id: parent, body: 'Temporary published discussion.' });
      assert.equal(created.status, 'published');
      assert.equal((await rows(b.client, 'bibi_content', 'id', created.id)).length, 1);
      assert.equal((await rows(b.client, 'bibi_content_revisions', 'id', created.revision_id))[0].status, 'approved');
      const edited = await command(a.client, 'publish', { kind, target_id: created.id, parent_id: parent, body: 'Temporary edited discussion.' });
      assert.equal((await rows(b.client, 'bibi_content_revisions', 'id', edited.revision_id))[0].body, 'Temporary edited discussion.');
      await command(a.client, 'withdraw', { target_id: created.id });
      assert.equal((await rows(b.client, 'bibi_content', 'id', created.id)).length, 0);
    }
    check('comment_and_reply_publish_edit_withdraw_public_readback');
    const videoObject = manifest.objects.find(item => item.mime_type === 'video/mp4');
    const videoBytes = await readFile(new URL('../../' + videoObject.source_paths[0], import.meta.url));
    assert.equal(createHash('sha256').update(videoBytes).digest('hex'), videoObject.sha256);
    const ownMedia = await command(a.client, 'stage_media', { mime_type: 'video/mp4' });
    unwrap(await a.client.storage.from(ownMedia.bucket_id).upload(ownMedia.object_path, videoBytes, { contentType: 'video/mp4', upsert: false }));
    assert.equal(unwrap(await a.client.functions.invoke('media-finalize', { body: { media_id: ownMedia.id } })).status, 'ready');
    assert.equal((await rows(b.client, 'bibi_media', 'id', ownMedia.id)).length, 0);
    const ownVideo = await command(a.client, 'publish', { kind: 'video', title: 'Acceptance video', body: 'Temporary private verification video.', media_id: ownMedia.id });
    assert.equal(ownVideo.status, 'pending');
    assert.equal((await rows(b.client, 'bibi_content', 'id', ownVideo.id)).length, 0);
    const walletBefore = (await rows(a.client, 'bibi_wallets', 'environment', 'Production'))[0];
    assert.equal(Number(walletBefore.balance), 0);
    const unlock = await a.client.rpc('bibi_command', { p_operation: randomUUID(), p_action: 'cosmetic_unlock', p_payload: { item_id: 'frame-sakura', environment: 'Production' } });
    assert.match(unlock.error?.message ?? '', /Insufficient available diamonds/);
    const challengeID = (await rows(a.client, 'bibi_challenges'))[0].id;
    const entry = await a.client.rpc('bibi_command', { p_operation: randomUUID(), p_action: 'challenge', p_payload: { target_id: ownVideo.id, challenge_id: challengeID, environment: 'Production' } });
    assert.match(entry.error?.message ?? '', /100 diamonds/);
    const failedPublishID = randomUUID();
    const combined = await a.client.rpc('bibi_command', { p_operation: failedPublishID, p_action: 'publish', p_payload: { kind: 'video', title: 'Unfunded entry', body: 'Temporary transaction rollback verification.', media_id: ownMedia.id, challenge_id: challengeID, environment: 'Production' } });
    assert.match(combined.error?.message ?? '', /100 diamonds/);
    assert.equal((await rows(a.client, 'bibi_content', 'id', failedPublishID)).length, 0);
    assert.equal((await rows(a.client, 'bibi_entries')).length, 0);
    assert.equal((await rows(a.client, 'bibi_wallet_activity')).length, 0);
    assert.equal((await rows(a.client, 'bibi_cosmetics')).length, 0);
    assert.equal(Number((await rows(a.client, 'bibi_wallets', 'environment', 'Production'))[0].balance), 0);
    await command(a.client, 'withdraw', { target_id: ownVideo.id });
    check('actual_own_video_upload_pending_visibility_and_insufficient_spending_atomic_rollback');
    await command(a.client, 'circle', { circle_id: circleID, selected: false });
    assert.equal((await rows(a.client, 'bibi_circle_members')).length, 0);
    check('circle_leave_persisted');
  }

  if (!businessOnly) {

  const room = (await command(a.client, 'direct', { target_id: b.id })).id;
  fixtureConversations.push(room);
  const receiveB = await watch(b.client, room);
  const firstID = randomUUID();
  const first = await command(a.client, 'send', { target_id: room, body: 'Acceptance message A.' }, firstID);
  diagnostics.push({ phase: 'first_send_persisted', recipientCanRead: (await rows(b.client, 'bibi_messages', 'id', firstID)).length === 1 });
  await receiveB.receive(firstID);
  assert.equal(first.sender_id, a.id);
  assert.equal((await rows(b.client, 'bibi_messages', 'id', firstID)).length, 1);
  check('a_to_b_actual_realtime_and_persistent_read');
  const duplicate = await command(a.client, 'send', { target_id: room, body: 'Acceptance message A.' }, firstID);
  assert.equal(duplicate.id, firstID);
  assert.equal((await rows(b.client, 'bibi_messages', 'id', firstID)).length, 1);
  await denied(a.client.rpc('bibi_command', { p_operation: firstID, p_action: 'send', p_payload: { target_id: room, body: 'Changed payload.' } }));
  check('stable_operation_id_deduplicates_and_rejects_changed_payload');

  const receiveA = await watch(a.client, room);
  const reverseID = randomUUID();
  await command(b.client, 'send', { target_id: room, body: 'Acceptance message B.' }, reverseID);
  await receiveA.receive(reverseID);
  assert.equal((await rows(a.client, 'bibi_messages', 'id', reverseID)).length, 1);
  check('b_to_a_actual_realtime_and_persistent_read');
  assert.equal((await rows(c.client, 'bibi_messages', 'conversation_id', room)).length, 0);
  await denied(c.client.rpc('bibi_command', { p_operation: randomUUID(), p_action: 'send', p_payload: { target_id: room, body: 'Denied nonmember message.' } }));
  await denied(c.client.from('bibi_messages').insert({ id: randomUUID(), conversation_id: room, sender_id: a.id, body: 'Denied sender forgery.' }));
  await denied(c.client.from('bibi_conversation_members').update({ read_sequence: first.sequence }).eq('conversation_id', room).eq('user_id', b.id));
  check('nonmember_read_send_sender_forgery_and_read_state_denied');

  await command(a.client, 'follow', { target_id: b.id });
  await command(b.client, 'follow', { target_id: a.id });
  await receiveB.stop();
  const offlineID = randomUUID();
  await command(a.client, 'send', { target_id: room, body: 'Acceptance disconnected interval.' }, offlineID);
  const resumedB = await watch(b.client, room);
  assert.ok((await rows(b.client, 'bibi_messages', 'conversation_id', room)).some(item => item.id === offlineID));
  const raceID = randomUUID();
  const historyRead = rows(b.client, 'bibi_messages', 'conversation_id', room);
  await command(a.client, 'send', { target_id: room, body: 'Acceptance history race.' }, raceID);
  await resumedB.receive(raceID);
  const merged = new Map([...(await historyRead), ...(await rows(b.client, 'bibi_messages', 'id', raceID))].map(item => [item.id, item]));
  assert.ok(merged.has(raceID));
  check('reconnect_history_catchup_and_concurrent_history_event_merge');
  await command(b.client, 'chat_preferences', { target_id: room, read_sequence: first.sequence });
  const readMember = (await rows(b.client, 'bibi_conversation_members', 'conversation_id', room)).find(item => item.user_id === b.id);
  assert.ok(Number(readMember.read_sequence) >= Number(first.sequence));
  check('own_read_progress_persisted');

  const group = (await command(a.client, 'group', { title: 'Acceptance group', members: [b.id] })).id;
  fixtureConversations.push(group);
  await command(a.client, 'send', { target_id: group, body: 'Acceptance before join.' });
  assert.equal((await rows(b.client, 'bibi_messages', 'conversation_id', group)).length, 0);
  await command(b.client, 'accept_invite', { target_id: group });
  assert.equal((await rows(b.client, 'bibi_messages', 'conversation_id', group)).length, 0);
  const groupB = await watch(b.client, group);
  const groupMessage = randomUUID();
  await command(a.client, 'send', { target_id: group, body: 'Acceptance after join.' }, groupMessage);
  await groupB.receive(groupMessage);
  await command(a.client, 'remove_member', { target_id: group, user_id: b.id });
  assert.equal((await rows(b.client, 'bibi_messages', 'conversation_id', group)).length, 0);
  await denied(b.client.rpc('bibi_command', { p_operation: randomUUID(), p_action: 'send', p_payload: { target_id: group, body: 'Denied removed member.' } }));
  const removedEventID = randomUUID();
  await command(a.client, 'send', { target_id: group, body: 'Acceptance after removal.' }, removedEventID);
  await new Promise(resolve => setTimeout(resolve, 900));
  assert.ok(!groupB.events.includes(removedEventID));
  check('invite_history_boundary_and_removed_member_body_revocation');

  const mediaID = randomUUID();
  const staged = await command(a.client, 'stage_media', { mime_type: 'image/png' }, mediaID);
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==', 'base64');
  unwrap(await a.client.storage.from(staged.bucket_id).upload(staged.object_path, png, { contentType: 'image/png', upsert: false }));
  const finalized = unwrap(await a.client.functions.invoke('media-finalize', { body: { media_id: mediaID } }));
  assert.equal(finalized.status, 'ready');
  assert.ok(unwrap(await a.client.storage.from(staged.bucket_id).createSignedUrl(staged.object_path, 30)).signedUrl);
  await denied(c.client.storage.from(staged.bucket_id).createSignedUrl(staged.object_path, 30));
  assert.equal((await rows(c.client, 'bibi_media', 'id', mediaID)).length, 0);
  check('actual_private_upload_finalize_owner_read_and_nonowner_denial');

  await command(a.client, 'block', { target_id: b.id });
  assert.equal((await rows(b.client, 'bibi_messages', 'conversation_id', room)).length, 0);
  await denied(b.client.rpc('bibi_command', { p_operation: randomUUID(), p_action: 'send', p_payload: { target_id: room, body: 'Denied blocked message.' } }));
  check('block_revokes_direct_reads_and_sends');
  }
} catch (error) {
  failure = error instanceof Error ? error.message : 'Unknown acceptance failure.';
} finally {
  for (const { client, channel } of channels) await client.removeChannel(channel).catch(() => {});
  for (const item of clients.reverse()) {
    try {
      const receipt = unwrap(await item.client.functions.invoke('delete-account', { body: { confirm_delete: true } }));
      assert.equal(receipt.status, 'deleted');
      cleanup.push({ label: item.label, user_id: item.id, status: 'deleted' });
    } catch {
      cleanup.push({ label: item.label, user_id: item.id, status: 'requires_scoped_admin_cleanup' });
    }
  }
}
console.log(JSON.stringify({ project_ref: 'yepycfnkkfrfmuwdekka', mode: businessOnly ? 'business_only' : chatOnly ? 'chat_only' : 'full', diagnostics, checks, cleanup, failure: failure ?? null,
  scoped_admin_cleanup_conversation_ids: fixtureConversations,
  limits: ['No iOS UI or simulator acceptance.', 'No real purchase or fabricated wallet credit.', 'No RTC, push, presence or typing claim.', 'DELETE transport metadata needs separate privacy verification.'] }, null, 2));
if (failure || cleanup.some(item => item.status !== 'deleted')) process.exitCode = 1;
