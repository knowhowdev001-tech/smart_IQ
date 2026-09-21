-- Question import, daily challenge composition, and two fields the results
-- screen needs back from a submitted session.
--
-- The question bank is loaded from a flat CSV rather than hand-written SQL:
-- one row per question, every language and option in that row. The content
-- team works in a spreadsheet, and nothing about that changes when the fake
-- questions are replaced by real ones.

-- ------------------------------------------------------------- staging --

-- Deliberately all-text and unconstrained: a CSV import fails as a whole if
-- one cell will not cast, so the parsing happens in `app.import_questions`
-- where a bad row can be reported and skipped instead.
--
-- Service-role only. RLS on with no policy, the same treatment `otp_requests`
-- gets in 0008: rows are loaded from the dashboard or psql, never the app.
create table public.question_import (
  id              bigint generated always as identity primary key,
  batch           text,
  sub_topic_key   text,
  difficulty      text,
  stem_en         text,
  stem_si         text,
  stem_ta         text,
  explanation_en  text,
  explanation_si  text,
  explanation_ta  text,
  option_a_en     text,
  option_a_si     text,
  option_a_ta     text,
  option_b_en     text,
  option_b_si     text,
  option_b_ta     text,
  option_c_en     text,
  option_c_si     text,
  option_c_ta     text,
  option_d_en     text,
  option_d_si     text,
  option_d_ta     text,
  correct_option  text,
  shuffle_options boolean not null default true,
  -- Bookkeeping, written by the importer. `question_id` is what makes a
  -- batch removable later; `error` is why a row did not import.
  question_id     uuid references public.questions(id) on delete set null,
  imported_at     timestamptz,
  error           text,
  created_at      timestamptz not null default now()
);

alter table public.question_import enable row level security;

create index question_import_pending_idx
  on public.question_import (batch) where imported_at is null;

comment on table public.question_import is
  'Flat staging area for the question CSV. One row per question, expanded by
   app.import_questions() into questions, options and their translations.';

-- ------------------------------------------------------------ importer --

