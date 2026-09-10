-- Covering indexes for foreign keys.
--
-- Without these, every delete of a parent row scans the child table to
-- check the constraint. That matters most on delete_account (PRD 9.3),
-- which cascades a user across a dozen tables in one transaction, and on
-- retiring a question, which touches every bank and session that referenced
-- it.

create index bookmarks_question_idx
  on public.bookmarks (question_id);
create index chat_threads_question_idx
  on public.chat_threads (question_id) where question_id is not null;
create index daily_challenge_participation_date_idx
  on public.daily_challenge_participation (challenge_date);
create index daily_challenge_participation_session_idx
  on public.daily_challenge_participation (session_id);
create index daily_challenge_questions_question_idx
  on public.daily_challenge_questions (question_id);
create index practice_sessions_category_idx
  on public.practice_sessions (category_id) where category_id is not null;
create index practice_sessions_sub_topic_idx
  on public.practice_sessions (sub_topic_id) where sub_topic_id is not null;
create index questions_correct_option_idx
  on public.questions (correct_option_id);
create index revenuecat_events_user_idx
  on public.revenuecat_events (user_id, received_at desc);
create index session_answers_selected_option_idx
  on public.session_answers (selected_option) where selected_option is not null;
create index user_topic_mastery_sub_topic_idx
  on public.user_topic_mastery (sub_topic_id);
create index wrong_answer_bank_question_idx
  on public.wrong_answer_bank (question_id);
