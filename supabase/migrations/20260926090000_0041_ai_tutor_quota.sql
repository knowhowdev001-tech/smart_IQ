-- AI tutor quota (PRD 4.5, 6.4, 7.6).
--
-- The ai-chat Edge Function is the enforcement point: it reserves one
-- message before forwarding to the endpoint and gives it back if the
-- endpoint fails. Both go through the same `ai_messages` counter that
-- get_entitlement already reports as `ai_messages_today`, so the client's
-- quota line moves without any change on its side.
--
-- Called with the service role only. The function authenticates the caller
-- itself (our own JWTs, not Supabase Auth), so it passes the user id in.

create or replace function public.consume_ai_message(p_user uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  t public.tier_key := app.current_tier(p_user);
  lim int;
begin
  select l.ai_messages_per_day into lim
    from public.tier_limits_effective l
   where l.tier = t::text;

  return jsonb_build_object(
    'allowed', app.consume_quota(
      p_user, 'ai_messages', app.sl_today(), 1, coalesce(lim, 0)
    ),
    'tier', t::text,
    'limit', coalesce(lim, 0)
  );
end;
$$;

-- A reply the student never got should not cost them one of Free's two
-- messages. Floors at zero so a double refund cannot mint credit.
create or replace function public.refund_ai_message(p_user uuid)
returns void
language sql
security definer
set search_path = public, app
as $$
  update public.quota_usage
     set used = greatest(used - 1, 0),
         updated_at = now()
   where user_id = p_user
     and counter_key = 'ai_messages'
     and period_start = app.sl_today();
$$;

revoke execute on function public.consume_ai_message(uuid)
  from public, anon, authenticated;
revoke execute on function public.refund_ai_message(uuid)
  from public, anon, authenticated;
grant execute on function public.consume_ai_message(uuid) to service_role;
grant execute on function public.refund_ai_message(uuid) to service_role;
