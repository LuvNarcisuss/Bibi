import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { authenticate, body, HTTPError, serve } from "../_shared/http.ts";

serve(async request => {
  const { db, user, token } = await authenticate(request, true);
  const input = await body(request, 10_000);
  if (user.is_anonymous === true) {
    if (input.confirm_delete !== true) throw new HTTPError(400, "Confirm guest account deletion.");
  } else {
    if (typeof input.password !== "string" || !user.email) throw new HTTPError(400, "Confirm your password to delete your account.");
    const auth = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: confirmed, error: authError } = await auth.auth.signInWithPassword({ email: user.email, password: input.password });
    if (authError || confirmed.user?.id !== user.id || !confirmed.session) throw new HTTPError(403, "Password confirmation failed.");
  }
  const { error: markError } = await db.rpc("bibi_begin_deletion", { p_user: user.id });
  if (markError) throw new HTTPError(500, "Account deletion could not start.");
  // Account status now denies business operations, including still-valid JWTs.
  // Revoke only after cleanup: an interrupted guest has no password to recover a revoked session.
  // Retry removes the first page each time so deleting a page cannot skip objects.
  for (const bucket of ["bibi-images", "bibi-videos"]) {
    for (let batch = 0; batch < 20; batch++) {
      const { data: objects, error: listError } = await db.storage.from(bucket).list(user.id, { limit: 100 });
      if (listError) throw new HTTPError(503, "Account locked. Media cleanup needs another attempt.");
      if (!objects?.length) break;
      const { error: removeError } = await db.storage.from(bucket).remove(objects.map(object => `${user.id}/${object.name}`));
      if (removeError) throw new HTTPError(503, "Account locked. Media cleanup needs another attempt.");
      if (batch === 19) throw new HTTPError(503, "Account locked. More media cleanup remains; retry deletion.");
    }
  }
  const { error: revokeError } = await db.auth.admin.signOut(token, "global");
  if (revokeError) throw new HTTPError(503, "Account locked. Session cleanup needs another attempt.");
  const { error: deleteError } = await db.auth.admin.deleteUser(user.id);
  if (deleteError) throw new HTTPError(503, "Account locked. Final cleanup needs another attempt.");
  // The private transaction evidence remains for reconciliation; it is not client-readable.
  return { status: "deleted" };
});
