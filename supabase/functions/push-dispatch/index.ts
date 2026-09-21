// POST /functions/v1/push-dispatch
//
// Drains the push outbox. `notifications` rows are written as 'pending' by
// the jobs and triggers in migration 0020; pg_cron calls this every minute
// through `app.kick_push_dispatch()`, but only when something is pending.
//
// Not user-facing: it is called by the database with a shared secret in
// `x-dispatch-secret`, which is why `verify_jwt` is off in config.toml.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { fail, json, requireEnv, serve } from "../_shared/http.ts";
import { timingSafeEqual } from "../_shared/tokens.ts";
import { FcmClient, type SendOutcome } from "../_shared/fcm.ts";

const BATCH_SIZE = 200;
const CONCURRENCY = 25;
// Leaves headroom under the 60s wall clock pg_net waits for. Anything not
// sent by then is picked up on the next minute's run.
const TIME_BUDGET_MS = 45_000;

interface ClaimedRow {
  id: string;
  user_id: string;
  kind: string;
  title: string;
  body: string | null;
  payload: Record<string, unknown> | null;
  tokens: { device_id: string; token: string; platform: string }[];
}

async function mapLimited<T, R>(
  items: T[],
  limit: number,
  fn: (item: T) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const i = next++;
      results[i] = await fn(items[i]);
    }
  });
  await Promise.all(workers);
  return results;
}

serve(async (req) => {
  if (req.method !== "POST") return fail(405, "method_not_allowed");

  const secret = requireEnv("PUSH_DISPATCH_SECRET");
  if (!timingSafeEqual(req.headers.get("x-dispatch-secret") ?? "", secret)) {
    return fail(401, "unauthorized");
  }

  const supabase = createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false } },
  );
  const fcm = new FcmClient(requireEnv("FCM_SERVICE_ACCOUNT"));

  const started = Date.now();
  const totals = { sent: 0, skipped: 0, failed: 0, retry: 0, dead_tokens: 0 };

  while (Date.now() - started < TIME_BUDGET_MS) {
    const { data, error } = await supabase.rpc("claim_push_batch", { p_limit: BATCH_SIZE });
    if (error) throw error;
    const rows = (data ?? []) as ClaimedRow[];
    if (rows.length === 0) break;

    const dead: { user_id: string; device_id: string }[] = [];

    const statuses = await mapLimited(rows, CONCURRENCY, async (row) => {
      if (row.tokens.length === 0) return "skipped";

      const fields: Record<string, string> = { kind: row.kind, notification_id: row.id };
      for (const [k, v] of Object.entries(row.payload ?? {})) {
        if (v != null) fields[k] = String(v);
      }

      const outcomes: SendOutcome[] = [];
      for (const t of row.tokens) {
        const outcome = await fcm.send(t.token, {
          title: row.title,
          body: row.body ?? "",
          channel: row.kind,
          data: fields,
        });
        if (outcome === "dead") dead.push({ user_id: row.user_id, device_id: t.device_id });
        outcomes.push(outcome);
      }

      // One delivered device is a delivered notification. Retrying the row
      // would re-send to the devices that already have it.
      if (outcomes.includes("sent")) return "sent";
      // Left in 'sending': claim_push_batch reclaims it after ten minutes,
      // which is the backoff, and gives up after the third attempt.
      if (outcomes.includes("retry")) return "retry";
      if (outcomes.every((o) => o === "dead")) return "skipped";
      return "failed";
    });

    totals.retry += statuses.filter((s) => s === "retry").length;
    for (const status of ["sent", "skipped", "failed"] as const) {
      const ids = rows.filter((_, i) => statuses[i] === status).map((r) => r.id);
      if (ids.length === 0) continue;
      const { error } = await supabase
        .from("notifications")
        .update({ push_status: status })
        .in("id", ids);
      if (error) throw error;
      totals[status] += ids.length;
    }

    for (const d of dead) {
      await supabase.from("device_tokens").delete()
        .eq("user_id", d.user_id).eq("device_id", d.device_id);
    }
    totals.dead_tokens += dead.length;

    if (rows.length < BATCH_SIZE) break;
  }

  console.log("push-dispatch", totals);
  return json(totals);
});
