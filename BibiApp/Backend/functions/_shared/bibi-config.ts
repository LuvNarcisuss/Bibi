import settings from "./bibi-settings.json" with { type: "json" };

export const bundleID = "com.bibi.quadratic";
export const contractID = "bibi-48369038-v1";
export const deploymentSettings = settings;

export function configuration() {
  const external = new URL(settings.externalOrigin);
  const native = new URL(Deno.env.get("SUPABASE_URL") ?? "");
  if (external.protocol !== "https:" || external.username || external.password
      || external.pathname !== "/" || external.search || external.hash
      || external.origin !== settings.externalOrigin || native.protocol !== "https:"
      || native.origin !== settings.bootstrapPreflight.nativeOrigin
      || external.origin === native.origin || settings.sourceAppId !== "48369038"
      || settings.balanceAuthority !== "external") throw new Error("configuration");
  for (const path of [settings.bootstrapPreflight.authenticatePath, settings.confirmPurchasePath]) {
    if (!path.startsWith("/") || path.startsWith("//") || /[?#\\]/.test(path)
        || new URL(path, external).origin !== external.origin) throw new Error("configuration");
  }
  return { ...settings, nativeOrigin: native.origin };
}

export function nonblank(value: unknown, maximum: number): value is string {
  return typeof value === "string" && value.trim().length > 0 && value.length <= maximum && !/[\u0000-\u001f\u007f]/.test(value);
}

export function isObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
