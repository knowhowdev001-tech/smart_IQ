-- AI chat and push notifications (PRD 8 "AI"; PRD 6.4, 6.8).
--
-- The app is a thin client over an external AI endpoint. Nothing here calls
-- that endpoint -- the Edge Function does, because the credential must stay
-- server-side (PRD 9.2). These tables only hold what the client is allowed
-- to read back.

create table public.chat_threads (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id) on delete cascade,
  topic      text,
  -- Set when a thread was opened from a question via "Explain this", so the
  -- follow-up thread keeps its context (PRD 6.4).
  question_id uuid references public.questions(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index chat_threads_user_idx
  on public.chat_threads (user_id, updated_at desc);

create trigger chat_threads_touch_updated_at
  before update on public.chat_threads
  for each row execute function app.touch_updated_at();

create table public.chat_messages (
  id         uuid primary key default gen_random_uuid(),
  thread_id  uuid not null references public.chat_threads(id) on delete cascade,
  role       public.chat_role not null,
  content    text not null,
  language   public.language_code not null,
  created_at timestamptz not null default now()
);

create index chat_messages_thread_idx
  on public.chat_messages (thread_id, created_at);

-- Written only by the Edge Function, which decrements quota before
-- forwarding to the endpoint (PRD 9.2). The client can read it to show
-- remaining messages but never enforces the limit (PRD 6.4).
create table public.ai_usage (
  user_id       uuid not null references public.users(id) on delete cascade,
  usage_date    date not null default app.sl_today(),
  message_count int not null default 0,
  primary key (user_id, usage_date)
);

-- Every notification type is individually toggleable (PRD 6.8).
create table public.notification_preferences (
  user_id uuid not null references public.users(id) on delete cascade,
  kind    public.notification_kind not null,
  enabled boolean not null default true,
  primary key (user_id, kind)
);

create table public.device_tokens (
  user_id    uuid not null references public.users(id) on delete cascade,
  device_id  text not null,
  push_token text not null,
  platform   text not null default 'android',
  updated_at timestamptz not null default now(),
  primary key (user_id, device_id)
);

create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id) on delete cascade,
  kind       public.notification_kind not null,
  title      text not null,
  body       text,
  payload    jsonb,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_user_idx
  on public.notifications (user_id, created_at desc);
