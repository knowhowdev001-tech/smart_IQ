-- Signing out another device, without letting a client rewrite its sessions.
--
-- 0008 let a signed-in user UPDATE their own auth_sessions rows so the app
-- could stamp revoked_at, but a row policy cannot restrict columns, and the
-- table grant covered all of them. A client could set revoked_at back to
-- null, which means whoever holds a stolen access token could undo "sign out
-- that device" for as long as the token lasts. It could also overwrite
-- refresh_token_hash or move device_id.
--
-- Revocation is now one RPC that can only ever stamp revoked_at, and only
-- forwards: an already revoked row is left as it was. The table goes back to
-- read-only for clients, and the read no longer includes the token hash,
-- which no screen has a use for.

drop policy auth_sessions_revoke_self on public.auth_sessions;

revoke update on public.auth_sessions from authenticated, anon;
revoke select on public.auth_sessions from authenticated, anon;
grant select (id, user_id, device_id, device_name, issued_at, last_seen_at, revoked_at)
  on public.auth_sessions to authenticated;

create function public.revoke_session(p_session_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, app, pg_temp
as $$
declare
  uid uuid := app.current_user_id();
  hit int;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  update public.auth_sessions
  set revoked_at = now()
  where id = p_session_id
    and user_id = uid
    and revoked_at is null;

  get diagnostics hit = row_count;
  return hit > 0;
end;
$$;

revoke all on function public.revoke_session(uuid) from public, anon;
grant execute on function public.revoke_session(uuid) to authenticated;
