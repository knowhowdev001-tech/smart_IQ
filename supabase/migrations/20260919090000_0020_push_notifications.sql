-- Push notifications (PRD 6.8).
--
-- `notifications` is both the inbox and the outbox. Every trigger below
-- inserts a row; the `push-dispatch` Edge Function claims pending rows and
-- sends them through FCM. A push the device never receives therefore still
-- shows up in the in-app inbox.
--
--   pg_cron ─► app.job_*() ─┐
--   telco_charges trigger ──┼─► insert into notifications (push_status 'pending')
--   current_affairs live ───┤        │
--   future webhooks ────────┘        ▼
--   pg_cron (1 min) ─► app.kick_push_dispatch() ─► push-dispatch ─► FCM
--
-- Preferences are enforced here, at enqueue time, not by the dispatcher: a
-- kind the user switched off never produces a row, so it cannot surface in
-- the inbox either.

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- ------------------------------------------------------------ settings --

-- Tunables the admin panel can change without a release. Service-only: RLS
-- on and no policy, the same treatment otp_requests gets in 0008.
create table public.app_settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.app_settings enable row level security;

create trigger app_settings_touch_updated_at
  before update on public.app_settings
  for each row execute function app.touch_updated_at();

insert into public.app_settings (key, value) values
  -- Days without practice or sign-in before the win-back push.
  ('inactivity_days', '3'),
  -- Days before valid_until that the renewal reminder goes out.
  ('renewal_reminder_days', '3');

