-- Question rendering.
--
-- Every question is returned in all three languages at once. PRD 6.5
-- requires an in-place language toggle on a question that does not lose the
-- user's answer state, and a refetch on toggle would either lose it or cost
-- a round trip mid-question. Sending three short strings instead of one is
-- much cheaper than either.

create or replace function app.render_question(p_question uuid)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'id', q.id,
    'sub_topic_id', q.sub_topic_id,
    'category_key', c.key,
    'difficulty', q.difficulty::text,
    'correct_option_id', q.correct_option_id,
    'shuffle_options', q.shuffle_options,
    'category_name', c.display_names,
    'sub_topic_name', st.display_names,
    'stem', (
      select jsonb_object_agg(t.language::text, t.stem_text)
      from public.question_translations t
      where t.question_id = q.id and t.stem_text is not null
    ),
    'stem_media', case
      when q.stem_media_path is null and not exists (
        select 1 from public.question_translations t
        where t.question_id = q.id and t.stem_media_path is not null
      ) then null
      else jsonb_strip_nulls(jsonb_build_object(
        'path', coalesce(q.stem_media_path, ''),
        'localized_path', (
          select jsonb_object_agg(t.language::text, t.stem_media_path)
          from public.question_translations t
          where t.question_id = q.id and t.stem_media_path is not null
        ),
        'alt', (
          select jsonb_object_agg(t.language::text, t.stem_media_alt)
          from public.question_translations t
          where t.question_id = q.id and t.stem_media_alt is not null
        )
      ))
    end,
    'explanation', (
      select jsonb_object_agg(t.language::text, t.explanation_text)
      from public.question_translations t
      where t.question_id = q.id and t.explanation_text is not null
    ),
    -- Language variants of the same step are merged by sort_order, so an
    -- ordered sequence of working stays one list however it was authored.
    'explanation_media', coalesce((
      select jsonb_agg(step order by step_order)
      from (
        select
          m.sort_order as step_order,
          jsonb_strip_nulls(jsonb_build_object(
            'path', min(m.media_path) filter (where m.language is null),
            'sort_order', m.sort_order,
            'localized_path', nullif(jsonb_object_agg(
              coalesce(m.language::text, 'shared'), m.media_path
            ) - 'shared', '{}'::jsonb),
            'alt', nullif(jsonb_object_agg(
              coalesce(m.language::text, 'shared'),
              coalesce(m.media_alt, '')
            ) - 'shared', '{}'::jsonb),
            'caption', nullif(jsonb_object_agg(
              coalesce(m.language::text, 'shared'),
              coalesce(m.caption, '')
            ) - 'shared', '{}'::jsonb)
          )) as step
        from public.question_explanation_media m
        where m.question_id = q.id
        group by m.sort_order
      ) steps
    ), '[]'::jsonb),
    'options', coalesce((
      select jsonb_agg(opt order by opt_order)
      from (
        select
          o.sort_order as opt_order,
          jsonb_strip_nulls(jsonb_build_object(
            'id', o.id,
            'option_key', o.option_key,
            'sort_order', o.sort_order,
            'text', (
              select jsonb_object_agg(ot.language::text, ot.option_text)
              from public.question_option_translations ot
              where ot.option_id = o.id and ot.option_text is not null
            ),
            'media', case
              when o.media_path is null and not exists (
                select 1 from public.question_option_translations ot
                where ot.option_id = o.id and ot.media_path is not null
              ) then null
              else jsonb_build_object(
                'path', coalesce(o.media_path, ''),
                'localized_path', (
                  select jsonb_object_agg(ot.language::text, ot.media_path)
                  from public.question_option_translations ot
                  where ot.option_id = o.id and ot.media_path is not null
                ),
                'alt', (
                  select jsonb_object_agg(ot.language::text, ot.media_alt)
                  from public.question_option_translations ot
                  where ot.option_id = o.id and ot.media_alt is not null
                )
              )
            end
          )) as opt
        from public.question_options o
        where o.question_id = q.id
      ) opts
    ), '[]'::jsonb)
  )
  from public.questions q
  join public.sub_topics st on st.id = q.sub_topic_id
  join public.categories c on c.id = st.category_id
  where q.id = p_question;
$$;

-- A question the user already has a relationship with -- bookmarked, in
-- their wrong-answer bank, or served to them in a past session. This is the
-- only read path into the bank that does not go through a quota-consuming
-- RPC, and it is bounded by rows the user already earned.
create or replace function public.get_questions_by_ids(p_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = public, app
as $$
declare
  uid uuid := app.current_user_id();
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(app.render_question(q.id))
    from public.questions q
    where q.id = any(p_ids)
      and (
        exists (select 1 from public.bookmarks b
                 where b.user_id = uid and b.question_id = q.id)
        or exists (select 1 from public.wrong_answer_bank w
                    where w.user_id = uid and w.question_id = q.id)
        or exists (select 1 from public.session_answers sa
                    join public.practice_sessions s on s.id = sa.session_id
                   where s.user_id = uid and sa.question_id = q.id)
      )
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.get_questions_by_ids(uuid[]) from public;
grant execute on function public.get_questions_by_ids(uuid[]) to authenticated;
