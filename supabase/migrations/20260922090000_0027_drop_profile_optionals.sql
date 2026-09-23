-- District and target exam date leave the product.
--
-- Both were collected on a profile-setup screen at the end of signup and
-- then read by exactly one home stat tile; no screen could edit them
-- afterwards. That screen is gone -- the profile is created the moment a
-- code is verified, from the name given at signup -- so the columns have no
-- writer and no reader left.
--
-- current_status and education_level stay: equally unused today, but they
-- are for a profile the user fills in rather than a screen being removed.

alter table public.profiles
  drop column district,
  drop column target_exam_date;

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
    'current_status', p.current_status,
    'education_level', p.education_level,
    'created_at', p.created_at
  )
  from public.profiles p
  join public.users u on u.id = p.user_id
  where p.user_id = p_user;
$$;

-- The parameter list changes, and create-or-replace cannot do that: leaving
-- the six-argument version in place would give PostgREST two candidates.
drop function public.create_profile(text, text, text, date, text, text);

create function public.create_profile(
  p_full_name       text,
  p_language        text default 'en',
  p_current_status  text default null,
  p_education_level text default null
)
returns jsonb
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

  if length(btrim(coalesce(p_full_name, ''))) = 0 then
    raise exception 'full name is required' using errcode = '22023';
  end if;

  insert into public.profiles (
    user_id, full_name, language_preference,
    current_status, education_level
  ) values (
    uid, btrim(p_full_name), p_language::public.language_code,
    p_current_status, p_education_level
  )
  on conflict (user_id) do update
    set full_name = excluded.full_name,
        language_preference = excluded.language_preference,
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

revoke all on function public.create_profile(text, text, text, text) from public;
grant execute on function public.create_profile(text, text, text, text) to authenticated;
revoke execute on function public.create_profile(text, text, text, text) from anon;
