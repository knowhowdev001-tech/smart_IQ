-- The home dashboard lists accuracy by sub-topic, not only weak areas.
--
-- `weak_areas` is a finding: it needs three answers in a sub-topic and an
-- accuracy under 70 before it will name one. That is right for a finding and
-- wrong for a dashboard — a user one session in, or a user doing well, sees
-- nothing at all. `sub_topic_accuracy` reports every sub-topic they have
-- touched, worst first, and leaves `weak_areas` exactly as it was.

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
    -- What the home dashboard reports: every sub-topic the user has answered
    -- anything in, worst first. No sample floor and no threshold — this is a
    -- report of where the user stands, not a finding about where they are weak.
    'sub_topic_accuracy', coalesce((
      select jsonb_agg(jsonb_build_object(
        'sub_topic_id', m.sub_topic_id,
        'name', st.display_names ->> lang,
        'accuracy', m.accuracy,
        'sample_size', m.sample_size
      ) order by m.accuracy)
      from public.user_topic_mastery m
      join public.sub_topics st on st.id = m.sub_topic_id
      where m.user_id = uid and m.sample_size > 0
      limit 10
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

revoke all on function public.get_progress() from public;
grant execute on function public.get_progress() to authenticated;
