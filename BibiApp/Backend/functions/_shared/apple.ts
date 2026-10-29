import { Buffer } from "node:buffer";
import { AppStoreServerAPIClient, Environment, SignedDataVerifier } from "npm:@apple/app-store-server-library@3.1.0";
import { HTTPError } from "./http.ts";

const bundle = "im.seex.sao2-neiku-30";
export function apple(environment: unknown) {
  const allowed = (Deno.env.get("APPLE_ALLOWED_ENVIRONMENTS") ?? "").split(",");
  if ((environment !== "Production" && environment !== "Sandbox") || !allowed.includes(environment)) {
    throw new HTTPError(503, "Purchases are not configured for this environment.");
  }
  const key = Deno.env.get("APPLE_PRIVATE_KEY");
  const keyID = Deno.env.get("APPLE_KEY_ID");
  const issuer = Deno.env.get("APPLE_ISSUER_ID");
  const roots = Deno.env.get("APPLE_ROOT_CA_BASE64_JSON");
  const appID = Number(Deno.env.get("APPLE_APP_ID"));
  if (!key || !keyID || !issuer || !roots || !Number.isSafeInteger(appID) || appID <= 0) {
    throw new HTTPError(503, "Purchase verification is not configured.");
  }
  const certificates = JSON.parse(roots);
  if (!Array.isArray(certificates) || !certificates.length || certificates.some(x => typeof x !== "string")) {
    throw new HTTPError(503, "Purchase verification is not configured.");
  }
  const selected = environment === "Production" ? Environment.PRODUCTION : Environment.SANDBOX;
  return {
    api: new AppStoreServerAPIClient(key, keyID, issuer, bundle, selected),
    verifier: new SignedDataVerifier(certificates.map(x => Buffer.from(x, "base64")), true, selected, bundle, appID),
  };
}
export async function verifiedTransaction(signed: unknown, environment: unknown, userID: string) {
  if (typeof signed !== "string" || signed.length > 50_000) throw new HTTPError(400, "Invalid transaction evidence.");
  const { api, verifier } = apple(environment);
  const submitted = await verifier.verifyAndDecodeTransaction(signed);
  if (!submitted.transactionId) throw new HTTPError(400, "Transaction identifier missing.");
  const current = await api.getTransactionInfo(submitted.transactionId);
  if (!current.signedTransactionInfo) throw new HTTPError(502, "Apple did not return transaction evidence.");
  const transaction = await verifier.verifyAndDecodeTransaction(current.signedTransactionInfo);
  if (transaction.transactionId !== submitted.transactionId || transaction.bundleId !== bundle
    || transaction.environment !== environment || transaction.appAccountToken?.toLowerCase() !== userID
    || transaction.revocationDate || transaction.type !== "Consumable" || !transaction.productId
    || !Number.isInteger(transaction.quantity) || transaction.quantity! < 1 || transaction.quantity! > 10) {
    throw new HTTPError(403, "This transaction cannot credit this account.");
  }
  return transaction;
}
