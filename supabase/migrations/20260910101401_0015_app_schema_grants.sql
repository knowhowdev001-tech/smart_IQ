-- Grants on the internal schema.
--
-- RLS policy expressions are evaluated with the privileges of the querying
-- role, so every policy that calls app.current_user_id() or app.sl_today()
-- needs the client to be able to execute them. Without this, RLS fails with
-- "permission denied for schema app" instead of filtering rows.
--
-- The grant is narrow on purpose: usage on the schema, execute on the two
-- read-only helpers, and nothing else. The functions that move quota or
-- open sessions stay unreachable, which is the whole point of them living
-- in a separate schema.

grant usage on schema app to authenticated;

grant execute on function app.current_user_id() to authenticated;
grant execute on function app.sl_today() to authenticated;
grant execute on function app.sl_month() to authenticated;
grant execute on function app.tier_limit(public.tier_key, text) to authenticated;

-- Postgres grants EXECUTE to PUBLIC by default, so anything the client must
-- not call has to be revoked explicitly rather than merely not granted.
revoke execute on function app.consume_quota(uuid, text, date, int, int)
  from public, anon, authenticated;
revoke execute on function app.open_session(uuid, public.practice_mode, uuid[], uuid, uuid)
  from public, anon, authenticated;
revoke execute on function app.render_question(uuid)
  from public, anon, authenticated;
revoke execute on function app.quota_used(uuid, text, date)
  from public, anon, authenticated;
revoke execute on function app.profile_json(uuid)
  from public, anon, authenticated;
revoke execute on function app.current_tier(uuid)
  from public, anon, authenticated;
revoke execute on function app.mode_allowed(public.tier_key, public.practice_mode)
  from public, anon, authenticated;
revoke execute on function app.assert_question_publishable()
  from public, anon, authenticated;
revoke execute on function app.touch_updated_at()
  from public, anon, authenticated;
