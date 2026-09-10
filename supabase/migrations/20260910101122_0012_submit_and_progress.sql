-- Scoring and progress (PRD 9.3, 6.3, 6.6).
--
-- Scoring happens here and nowhere else. The client never tells the server
-- whether an answer was right; it sends which option was tapped, and the
-- correct option is compared server-side against the row the client was
-- never allowed to read.

create or replace function public.submit_practice_session(
  p_session_id       uuid,
  p_answers          jsonb default '[]'::jsonb,
  p_duration_seconds int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  uid       uuid := app.current_user_id();
  sess      public.practice_sessions%rowtype;
  correct   int;
  incorrect int;
  skipped   int;
  total     int;
  points    numeric(6,2);
  today     date := app.sl_today();
  prev_date date;
  cur_streak int;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select * into sess from public.practice_sessions
  where id = p_session_id and user_id = uid
  for update;

  if not found then
    raise exception 'session not found' using errcode = 'P0002';
  end if;
  if sess.completed_at is not null then
    raise exception 'session already submitted' using errcode = 'P0001',
      hint = 'already_submitted';
  end if;

  -- Only questions actually issued to this session are updated. An answer
  -- for anything else is ignored rather than rejected, so a stale client
  -- retry cannot fail the whole submission.
  update public.session_answers sa
  set selected_option   = a.selected_option,
      time_taken        = a.time_taken,
      marked_for_review = coalesce(a.marked_for_review, false),
      is_correct        = (a.selected_option is not null
                           and a.selected_option = q.correct_option_id),
      outcome = case
        when a.selected_option is null then 'skipped'::public.answer_outcome
        when a.selected_option = q.correct_option_id
          then 'correct'::public.answer_outcome
        else 'incorrect'::public.answer_outcome
      end,
      answered_at = case when a.selected_option is null then null else now() end
  from jsonb_to_recordset(p_answers) as a(
    question_id uuid,
    selected_option uuid,
    time_taken int,
    marked_for_review boolean
  )
  join public.questions q on q.id = a.question_id
  where sa.session_id = p_session_id
    and sa.question_id = a.question_id;

  select
    count(*) filter (where outcome = 'correct'),
    count(*) filter (where outcome = 'incorrect'),
    count(*) filter (where outcome = 'skipped'),
    count(*)
  into correct, incorrect, skipped, total
  from public.session_answers where session_id = p_session_id;

  -- Mock exams carry negative marking (PRD 6.3). Skipped questions are
  -- never penalised, which is what makes leaving one blank a real choice.
  points := case
    when sess.type = 'mock_exam' then correct - (incorrect * 0.25)
    else correct
  end;

  update public.practice_sessions
  set completed_at = now(),
      correct_count = correct,
      incorrect_count = incorrect,
      skipped_count = skipped,
      score = points,
      duration_seconds = coalesce(
        p_duration_seconds,
        greatest(0, extract(epoch from (now() - sess.started_at))::int)
      )
  where id = p_session_id;

  -- Mastery per sub-topic, recomputed from the user's whole history rather
  -- than nudged, so a replayed submission cannot drift it.
  insert into public.user_topic_mastery
    (user_id, sub_topic_id, correct_count, sample_size, accuracy, updated_at)
  select
    uid,
    q.sub_topic_id,
    count(*) filter (where sa.outcome = 'correct'),
    count(*) filter (where sa.outcome <> 'skipped'),
    case when count(*) filter (where sa.outcome <> 'skipped') = 0 then 0
         else round(
           100.0 * count(*) filter (where sa.outcome = 'correct')
           / count(*) filter (where sa.outcome <> 'skipped')
         )::int end,
    now()
  from public.session_answers sa
  join public.practice_sessions s on s.id = sa.session_id
  join public.questions q on q.id = sa.question_id
  where s.user_id = uid
    and s.completed_at is not null
    and q.sub_topic_id in (
      select q2.sub_topic_id from public.session_answers sa2
      join public.questions q2 on q2.id = sa2.question_id
      where sa2.session_id = p_session_id
    )
  group by q.sub_topic_id
  on conflict (user_id, sub_topic_id) do update
    set correct_count = excluded.correct_count,
        sample_size = excluded.sample_size,
        accuracy = excluded.accuracy,
        updated_at = now();

  -- Wrong answers are retained and resurfaced on a widening interval
  -- (PRD 6.3). A wrong answer resets the schedule; a right one advances it.
  insert into public.wrong_answer_bank
    (user_id, question_id, next_review_at, review_count, last_wrong_at)
  select uid, sa.question_id, now() + interval '1 day', 0, now()
  from public.session_answers sa
  where sa.session_id = p_session_id and sa.outcome = 'incorrect'
  on conflict (user_id, question_id) do update
    set next_review_at = now() + interval '1 day',
        review_count = 0,
        last_wrong_at = now(),
        retired_at = null;

  update public.wrong_answer_bank w
  set review_count = w.review_count + 1,
      next_review_at = now() + (
        case w.review_count
          when 0 then interval '3 days'
          when 1 then interval '7 days'
          when 2 then interval '16 days'
          else interval '35 days'
        end
      ),
      retired_at = case when w.review_count + 1 >= 4 then now() else null end
  from public.session_answers sa
  where sa.session_id = p_session_id
    and sa.outcome = 'correct'
    and w.user_id = uid
    and w.question_id = sa.question_id
    and w.retired_at is null;

  -- Streaks count consecutive Sri Lanka days with a completed session
  -- (PRD 6.7). Two sessions on one day is still one day.
  select last_practice_date, current_streak into prev_date, cur_streak
  from public.user_streaks where user_id = uid;

  if prev_date is null then
    cur_streak := 1;
  elsif prev_date = today then
    cur_streak := greatest(coalesce(cur_streak, 1), 1);
  elsif prev_date = today - 1 then
    cur_streak := coalesce(cur_streak, 0) + 1;
  else
    cur_streak := 1;
  end if;

  insert into public.user_streaks
    (user_id, current_streak, longest_streak, last_practice_date, updated_at)
  values (uid, cur_streak, cur_streak, today, now())
  on conflict (user_id) do update
    set current_streak = cur_streak,
        longest_streak = greatest(public.user_streaks.longest_streak, cur_streak),
        last_practice_date = today,
        updated_at = now();

  return jsonb_build_object(
    'session_id', p_session_id,
    'mode', sess.type::text,
    'question_count', total,
    'correct_count', correct,
    'incorrect_count', incorrect,
    'skipped_count', skipped,
    'score', points,
    'accuracy', case when total = 0 then 0
                     else round(100.0 * correct / total)::int end,
    'streak_days', cur_streak,
    'breakdown', coalesce((
      select jsonb_agg(jsonb_build_object(
        'sub_topic_id', b.sub_topic_id,
        'name', b.names,
        'correct', b.correct,
        'total', b.total
      ))
      from (
        select q.sub_topic_id,
               st.display_names as names,
               count(*) filter (where sa.outcome = 'correct') as correct,
               count(*) as total
        from public.session_answers sa
        join public.questions q on q.id = sa.question_id
        join public.sub_topics st on st.id = q.sub_topic_id
        where sa.session_id = p_session_id
        group by q.sub_topic_id, st.display_names
      ) b
    ), '[]'::jsonb)
  );
end;
$$;

-- The dashboard (PRD 6.6). Everything here is self-referential; no query in
-- this function reads another user's row, which is not an accident.
create or replace function public.get_progress()
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  uid       uuid := app.current_user_id();
  lang      text;
  answered  int;
  correct   int;
  sessions  int;
  accuracy  numeric;
  volume    numeric;
  readiness int;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select language_preference::text into lang
  from public.profiles where user_id = uid;
  lang := coalesce(lang, 'en');

  select
    count(*) filter (where sa.outcome <> 'skipped'),
    count(*) filter (where sa.outcome = 'correct')
  into answered, correct
  from public.session_answers sa
  join public.practice_sessions s on s.id = sa.session_id
  where s.user_id = uid and s.completed_at is not null;

  select count(*) into sessions
  from public.practice_sessions
  where user_id = uid and completed_at is not null;

  accuracy := case when answered = 0 then 0 else correct::numeric / answered end;

  -- Readiness is accuracy discounted by how little evidence there is behind
  -- it. A user three questions in has not earned a high score, however well
  -- those three went.
  volume := least(1.0, answered / 200.0);
  readiness := round(accuracy * 100 * (0.4 + 0.6 * volume));

  return jsonb_build_object(
    'streak_days', coalesce(
      (select current_streak from public.user_streaks where user_id = uid), 0),
    'readiness_score', readiness,
    'questions_answered', answered,
    'sessions_completed', sessions,
    'overall_accuracy', accuracy,
    'recent_accuracy', coalesce((
      select jsonb_agg(a order by started_at)
      from (
        select started_at,
               case when correct_count + incorrect_count + skipped_count = 0
                    then 0
                    else round(100.0 * correct_count
                      / (correct_count + incorrect_count + skipped_count))::int
               end as a
        from public.practice_sessions
        where user_id = uid and completed_at is not null
        order by started_at desc
        limit 8
      ) recent
    ), '[]'::jsonb),
    -- Weak areas need enough evidence to be a finding rather than a bad
    -- morning, hence the sample floor.
    'weak_areas', coalesce((
      select jsonb_agg(jsonb_build_object(
        'sub_topic_id', m.sub_topic_id,
        'name', st.display_names ->> lang,
        'accuracy', m.accuracy,
        'sample_size', m.sample_size
      ) order by m.accuracy)
      from public.user_topic_mastery m
      join public.sub_topics st on st.id = m.sub_topic_id
      where m.user_id = uid and m.sample_size >= 3 and m.accuracy < 70
      limit 5
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.submit_practice_session(uuid, jsonb, int) from public;
grant execute on function public.submit_practice_session(uuid, jsonb, int) to authenticated;
revoke all on function public.get_progress() from public;
grant execute on function public.get_progress() to authenticated;
