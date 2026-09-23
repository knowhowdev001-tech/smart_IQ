-- The line under a category tile on the home grid.
--
-- get_categories returned no `meta`, so the client fell back to an empty
-- string and the tiles lost their subtitle the moment the catalogue came
-- from the server. It is editable copy rather than a computed count: what
-- is worth saying about "Current affairs" is its rhythm, and about mock
-- exams that they are timed and negatively marked.

alter table public.categories
  add column if not exists meta_names jsonb not null default '{}'::jsonb;

comment on column public.categories.meta_names is
  'The subtitle under a category tile, per language. Editable copy, not a
   computed count.';

update public.categories set meta_names = jsonb_build_object(
    'en', '8 topics',
    'si', 'මාතෘකා 8',
    'ta', '8 தலைப்புகள்')
where key = 'gk';

update public.categories set meta_names = jsonb_build_object(
    'en', 'Daily · weekly · monthly',
    'si', 'දෛනික · සතිපතා · මාසික',
    'ta', 'தினசரி · வாராந்திர · மாதாந்திர')
where key = 'ca';

update public.categories set meta_names = jsonb_build_object(
    'en', '13 sub-topics',
    'si', 'උප මාතෘකා 13',
    'ta', '13 துணைத் தலைப்புகள்')
where key = 'iq';

update public.categories set meta_names = jsonb_build_object(
    'en', 'Timed · negative marking',
    'si', 'කාල සීමිත · ඍණ ලකුණු',
    'ta', 'நேர வரம்பு · எதிர்மறை மதிப்பெண்')
where key = 'mock';

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
      'meta', c.meta_names,
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

revoke all on function public.get_categories() from public;
grant execute on function public.get_categories() to authenticated;
