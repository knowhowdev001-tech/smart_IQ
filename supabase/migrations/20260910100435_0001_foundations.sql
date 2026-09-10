-- Foundations: schema, enumerated types and the helpers every later
-- migration leans on.
--
-- PRD 4.4 rejects Supabase Auth outright, so identity is our own. The one
-- thing we keep is the JWT shape: the Edge Function signs tokens with the
-- project JWT secret and sets `sub` to users.id, which is what lets
-- auth.uid() and therefore ordinary RLS keep working (PRD 4.4, token
-- strategy). app.current_user_id() is the accessor everything else uses so
-- that assumption lives in exactly one place.

create extension if not exists pgcrypto with schema extensions;

create schema if not exists app;
comment on schema app is
  'Internal helpers and quota machinery. Not exposed through PostgREST.';

-- ---------------------------------------------------------------- enums --

create type public.language_code as enum ('si', 'ta', 'en');
create type public.theme_preference as enum ('light', 'dark', 'system');
create type public.user_status as enum ('active', 'suspended', 'deleted');

create type public.tier_key as enum ('free', 'basic', 'pro', 'pro_plus');
create type public.difficulty as enum ('easy', 'medium', 'hard');
create type public.question_status as enum ('draft', 'live', 'retired');
create type public.current_affairs_type as enum ('daily', 'weekly', 'monthly');

create type public.practice_mode as enum (
  'quick', 'timed', 'speed', 'adaptive',
  'daily_challenge', 'mock_exam', 'wrong_answer_drill'
);
create type public.answer_outcome as enum ('correct', 'incorrect', 'skipped');
create type public.chat_role as enum ('user', 'assistant');

create type public.entitlement_source as enum ('telco', 'revenuecat');
create type public.entitlement_status as enum (
  'active', 'failed', 'cancelled', 'expired', 'none'
);

create type public.notification_kind as enum (
  'daily_challenge', 'streak', 'digest',
  'charge_failed', 'renewal', 'inactivity'
);

-- -------------------------------------------------------------- helpers --

-- The signed-in user, or null. Deliberately forgiving: an absent or
-- malformed claim means "not signed in", never an error, because it is read
-- inside RLS policies where an exception would surface as a 500 rather than
-- an empty result.
create or replace function app.current_user_id()
returns uuid
language plpgsql
stable
as $$
declare
  raw text;
begin
  raw := nullif(current_setting('request.jwt.claims', true), '');
  if raw is null then
    return null;
  end if;
  return nullif(raw::jsonb ->> 'sub', '')::uuid;
exception
  when others then
    return null;
end;
$$;

-- PRD 7.6: quota counters reset on a daily boundary in Sri Lanka time.
-- Every counter key is derived from this, never from the server's own date.
create or replace function app.sl_today()
returns date
language sql
stable
as $$
  select (now() at time zone 'Asia/Colombo')::date;
$$;

create or replace function app.sl_month()
returns date
language sql
stable
as $$
  select date_trunc('month', (now() at time zone 'Asia/Colombo'))::date;
$$;

create or replace function app.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on schema app from anon, authenticated;
