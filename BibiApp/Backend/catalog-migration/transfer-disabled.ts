// Permanent disabled revision retained after the bounded migration completes.
Deno.serve(() => new Response(JSON.stringify({error: "Catalog transfer is disabled."}), {
  status: 410, headers: {"Content-Type": "application/json", "Cache-Control": "no-store"}
}));
