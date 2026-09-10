-- Function hardening.
--
-- Two fixes, both flagged by the database linter.
--
-- 1. Pin search_path on every function. Without it, pg_temp is searched
--    first, so a caller who can create a temporary object can shadow a
--    table name inside a SECURITY DEFINER function and have it run against
--    their object with the definer's privileges. Listing pg_temp last
--    closes that.
--
-- 2. Revoke EXECUTE from anon. Supabase's default privileges grant it on
--    functions in the public schema, so revoking from PUBLIC alone did not
--    remove it. Every one of these functions already refuses an
--    unauthenticated caller, but a signed-out client should not reach the
--    function body at all.

do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('app', 'public')
      and p.prokind = 'f'
      and p.proname in (
        'current_user_id', 'sl_today', 'sl_month', 'touch_updated_at',
        'tier_limit', 'consume_quota', 'quota_used', 'current_tier',
        'profile_json', 'mode_allowed', 'open_session', 'render_question',
        'assert_question_publishable',
        'get_entitlement', 'get_questions_by_ids', 'create_profile',
        'delete_account', 'get_practice_set', 'get_mock_exam',
        'get_daily_challenge', 'submit_practice_session', 'get_progress',
        'get_categories', 'get_sub_topics', 'get_current_affairs'
      )
  loop
    execute format(
      'alter function %s set search_path = public, app, pg_temp', fn.sig
    );
  end loop;
end $$;

revoke execute on function public.get_entitlement() from anon;
revoke execute on function public.get_questions_by_ids(uuid[]) from anon;
revoke execute on function public.create_profile(text, text, text, date, text, text) from anon;
revoke execute on function public.delete_account() from anon;
revoke execute on function public.get_practice_set(text, uuid, uuid, int) from anon;
revoke execute on function public.get_mock_exam(int) from anon;
revoke execute on function public.get_daily_challenge() from anon;
revoke execute on function public.submit_practice_session(uuid, jsonb, int) from anon;
revoke execute on function public.get_progress() from anon;
revoke execute on function public.get_categories() from anon;
revoke execute on function public.get_sub_topics(uuid) from anon;
revoke execute on function public.get_current_affairs(int) from anon;

-- New tables in this schema must not silently become client-readable if a
-- future migration forgets a grant.
alter default privileges in schema public
  revoke execute on functions from anon;
