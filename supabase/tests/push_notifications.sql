-- Smoke test for migration 0020 (push notifications).
--
-- Transactional, like the rest of the schema checks (see README): creates
-- throwaway users, runs every job, asserts on what was queued, then rolls
-- back. Safe to run against the live project; nothing survives it.
--
--   psql "$DATABASE_URL" -f supabase/tests/push_notifications.sql
--
-- A failed assertion raises, which aborts the transaction and prints which
-- check failed. "push smoke test passed" means every check held.

begin;

do $$
declare
  si  uuid;   -- Sinhala, practised yesterday, Pro on RevenueCat
  en  uuid;   -- English, streak kind switched off, long inactive
  n   int;
  r   record;
  today date := app.sl_today();
begin
  insert into public.users (msisdn) values ('+94770000001') returning id into si;
  insert into public.users (msisdn) values ('+94770000002') returning id into en;

  insert into public.profiles (user_id, full_name, language_preference, created_at)
  values (si, 'Test SI', 'si', now() - interval '30 days'),
         (en, 'Test EN', 'en', now() - interval '30 days');

  insert into public.notification_preferences (user_id, kind, enabled)
  select u, k, not (u = en and k = 'streak')
  from unnest(array[si, en]) u, unnest(enum_range(null::public.notification_kind)) k;

  insert into public.user_streaks (user_id, current_streak, last_practice_date)
  values (si, 4, today - 1), (en, 4, today - 1);

  -- streak: only the user who left the kind on, in their own language.
  perform app.job_streak_at_risk();
  select * into r from public.notifications where user_id = si and kind = 'streak';
  if r.id is null then raise exception 'streak: not queued for si'; end if;
  if r.title not like '%4%' or r.title not like '%අඛණ්ඩතාව%' then
    raise exception 'streak: wrong copy %', r.title;
  end if;
  if r.push_status <> 'pending' then raise exception 'streak: status %', r.push_status; end if;
  if exists (select 1 from public.notifications where user_id = en and kind = 'streak') then
    raise exception 'streak: sent to a user who turned it off';
  end if;

  -- Re-running is a no-op.
  perform app.job_streak_at_risk();
  select count(*) into n from public.notifications where user_id = si and kind = 'streak';
  if n <> 1 then raise exception 'streak: dedupe failed, % rows', n; end if;

  -- inactivity: the English user has been away for over a week.
  update public.user_streaks set last_practice_date = today - 8 where user_id = en;
  perform app.job_inactivity();
  if not exists (select 1 from public.notifications where user_id = en and kind = 'inactivity') then
    raise exception 'inactivity: not queued';
  end if;
  if exists (select 1 from public.notifications where user_id = si and kind = 'inactivity') then
    raise exception 'inactivity: sent to an active user';
  end if;

  -- renewal: RevenueCat plan ending in exactly renewal_reminder_days.
  insert into public.payment_status (user_id, tier, source, status, valid_until)
  values (si, 'pro', 'revenuecat', 'active',
          ((today + app.setting_int('renewal_reminder_days', 3))::timestamp + interval '12 hours')
            at time zone 'Asia/Colombo');
  perform app.job_renewal_reminder();
  if not exists (select 1 from public.notifications where user_id = si and kind = 'renewal') then
    raise exception 'renewal: not queued';
  end if;

  -- daily challenge: Pro includes it, Free (the English user) does not.
  insert into public.daily_challenges (challenge_date) values (today) on conflict do nothing;
  perform app.job_daily_challenge();
  if not exists (select 1 from public.notifications where user_id = si and kind = 'daily_challenge') then
    raise exception 'daily challenge: not queued for Pro';
  end if;
  if exists (select 1 from public.notifications where user_id = en and kind = 'daily_challenge') then
    raise exception 'daily challenge: sent to Free';
  end if;

  -- charge failed via the telco trigger, once per charge.
  insert into public.telco_charges (user_id, msisdn, provider, charge_date, status)
  values (en, '+94770000002', 'test', today, 'failed');
  select count(*) into n from public.notifications where user_id = en and kind = 'charge_failed';
  if n <> 1 then raise exception 'charge failed: % rows', n; end if;

  -- digest on publish, English fallback title for a missing translation.
  insert into public.current_affairs (publish_date, type, status)
  values (today, 'daily', 'draft') returning id into r;
  insert into public.current_affairs_translations (item_id, language, title)
  values (r.id, 'en', 'Budget 2027 passed');
  update public.current_affairs set status = 'live' where id = r.id;
  if not exists (
    select 1 from public.notifications
    where user_id = si and kind = 'digest' and body = 'Budget 2027 passed'
  ) then
    raise exception 'digest: not queued with fallback title';
  end if;

  -- The dispatcher's claim hands over the batch and marks it sending.
  insert into public.device_tokens (user_id, device_id, push_token)
  values (si, 'dev-1', 'tok-1');
  select count(*) into n from public.claim_push_batch(500) c where c.user_id = si and c.tokens <> '[]';
  if n = 0 then raise exception 'claim: nothing claimed with tokens'; end if;
  if exists (select 1 from public.notifications where user_id = si and push_status = 'pending') then
    raise exception 'claim: rows left pending';
  end if;

  raise notice 'push smoke test passed';
end $$;

rollback;