create or replace function app.setting_int(p_key text, p_default int)
returns int
language sql
stable
set search_path = public, app, pg_temp
as $$
  select coalesce(
    (select (value #>> '{}')::int from public.app_settings where key = p_key),
    p_default
  );
$$;

-- ----------------------------------------------------------- templates --

-- Pushes arrive while the app is closed, so the copy cannot come from the
-- app's ARB files. {placeholders} are filled from the enqueue's vars.
create table public.notification_templates (
  kind     public.notification_kind not null,
  language public.language_code not null,
  title    text not null,
  body     text not null,
  primary key (kind, language)
);

alter table public.notification_templates enable row level security;

insert into public.notification_templates (kind, language, title, body) values
  ('daily_challenge', 'en', 'Today''s challenge is ready',
   'A fresh set of questions is waiting. Take it on before midnight.'),
  ('daily_challenge', 'si', 'අද අභියෝගය සූදානම්',
   'නව ප්‍රශ්න කට්ටලයක් ඔබ එනතුරු බලා සිටී. මධ්‍යම රාත්‍රියට පෙර උත්සාහ කරන්න.'),
  ('daily_challenge', 'ta', 'இன்றைய சவால் தயார்',
   'புதிய கேள்விகள் காத்திருக்கின்றன. நள்ளிரவுக்கு முன் முயற்சி செய்யுங்கள்.'),

  ('streak', 'en', 'Keep your {streak}-day streak alive',
   'Practise a few questions today so your streak does not reset.'),
  ('streak', 'si', 'ඔබේ දින {streak} අඛණ්ඩතාව රැක ගන්න',
   'අඛණ්ඩතාව බිඳී නොයන ලෙස අද ප්‍රශ්න කිහිපයක් පුහුණු වන්න.'),
  ('streak', 'ta', 'உங்கள் {streak} நாள் தொடர்ச்சியைத் தக்கவையுங்கள்',
   'தொடர்ச்சி முறியாமல் இருக்க இன்று சில கேள்விகளைப் பயிற்சி செய்யுங்கள்.'),

  ('digest', 'en', 'New current affairs',
   '{title}'),
  ('digest', 'si', 'නව කාලීන සිදුවීම්',
   '{title}'),
  ('digest', 'ta', 'புதிய நடப்பு நிகழ்வுகள்',
   '{title}'),

  ('charge_failed', 'en', 'We could not renew your plan',
   'Your last subscription charge did not go through. Top up or update your payment to keep your plan.'),
  ('charge_failed', 'si', 'ඔබේ සැලසුම අලුත් කිරීමට නොහැකි විය',
   'ඔබේ අවසන් දායක ගාස්තුව අසාර්ථක විය. සැලසුම තබා ගැනීමට රීලෝඩ් කරන්න හෝ ගෙවීම් ක්‍රමය යාවත්කාලීන කරන්න.'),
  ('charge_failed', 'ta', 'உங்கள் திட்டத்தைப் புதுப்பிக்க முடியவில்லை',
   'உங்கள் கடைசி சந்தா கட்டணம் தோல்வியடைந்தது. திட்டத்தைத் தொடர ரீசார்ஜ் செய்யுங்கள் அல்லது கட்டண முறையைப் புதுப்பியுங்கள்.'),

  ('renewal', 'en', 'Your plan renews in {days} days',
   'No action needed if you want to keep going. You can manage your plan from your profile.'),
  ('renewal', 'si', 'ඔබේ සැලසුම දින {days} කින් අලුත් වේ',
   'දිගටම යාමට කිසිවක් කිරීමට අවශ්‍ය නැත. ඔබේ පැතිකඩෙන් සැලසුම කළමනාකරණය කළ හැක.'),
  ('renewal', 'ta', 'உங்கள் திட்டம் {days} நாட்களில் புதுப்பிக்கப்படும்',
   'தொடர எதுவும் செய்ய வேண்டியதில்லை. உங்கள் சுயவிவரத்திலிருந்து திட்டத்தை நிர்வகிக்கலாம்.'),

  ('inactivity', 'en', 'We miss you',
   'Your exam is not going to wait. Pick up where you left off with a quick practice set.'),
  ('inactivity', 'si', 'අපි ඔබව මග හැරෙනවා',
   'ඔබේ විභාගය බලා නොසිටී. කෙටි පුහුණු කට්ටලයකින් නැවත ආරම්භ කරන්න.'),
  ('inactivity', 'ta', 'உங்களைக் காணவில்லை',
   'உங்கள் தேர்வு காத்திருக்காது. ஒரு சிறிய பயிற்சித் தொகுப்புடன் மீண்டும் தொடங்குங்கள்.');

create or replace function app.render_template(
  p_kind     public.notification_kind,
  p_language public.language_code,
  p_vars     jsonb
)
returns table (title text, body text)
language plpgsql
stable
set search_path = public, app, pg_temp
as $$
declare
  v record;
begin
  -- English is the fallback for a language the content team has not
  -- written yet, so a missing row degrades to readable rather than silent.
  select t.title, t.body into title, body
  from public.notification_templates t
  where t.kind = p_kind and t.language in (p_language, 'en')
  order by (t.language = p_language) desc
  limit 1;

  if title is null then
    return;
  end if;

  for v in select * from jsonb_each_text(coalesce(p_vars, '{}'::jsonb)) loop
    title := replace(title, '{' || v.key || '}', v.value);
    body  := replace(body,  '{' || v.key || '}', v.value);
  end loop;

  return next;
end;
$$;

-- ---------------------------------------------------------- the outbox --

-- Existing rows predate push delivery and must not all fire at once on
-- deploy, so the column is added as 'skipped' and only then defaulted.
alter table public.notifications
  add column dedupe_key      text unique,
  add column push_status     text not null default 'skipped',
  add column push_attempts   int  not null default 0,
  add column push_claimed_at timestamptz,
  add constraint notifications_push_status_known
    check (push_status in ('pending', 'sending', 'sent', 'failed', 'skipped'));

alter table public.notifications alter column push_status set default 'pending';

create index notifications_push_pending_idx
  on public.notifications (created_at)
  where push_status in ('pending', 'sending');

-- The client may mark its own rows read and nothing else. Without this the
-- update policy in 0008 would also let it rewrite title or push_status.
revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

-- Who can receive a given kind: active, has a profile, has not switched the
-- kind off. A missing preference row counts as on, matching the default
-- create_profile seeds.
create or replace function app.push_audience(p_kind public.notification_kind)
returns table (user_id uuid, language public.language_code)
language sql
stable
set search_path = public, app, pg_temp
as $$
  select u.id, p.language_preference
  from public.users u
  join public.profiles p on p.user_id = u.id
  left join public.notification_preferences np
    on np.user_id = u.id and np.kind = p_kind
  where u.status = 'active'
    and coalesce(np.enabled, true);
$$;

-- The single-user entry point, for anything outside this migration that
-- needs to notify someone (the RevenueCat webhook, the admin panel).
-- Returns the new row's id, or null when the user opted out or the dedupe
-- key was already used.
create or replace function public.enqueue_notification(
  p_user   uuid,
  p_kind   public.notification_kind,
  p_dedupe text,
  p_vars   jsonb default '{}'::jsonb,
  p_route  text default null
)
returns uuid
language sql
security definer
set search_path = public, app, pg_temp
as $$
  insert into public.notifications
    (user_id, kind, title, body, payload, dedupe_key)
  select a.user_id, p_kind, t.title, t.body,
         jsonb_build_object('route', p_route), p_dedupe
  from app.push_audience(p_kind) a
  cross join lateral app.render_template(p_kind, a.language, p_vars) t
  where a.user_id = p_user
  on conflict (dedupe_key) do nothing
  returning id;
$$;

revoke all on function public.enqueue_notification(uuid, public.notification_kind, text, jsonb, text)
  from public, anon, authenticated;
grant execute on function public.enqueue_notification(uuid, public.notification_kind, text, jsonb, text)
  to service_role;

-- ---------------------------------------------------------------- jobs --
--
-- Each job is idempotent through its dedupe key, so a cron retry or a
-- manual rerun never double-sends.

-- 07:00 SL. Only tiers that include the challenge (PRD 6.7): telling a
-- Free user about something they cannot open is a paywall, not a reminder.
create or replace function app.job_daily_challenge()
returns int
language plpgsql
security definer
set search_path = public, app, pg_temp
as $$
declare
  today date := app.sl_today();
  n int;
begin
  if not exists (select 1 from public.daily_challenges where challenge_date = today) then
    return 0;
  end if;

  insert into public.notifications (user_id, kind, title, body, payload, dedupe_key)
  select a.user_id, 'daily_challenge', t.title, t.body,
         jsonb_build_object('route', '/home'),
         format('dc:%s:%s', today, a.user_id)
  from app.push_audience('daily_challenge') a
  cross join lateral app.render_template('daily_challenge', a.language, '{}') t
  where app.tier_limit(app.current_tier(a.user_id), 'daily_challenge') = 1
    and not exists (
      select 1 from public.daily_challenge_participation dp
      where dp.user_id = a.user_id and dp.challenge_date = today
    )
  on conflict (dedupe_key) do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;

-- 20:00 SL. Practised yesterday but not yet today: the streak breaks at
-- midnight unless they practise now.
create or replace function app.job_streak_at_risk()
returns int
language plpgsql
security definer
set search_path = public, app, pg_temp
as $$
declare
  today date := app.sl_today();
  n int;
begin
  insert into public.notifications (user_id, kind, title, body, payload, dedupe_key)
  select a.user_id, 'streak', t.title, t.body,
         jsonb_build_object('route', '/practice'),
         format('streak:%s:%s', today, a.user_id)
  from app.push_audience('streak') a
  join public.user_streaks s on s.user_id = a.user_id
  cross join lateral app.render_template(
    'streak', a.language, jsonb_build_object('streak', s.current_streak)
  ) t
  where s.current_streak > 0
    and s.last_practice_date = today - 1
  on conflict (dedupe_key) do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;

-- 10:00 SL. RevenueCat plans only: the telco rail charges daily, so a
-- countdown to a date that moves forward every day would fire forever.
create or replace function app.job_renewal_reminder()
returns int
language plpgsql
security definer
set search_path = public, app, pg_temp
as $$
declare
  days int := app.setting_int('renewal_reminder_days', 3);
  n int;
begin
  insert into public.notifications (user_id, kind, title, body, payload, dedupe_key)
  select a.user_id, 'renewal', t.title, t.body,
         jsonb_build_object('route', '/profile'),
         format('renew:%s:%s', ps.valid_until::date, a.user_id)
  from app.push_audience('renewal') a
  join public.payment_status ps on ps.user_id = a.user_id
  cross join lateral app.render_template(
    'renewal', a.language, jsonb_build_object('days', days)
  ) t
  where ps.status = 'active'
    and ps.source = 'revenuecat'
    and ps.tier <> 'free'
    and (ps.valid_until at time zone 'Asia/Colombo')::date = app.sl_today() + days
  on conflict (dedupe_key) do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;

-- 18:00 SL. Once per stretch of inactivity: the dedupe key carries the
-- last active date, so coming back and drifting away again earns a new
-- reminder but staying away does not earn one a day.
create or replace function app.job_inactivity()
returns int
language plpgsql
security definer
set search_path = public, app, pg_temp
as $$
declare
  today date := app.sl_today();
  days int := app.setting_int('inactivity_days', 3);
  n int;
begin
  insert into public.notifications (user_id, kind, title, body, payload, dedupe_key)
  select a.user_id, 'inactivity', t.title, t.body,
         jsonb_build_object('route', '/practice'),
         format('inactive:%s:%s', la.last_active, a.user_id)
  from app.push_audience('inactivity') a
  join public.profiles p on p.user_id = a.user_id
  join public.users u on u.id = a.user_id
  left join public.user_streaks s on s.user_id = a.user_id
  cross join lateral (
    select greatest(
      s.last_practice_date,
      (u.last_login_at at time zone 'Asia/Colombo')::date,
      (select max(last_seen_at at time zone 'Asia/Colombo')::date
         from public.auth_sessions where user_id = a.user_id),
      (p.created_at at time zone 'Asia/Colombo')::date
    ) as last_active
  ) la
  cross join lateral app.render_template('inactivity', a.language, '{}') t
  where la.last_active <= today - days
  on conflict (dedupe_key) do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;

-- Digest: fires when an item goes live, not on a schedule, so the push
-- goes out when the content team presses publish. The body is the item's
-- own title in the reader's language.
create or replace function app.on_current_affairs_live()
returns trigger
language plpgsql
security definer
set search_path = public, app, pg_temp
as $$
begin
  if new.status <> 'live' then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if old.status = 'live' then
      return new;
    end if;
  end if;

  insert into public.notifications (user_id, kind, title, body, payload, dedupe_key)
  select a.user_id, 'digest', t.title, t.body,
         jsonb_build_object('route', '/home', 'current_affairs_id', new.id),
         format('digest:%s:%s', new.id, a.user_id)
  from app.push_audience('digest') a
  left join public.current_affairs_translations ct
    on ct.item_id = new.id and ct.language = a.language
  left join public.current_affairs_translations ct_en
    on ct_en.item_id = new.id and ct_en.language = 'en'
  cross join lateral app.render_template(
    'digest', a.language,
    jsonb_build_object('title', coalesce(ct.title, ct_en.title, ''))
  ) t
  on conflict (dedupe_key) do nothing;

  return new;
end;
$$;

create trigger current_affairs_notify_live
  after insert or update of status on public.current_affairs
  for each row execute function app.on_current_affairs_live();

-- Charge failed on the telco rail. The RevenueCat side has no table of its
-- own outcomes yet; its webhook calls public.enqueue_notification directly.
create or replace function app.on_telco_charge_failed()
returns trigger
language plpgsql
security definer
set search_path = public, app, pg_temp
as $$
begin
  if new.user_id is null or lower(new.status) <> 'failed' then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if lower(old.status) = 'failed' then
      return new;
    end if;
  end if;

  perform public.enqueue_notification(
    new.user_id, 'charge_failed', format('chargefail:%s', new.id),
    '{}'::jsonb, '/profile'
  );
  return new;
end;
$$;

create trigger telco_charges_notify_failed
  after insert or update of status on public.telco_charges
  for each row execute function app.on_telco_charge_failed();

-- ------------------------------------------------------- device tokens --

-- An FCM token belongs to an install, not a person. When a second account
-- signs in on the same phone the token must leave the first account, or
-- the first user's streak reminders land on someone else's lock screen.
create or replace function public.register_device_token(
  p_device_id text,
  p_token     text,
  p_platform  text default 'android'
)
returns void
language plpgsql
security definer
set search_path = public, app, pg_temp
as $$
declare
  uid uuid := app.current_user_id();
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if coalesce(p_token, '') = '' or coalesce(p_device_id, '') = '' then
    raise exception 'device and token are required' using errcode = '22023';
  end if;

  delete from public.device_tokens
  where (push_token = p_token or device_id = p_device_id)
    and user_id <> uid;

  insert into public.device_tokens (user_id, device_id, push_token, platform)
  values (uid, p_device_id, p_token, p_platform)
  on conflict (user_id, device_id) do update
    set push_token = excluded.push_token,
        platform   = excluded.platform,
        updated_at = now();
end;
$$;

revoke all on function public.register_device_token(text, text, text) from public, anon;
grant execute on function public.register_device_token(text, text, text) to authenticated;

create index device_tokens_token_idx on public.device_tokens (push_token);

-- ------------------------------------------------------------ dispatch --

-- Hands the dispatcher a batch with each recipient's tokens attached.
-- SKIP LOCKED lets two overlapping invocations split the queue instead of
-- double-sending. A row stuck in 'sending' (the function died mid-batch)
-- is reclaimed after ten minutes, up to three attempts.
create or replace function public.claim_push_batch(p_limit int default 200)
returns table (
  id      uuid,
  user_id uuid,
  kind    text,
  title   text,
  body    text,
  payload jsonb,
  tokens  jsonb
)
language plpgsql
security definer
set search_path = public, app, pg_temp
as $$
begin
  -- A daily-challenge push that arrives the next afternoon is noise.
  update public.notifications n
     set push_status = 'skipped'
   where n.push_status in ('pending', 'sending')
     and (n.created_at < now() - interval '12 hours' or n.push_attempts >= 3);

  return query
  with batch as (
    select n.id
    from public.notifications n
    where n.push_status = 'pending'
       or (n.push_status = 'sending'
           and n.push_claimed_at < now() - interval '10 minutes')
    order by n.created_at
    limit p_limit
    for update skip locked
  ), claimed as (
    update public.notifications n
       set push_status = 'sending',
           push_attempts = n.push_attempts + 1,
           push_claimed_at = now()
      from batch
     where n.id = batch.id
    returning n.id, n.user_id, n.kind, n.title, n.body, n.payload
  )
  select c.id, c.user_id, c.kind::text, c.title, c.body, c.payload,
         coalesce(
           (select jsonb_agg(jsonb_build_object(
                     'device_id', d.device_id,
                     'token', d.push_token,
                     'platform', d.platform))
              from public.device_tokens d
             where d.user_id = c.user_id),
           '[]'::jsonb)
  from claimed c;
end;
$$;

revoke all on function public.claim_push_batch(int) from public, anon, authenticated;
grant execute on function public.claim_push_batch(int) to service_role;

-- Called every minute, but only spends an Edge Function invocation when
-- there is something to send. The URL and shared secret live in Vault:
--
--   select vault.create_secret('https://<ref>.supabase.co/functions/v1/push-dispatch', 'push_dispatch_url');
--   select vault.create_secret('<random>', 'push_dispatch_secret');
--
-- Until both exist this is a no-op, so local stacks and branches without
-- FCM credentials simply accumulate an inbox.
create or replace function app.kick_push_dispatch()
returns void
language plpgsql
security definer
set search_path = public, app, pg_temp
as $$
declare
  url text;
  secret text;
begin
  if not exists (
    select 1 from public.notifications
    where push_status = 'pending'
       or (push_status = 'sending' and push_claimed_at < now() - interval '10 minutes')
  ) then
    return;
  end if;

  select decrypted_secret into url
    from vault.decrypted_secrets where name = 'push_dispatch_url';
  select decrypted_secret into secret
    from vault.decrypted_secrets where name = 'push_dispatch_secret';
  if url is null or secret is null then
    return;
  end if;

  perform net.http_post(
    url := url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-dispatch-secret', secret),
    body := '{}'::jsonb,
    timeout_milliseconds := 55000
  );
end;
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'app.setting_int(text, int)',
    'app.render_template(public.notification_kind, public.language_code, jsonb)',
    'app.push_audience(public.notification_kind)',
    'app.job_daily_challenge()',
    'app.job_streak_at_risk()',
    'app.job_renewal_reminder()',
    'app.job_inactivity()',
    'app.on_current_affairs_live()',
    'app.on_telco_charge_failed()',
    'app.kick_push_dispatch()'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', fn);
  end loop;
end $$;

-- ------------------------------------------------------------ schedule --
--
-- pg_cron runs in UTC; Sri Lanka is UTC+05:30 with no DST.

select cron.schedule('push-daily-challenge', '30 1 * * *',  'select app.job_daily_challenge()');   -- 07:00 SL
select cron.schedule('push-renewal',         '30 4 * * *',  'select app.job_renewal_reminder()');  -- 10:00 SL
select cron.schedule('push-inactivity',      '30 12 * * *', 'select app.job_inactivity()');        -- 18:00 SL
select cron.schedule('push-streak',          '30 14 * * *', 'select app.job_streak_at_risk()');    -- 20:00 SL
select cron.schedule('push-dispatch',        '* * * * *',   'select app.kick_push_dispatch()');
