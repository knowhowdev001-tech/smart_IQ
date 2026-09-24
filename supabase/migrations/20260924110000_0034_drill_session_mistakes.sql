-- "Drill wrong answers" drills the answers that were just wrong.
--
-- The results screen offers the button as soon as a session has mistakes,
-- but submit schedules each of those for review tomorrow, and the drill only
-- served rows already due. So the button always found an empty bank and the
-- quiz opened on an error.
--
-- The drill now takes the ids it wants. They are matched against the
-- caller's own bank, not trusted: a list of arbitrary ids must not become a
-- way to read questions around the quota (PRD 4.6). Without ids it serves
-- what is due, as before.
--
-- A new parameter needs a drop rather than `create or replace`, which would
-- leave two overloads and make PostgREST refuse to choose between them.
-- get_mock_exam calls this positionally with four arguments and needs no
-- change.

drop function public.get_practice_set(text, uuid, uuid, int);

create function public.get_practice_set(
  p_mode         text   default 'quick',
  p_sub_topic_id uuid   default null,
  p_category_id  uuid   default null,
  p_size         int    default 10,
  p_question_ids uuid[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, app, pg_temp
as $$
declare
  uid        uuid := app.current_user_id();
  tier       public.tier_key;
  mode       public.practice_mode;
  today      date := app.sl_today();
  month      date := app.sl_month();
  max_size   int;
  want       int;
  ids        uuid[];
  got        int;
  sid        uuid;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  mode := p_mode::public.practice_mode;
  tier := app.current_tier(uid);

  if not app.mode_allowed(tier, mode) then
    raise exception 'mode % is not available on tier %', mode, tier
      using errcode = 'P0001', hint = 'upgrade_required';
  end if;

  max_size := app.tier_limit(tier, 'max_practice_set_size');
  if max_size <= 0 then
    raise exception 'no practice allowance on tier %', tier
      using errcode = 'P0001', hint = 'quota_exceeded';
  end if;
  want := greatest(1, least(coalesce(p_size, 10), max_size));

  -- Pick first, charge second. Questions the user has not seen come first;
  -- seen ones top the set up rather than leaving it short.
  if mode = 'wrong_answer_drill' then
    select array_agg(q.id order by random())
      into ids
    from (
      select w.question_id as id
      from public.wrong_answer_bank w
      join public.questions qq on qq.id = w.question_id
      where w.user_id = uid
        and w.retired_at is null
        and qq.status = 'live'
        -- Named ids are drilled now, whatever their schedule says; with
        -- none, only what spaced repetition says is due.
        and case when p_question_ids is null
                 then w.next_review_at <= now()
                 else w.question_id = any(p_question_ids) end
      order by w.next_review_at
      limit want
    ) q;
  else
    select array_agg(id order by seen, difficulty_rank, rnd)
      into ids
    from (
      select
        q.id,
        exists (
          select 1 from public.session_answers sa
          join public.practice_sessions s on s.id = sa.session_id
          where s.user_id = uid
            and sa.question_id = q.id
            and s.started_at > now() - interval '30 days'
        )::int as seen,
        -- Adaptive sets lean easier on sub-topics the user is weak in and
        -- harder where they are strong (PRD 6.3). Every other mode ignores
        -- this and falls to a flat rank.
        case when mode = 'adaptive' then
          abs(
            case q.difficulty when 'easy' then 30 when 'medium' then 60 else 85 end
            - coalesce((
                select m.accuracy from public.user_topic_mastery m
                where m.user_id = uid and m.sub_topic_id = q.sub_topic_id
              ), 55)
          )
        else 0 end as difficulty_rank,
        random() as rnd
      from public.questions q
      join public.sub_topics st on st.id = q.sub_topic_id
      where q.status = 'live'
        and (p_sub_topic_id is null or q.sub_topic_id = p_sub_topic_id)
        and (p_category_id is null or st.category_id = p_category_id)
      order by seen, difficulty_rank, rnd
      limit want
    ) picked;
  end if;

  got := coalesce(array_length(ids, 1), 0);
  if got = 0 then
    raise exception 'no questions available for this selection'
      using errcode = 'P0001', hint = 'empty_set';
  end if;

  -- Mock exams are charged against the monthly allowance, not the daily
  -- question count (PRD 7.5 lists them as separate limits).
  if mode = 'mock_exam' then
    if not app.consume_quota(uid, 'mock_exams', month, 1,
                             app.tier_limit(tier, 'mock_exams_per_month')) then
      raise exception 'monthly mock exam allowance exhausted'
        using errcode = 'P0001', hint = 'quota_exceeded';
    end if;
  elsif mode <> 'daily_challenge' then
    if not app.consume_quota(uid, 'questions', today, got,
                             app.tier_limit(tier, 'questions_per_day')) then
      raise exception 'daily question allowance exhausted'
        using errcode = 'P0001', hint = 'quota_exceeded';
    end if;
  end if;

  sid := app.open_session(uid, mode, ids, p_sub_topic_id, p_category_id);

  return jsonb_build_object(
    'session_id', sid,
    'mode', mode::text,
    'question_count', got,
    'questions', (
      select coalesce(jsonb_agg(app.render_question(qid) order by ord), '[]'::jsonb)
      from unnest(ids) with ordinality as t(qid, ord)
    )
  );
end;
$$;

revoke all on function public.get_practice_set(text, uuid, uuid, int, uuid[])
  from public, anon;
grant execute on function public.get_practice_set(text, uuid, uuid, int, uuid[])
  to authenticated;
