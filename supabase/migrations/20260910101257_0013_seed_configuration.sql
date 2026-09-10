-- Configuration seed.
--
-- Only tier_limits is authoritative here: the values are PRD 7.5 exactly.
-- They are also explicitly starting values, tunable per tier from the admin
-- panel without an app release, so nothing downstream may treat them as
-- constants.
--
-- -1 means unlimited. Boolean limits are stored as 0 or 1.

insert into public.tier_limits (tier, limit_key, limit_value) values
  ('free',     'questions_per_day',          2),
  ('free',     'ai_messages_per_day',        2),
  ('free',     'mock_exams_per_month',       0),
  ('free',     'max_practice_set_size',      2),
  ('free',     'daily_challenge',            0),
  ('free',     'adaptive_difficulty',        0),
  ('free',     'study_plan',                 0),
  ('free',     'speed_drills',               0),
  ('free',     'chat_retention_days',        1),
  ('free',     'wrong_answer_bank_full',     0),
  ('free',     'wrong_answer_bank_limited',  0),

  ('basic',    'questions_per_day',         50),
  ('basic',    'ai_messages_per_day',       10),
  ('basic',    'mock_exams_per_month',       2),
  ('basic',    'max_practice_set_size',     20),
  ('basic',    'daily_challenge',            1),
  ('basic',    'adaptive_difficulty',        0),
  ('basic',    'study_plan',                 0),
  ('basic',    'speed_drills',               0),
  ('basic',    'chat_retention_days',        7),
  ('basic',    'wrong_answer_bank_full',     0),
  ('basic',    'wrong_answer_bank_limited',  1),

  ('pro',      'questions_per_day',        250),
  ('pro',      'ai_messages_per_day',       60),
  ('pro',      'mock_exams_per_month',      15),
  ('pro',      'max_practice_set_size',     50),
  ('pro',      'daily_challenge',            1),
  ('pro',      'adaptive_difficulty',        1),
  ('pro',      'study_plan',                 1),
  ('pro',      'speed_drills',               1),
  ('pro',      'chat_retention_days',       90),
  ('pro',      'wrong_answer_bank_full',     1),
  ('pro',      'wrong_answer_bank_limited',  0),

  ('pro_plus', 'questions_per_day',         -1),
  ('pro_plus', 'ai_messages_per_day',      200),
  ('pro_plus', 'mock_exams_per_month',      -1),
  ('pro_plus', 'max_practice_set_size',    100),
  ('pro_plus', 'daily_challenge',            1),
  ('pro_plus', 'adaptive_difficulty',        1),
  ('pro_plus', 'study_plan',                 1),
  ('pro_plus', 'speed_drills',               1),
  ('pro_plus', 'chat_retention_days',       -1),
  ('pro_plus', 'wrong_answer_bank_full',     1),
  ('pro_plus', 'wrong_answer_bank_limited',  0)
on conflict (tier, limit_key) do update
  set limit_value = excluded.limit_value;

-- Prefix routing (PRD 7.2). Prefixes and carriers are seeded so the mapping
-- exists; every row is inactive with no endpoint because PRD 7.2 defers
-- integration specifics to provider documentation. Nothing routes until an
-- operator fills in a real endpoint and flips active, which is the
-- deliberate safe default -- an unknown prefix simply has no telco rail.
insert into public.msisdn_prefix_routing (prefix, provider, endpoint, active) values
  ('070', 'dialog',  '', false),
  ('071', 'mobitel', '', false),
  ('072', 'hutch',   '', false),
  ('074', 'dialog',  '', false),
  ('075', 'airtel',  '', false),
  ('076', 'dialog',  '', false),
  ('077', 'dialog',  '', false),
  ('078', 'hutch',   '', false)
on conflict (prefix) do nothing;

