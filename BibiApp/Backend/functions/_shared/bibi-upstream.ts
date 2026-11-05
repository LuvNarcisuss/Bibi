import { isObject } from "./bibi-config.ts";

export class UpstreamError extends Error {
  constructor(public category: "configuration" | "transient" | "needs_reconciliation", message: string) { super(message); }
}

// Preserve the lexical integer requirement even for JSON numbers such as 0.0 or
// 0e0 that JSON.parse otherwise converts to the same JavaScript integer zero.
export function integerField(text: string, key: string): number {
  let cursor = 0;
  const whitespace = () => { while (/\s/.test(text[cursor] ?? "") && cursor < text.length) cursor++; };
  function valueEnd(start: number): number {
    let quoted = false, escaped = false, depth = 0;
    for (let i = start; i < text.length; i++) {
      const char = text[i];
      if (quoted) { if (escaped) escaped = false; else if (char === "\\") escaped = true; else if (char === '"') quoted = false; continue; }
      if (char === '"') quoted = true;
      else if (char === "{" || char === "[") depth++;
      else if (char === "}" || char === "]") { if (depth === 0) return i; depth--; }
      else if (char === "," && depth === 0) return i;
    }
    return text.length;
  }
  whitespace();
  if (text[cursor++] !== "{") throw new UpstreamError("configuration", "Invalid response envelope.");
  let found: number | undefined;
  while (cursor < text.length) {
    whitespace();
    if (text[cursor] === "}") break;
    if (text[cursor] !== '"') throw new UpstreamError("configuration", "Invalid response envelope.");
    const start = cursor++;
    let escaped = false;
    while (cursor < text.length) {
      const char = text[cursor++];
      if (escaped) escaped = false;
      else if (char === "\\") escaped = true;
      else if (char === '"') break;
    }
    const name = JSON.parse(text.slice(start, cursor));
    whitespace();
    if (text[cursor++] !== ":") throw new UpstreamError("configuration", "Invalid response envelope.");
    whitespace();
    const end = valueEnd(cursor);
    if (name === key) {
      const raw = text.slice(cursor, end).trim();
      if (found !== undefined || !/^-?(0|[1-9][0-9]*)$/.test(raw) || !Number.isSafeInteger(Number(raw))) {
        throw new UpstreamError("configuration", "Response code must be an integer.");
      }
      found = Number(raw);
    }
    cursor = end;
    if (text[cursor] === ",") cursor++;
    else break;
  }
  if (found === undefined) throw new UpstreamError("configuration", "Response code is missing.");
  return found;
}

export async function fixedPost(url: URL, payload: Record<string, unknown>,
  fetcher: typeof fetch = fetch, timeoutMilliseconds = 15_000, maximumBytes = 1_048_576) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMilliseconds);
  try {
    const response = await fetcher(url, {
      method: "POST", redirect: "error", signal: controller.signal,
      headers: { "Content-Type": "application/json", "Accept": "application/json" },
      body: JSON.stringify(payload),
    });
    const reader = response.body?.getReader();
    if (!reader) throw new UpstreamError("configuration", "The response body is missing.");
    const chunks: Uint8Array[] = [];
    let size = 0;
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > maximumBytes) { await reader.cancel(); throw new UpstreamError("configuration", "The response is too large."); }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    let parsed: unknown;
    try { parsed = JSON.parse(text); } catch { throw new UpstreamError("configuration", "The response is not valid JSON."); }
    if (!isObject(parsed)) throw new UpstreamError("configuration", "The response envelope is invalid.");
    return { status: response.status, object: parsed, text };
  } catch (error) {
    if (error instanceof UpstreamError) throw error;
    throw new UpstreamError("transient", "The upstream outcome is unavailable.");
  } finally { clearTimeout(timer); }
}

export function bootstrapDecision(status: number, text: string, envelope: Record<string, unknown>,
  fields: { code: string; data: string }, continuationField: string): "external" | "native" {
  const code = integerField(text, fields.code);
  const data = envelope[fields.data];
  if (!isObject(data) || !(status >= 200 && status < 300 || status === 401)) {
    throw new UpstreamError("configuration", "The authentication response is invalid.");
  }
  if (Object.prototype.hasOwnProperty.call(data, continuationField)) return "external";
  if (status >= 200 && status < 300 && code === 0) return "native";
  throw new UpstreamError("configuration", "The authentication response did not authorize continuation.");
}
