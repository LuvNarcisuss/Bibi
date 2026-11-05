import { authenticate, body, HTTPError } from "../_shared/http.ts";
import { configuration, contractID, deploymentSettings, isObject, nonblank } from "../_shared/bibi-config.ts";
import { fixedPost, integerField } from "../_shared/bibi-upstream.ts";

type Category = "invalid_input" | "session_expired" | "ownership_conflict" | "configuration"
  | "awaiting_evidence" | "processing" | "needs_reconciliation" | "upstream_rejected"
  | "transient" | "association_missing";
class SettlementError extends Error {
  constructor(public category: Category, public status: number, public state = "needsReconciliation") { super(category); }
}
const messages: Record<Category, string> = {
  invalid_input: "The purchase details are invalid.",
  session_expired: "Restore the original account to continue.",
  ownership_conflict: "This transaction belongs to a different purchase context.",
  configuration: "Purchase configuration is unavailable.",
  awaiting_evidence: "Obtain the current transaction receipt before confirming.",
  processing: "This purchase is still being confirmed.",
  needs_reconciliation: "The original confirmation outcome needs reconciliation.",
  upstream_rejected: "The original service did not confirm this purchase.",
  transient: "Confirmation could not be completed. Retry its status later.",
  association_missing: "The original purchase association needs reconciliation.",
};
const settings = deploymentSettings;
const fields = settings.requestFields;
const purchase = settings.purchaseFields;

function string(input: Record<string, unknown>, field: string, maximum: number): string {
  const value = input[field];
  if (!nonblank(value, maximum)) throw new SettlementError("invalid_input", 400);
  return value;
}
function optional(input: Record<string, unknown>, field: string, maximum: number): string | undefined {
  return Object.prototype.hasOwnProperty.call(input, field) ? string(input, field, maximum) : undefined;
}
function base(input: Record<string, unknown>) {
  if (input.contract_id !== contractID) throw new SettlementError("configuration", 400);
  if (input.environment !== "Production" && input.environment !== "Sandbox") throw new SettlementError("configuration", 400);
  return { environment: input.environment as string };
}
function transaction(input: Record<string, unknown>) {
  const id = string(input, fields.transactionId, 100);
  if (!/^[0-9]+$/.test(id)) throw new SettlementError("invalid_input", 400);
  return id;
}
function source(input: Record<string, unknown>) {
  const value = input[purchase.source];
  if (value !== settings.purchaseSources.local && value !== settings.purchaseSources.socket) throw new SettlementError("invalid_input", 400);
  return value as string;
}
async function evidence(input: Record<string, unknown>) {
  const encoded = input[fields.payload];
  if (typeof encoded !== "string" || encoded.length < 4 || encoded.length > 4_194_304
      || encoded.length % 4 !== 0 || !/^[A-Za-z0-9+/]+={0,2}$/.test(encoded)) throw new SettlementError("awaiting_evidence", 400, "awaitingEvidence");
  let bytes: Uint8Array;
  try { bytes = Uint8Array.from(atob(encoded), char => char.charCodeAt(0)); }
  catch { throw new SettlementError("awaiting_evidence", 400, "awaitingEvidence"); }
  if (!bytes.length) throw new SettlementError("awaiting_evidence", 400, "awaitingEvidence");
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return { encoded, hash: Array.from(digest, byte => byte.toString(16).padStart(2, "0")).join("") };
}

