import { createClient } from "npm:@supabase/supabase-js@2.57.4";

export class HTTPError extends Error {
  constructor(public status: number, message: string) { super(message); }
}
export function admin() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new HTTPError(503, "Service configuration is incomplete.");
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}
export async function authenticate(request: Request, allowDeleting = false) {
  const token = request.headers.get("Authorization")?.match(/^Bearer ([^\s]+)$/)?.[1];
  if (!token) throw new HTTPError(401, "Sign in to continue.");
  const db = admin();
  const { data, error } = await db.auth.getUser(token);
  if (error || !data.user || (!data.user.email_confirmed_at && data.user.is_anonymous !== true)) throw new HTTPError(401, "Sign in to continue.");
  const { data: profile, error: profileError } = await db.from("bibi_profiles")
    .select("account_status").eq("id", data.user.id).maybeSingle();
  if (profileError || !profile || !(profile.account_status === "active" || allowDeleting && profile.account_status === "deleting")) {
    throw new HTTPError(403, "Account unavailable.");
  }
  // Validate live session through a user-scoped RPC; the deleting retry path is
  // restricted to cleanup and cannot authorize any content or wallet operation.
  if (!allowDeleting) {
    const scoped = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: `Bearer ${token}` } }, auth: { persistSession: false },
    });
    const { data: profiles, error: liveError } = await scoped.from("bibi_profiles").select("id").eq("id", data.user.id);
    if (liveError || profiles?.length !== 1) throw new HTTPError(401, "This session has ended.");
  }
  return { db, user: data.user, token };
}
export async function body(request: Request, maximum = 100_000): Promise<Record<string, unknown>> {
  if (request.method !== "POST") throw new HTTPError(405, "Use POST.");
  const reader = request.body?.getReader();
  if (!reader) throw new HTTPError(400, "Request body required.");
  let length = 0;
  const chunks: Uint8Array[] = [];
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    length += value.length;
    if (length > maximum) { await reader.cancel(); throw new HTTPError(413, "Request too large."); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(length); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  let parsed;
  try { parsed = JSON.parse(new TextDecoder().decode(bytes)); } catch { throw new HTTPError(400, "Invalid JSON."); }
  if (!parsed || Array.isArray(parsed) || typeof parsed !== "object") throw new HTTPError(400, "Invalid request.");
  return parsed;
}
export function uuid(value: unknown): string {
  if (typeof value !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) {
    throw new HTTPError(400, "Invalid identifier.");
  }
  return value.toLowerCase();
}
export function serve(handler: (request: Request) => Promise<unknown>) {
  Deno.serve(async request => {
    try {
      const result = await handler(request);
      return Response.json(result, { headers: { "Cache-Control": "no-store" } });
    } catch (error) {
      const known = error instanceof HTTPError;
      return Response.json({ error: known ? error.message : "The request could not be completed. Please try again." },
        { status: known ? error.status : 500, headers: { "Cache-Control": "no-store" } });
    }
  });
}
