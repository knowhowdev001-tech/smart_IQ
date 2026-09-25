-- Free Fallback goes back to the PRD 7.5 limits.
--
-- 0025 gave free Basic's numbers while billing was unconnected, when every
-- account resolved to free and the real values made a two-question demo.
-- Billing is connected now: a telco subscriber is Basic (otp-verify at
-- signup, payment-status on every open), and anyone the carrier no longer
-- has subscribed falls to free. With free still on Basic's limits, falling
-- to it cost nothing, and PRD 7.7's conversion design had nothing to stand
-- on.
--
-- Basic, Pro and Pro+ already hold their 7.5 values and are not touched.

insert into public.tier_limits (tier, limit_key, limit_value) values
  ('free', 'questions_per_day',          2),
  ('free', 'max_practice_set_size',      2),
  ('free', 'ai_messages_per_day',        2),
  ('free', 'mock_exams_per_month',       0),
  ('free', 'daily_challenge',            0),
  ('free', 'wrong_answer_bank_limited',  0),
  ('free', 'chat_retention_days',        1)
on conflict (tier, limit_key) do update
  set limit_value = excluded.limit_value;
