-- The server taxonomy the app actually shows.
--
-- Migration 0013 seeded three categories and thirteen family-level
-- sub-topics as a first cut. The app ships a finer one: four categories
-- including mock exams, and the thirteen named IQ types from PRD Appendix A
-- rather than the five families. Its keys are also the ones the client
-- already switches on -- the home icon map, the mock-exam special case on
-- the practice screen and the router's fallback category all read
-- 'gk' / 'ca' / 'iq' / 'mock' -- so seeding those keys here is what lets
-- practice move to the server without an app release.
--
-- The 0013 rows are removed, but only where nothing was ever authored
-- against them, so this is a no-op on an environment holding real content.

insert into public.categories (key, display_names, sort_order) values
  ('gk', jsonb_build_object(
     'en', 'General Knowledge',
     'si', 'සාමාන්‍ය දැනීම',
     'ta', 'பொது அறிவு'), 1),
  ('ca', jsonb_build_object(
     'en', 'Current Affairs',
     'si', 'තත්කාලීන කරුණු',
     'ta', 'நடப்பு நிகழ்வுகள்'), 2),
  ('iq', jsonb_build_object(
     'en', 'IQ / Aptitude',
     'si', 'බුද්ධි පරීක්ෂණ',
     'ta', 'திறனறி'), 3),
  ('mock', jsonb_build_object(
     'en', 'Mock exams',
     'si', 'ආදර්ශ විභාග',
     'ta', 'மாதிரித் தேர்வுகள்'), 4)
on conflict (key) do update
  set display_names = excluded.display_names,
      sort_order = excluded.sort_order;

-- Spatial and Venn sub-topics cannot be answered without their diagram
-- (PRD A.6), which is what requires_image marks.
insert into public.sub_topics
  (category_id, key, display_names, sort_order, requires_image)
