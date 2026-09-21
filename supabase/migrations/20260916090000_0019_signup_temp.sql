-- Pending signups.
--
-- The name a user types on the signup screen has, until now, existed only in
-- memory on the handset between that screen and profile creation several
-- steps later. This holds it server-side for the window in which the number
-- is unverified, from the moment signup is submitted until the code is
-- checked.
--
-- It is deliberately not part of `users`: nothing here has proved it owns the
-- number yet, and a row in `users` is an account.

create table public.temp (
  id         uuid primary key default gen_random_uuid(),
  msisdn     text not null unique,
  full_name  text not null,
  created_at timestamptz not null default now(),
  -- The same two constraints `users` and `profiles` carry, so a number cannot
  -- be spelled one way here and another way there, and a blank name cannot
  -- be parked for a profile that will later reject it.
  constraint temp_msisdn_e164 check (msisdn ~ '^\+94[0-9]{9}$'),
  constraint temp_full_name_present check (length(btrim(full_name)) > 0)
);

comment on table public.temp is
  'Name and number for a signup whose OTP has not been verified yet. Written
   by the otp-request Edge Function, deleted by otp-verify. Unique on msisdn,
   so a resend or a second attempt overwrites rather than accumulating.';

create index temp_created_at_idx on public.temp (created_at);

-- Default deny, the same treatment otp_requests gets in 0008: RLS on with no
-- policy at all. Only the service role inside the Edge Functions sees this,
-- which matters more here than for most tables because the rows are a name
-- and a phone number that nobody has authenticated against yet.
alter table public.temp enable row level security;

-- Abandoned signups would otherwise sit here indefinitely: someone types a
-- name and a number, never enters the code, and the row stays.
--
-- Deliberately not called from otp-request. Every call that function makes is
-- a separate round trip out through the API gateway, and those round trips —
-- not the SQL, which runs in single-digit milliseconds — are what make the
-- endpoint slow. Adding a sweep to the signup path would charge every user
-- for cleaning up after everyone else. Schedule it instead, or run it by
-- hand; a row older than a day belongs to a code that expired long before.
create or replace function app.purge_stale_signups()
returns void
language sql
security definer
set search_path = public, app, pg_temp
as $$
  delete from public.temp where created_at < now() - interval '1 day';
$$;

revoke all on function app.purge_stale_signups() from public, anon, authenticated;
