-- Row level security (PRD 9.4).
--
-- Default deny everywhere. A table with RLS on and no policy is invisible
-- to the client, and several tables here are meant to stay that way:
--
--  * questions and their translations/options -- PRD 9.3 is explicit that a
--    modified client would otherwise page through the whole bank without
--    ever touching a quota counter. They are served only through RPCs.
--  * otp_requests, msisdn_prefix_routing -- infrastructure, never client
--    readable.
--  * payment_status, telco_charges, revenuecat_events, ai_usage,
--    quota_usage -- readable, never writable. A client that can write its
--    own payment_status row grants itself Pro+ with one request.

alter table public.users                        enable row level security;
alter table public.profiles                     enable row level security;
alter table public.otp_requests                 enable row level security;
alter table public.auth_sessions                enable row level security;
alter table public.categories                   enable row level security;
alter table public.sub_topics                   enable row level security;
alter table public.questions                    enable row level security;
alter table public.question_translations        enable row level security;
alter table public.question_options             enable row level security;
alter table public.question_option_translations enable row level security;
alter table public.question_explanation_media   enable row level security;
alter table public.current_affairs              enable row level security;
alter table public.current_affairs_translations enable row level security;
alter table public.practice_sessions            enable row level security;
alter table public.session_answers              enable row level security;
alter table public.wrong_answer_bank            enable row level security;
alter table public.bookmarks                    enable row level security;
alter table public.user_topic_mastery           enable row level security;
alter table public.user_streaks                 enable row level security;
alter table public.daily_challenges             enable row level security;
alter table public.daily_challenge_questions    enable row level security;
alter table public.daily_challenge_participation enable row level security;
alter table public.chat_threads                 enable row level security;
alter table public.chat_messages                enable row level security;
alter table public.ai_usage                     enable row level security;
alter table public.notification_preferences     enable row level security;
alter table public.device_tokens                enable row level security;
alter table public.notifications                enable row level security;
alter table public.payment_status               enable row level security;
alter table public.telco_charges                enable row level security;
alter table public.revenuecat_events            enable row level security;
alter table public.msisdn_prefix_routing        enable row level security;
alter table public.tier_limits                  enable row level security;
alter table public.quota_usage                  enable row level security;

-- ------------------------------------------ reference data, read by all --

create policy categories_read on public.categories
  for select to authenticated using (true);

create policy sub_topics_read on public.sub_topics
  for select to authenticated using (true);

create policy tier_limits_read on public.tier_limits
  for select to authenticated using (true);

create policy daily_challenges_read on public.daily_challenges
  for select to authenticated using (true);

-- Published items only. A draft digest is not the client's business.
create policy current_affairs_read on public.current_affairs
  for select to authenticated
  using (status = 'live' and publish_date <= app.sl_today());

create policy current_affairs_translations_read
  on public.current_affairs_translations
  for select to authenticated
  using (exists (
    select 1 from public.current_affairs c
    where c.id = item_id
      and c.status = 'live'
      and c.publish_date <= app.sl_today()
  ));

-- ------------------------------------------------------ the user's own --

create policy users_read_self on public.users
  for select to authenticated using (id = app.current_user_id());

create policy profiles_read_self on public.profiles
  for select to authenticated using (user_id = app.current_user_id());

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (user_id = app.current_user_id())
  with check (user_id = app.current_user_id());

-- Read own devices, and revoke them. The update policy is narrow on
-- purpose: it exists so "sign out other devices" (PRD 6.1) works, not so a
-- client can rewrite a token hash.
create policy auth_sessions_read_self on public.auth_sessions
  for select to authenticated using (user_id = app.current_user_id());

create policy auth_sessions_revoke_self on public.auth_sessions
  for update to authenticated
  using (user_id = app.current_user_id())
  with check (user_id = app.current_user_id());

create policy practice_sessions_read_self on public.practice_sessions
  for select to authenticated using (user_id = app.current_user_id());

create policy session_answers_read_self on public.session_answers
  for select to authenticated
  using (exists (
    select 1 from public.practice_sessions s
    where s.id = session_id and s.user_id = app.current_user_id()
  ));

create policy wrong_answer_bank_read_self on public.wrong_answer_bank
  for select to authenticated using (user_id = app.current_user_id());

create policy user_topic_mastery_read_self on public.user_topic_mastery
  for select to authenticated using (user_id = app.current_user_id());

create policy user_streaks_read_self on public.user_streaks
  for select to authenticated using (user_id = app.current_user_id());

create policy daily_challenge_participation_read_self
  on public.daily_challenge_participation
  for select to authenticated using (user_id = app.current_user_id());

-- Bookmarks are the one user-scoped table with full client write access
-- (PRD 9.4). Nothing about them consumes quota or grants entitlement.
create policy bookmarks_all_self on public.bookmarks
  for all to authenticated
  using (user_id = app.current_user_id())
  with check (user_id = app.current_user_id());

create policy chat_threads_read_self on public.chat_threads
  for select to authenticated using (user_id = app.current_user_id());

create policy chat_messages_read_self on public.chat_messages
  for select to authenticated
  using (exists (
    select 1 from public.chat_threads t
    where t.id = thread_id and t.user_id = app.current_user_id()
  ));

create policy notification_preferences_all_self
  on public.notification_preferences
  for all to authenticated
  using (user_id = app.current_user_id())
  with check (user_id = app.current_user_id());

create policy device_tokens_all_self on public.device_tokens
  for all to authenticated
  using (user_id = app.current_user_id())
  with check (user_id = app.current_user_id());

create policy notifications_read_self on public.notifications
  for select to authenticated using (user_id = app.current_user_id());

create policy notifications_mark_read on public.notifications
  for update to authenticated
  using (user_id = app.current_user_id())
  with check (user_id = app.current_user_id());

-- ------------------------------------------- read-only entitlement data --

create policy payment_status_read_self on public.payment_status
  for select to authenticated using (user_id = app.current_user_id());

create policy telco_charges_read_self on public.telco_charges
  for select to authenticated using (user_id = app.current_user_id());

create policy ai_usage_read_self on public.ai_usage
  for select to authenticated using (user_id = app.current_user_id());

create policy quota_usage_read_self on public.quota_usage
  for select to authenticated using (user_id = app.current_user_id());