select c.id, v.key, v.names, v.sort_order, v.requires_image
from public.categories c
join (values
  ('gk', 'gk-history', jsonb_build_object(
     'en', 'Sri Lankan history',
     'si', 'ශ්‍රී ලංකා ඉතිහාසය',
     'ta', 'இலங்கை வரலாறு'), 1, false),
  ('gk', 'gk-politics', jsonb_build_object(
     'en', 'Politics and constitution',
     'si', 'දේශපාලනය හා ව්‍යවස්ථාව',
     'ta', 'அரசியலும் அரசியலமைப்பும்'), 2, false),
  ('gk', 'gk-geography', jsonb_build_object(
     'en', 'Geography',
     'si', 'භූගෝල විද්‍යාව',
     'ta', 'புவியியல்'), 3, false),
  ('gk', 'gk-economy', jsonb_build_object(
     'en', 'Economy',
     'si', 'ආර්ථිකය',
     'ta', 'பொருளாதாரம்'), 4, false),
  ('gk', 'gk-science', jsonb_build_object(
     'en', 'Science and technology',
     'si', 'විද්‍යාව හා තාක්ෂණය',
     'ta', 'அறிவியலும் தொழில்நுட்பமும்'), 5, false),
  ('gk', 'gk-sports', jsonb_build_object(
     'en', 'Sports',
     'si', 'ක්‍රීඩා',
     'ta', 'விளையாட்டு'), 6, false),
  ('gk', 'gk-literature', jsonb_build_object(
     'en', 'Literature',
     'si', 'සාහිත්‍යය',
     'ta', 'இலக்கியம்'), 7, false),
  ('gk', 'gk-world', jsonb_build_object(
     'en', 'World affairs',
     'si', 'ලෝක කටයුතු',
     'ta', 'உலக விவகாரங்கள்'), 8, false),
  ('ca', 'ca-daily', jsonb_build_object(
     'en', 'Daily digest',
     'si', 'දෛනික සාරාංශය',
     'ta', 'தினசரிச் சுருக்கம்'), 1, false),
  ('ca', 'ca-weekly', jsonb_build_object(
     'en', 'Weekly digest',
     'si', 'සතිපතා සාරාංශය',
     'ta', 'வாராந்திரச் சுருக்கம்'), 2, false),
  ('ca', 'ca-monthly', jsonb_build_object(
     'en', 'Monthly compilation',
     'si', 'මාසික සම්පාදනය',
     'ta', 'மாதாந்திரத் தொகுப்பு'), 3, false),
  ('iq', 'iq-age', jsonb_build_object(
     'en', 'Age-related problems',
     'si', 'වයස් සම්බන්ධ ගැටලු',
     'ta', 'வயது சார்ந்த கணக்குகள்'), 1, false),
  ('iq', 'iq-ratio', jsonb_build_object(
     'en', 'Ratio and proportion',
     'si', 'අනුපාත සම්බන්ධ ගැටලු',
     'ta', 'விகிதம் சார்ந்த கணக்குகள்'), 2, false),
  ('iq', 'iq-speed', jsonb_build_object(
     'en', 'Distance, speed and time',
     'si', 'දුර වේගය කාලය',
     'ta', 'தூரம், வேகம், நேரம்'), 3, false),
  ('iq', 'iq-direction', jsonb_build_object(
     'en', 'Direction sense',
     'si', 'දිශා ආශ්‍රිත ගැටලු',
     'ta', 'திசை சார்ந்த கணக்குகள்'), 4, false),
  ('iq', 'iq-coding', jsonb_build_object(
     'en', 'Coding and decoding',
     'si', 'රහස් භාෂා',
     'ta', 'இரகசிய மொழி'), 5, false),
  ('iq', 'iq-blood', jsonb_build_object(
     'en', 'Blood relations',
     'si', 'නෑදෑකම් ආශ්‍රිත ගැටලු',
     'ta', 'உறவுமுறை சார்ந்த கணக்குகள்'), 6, false),
  ('iq', 'iq-calendar', jsonb_build_object(
     'en', 'Calendars',
     'si', 'දින දර්ශන',
     'ta', 'நாட்காட்டி'), 7, false),
  ('iq', 'iq-clocks', jsonb_build_object(
     'en', 'Clocks and angles',
     'si', 'ඕරලෝසු හා කෝණික ගැටලු',
     'ta', 'கடிகாரமும் கோணங்களும்'), 8, false),
  ('iq', 'iq-triangles', jsonb_build_object(
     'en', 'Counting triangles',
     'si', 'ත්‍රිකෝණ ගණන සෙවීම',
     'ta', 'முக்கோணங்களை எண்ணுதல்'), 9, true),
  ('iq', 'iq-squares', jsonb_build_object(
     'en', 'Counting squares',
     'si', 'සමචතුරස්‍ර ගණන සෙවීම',
     'ta', 'சதுரங்களை எண்ணுதல்'), 10, true),
  ('iq', 'iq-dice', jsonb_build_object(
     'en', 'Dice problems',
     'si', 'දාදු කැට ගැටලු',
     'ta', 'பகடை கணக்குகள்'), 11, true),
  ('iq', 'iq-probability', jsonb_build_object(
     'en', 'Probability',
     'si', 'සම්භාවිතාව',
     'ta', 'நிகழ்தகவு'), 12, false),
  ('iq', 'iq-sets', jsonb_build_object(
     'en', 'Sets and Venn diagrams',
     'si', 'කුලක හා වෙන් රූප',
     'ta', 'கணங்களும் வென் படங்களும்'), 13, true),
  ('mock', 'mock-full', jsonb_build_object(
     'en', 'Full paper · 100 questions',
     'si', 'සම්පූර්ණ ප්‍රශ්න පත්‍රය',
     'ta', 'முழுத் தாள் · 100 வினாக்கள்'), 1, false),
  ('mock', 'mock-half', jsonb_build_object(
     'en', 'Half paper · 50 questions',
     'si', 'අර්ධ ප්‍රශ්න පත්‍රය',
     'ta', 'அரைத் தாள் · 50 வினாக்கள்'), 2, false)
) as v(category_key, key, names, sort_order, requires_image)
  on v.category_key = c.key
on conflict (key) do update
  set category_id = excluded.category_id,
      display_names = excluded.display_names,
      sort_order = excluded.sort_order,
      requires_image = excluded.requires_image;

-- The 0013 taxonomy, gone only if it was never authored against.
delete from public.sub_topics st
where st.key in (
  'gk_sri_lankan_history', 'gk_politics_constitution', 'gk_geography',
  'gk_economy', 'gk_science_technology', 'gk_sports', 'gk_literature',
  'gk_world_affairs', 'iq_numerical', 'iq_logical', 'iq_spatial',
  'iq_data', 'iq_verbal')
  and not exists (
    select 1 from public.questions q where q.sub_topic_id = st.id
  );

delete from public.categories c
where c.key in ('general_knowledge', 'current_affairs', 'aptitude')
  and not exists (
    select 1 from public.sub_topics st where st.category_id = c.id
  );

-- The client needs the sub-topic key, not only its uuid: which mock paper
-- was tapped decides the exam length, and that is a key rather than a name.
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
      'key', st.key,
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

revoke all on function public.get_sub_topics(uuid) from public;
grant execute on function public.get_sub_topics(uuid) to authenticated;