export async function handleSettlement(request: Request) {
  const { db, user } = await authenticate(request);
  const input = await body(request, 4_210_688);
  const permitted = new Set(["action", "environment", "contract_id", "request_id", "message_id", "external_attempt_id", "context_origin", "app_id",
    ...Object.values(fields), ...Object.values(purchase)]);
  if (Object.keys(input).some(key => !permitted.has(key))) throw new SettlementError("invalid_input", 400);
  const contextBase = base(input);
  async function rpc(action: string, payload: Record<string, unknown>) {
    const { data, error } = await db.rpc("bibi_settlement", { p_user: user.id, p_action: action, p_request: payload });
    if (error || !isObject(data)) throw new SettlementError("transient", 503);
    return data;
  }
  if (input.action === "status") {
    return await rpc("status", { ...contextBase, transaction_id: transaction(input) });
  }
  const selectedSource = source(input);
  const product = string(input, purchase.productID, 255);
  if (input[purchase.quantity] !== 1) throw new SettlementError("invalid_input", 400);
  if (input.action === "availability") {
    if (selectedSource === settings.purchaseSources.socket) {
      try { configuration(); } catch { throw new SettlementError("configuration", 503); }
    }
    return await rpc("availability", { ...contextBase, source: selectedSource, product_id: product, quantity: 1 });
  }
  if (input.action !== "confirm") throw new SettlementError("invalid_input", 400);
  const tx = transaction(input), version = string(input, fields.appVersion, 64), device = string(input, fields.deviceNo, 200);
  const receipt = await evidence(input);
  const order = optional(input, fields.callbackResult, 1_024);
  if (selectedSource === settings.purchaseSources.local && order !== undefined) throw new SettlementError("invalid_input", 400);
  const context: Record<string, string> = { app_version: version, device_no: device };
  for (const key of ["request_id", "message_id", "external_attempt_id", "context_origin", "app_id"]) {
    const value = optional(input, key, key === "context_origin" ? 2_048 : 200);
    if (value !== undefined) context[key] = value;
  }
  if (context.context_origin !== undefined && context.context_origin !== settings.externalOrigin
      || context.app_id !== undefined && context.app_id !== settings.sourceAppId) throw new SettlementError("ownership_conflict", 409);
  const payload = { ...contextBase, transaction_id: tx, source: selectedSource, product_id: product,
    quantity: 1, contract_id: contractID, context, receipt_sha256: receipt.hash,
    ...(order === undefined ? {} : { order_reference: order }) };
  if (selectedSource === settings.purchaseSources.local) return await rpc("settle_local", payload);

  let config;
  try { config = configuration(); } catch { throw new SettlementError("configuration", 503); }
  const claim = await rpc("claim_remote", payload);
  if (claim.dispatch !== true) return claim;
  if (!nonblank(claim.lease_owner, 36)) throw new SettlementError("transient", 503);
  const lease = { ...contextBase, transaction_id: tx, lease_owner: claim.lease_owner };
  const marked = await rpc("mark_forwarding", lease);
  if (marked.dispatch !== true) return marked;

  // Construct only the original four strings, plus an actual optional order.
  // Supabase JWT, IP headers, source and product metadata never leave this Edge.
  const upstream = {
    [fields.appVersion]: version, [fields.deviceNo]: device,
    [fields.transactionId]: tx, [fields.payload]: receipt.encoded,
    ...(order === undefined ? {} : { [fields.callbackResult]: order }),
  };
  let accepted = false, rejected = false;
  try {
    const response = await fixedPost(new URL(config.confirmPurchasePath, config.externalOrigin), upstream);
    const code = integerField(response.text, config.responseFields.code);
    accepted = response.status >= 200 && response.status < 300 && code === 0;
    rejected = response.status >= 200 && response.status < 300 && code !== 0;
  } catch { /* A sent request with no confirmed outcome is never blindly resent. */ }
  if (!accepted) return await rpc("record_outcome", { ...lease, outcome: rejected ? "rejected" : "unknown" });

  // Only persistence may be repeated here, never the upstream HTTP operation.
  // A stored upstreamConfirmed record is finalized on later owner status/confirm.
  let stored: Record<string, unknown>;
  try { stored = await rpc("record_upstream", lease); }
  catch { stored = await rpc("record_upstream", lease); }
  if (stored.code !== 0 || stored.state !== "upstreamConfirmed") return stored;
  try { return await rpc("finalize_remote", lease); }
  catch { throw new SettlementError("transient", 503, "upstreamConfirmed"); }
}

Deno.serve(async request => {
  try { return Response.json(await handleSettlement(request), { headers: { "Cache-Control": "no-store" } }); }
  catch (error) {
    const known = error instanceof SettlementError;
    const category: Category = known ? error.category : error instanceof HTTPError && error.status === 401 ? "session_expired"
      : error instanceof HTTPError && error.status < 500 ? "invalid_input" : "transient";
    const status = known ? error.status : error instanceof HTTPError ? error.status : 503;
    return Response.json({ code: status, message: messages[category], category,
      state: known ? error.state : "needsReconciliation" }, { status, headers: { "Cache-Control": "no-store" } });
  }
});
