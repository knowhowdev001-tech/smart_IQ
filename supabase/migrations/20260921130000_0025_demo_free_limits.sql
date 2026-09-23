-- Demo limits for the free tier.
--
-- Billing is not connected yet (SupabaseEntitlementRepository.startSubscription
-- throws), so every real account resolves to 'free', and 0013 gives free two
-- questions a day, a set size of two and no daily challenge. That is the
-- correct commercial shape and a useless demo: the app would serve a
-- two-question quiz once a day and a dead challenge card.
--
-- These are basic's numbers, applied to free until billing lands. Revert by
-- re-running the 0013 insert, which upserts the same keys.

insert into public.tier_limits (tier, limit_key, limit_value) values
  ('free', 'questions_per_day',      50),
  ('free', 'max_practice_set_size',  20),
  ('free', 'daily_challenge',         1),
  ('free', 'mock_exams_per_month',    2),
  ('free', 'ai_messages_per_day',    10),
  ('free', 'wrong_answer_bank_limited', 1),
  ('free', 'chat_retention_days',     7)
on conflict (tier, limit_key) do update
  set limit_value = excluded.limit_value;