-- Category taxonomy (PRD 5.2). Three categories and the family-level
-- sub-topics under them.
--
-- The full Appendix A taxonomy -- 30 confirmed IQ types plus 32 proposed --
-- is deliberately NOT seeded here. Its Sinhala labels are supplied by the
-- content team and its Tamil labels are drafted and explicitly marked as
-- needing review before going live. Those belong in a content import from
-- the source document, not in a schema migration.
insert into public.categories (key, display_names, sort_order) values
  ('general_knowledge', jsonb_build_object(
      'en', 'General Knowledge',
      'si', 'සාමාන්‍ය දැනුම',
      'ta', 'பொது அறிவு'), 1),
  ('current_affairs', jsonb_build_object(
      'en', 'Current Affairs',
      'si', 'වත්මන් තොරතුරු',
      'ta', 'நடப்பு நிகழ்வுகள்'), 2),
  ('aptitude', jsonb_build_object(
      'en', 'IQ / Aptitude',
      'si', 'බුද්ධි පරීක්ෂණ',
      'ta', 'அறிவுத்திறன்'), 3)
on conflict (key) do nothing;

insert into public.sub_topics (category_id, key, display_names, sort_order)
select c.id, v.key, v.names, v.sort_order
from public.categories c
join (values
  ('general_knowledge', 'gk_sri_lankan_history', jsonb_build_object(
     'en', 'Sri Lankan history', 'si', 'ශ්‍රී ලංකා ඉතිහාසය',
     'ta', 'இலங்கை வரலாறு'), 1),
  ('general_knowledge', 'gk_politics_constitution', jsonb_build_object(
     'en', 'Politics and constitution', 'si', 'දේශපාලනය හා ව්‍යවස්ථාව',
     'ta', 'அரசியலும் அரசியலமைப்பும்'), 2),
  ('general_knowledge', 'gk_geography', jsonb_build_object(
     'en', 'Geography', 'si', 'භූගෝල විද්‍යාව',
     'ta', 'புவியியல்'), 3),
  ('general_knowledge', 'gk_economy', jsonb_build_object(
     'en', 'Economy', 'si', 'ආර්ථිකය',
     'ta', 'பொருளாதாரம்'), 4),
  ('general_knowledge', 'gk_science_technology', jsonb_build_object(
     'en', 'Science and technology', 'si', 'විද්‍යාව හා තාක්ෂණය',
     'ta', 'அறிவியலும் தொழில்நுட்பமும்'), 5),
  ('general_knowledge', 'gk_sports', jsonb_build_object(
     'en', 'Sports', 'si', 'ක්‍රීඩා', 'ta', 'விளையாட்டு'), 6),
  ('general_knowledge', 'gk_literature', jsonb_build_object(
     'en', 'Literature', 'si', 'සාහිත්‍යය', 'ta', 'இலக்கியம்'), 7),
  ('general_knowledge', 'gk_world_affairs', jsonb_build_object(
     'en', 'World affairs', 'si', 'ලෝක කටයුතු',
     'ta', 'உலக நிகழ்வுகள்'), 8),

  ('aptitude', 'iq_numerical', jsonb_build_object(
     'en', 'Numerical and arithmetic reasoning',
     'si', 'සංඛ්‍යාත්මක හා ගණිතමය තර්කනය',
     'ta', 'எண்ணியல் மற்றும் கணித பகுத்தறிவு'), 1),
  ('aptitude', 'iq_logical', jsonb_build_object(
     'en', 'Logical and analytical reasoning',
     'si', 'තාර්කික හා විශ්ලේෂණාත්මක තර්කනය',
     'ta', 'தர்க்க மற்றும் பகுப்பாய்வுத் திறன்'), 2),
  ('aptitude', 'iq_spatial', jsonb_build_object(
     'en', 'Spatial and visual reasoning',
     'si', 'අවකාශීය හා දෘශ්‍ය තර්කනය',
     'ta', 'இட மற்றும் காட்சி பகுத்தறிவு'), 3),
  ('aptitude', 'iq_data', jsonb_build_object(
     'en', 'Data interpretation and probability',
     'si', 'දත්ත විග්‍රහය හා සම්භාවිතාව',
     'ta', 'தரவு விளக்கமும் நிகழ்தகவும்'), 4),
  ('aptitude', 'iq_verbal', jsonb_build_object(
     'en', 'Verbal reasoning and comprehension',
     'si', 'වාචික තර්කනය හා අවබෝධය',
     'ta', 'மொழித்திறன் மற்றும் புரிதல்'), 5)
) as v(category_key, key, names, sort_order)
  on v.category_key = c.key
on conflict (key) do nothing;
