-- Entitlement, billing rails and tunable limits (PRD 7, PRD 8 "Billing").
--
-- PRD 7.1: the two rails are independent sources and neither is read
-- directly by the application. payment_status is the single source of
-- truth, and app.current_tier() is the only way anything else asks what a
-- user is entitled to.

create table public.payment_status (
  user_id         uuid primary key references public.users(id) on delete cascade,
  tier            public.tier_key not null default 'free',
  source          public.entitlement_source,
  status          public.entitlement_status not null default 'none',
  valid_until     timestamptz,
  last_checked_at timestamptz,
  updated_at      timestamptz not null default now()
);

create trigger payment_status_touch_updated_at
  before update on public.payment_status
  for each row execute function app.touch_updated_at();

create table public.telco_charges (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references public.users(id) on delete set null,
  msisdn       text not null,
  provider     text not null,
  charge_date  date not null,
  status       text not null,
  raw_callback jsonb,
  received_at  timestamptz not null default now()
);

create index telco_charges_user_idx
  on public.telco_charges (user_id, charge_date desc);

create table public.revenuecat_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references public.users(id) on delete set null,
  event_type  text not null,
  product_id  text,
  raw_payload jsonb,
  received_at timestamptz not null default now()
);

-- PRD 7.2: routing is decided by the first three digits of the MSISDN, and
-- the mapping is editable without an app release, which is the whole reason
-- it is a table.
create table public.msisdn_prefix_routing (
  prefix   text primary key,
  provider text not null,
  endpoint text not null,
  active   boolean not null default true,
  constraint msisdn_prefix_shape check (prefix ~ '^[0-9]{3}$')
);

-- PRD 7.5/7.6: every limit is configuration, tunable per tier from the
-- admin panel with no app release. -1 means unlimited; boolean limits are
-- stored as 0 or 1 so one table covers both kinds.
create table public.tier_limits (
  tier        public.tier_key not null,
  limit_key   text not null,
  limit_value int not null,
  updated_at  timestamptz not null default now(),
  primary key (tier, limit_key)
);

create trigger tier_limits_touch_updated_at
  before update on public.tier_limits
  for each row execute function app.touch_updated_at();

create or replace function app.tier_limit(p_tier public.tier_key, p_key text)
returns int
language sql
stable
as $$
  select coalesce(
    (select limit_value from public.tier_limits
      where tier = p_tier and limit_key = p_key),
    0
  );
$$;

-- The flat shape the client reads. Keeping the storage table narrow keeps
-- the admin panel generic; keeping this view wide means the app fetches one
-- row instead of pivoting a dozen.
create or replace view public.tier_limits_effective
with (security_invoker = true) as
select
  t.tier::text                                          as tier,
  app.tier_limit(t.tier, 'questions_per_day')           as questions_per_day,
  app.tier_limit(t.tier, 'ai_messages_per_day')         as ai_messages_per_day,
  app.tier_limit(t.tier, 'mock_exams_per_month')        as mock_exams_per_month,
  app.tier_limit(t.tier, 'max_practice_set_size')       as max_practice_set_size,
  app.tier_limit(t.tier, 'daily_challenge') = 1         as daily_challenge,
  app.tier_limit(t.tier, 'adaptive_difficulty') = 1     as adaptive_difficulty,
  app.tier_limit(t.tier, 'study_plan') = 1              as study_plan,
  app.tier_limit(t.tier, 'speed_drills') = 1            as speed_drills,
  app.tier_limit(t.tier, 'chat_retention_days')         as chat_retention_days,
  app.tier_limit(t.tier, 'wrong_answer_bank_full') = 1  as wrong_answer_bank_full,
  app.tier_limit(t.tier, 'wrong_answer_bank_limited') = 1 as wrong_answer_bank_limited
from (select unnest(enum_range(null::public.tier_key)) as tier) t;

-- Counters, one row per user per counter per period. Written only through
-- SECURITY DEFINER functions; the client has no write path to it at all,
-- because a client that can edit its own counter has no quota (PRD 9.4).
create table public.quota_usage (
  user_id      uuid not null references public.users(id) on delete cascade,
  counter_key  text not null,
  period_start date not null,
  used         int not null default 0,
  updated_at   timestamptz not null default now(),
  primary key (user_id, counter_key, period_start)
);

-- The resolved tier. Anything expired, failed or absent is Free Fallback,
-- with no grace period on either rail (PRD 7.2, 7.3).
create or replace function app.current_tier(p_user uuid)
returns public.tier_key
language sql
stable
as $$
  select case
    when p.user_id is null then 'free'::public.tier_key
    when p.status <> 'active' then 'free'::public.tier_key
    when p.valid_until is not null and p.valid_until < now()
      then 'free'::public.tier_key
    else p.tier
  end
  from (select 1) dummy
  left join public.payment_status p on p.user_id = p_user;
$$;
