-- Quota accounting (PRD 7.6, 9.3).
--
-- The check and the increment happen in one statement. That is what makes
-- the limit safe against a client firing parallel requests to race it --
-- the reason PRD 9.3 insists question serving goes through an RPC rather
-- than a plain read.

-- Reserves `p_amount` against a counter, or returns false if that would
-- exceed the limit. -1 means unlimited. The insert-on-conflict is the whole
-- point: one atomic statement, no read-then-write window.
create or replace function app.consume_quota(
  p_user         uuid,
  p_counter      text,
  p_period_start date,
  p_amount       int,
  p_limit        int
)
returns boolean
language plpgsql
as $$
declare
  updated int;
begin
  if p_limit = -1 then
    insert into public.quota_usage (user_id, counter_key, period_start, used)
    values (p_user, p_counter, p_period_start, p_amount)
    on conflict (user_id, counter_key, period_start)
      do update set used = public.quota_usage.used + p_amount,
                    updated_at = now();
    return true;
  end if;

  if p_limit <= 0 or p_amount > p_limit then
    return false;
  end if;

  insert into public.quota_usage (user_id, counter_key, period_start, used)
  values (p_user, p_counter, p_period_start, p_amount)
  on conflict (user_id, counter_key, period_start)
    do update set used = public.quota_usage.used + p_amount,
                  updated_at = now()
    where public.quota_usage.used + p_amount <= p_limit;

  get diagnostics updated = row_count;
  return updated > 0;
end;
$$;

create or replace function app.quota_used(
  p_user uuid, p_counter text, p_period_start date
)
returns int
language sql
stable
as $$
  select coalesce(
    (select used from public.quota_usage
      where user_id = p_user and counter_key = p_counter
        and period_start = p_period_start),
    0
  );
$$;

-- The entitlement the client reads on every app open (PRD 7.3). Shaped to
-- match the client's Entitlement model exactly so the repository swap is a
-- deserialisation change and nothing more.
create or replace function public.get_entitlement()
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  uid uuid := app.current_user_id();
  t public.tier_key;
  today date := app.sl_today();
  month_start date := app.sl_month();
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  t := app.current_tier(uid);

  return jsonb_build_object(
    'tier', t::text,
    'limits', (
      select to_jsonb(l) from public.tier_limits_effective l
      where l.tier = t::text
    ),
    'usage', jsonb_build_object(
      'questions_today',      app.quota_used(uid, 'questions', today),
      'ai_messages_today',    app.quota_used(uid, 'ai_messages', today),
      'mock_exams_this_month', app.quota_used(uid, 'mock_exams', month_start),
      'as_of', now()
    ),
    'source', (select source::text from public.payment_status where user_id = uid),
    'valid_until', (select valid_until from public.payment_status where user_id = uid),
    'last_checked_at', (select last_checked_at from public.payment_status where user_id = uid)
  );
end;
$$;

revoke all on function public.get_entitlement() from public;
grant execute on function public.get_entitlement() to authenticated;
