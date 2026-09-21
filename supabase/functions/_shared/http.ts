// Shared request plumbing: CORS, JSON replies and the error shape the
// Flutter client branches on.
//
// Errors carry a `hint` for the same reason the RPCs do (see
// supabase/README.md): the client needs to tell "wrong code" from "expired"
// without parsing a human-readable message that may be translated later.

export const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

export function fail(status: number, hint: string, message?: string): Response {
  return json({ hint, message: message ?? hint }, status);
}

export function preflight(req: Request): Response | null {
  return req.method === "OPTIONS"
    ? new Response("ok", { headers: CORS_HEADERS })
    : null;
}

/// Reads an environment variable, failing loudly at first use rather than
/// silently signing tokens with `undefined`.
export function requireEnv(...names: string[]): string {
  for (const name of names) {
    const value = Deno.env.get(name);
    if (value) return value;
  }
  throw new Error(`missing environment variable: ${names.join(" or ")}`);
}

/// Serves `handler`, answering preflight and turning an uncaught throw into a
/// JSON 500 that still carries the CORS headers.
///
/// Without this the runtime's own 500 has no `Access-Control-Allow-Origin`,
/// so the browser hides a plain server error behind a CORS message and the
/// real cause only exists in the function logs.
export function serve(handler: (req: Request) => Promise<Response>): void {
  Deno.serve(async (req) => {
    const cors = preflight(req);
    if (cors) return cors;

    try {
      return await handler(req);
    } catch (error) {
      console.error("unhandled error", error);
      return fail(500, "server_error");
    }
  });
}
