-- Profile and account lifecycle (PRD 9.3).

create or replace function app.profile_json(p_user uuid)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'user_id', p.user_id,
    'full_name', p.full_name,
    'language_preference', p.language_preference::text,
    'theme_preference', p.theme_preference::text,
    'msisdn', u.msisdn,
    'district', p.district,
    'target_exam_date', p.target_exam_date,
    'current_status', p.current_status,
    'education_level', p.education_level,
    'created_at', p.created_at
  )
  from public.profiles p
  join public.users u on u.id = p.user_id
  where p.user_id = p_user;
$$;

-- First sign-in profile creation. One profile per user is enforced here
-- rather than left to the client, which is the only reason this is an RPC
-- and not an insert policy.
create or replace function public.create_profile(
  p_full_name        text,
  p_language         text default 'en',
  p_district         text default null,
  p_target_exam_date date default null,
  p_current_status   text default null,
  p_education_level  text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  uid uuid := app.current_user_id();
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if length(btrim(coalesce(p_full_name, ''))) = 0 then
    raise exception 'full name is required' using errcode = '22023';
  end if;

  insert into public.profiles (
    user_id, full_name, language_preference,
    district, target_exam_date, current_status, education_level
  ) values (
    uid, btrim(p_full_name), p_language::public.language_code,
    p_district, p_target_exam_date, p_current_status, p_education_level
  )
  on conflict (user_id) do update
    set full_name = excluded.full_name,
        language_preference = excluded.language_preference,
        district = coalesce(excluded.district, public.profiles.district),
        target_exam_date = coalesce(excluded.target_exam_date,
                                    public.profiles.target_exam_date),
        current_status = coalesce(excluded.current_status,
                                  public.profiles.current_status),
        education_level = coalesce(excluded.education_level,
                                   public.profiles.education_level);

  -- Free Fallback until a rail says otherwise. PRD 7.3: absent charging
  -- status is Free Fallback, not an error and not a grace period.
  insert into public.payment_status (user_id, tier, status)
  values (uid, 'free', 'none')
  on conflict (user_id) do nothing;

  insert into public.user_streaks (user_id) values (uid)
  on conflict (user_id) do nothing;

  insert into public.notification_preferences (user_id, kind, enabled)
  select uid, k, true
  from unnest(enum_range(null::public.notification_kind)) k
  on conflict do nothing;

  return app.profile_json(uid);
end;
$$;

-- Cascading deletion under a single transaction (PRD 9.3). Every
-- user-scoped table cascades from users, so this is one delete; the
-- function exists so the client cannot be given a delete policy on users.
create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public, app
as $$
declare
  uid uuid := app.current_user_id();
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  -- Charge and webhook rows are financial records. They are unlinked rather
  -- than deleted so reconciliation still balances after the account goes.
  update public.telco_charges set user_id = null where user_id = uid;
  update public.revenuecat_events set user_id = null where user_id = uid;

  delete from public.users where id = uid;
end;
$$;

revoke all on function public.create_profile(text, text, text, date, text, text) from public;
grant execute on function public.create_profile(text, text, text, date, text, text) to authenticated;
revoke all on function public.delete_account() from public;
grant execute on function public.delete_account() to authenticated;
