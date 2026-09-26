// POST /functions/v1/ai-chat   (Authorization: Bearer <access token>)
//
// The AI tutor proxy (PRD 4.5, 6.4). The app never calls the endpoint
// itself: the key stays here, and so does the daily message limit, which is
// reserved before forwarding and handed back if the endpoint fails.
//
// Body: { thread_id, type: "iq" | "gk", content, language: "si"|"ta"|"en",
//         question_id? }
//
// The thread id is minted on the device and becomes the endpoint's
// session_id, so a follow-up in the same thread keeps its context. The row
// is created here on first use; nobody else's thread can be written to.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { fail, json, requireEnv, serve } from "../_shared/http.ts";
import { verifyAccessToken } from "../_shared/tokens.ts";

const LANGUAGES: Record<string, string> = {
  si: "Sinhala",
  ta: "Tamil",
  en: "English",
};
const TYPES = new Set(["iq", "gk"]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_CONTENT = 4000;

// The endpoint answers in a few seconds; a search-backed GK answer can take
// longer. Past this the student is better off retrying than watching a
// spinner.
const ENDPOINT_TIMEOUT_MS = 30_000;

serve(async (req) => {
  if (req.method !== "POST") return fail(405, "method_not_allowed");

  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  const userId = token
    ? await verifyAccessToken(
      token,
      requireEnv("SUPABASE_JWT_SECRET", "APP_JWT_SECRET"),
    )
    : null;
  if (!userId) return fail(401, "unauthenticated");

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return fail(400, "invalid_body");
  }

  const threadId = body.thread_id;
  const type = body.type;
  const language = body.language;
  const content = typeof body.content === "string" ? body.content.trim() : "";
  const questionId = body.question_id ?? null;

  if (typeof threadId !== "string" || !UUID.test(threadId)) {
    return fail(400, "invalid_thread");
  }
  if (typeof type !== "string" || !TYPES.has(type)) {
    return fail(400, "invalid_type");
  }
  if (typeof language !== "string" || !(language in LANGUAGES)) {
    return fail(400, "invalid_language");
  }
  if (content.length === 0 || content.length > MAX_CONTENT) {
    return fail(400, "invalid_content");
  }
  if (
    questionId !== null &&
    (typeof questionId !== "string" || !UUID.test(questionId))
  ) {
    return fail(400, "invalid_question");
  }

  const supabase = createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false } },
  );

  const { data: user, error: userError } = await supabase
    .from("users")
    .select("status, profiles(full_name)")
    .eq("id", userId)
    .maybeSingle();

  if (userError) {
    console.error("ai-chat: user lookup failed", userError);
    return fail(500, "server_error");
  }
  if (!user) return fail(401, "unauthenticated");
  if (user.status !== "active") return fail(403, "account_suspended");

  // The thread: created on first use, and only ever the caller's own.
  const { data: thread, error: threadError } = await supabase
    .from("chat_threads")
    .select("user_id")
    .eq("id", threadId)
    .maybeSingle();

  if (threadError) {
    console.error("ai-chat: thread lookup failed", threadError);
    return fail(500, "server_error");
  }
  if (thread && thread.user_id !== userId) return fail(403, "forbidden");
  if (!thread) {
    const { error } = await supabase.from("chat_threads").insert({
      id: threadId,
      user_id: userId,
      topic: type,
      question_id: questionId,
    });
    if (error) {
      console.error("ai-chat: thread insert failed", error);
      return fail(500, "server_error");
    }
  }

  // Reserve before forwarding (PRD 4.5), atomically, so parallel sends
  // cannot race past the limit.
  const { data: quota, error: quotaError } = await supabase.rpc(
    "consume_ai_message",
    { p_user: userId },
  );
  if (quotaError) {
    console.error("ai-chat: quota reservation failed", quotaError);
    return fail(500, "server_error");
  }
  if (!quota?.allowed) {
    return json({
      hint: "quota_exceeded",
      message: "quota_exceeded",
      tier: quota?.tier ?? "free",
      limit: quota?.limit ?? 0,
    }, 429);
  }

  const refund = async () => {
    const { error } = await supabase.rpc("refund_ai_message", {
      p_user: userId,
    });
    if (error) console.error("ai-chat: refund failed", error);
  };

  const { error: userMessageError } = await supabase
    .from("chat_messages")
    .insert({ thread_id: threadId, role: "user", content, language });
  if (userMessageError) {
    console.error("ai-chat: message insert failed", userMessageError);
    await refund();
    return fail(500, "server_error");
  }

  // deno-lint-ignore no-explicit-any
  const profile = (user as any).profiles;
  const userName: string | undefined =
    (Array.isArray(profile) ? profile[0] : profile)?.full_name ?? undefined;

  let answer: string;
  let usedSearch = false;
  try {
    const response = await fetch(requireEnv("AI_TUTOR_URL"), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": requireEnv("AI_TUTOR_API_KEY"),
      },
      body: JSON.stringify({
        type,
        question: content,
        language: LANGUAGES[language],
        session_id: threadId,
        user_name: userName,
      }),
      signal: AbortSignal.timeout(ENDPOINT_TIMEOUT_MS),
    });
    if (!response.ok) {
      throw new Error(`endpoint ${response.status}: ${await response.text()}`);
    }
    const reply = await response.json();
    answer = typeof reply.answer === "string" ? reply.answer.trim() : "";
    if (!answer) throw new Error("endpoint returned no answer");
    usedSearch = reply.used_search === true;
    console.log("ai-chat: answered", {
      type,
      language,
      used_search: usedSearch,
      input_tokens: reply.input_tokens,
      output_tokens: reply.output_tokens,
    });
  } catch (error) {
    console.error("ai-chat: endpoint failed", error);
    await refund();
    return fail(502, "tutor_unavailable");
  }

  const { data: saved, error: savedError } = await supabase
    .from("chat_messages")
    .insert({
      thread_id: threadId,
      role: "assistant",
      content: answer,
      language,
    })
    .select("id, created_at")
    .single();
  if (savedError) {
    // The student still gets the answer; only the history misses it.
    console.error("ai-chat: reply insert failed", savedError);
  }
  await supabase
    .from("chat_threads")
    .update({ updated_at: new Date().toISOString() })
    .eq("id", threadId);

  return json({
    thread_id: threadId,
    message: {
      id: saved?.id ?? crypto.randomUUID(),
      content: answer,
      created_at: saved?.created_at ?? new Date().toISOString(),
    },
    used_search: usedSearch,
  });
});
