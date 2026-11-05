// Temporary, manifest-scoped migration endpoint. Deploy the disabled source after use.
// Replace __TOKEN_DIGEST__ and __ALLOWLIST__ only in memory at deployment time.
const tokenDigest = "__TOKEN_DIGEST__";
const allowlist: Record<string, {size: number; mime: string; sha256: string}> = __ALLOWLIST__;
const origin = Deno.env.get("SUPABASE_URL")!;
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const encoder = new TextEncoder();
async function digest(bytes: Uint8Array) {
  return [...new Uint8Array(await crypto.subtle.digest("SHA-256", bytes))]
    .map(b => b.toString(16).padStart(2, "0")).join("");
}
function equal(a: string, b: string) {
  let difference = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) difference |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  return difference === 0;
}
function response(status: number, body: object) {
  return new Response(JSON.stringify(body), {status, headers: {"Content-Type": "application/json", "Cache-Control": "no-store"}});
}
Deno.serve(async req => {
  if (Date.now() > __EXPIRES_AT__) return response(410, {error:"Transfer expired"});
  const token = req.headers.get("Authorization")?.replace(/^Bearer /, "") ?? "";
  if (!equal(await digest(encoder.encode(token)), tokenDigest)) return response(401, {error:"Unauthorized"});
  const target = new URL(req.url).searchParams.get("object") ?? "";
  const item = allowlist[target];
  if (!item || !["POST", "GET"].includes(req.method)) return response(403, {error:"Object unavailable"});
  const url = `${origin}/storage/v1/object/${target}`;
  const headers = {"apikey":key, "Authorization":`Bearer ${key}`};
  try {
    if (req.method === "POST") {
      if (Number(req.headers.get("Content-Length")) !== item.size || req.headers.get("Content-Type") !== item.mime)
        return response(400, {error:"Unexpected media metadata"});
      // The fixed allowlist bounds each request to at most the largest catalog clip.
      const bytes = new Uint8Array(await req.arrayBuffer());
      if (bytes.length !== item.size || await digest(bytes) !== item.sha256) return response(400, {error:"Integrity mismatch"});
      const existing = await fetch(url, {headers});
      if (existing.ok) {
        const old = new Uint8Array(await existing.arrayBuffer());
        if (old.length !== item.size || await digest(old) !== item.sha256) return response(409, {error:"Existing object conflict"});
      } else if (existing.status === 404 || existing.status === 400) {
        const uploaded = await fetch(url, {method:"POST",headers:{...headers,"Content-Type":item.mime,"x-upsert":"false"},body:bytes});
        if (!uploaded.ok) return response(502, {error:"Storage upload failed",storage_status:uploaded.status});
      } else return response(502, {error:"Storage lookup failed",storage_status:existing.status});
    }
    const result = await fetch(url, {headers});
    if (!result.ok) return response(502, {error:"Storage readback failed",storage_status:result.status});
    const bytes = new Uint8Array(await result.arrayBuffer());
    const actual = await digest(bytes);
    if (bytes.length !== item.size || actual !== item.sha256 || result.headers.get("Content-Type")?.split(";")[0] !== item.mime)
      return response(409, {error:"Stored object integrity mismatch"});
    return response(200, {object:target,byte_count:bytes.length,sha256:actual,mime_type:item.mime,verified:true});
  } catch { return response(502, {error:"Storage request failed"}); }
});
