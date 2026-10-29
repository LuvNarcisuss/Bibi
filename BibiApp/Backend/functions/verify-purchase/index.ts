import { authenticate, body, HTTPError, serve } from "../_shared/http.ts";
import { apple, verifiedTransaction } from "../_shared/apple.ts";

serve(async request => {
  const { db, user } = await authenticate(request);
  const input = await body(request);
  if (input.action === "availability") {
    apple(input.environment);
    return { available: true, environment: input.environment };
  }
  const transaction = await verifiedTransaction(input.signed_transaction, input.environment, user.id);
  const { data, error } = await db.rpc("bibi_credit_purchase", {
    p_user: user.id, p_transaction: transaction.transactionId,
    p_environment: transaction.environment, p_product: transaction.productId, p_quantity: transaction.quantity,
  });
  if (error) throw new HTTPError(409, "The transaction could not be credited. Keep it pending and retry.");
  return data;
});
