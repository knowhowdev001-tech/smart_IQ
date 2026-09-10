-- Serving practice sets (PRD 9.3).
--
-- Questions are never plain-selectable. Every set comes from here, where
-- the tier gate, the quota check and the increment happen in one
-- transaction. Selection runs before the charge so a user is never billed
-- quota for questions the bank could not supply.

create or replace function app.mode_allowed(
  p_tier public.tier_key, p_mode public.practice_mode
)
returns boolean
language sql
stable
as $$
  select case p_mode
    when 'speed'              then app.tier_limit(p_tier, 'speed_drills') = 1
    when 'adaptive'           then app.tier_limit(p_tier, 'adaptive_difficulty') = 1
    when 'daily_challenge'    then app.tier_limit(p_tier, 'daily_challenge') = 1
    when 'mock_exam'          then app.tier_limit(p_tier, 'mock_exams_per_month') <> 0
    when 'wrong_answer_drill' then
      app.tier_limit(p_tier, 'wrong_answer_bank_full') = 1
      or app.tier_limit(p_tier, 'wrong_answer_bank_limited') = 1
    else true
  end;
$$;

-- Opens a session and writes its manifest. Rows land in session_answers at
-- issue time with outcome 'skipped', which is both the list the submit RPC
-- scores against and the right answer for a question never reached.
create or replace function app.open_session(
  p_user uuid,
  p_mode public.practice_mode,
  p_question_ids uuid[],
  p_sub_topic uuid,
  p_category uuid
)
returns uuid
language plpgsql
as $$
declare
  sid uuid;
begin
  insert into public.practice_sessions (
    user_id, type, sub_topic_id, category_id, question_count
  ) values (
    p_user, p_mode, p_sub_topic, p_category, array_length(p_question_ids, 1)
  ) returning id into sid;

  insert into public.session_answers (session_id, question_id, sort_order)
  select sid, qid, ord
  from unnest(p_question_ids) with ordinality as t(qid, ord);

  return sid;
end;
$$;

create or replace function public.get_practice_set(
  p_mode         text default 'quick',
  p_sub_topic_id uuid default null,
  p_category_id  uuid default null,
  p_size         int  default 10
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
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
        and w.next_review_at <= now()
        and qq.status = 'live'
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

create or replace function public.get_mock_exam(p_size int default 50)
returns jsonb
language sql
security definer
set search_path = public, app
as $$
  select public.get_practice_set('mock_exam', null, null, p_size);
$$;

-- Today's set, shared by everyone, plus the participation row that the
-- streak and the "already done today" state read from (PRD 6.7).
create or replace function public.get_daily_challenge()
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  uid   uuid := app.current_user_id();
  tier  public.tier_key;
  today date := app.sl_today();
  ids   uuid[];
  sid   uuid;
  existing uuid;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  tier := app.current_tier(uid);
  if not app.mode_allowed(tier, 'daily_challenge') then
    raise exception 'daily challenge is not available on tier %', tier
      using errcode = 'P0001', hint = 'upgrade_required';
  end if;

  select array_agg(dq.question_id order by dq.sort_order)
    into ids
  from public.daily_challenge_questions dq
  join public.questions q on q.id = dq.question_id and q.status = 'live'
  where dq.challenge_date = today;

  if coalesce(array_length(ids, 1), 0) = 0 then
    raise exception 'no daily challenge published for %', today
      using errcode = 'P0001', hint = 'empty_set';
  end if;

  -- Returning the same session on a second call is deliberate: the
  -- challenge is one attempt per day, so a reopened app resumes rather than
  -- silently starting again.
  select p.session_id into existing
  from public.daily_challenge_participation p
  where p.user_id = uid and p.challenge_date = today;

  if existing is not null then
    sid := existing;
  else
    sid := app.open_session(uid, 'daily_challenge', ids, null, null);
    insert into public.daily_challenge_participation
      (user_id, challenge_date, session_id)
    values (uid, today, sid)
    on conflict (user_id, challenge_date) do update
      set session_id = excluded.session_id;
  end if;

  return jsonb_build_object(
    'session_id', sid,
    'mode', 'daily_challenge',
    'challenge_date', today,
    'question_count', array_length(ids, 1),
    'questions', (
      select coalesce(jsonb_agg(app.render_question(qid) order by ord), '[]'::jsonb)
      from unnest(ids) with ordinality as t(qid, ord)
    )
  );
end;
$$;

revoke all on function public.get_practice_set(text, uuid, uuid, int) from public;
grant execute on function public.get_practice_set(text, uuid, uuid, int) to authenticated;
revoke all on function public.get_mock_exam(int) from public;
grant execute on function public.get_mock_exam(int) to authenticated;
revoke all on function public.get_daily_challenge() from public;
grant execute on function public.get_daily_challenge() to authenticated;
