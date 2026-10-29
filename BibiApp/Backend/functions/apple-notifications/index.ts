import { admin, body, HTTPError, serve } from "../_shared/http.ts";
import { apple } from "../_shared/apple.ts";

serve(async request => {
  const input = await body(request);
  if (typeof input.signedPayload !== "string") throw new HTTPError(400, "Signed notification required.");
  // Never trust an unsigned environment claim to authorize a notification.
  let verified: Awaited<ReturnType<ReturnType<typeof apple>["verifier"]["verifyAndDecodeNotification"]>> | undefined;
  let selected: ReturnType<typeof apple> | undefined;
  for (const environment of ["Production", "Sandbox"]) {
    try {
      const candidate = apple(environment);
      verified = await candidate.verifier.verifyAndDecodeNotification(input.signedPayload);
      selected = candidate;
      break;
    } catch { /* Try the other explicitly configured Apple environment. */ }
  }
  if (!verified || !selected) throw new HTTPError(403, "Notification signature could not be verified.");
  if (verified.notificationType === "REFUND" || verified.notificationType === "REVOKE") {
    const signed = verified.data?.signedTransactionInfo;
    if (!signed) throw new HTTPError(400, "Transaction evidence missing.");
    const transaction = await selected.verifier.verifyAndDecodeTransaction(signed);
    if (!transaction.transactionId || !transaction.revocationDate) throw new HTTPError(400, "Revocation evidence missing.");
    const { error } = await admin().rpc("bibi_revoke_purchase", {
      p_transaction: transaction.transactionId, p_environment: transaction.environment,
    });
    if (error) throw new HTTPError(500, "The revocation could not be saved.");
  }
  return { received: true };
});