-- Expands pending staging rows into the content tables and publishes them.
-- Returns {imported, failed, errors[]}.
--
-- Each row runs in its own block, so a row that cannot be published (missing
-- translation, unknown sub-topic, a correct_option that is not there) is
-- recorded against that row and the rest of the batch still lands.
create or replace function app.import_questions(p_batch text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, app, pg_temp
as $fn$
declare
  r          record;
  v_sub      uuid;
  v_question uuid;
  v_option   uuid;
  v_correct  uuid;
  v_options  int;
  v_key      text;
  v_en       text;
  v_si       text;
  v_ta       text;
  imported   int := 0;
  failed     int := 0;
  errors     jsonb := '[]'::jsonb;
begin
  for r in
    select * from public.question_import
    where imported_at is null
      and (p_batch is null or batch = p_batch)
    order by id
  loop
    begin
      select id into v_sub from public.sub_topics
      where key = btrim(coalesce(r.sub_topic_key, ''));
      if v_sub is null then
        raise exception 'unknown sub_topic_key %', r.sub_topic_key;
      end if;
      if length(btrim(coalesce(r.stem_en, ''))) = 0 then
        raise exception 'stem_en is required';
      end if;
      if length(btrim(coalesce(r.explanation_en, ''))) = 0 then
        raise exception 'explanation_en is required';
      end if;

      insert into public.questions
        (sub_topic_id, difficulty, shuffle_options, status)
      values (
        v_sub,
        coalesce(nullif(btrim(lower(r.difficulty)), ''), 'medium')::public.difficulty,
        r.shuffle_options,
        'draft'
      )
      returning id into v_question;

      -- Sinhala and Tamil fall back to the English cell rather than being
      -- left blank: a blank one fails the publish check, and a half-imported
      -- batch is worse than an obviously untranslated one.
      insert into public.question_translations
        (question_id, language, stem_text, explanation_text)
      values
        (v_question, 'en', btrim(r.stem_en), btrim(r.explanation_en)),
        (v_question, 'si',
         coalesce(nullif(btrim(coalesce(r.stem_si, '')), ''), btrim(r.stem_en)),
         coalesce(nullif(btrim(coalesce(r.explanation_si, '')), ''),
                  btrim(r.explanation_en))),
        (v_question, 'ta',
         coalesce(nullif(btrim(coalesce(r.stem_ta, '')), ''), btrim(r.stem_en)),
         coalesce(nullif(btrim(coalesce(r.explanation_ta, '')), ''),
                  btrim(r.explanation_en)));

      v_options := 0;
      v_correct := null;

      foreach v_key in array array['A', 'B', 'C', 'D'] loop
        v_en := case v_key
                  when 'A' then r.option_a_en when 'B' then r.option_b_en
                  when 'C' then r.option_c_en else r.option_d_en end;
        -- A blank option column simply means this question has fewer than
        -- four choices.
        continue when length(btrim(coalesce(v_en, ''))) = 0;

        v_si := case v_key
                  when 'A' then r.option_a_si when 'B' then r.option_b_si
                  when 'C' then r.option_c_si else r.option_d_si end;
        v_ta := case v_key
                  when 'A' then r.option_a_ta when 'B' then r.option_b_ta
                  when 'C' then r.option_c_ta else r.option_d_ta end;

        insert into public.question_options (question_id, option_key, sort_order)
        values (v_question, v_key, v_options)
        returning id into v_option;

        insert into public.question_option_translations
          (option_id, language, option_text)
        values
          (v_option, 'en', btrim(v_en)),
          (v_option, 'si',
           coalesce(nullif(btrim(coalesce(v_si, '')), ''), btrim(v_en))),
          (v_option, 'ta',
           coalesce(nullif(btrim(coalesce(v_ta, '')), ''), btrim(v_en)));

        if v_key = upper(btrim(coalesce(r.correct_option, ''))) then
          v_correct := v_option;
        end if;
        v_options := v_options + 1;
      end loop;

      if v_options < 2 then
        raise exception 'needs at least 2 options, found %', v_options;
      end if;
      if v_correct is null then
        raise exception 'correct_option % is not one of the filled options',
          r.correct_option;
      end if;

      update public.questions
      set correct_option_id = v_correct, status = 'live'
      where id = v_question;

      -- `questions_publishable` is a deferred constraint trigger, so without
      -- this it would not fire until COMMIT -- long after this block could
      -- catch it, and one unpublishable row would take the whole batch down.
      set constraints all immediate;
      set constraints all deferred;

      update public.question_import
      set question_id = v_question, imported_at = now(), error = null
      where id = r.id;
      imported := imported + 1;

    exception when others then
      failed := failed + 1;
      errors := errors || jsonb_build_object(
        'row', r.id, 'sub_topic_key', r.sub_topic_key, 'error', sqlerrm);
      -- Runs after the failed row's own work is rolled back, so it records
      -- the reason without keeping any of the half-written content.
      update public.question_import set error = sqlerrm where id = r.id;
    end;
  end loop;

  return jsonb_build_object(
    'imported', imported, 'failed', failed, 'errors', errors);
end;
$fn$;

comment on function app.import_questions(text) is
  'Expands public.question_import into live questions. Safe to re-run: rows
   already imported are skipped. Remove a batch with
   delete from public.questions where id in
     (select question_id from public.question_import where batch = ...);';

-- ----------------------------------------------------- daily challenge --

-- Composes today's shared set (PRD 6.7). Runs at 06:00 SL, an hour before
-- the notification job, which does nothing when no challenge exists.
--
-- Questions used in the last 30 days sort last rather than being excluded,
-- so a small bank still produces a full set instead of an empty day.
create or replace function app.job_build_daily_challenge(p_size int default 10)
returns int
language plpgsql
security definer
set search_path = public, app, pg_temp
as $fn$
declare
  today date := app.sl_today();
  n int;
begin
  if exists (
    select 1 from public.daily_challenge_questions where challenge_date = today
  ) then
    return 0;
  end if;

  insert into public.daily_challenges (challenge_date)
  values (today)
  on conflict (challenge_date) do nothing;

  insert into public.daily_challenge_questions
    (challenge_date, question_id, sort_order)
  select today, picked.id, picked.rn
  from (
    select q.id, (row_number() over ()) - 1 as rn
    from public.questions q
    where q.status = 'live'
    order by
      exists (
        select 1 from public.daily_challenge_questions d
        where d.question_id = q.id and d.challenge_date > today - 30
      ),
      random()
    limit greatest(1, p_size)
  ) picked
  on conflict do nothing;

  get diagnostics n = row_count;

  -- An empty bank leaves an empty day; drop the parent row again so the
  -- notification job stays silent rather than pointing at nothing.
  if n = 0 then
    delete from public.daily_challenges
    where challenge_date = today
      and not exists (
        select 1 from public.daily_challenge_questions
        where challenge_date = today
      );
  end if;

  return n;
end;
$fn$;

do $$
begin
  perform cron.unschedule('daily-challenge-build');
exception when others then
  null;
end $$;

-- 00:30 UTC = 06:00 SL, before push-daily-challenge at 01:30 UTC.
select cron.schedule(
  'daily-challenge-build', '30 0 * * *',
  'select app.job_build_daily_challenge()'
);

revoke all on function app.import_questions(text)
  from public, anon, authenticated;
revoke all on function app.job_build_daily_challenge(int)
  from public, anon, authenticated;

-- ------------------------------------------------ submit: two additions --

-- Unchanged from 0012 except for the last two keys of the returned object.
-- The results screen offers "drill your wrong answers" and draws a history
-- sparkline; both were being invented client-side because the RPC did not
-- return them, which meant neither survived the move off the mocks.
create or replace function public.submit_practice_session(
  p_session_id       uuid,
  p_answers          jsonb default '[]'::jsonb,
  p_duration_seconds int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, app, pg_temp
as $fn$
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
    ), '[]'::jsonb),
    -- What the "drill your wrong answers" button is built from.
    'wrong_question_ids', coalesce((
      select jsonb_agg(sa.question_id)
      from public.session_answers sa
      where sa.session_id = p_session_id and sa.outcome = 'incorrect'
    ), '[]'::jsonb),
    -- Accuracy of the user's recent sessions, oldest first, this one last.
    -- Same shape and window as get_progress.recent_accuracy.
    'own_history', coalesce((
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
    ), '[]'::jsonb)
  );
end;
$fn$;

revoke all on function public.submit_practice_session(uuid, jsonb, int)
  from public, anon;
grant execute on function public.submit_practice_session(uuid, jsonb, int)
  to authenticated;
