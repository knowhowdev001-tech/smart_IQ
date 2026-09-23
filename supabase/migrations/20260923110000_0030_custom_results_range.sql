-- A custom window: the results figures over however many days the user asks
-- for, ending today.
--
-- The three named ranges were enough while they were constants, but a day
-- count is an argument, so the function takes one. Adding a parameter cannot
-- be done with create-or-replace -- it would leave the one-argument version
-- in place and give PostgREST two candidates -- so the old signature is
-- dropped first.

drop function public.get_results_summary(text);

create function public.get_results_summary(
  p_range text default 'all',
  p_days  int default null
)
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

  if p_range not in ('all', 'week', 'today', 'custom') then
    raise exception 'unknown range %', p_range using errcode = '22023';
  end if;

  -- A custom window is a day count the user typed, so it is the one input
  -- here that is not a constant and has to be bounded. 365 is already more
  -- history than any account has, and it caps the chart at 365 bars.
  if p_range = 'custom' and (p_days is null or p_days < 1 or p_days > 365) then
    raise exception 'custom range needs 1 to 365 days, got %', p_days
      using errcode = '22023';
  end if;

  select language_preference::text into lang
  from public.profiles where user_id = uid;
  lang := coalesce(lang, 'en');

  -- Inclusive lower bound on the SLT calendar day. For 'all' that is the
  -- first day the user ever completed a session, and null only when they
  -- never have.
  since := case p_range
             when 'today'  then app.sl_today()
             when 'week'   then app.sl_today() - 6
             -- Today is day one of the count, so N days reaches back N - 1.
             when 'custom' then app.sl_today() - (p_days - 1)
             else (select min(issued_on)
                   from public.practice_sessions
                   where user_id = uid and completed_at is not null)
           end;

  with ranged as (
    select s.id, s.issued_on, s.correct_count, s.incorrect_count,
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
  ),
  daily as (
    select issued_on as day,
           sum(correct_count) as correct,
           sum(correct_count + incorrect_count + skipped_count) as total
    from ranged
    group by issued_on
  ),
  -- Every calendar day in the window, so a day off is an empty bar rather
  -- than a missing one.
  days as (
    select d::date as day
    from generate_series(coalesce(since, app.sl_today()), app.sl_today(),
                         interval '1 day') d
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
    'history', case when t.answered + t.skipped = 0 then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object(
        'at', d.day,
        'accuracy', case when coalesce(x.total, 0) = 0 then 0
                         else round(100.0 * x.correct / x.total)::int end
      ) order by d.day)
      from days d
      left join daily x on x.day = d.day
    ), '[]'::jsonb) end
  )
  into out
  from totals t;

  return out;
end;
$$;

revoke all on function public.get_results_summary(text, int) from public;
grant execute on function public.get_results_summary(text, int) to authenticated;
