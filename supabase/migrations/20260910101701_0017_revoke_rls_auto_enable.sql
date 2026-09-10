-- rls_auto_enable is Supabase's own event-trigger function, which turns RLS
-- on for any new table in the public schema. It is not ours and it stays.
--
-- What it should not be is reachable over the REST API. Event triggers fire
-- as their owner regardless of who holds EXECUTE, so revoking it changes
-- nothing about the automatic behaviour and removes it from the exposed
-- surface.
revoke execute on function public.rls_auto_enable() from anon, authenticated, public;
