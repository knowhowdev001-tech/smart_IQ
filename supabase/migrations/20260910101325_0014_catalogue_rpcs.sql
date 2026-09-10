-- Catalogue reads.
--
-- The tables themselves are readable under RLS (PRD 9.4), but the client
-- needs live question counts and the user's own mastery alongside them, and
-- neither can come from a plain select without exposing question rows.

alter table public.sub_topics
  add column requires_image boolean not null default false,
  add column language_specific boolean not null default false;

comment on column public.sub_topics.requires_image is
  'Spatial reasoning and data interpretation cannot be authored without a
   diagram (PRD 5.3). Flagged so authoring tools can refuse a text-only
   question here rather than shipping an unanswerable one.';

comment on column public.sub_topics.language_specific is
  'Verbal reasoning is authored per language rather than translated
   (PRD Appendix A.5), so its stems legitimately differ between languages.';

update public.sub_topics
set requires_image = true
where key in ('iq_spatial', 'iq_data');

update public.sub_topics
set language_specific = true
where key = 'iq_verbal';

create or replace function public.get_categories()
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
    select jsonb_agg(jsonb_build_object(
      'id', c.id,
      'key', c.key,
      'name', c.display_names,
      'sort_order', c.sort_order,
      'question_count', (
        select count(*) from public.questions q
        join public.sub_topics st on st.id = q.sub_topic_id
        where st.category_id = c.id and q.status = 'live'
      )
    ) order by c.sort_order)
    from public.categories c
  ), '[]'::jsonb);
end;
$$;

-- Mastery is null until the user has actually attempted the sub-topic. A
-- zero would read as "you scored nothing", which is a different and much
-- more discouraging claim than "you have not started".
create or replace function public.get_sub_topics(p_category_id uuid default null)
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
    select jsonb_agg(jsonb_build_object(
      'id', st.id,
      'category_key', c.key,
      'name', st.display_names,
      'sort_order', st.sort_order,
      'requires_image', st.requires_image,
      'verbal_language_specific', st.language_specific,
      'mastery', (
        select m.accuracy from public.user_topic_mastery m
        where m.user_id = uid and m.sub_topic_id = st.id and m.sample_size > 0
      ),
      'question_count', (
        select count(*) from public.questions q
        where q.sub_topic_id = st.id and q.status = 'live'
      )
    ) order by c.sort_order, st.sort_order)
    from public.sub_topics st
    join public.categories c on c.id = st.category_id
    where p_category_id is null or st.category_id = p_category_id
  ), '[]'::jsonb);
end;
$$;

create or replace function public.get_current_affairs(p_limit int default 20)
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
    select jsonb_agg(item order by publish_date desc)
    from (
      select ca.publish_date, jsonb_build_object(
        'id', ca.id,
        'publish_date', ca.publish_date,
        'type', ca.type::text,
        'title', (
          select jsonb_object_agg(t.language::text, t.title)
          from public.current_affairs_translations t where t.item_id = ca.id
        ),
        'body', (
          select jsonb_object_agg(t.language::text, coalesce(t.body, t.summary))
          from public.current_affairs_translations t
          where t.item_id = ca.id and coalesce(t.body, t.summary) is not null
        )
      ) as item
      from public.current_affairs ca
      where ca.status = 'live' and ca.publish_date <= app.sl_today()
      order by ca.publish_date desc
      limit greatest(1, least(coalesce(p_limit, 20), 100))
    ) rows
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.get_categories() from public;
grant execute on function public.get_categories() to authenticated;
revoke all on function public.get_sub_topics(uuid) from public;
grant execute on function public.get_sub_topics(uuid) to authenticated;
revoke all on function public.get_current_affairs(int) from public;
grant execute on function public.get_current_affairs(int) to authenticated;
