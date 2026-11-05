import { authenticate, body, HTTPError, serve } from "../_shared/http.ts";
import { configuration, nonblank } from "../_shared/bibi-config.ts";
import { bootstrapDecision, fixedPost } from "../_shared/bibi-upstream.ts";

// This preflight never returns upstream tickets, credentials or response data.
serve(async request => {
  await authenticate(request);
  let config;
  try { config = configuration(); } catch { throw new HTTPError(503, "Service configuration is incomplete."); }
  const input = await body(request, 8_192);
  const fields = config.bootstrapPreflight.requestFields;
  if (!nonblank(input[fields.appVersion], 64) || typeof input[fields.pushToken] !== "string"
      || (input[fields.pushToken] as string).length > 512 || !nonblank(input[fields.deviceNo], 200)
      || input[fields.roomPushMsgType] !== 2) {
    throw new HTTPError(400, "The device context is invalid.");
  }
  const payload = Object.fromEntries(Object.values(fields).map(field => [field, input[field]]));
  try {
    const result = await fixedPost(new URL(config.bootstrapPreflight.authenticatePath, config.externalOrigin), payload,
      fetch, config.bootstrapPreflight.timeoutSeconds * 1_000, config.bootstrapPreflight.maxResponseBytes);
    const destination = bootstrapDecision(result.status, result.text, result.object,
      config.bootstrapPreflight.responseFields, config.bootstrapPreflight.continuationField);
    return { code: 0, message: "ok", data: {
      [config.bootstrapPreflight.bootstrapFields.backendOrigin]: destination === "external" ? config.externalOrigin : config.nativeOrigin,
      [config.bootstrapPreflight.bootstrapFields.applicationID]: config.sourceAppId,
    } };
  } catch { throw new HTTPError(502, "The connection could not be confirmed. Please retry."); }
});
