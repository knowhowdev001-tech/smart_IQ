-- The results screen becomes a small dashboard: the same figures over
-- "All time", "Last 7 days" or "Today".
--
-- None of this can come from user_topic_mastery, which is cumulative and has
-- no date dimension. It is recomputed from the answers themselves, keyed on
-- practice_sessions.issued_on — already the Sri Lanka calendar day, and
-- already indexed by (user_id, issued_on).

create or replace function public.get_results_summary(p_range text default 'all')
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  uid   uuid := app.current_user_id();
  lang  text;
  since date;
  out   jsonb;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if p_range not in ('all', 'week', 'today') then
    raise exception 'unknown range %', p_range using errcode = '22023';
  end if;

  select language_preference::text into lang
  from public.profiles where user_id = uid;
  lang := coalesce(lang, 'en');

  -- Inclusive lower bound on the SLT calendar day; null means all time.
  since := case p_range
             when 'today' then app.sl_today()
             when 'week'  then app.sl_today() - 6
           end;

  with ranged as (
    select s.id, s.started_at, s.correct_count, s.incorrect_count,
           s.skipped_count
    from public.practice_sessions s
    where s.user_id = uid
      and s.completed_at is not null
      and (since is null or s.issued_on >= since)
  ),
  answers as (
    select sa.outcome, sa.time_taken, q.sub_topic_id
    from public.session_answers sa
    join ranged r on r.id = sa.session_id
    join public.questions q on q.id = sa.question_id
  ),
  totals as (
    select
      count(*) filter (where outcome <> 'skipped')            as answered,
      count(*) filter (where outcome = 'correct')             as correct,
      count(*) filter (where outcome = 'skipped')             as skipped,
      -- time_taken is seconds; the client works in milliseconds.
      coalesce(sum(time_taken), 0) * 1000                     as total_time_ms
    from answers
  )
  select jsonb_build_object(
    'answered', t.answered,
    'correct', t.correct,
    'skipped', t.skipped,
    'total_time_ms', t.total_time_ms,
    -- Worst first, the order the list is read in.
    'breakdown', coalesce((
      select jsonb_agg(jsonb_build_object(
        'sub_topic_id', b.sub_topic_id,
        'name', b.names,
        'correct', b.correct,
        'total', b.total
      ) order by case when b.total = 0 then 0
                      else b.correct::numeric / b.total end)
      from (
        select a.sub_topic_id,
               st.display_names as names,
               count(*) filter (where a.outcome = 'correct') as correct,
               count(*) as total
        from answers a
        join public.sub_topics st on st.id = a.sub_topic_id
        group by a.sub_topic_id, st.display_names
      ) b
    ), '[]'::jsonb),
    -- The chart holds eight bars, oldest first.
    'history', coalesce((
      select jsonb_agg(jsonb_build_object('at', h.started_at, 'accuracy', h.a)
                       order by h.started_at)
      from (
        select started_at,
               case when correct_count + incorrect_count + skipped_count = 0
                    then 0
                    else round(100.0 * correct_count
                      / (correct_count + incorrect_count + skipped_count))::int
               end as a
        from ranged
        order by started_at desc
        limit 8
      ) h
    ), '[]'::jsonb)
  )
  into out
  from totals t;

  return out;
end;
$$;

revoke all on function public.get_results_summary(text) from public;
grant execute on function public.get_results_summary(text) to authenticated;
