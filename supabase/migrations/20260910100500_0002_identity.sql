-- Identity and profile (PRD 8, "Identity and Profile").
--
-- These are our own tables because PRD 4.4 does not use Supabase Auth. The
-- MSISDN is the account identity and the same number the telco rail charges
-- (PRD 6.1), so it is unique and normalised to E.164 before it ever gets
-- here.

create table public.users (
  id                 uuid primary key default gen_random_uuid(),
  msisdn             text not null unique,
  msisdn_verified_at timestamptz,
  status             public.user_status not null default 'active',
  created_at         timestamptz not null default now(),
  last_login_at      timestamptz,
  constraint users_msisdn_e164 check (msisdn ~ '^\+94[0-9]{9}$')
);

comment on column public.users.msisdn is
  'E.164, always +94 followed by nine digits. The client normalises before
   sending; the constraint is here so a second client cannot invent a
   variant that would split one person into two accounts.';

create table public.profiles (
  user_id             uuid primary key
                        references public.users(id) on delete cascade,
  full_name           text not null,
  language_preference public.language_code not null default 'en',
  theme_preference    public.theme_preference not null default 'system',
  -- Optional and skippable (PRD 6.2). Used for recommendation and internal
  -- analytics only; no surface in the product shows them to anyone else.
  district            text,
  target_exam_date    date,
  current_status      text,
  education_level     text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint profiles_full_name_present check (length(btrim(full_name)) > 0)
);

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function app.touch_updated_at();

-- OTP is never stored in the clear. The Edge Function hashes it before the
-- row is written and compares hashes on verify (PRD 6.1).
create table public.otp_requests (
  id            uuid primary key default gen_random_uuid(),
  msisdn        text not null,
  otp_hash      text not null,
  expires_at    timestamptz not null,
  attempt_count int not null default 0,
  consumed_at   timestamptz,
  request_ip    inet,
  device_id     text,
  created_at    timestamptz not null default now()
);

create index otp_requests_msisdn_live_idx
  on public.otp_requests (msisdn, created_at desc)
  where consumed_at is null;

create index otp_requests_expiry_idx on public.otp_requests (expires_at);

-- One row per signed-in device. Refresh tokens rotate on use, which is what
-- makes "sign out other devices" in PRD 6.1 actually enforceable rather
-- than cosmetic.
create table public.auth_sessions (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.users(id) on delete cascade,
  device_id          text not null,
  device_name        text,
  refresh_token_hash text not null,
  issued_at          timestamptz not null default now(),
  last_seen_at       timestamptz not null default now(),
  revoked_at         timestamptz
);

create index auth_sessions_user_idx
  on public.auth_sessions (user_id, last_seen_at desc);
create unique index auth_sessions_live_device_idx
  on public.auth_sessions (user_id, device_id)
  where revoked_at is null;
