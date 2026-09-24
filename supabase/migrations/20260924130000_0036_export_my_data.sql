-- Data export on request (PRD 6.1, 6.9).
--
-- One call returns everything the product holds about the caller, as a
-- single JSON document the app saves and hands to the share sheet.
--
-- Scoped to app.current_user_id() and nothing else, so it cannot be pointed
-- at another account. Left out on purpose:
--   * refresh_token_hash and push_token: credentials, not personal data, and
--     an export file travels by email and chat apps.
--   * raw_callback and raw_payload: the providers' own messages, which can
--     carry their identifiers and signatures. The billing facts they
--     produced are exported instead.
--   * the notification push queue's bookkeeping (dedupe key, attempts).
--   * question text: answers carry the question id only. The bank is the
--     protected asset (PRD 9.3), and an export must not become a way to
--     page through it.

create function public.export_my_data()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, app, pg_temp
as $$
declare
  uid uuid := app.current_user_id();
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'format', 'smart-iq-export/1',
    'exported_at', now(),

    'account', (
      select jsonb_build_object(
        'user_id', u.id,
        'msisdn', u.msisdn,
        'msisdn_verified_at', u.msisdn_verified_at,
        'status', u.status,
        'created_at', u.created_at,
        'last_login_at', u.last_login_at
      )
      from public.users u where u.id = uid
    ),

    'profile', (
      select to_jsonb(p) - 'user_id'
      from public.profiles p where p.user_id = uid
    ),

    'subscription', jsonb_build_object(
      'status', (
        select to_jsonb(ps) - 'user_id'
        from public.payment_status ps where ps.user_id = uid
      ),
      'telco_charges', coalesce((
        select jsonb_agg(jsonb_build_object(
          'charge_date', t.charge_date,
          'provider', t.provider,
          'msisdn', t.msisdn,
          'status', t.status,
          'received_at', t.received_at
        ) order by t.charge_date)
        from public.telco_charges t where t.user_id = uid
      ), '[]'::jsonb),
      'store_events', coalesce((
        select jsonb_agg(jsonb_build_object(
          'event_type', r.event_type,
          'product_id', r.product_id,
          'received_at', r.received_at
        ) order by r.received_at)
        from public.revenuecat_events r where r.user_id = uid
      ), '[]'::jsonb)
    ),

    'practice_sessions', coalesce((
      select jsonb_agg(
        (to_jsonb(s) - 'user_id') || jsonb_build_object(
          'answers', coalesce((
            select jsonb_agg(to_jsonb(a) - 'session_id' order by a.sort_order)
            from public.session_answers a where a.session_id = s.id
          ), '[]'::jsonb)
        )
        order by s.started_at
      )
      from public.practice_sessions s where s.user_id = uid
    ), '[]'::jsonb),

    'daily_challenges', coalesce((
      select jsonb_agg(to_jsonb(d) - 'user_id' order by d.challenge_date)
      from public.daily_challenge_participation d where d.user_id = uid
    ), '[]'::jsonb),

    'streak', (
      select to_jsonb(st) - 'user_id'
      from public.user_streaks st where st.user_id = uid
    ),

    'topic_mastery', coalesce((
      select jsonb_agg(to_jsonb(m) - 'user_id' order by m.sub_topic_id)
      from public.user_topic_mastery m where m.user_id = uid
    ), '[]'::jsonb),

    'bookmarks', coalesce((
      select jsonb_agg(to_jsonb(b) - 'user_id' order by b.created_at)
      from public.bookmarks b where b.user_id = uid
    ), '[]'::jsonb),

    'wrong_answer_bank', coalesce((
      select jsonb_agg(to_jsonb(w) - 'user_id' order by w.last_wrong_at)
      from public.wrong_answer_bank w where w.user_id = uid
    ), '[]'::jsonb),

    'usage', jsonb_build_object(
      'quota', coalesce((
        select jsonb_agg(to_jsonb(q) - 'user_id' order by q.period_start, q.counter_key)
        from public.quota_usage q where q.user_id = uid
      ), '[]'::jsonb),
      'ai_messages', coalesce((
        select jsonb_agg(to_jsonb(ai) - 'user_id' order by ai.usage_date)
        from public.ai_usage ai where ai.user_id = uid
      ), '[]'::jsonb)
    ),

    'chat_threads', coalesce((
      select jsonb_agg(
        (to_jsonb(ct) - 'user_id') || jsonb_build_object(
          'messages', coalesce((
            select jsonb_agg(to_jsonb(cm) - 'thread_id' order by cm.created_at)
            from public.chat_messages cm where cm.thread_id = ct.id
          ), '[]'::jsonb)
        )
        order by ct.created_at
      )
      from public.chat_threads ct where ct.user_id = uid
    ), '[]'::jsonb),

    'notifications', coalesce((
      select jsonb_agg(jsonb_build_object(
        'kind', n.kind,
        'title', n.title,
        'body', n.body,
        'created_at', n.created_at,
        'read_at', n.read_at
      ) order by n.created_at)
      from public.notifications n where n.user_id = uid
    ), '[]'::jsonb),

    'notification_preferences', coalesce((
      select jsonb_object_agg(np.kind, np.enabled)
      from public.notification_preferences np where np.user_id = uid
    ), '{}'::jsonb),

    'devices', coalesce((
      select jsonb_agg(jsonb_build_object(
        'device_name', a.device_name,
        'issued_at', a.issued_at,
        'last_seen_at', a.last_seen_at,
        'revoked_at', a.revoked_at
      ) order by a.issued_at)
      from public.auth_sessions a where a.user_id = uid
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;
