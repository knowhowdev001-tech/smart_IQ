-- Practice engine (PRD 8, "Practice"; PRD 6.3).
--
-- All progress here is self-referential. PRD 6.6 forbids any comparison
-- against another user, so nothing in this migration aggregates across
-- users and no view exposes another user's rows.

create table public.practice_sessions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.users(id) on delete cascade,
  type             public.practice_mode not null,
  sub_topic_id     uuid references public.sub_topics(id) on delete set null,
  category_id      uuid references public.categories(id) on delete set null,
  question_count   int not null default 0,
  started_at       timestamptz not null default now(),
  completed_at     timestamptz,
  -- Points after negative marking, which applies to mock exams (PRD 6.3).
  score            numeric(6,2),
  correct_count    int not null default 0,
  incorrect_count  int not null default 0,
  skipped_count    int not null default 0,
  duration_seconds int,
  -- The Sri Lanka calendar day the set was issued on, so streaks and daily
  -- quota agree on where the boundary falls (PRD 7.6).
  issued_on        date not null default app.sl_today()
);

create index practice_sessions_user_idx
  on public.practice_sessions (user_id, started_at desc);
create index practice_sessions_user_day_idx
  on public.practice_sessions (user_id, issued_on);

-- One row per question in the set. Rows are written when the set is issued,
-- with the outcome left as 'skipped' -- that is both the issued manifest the
-- submit RPC scores against and the correct default for a question the user
-- never reached.
create table public.session_answers (
  session_id       uuid not null references public.practice_sessions(id) on delete cascade,
  question_id      uuid not null references public.questions(id) on delete cascade,
  sort_order       int not null default 0,
  selected_option  uuid references public.question_options(id) on delete set null,
  is_correct       boolean,
  outcome          public.answer_outcome not null default 'skipped',
  time_taken       int,
  marked_for_review boolean not null default false,
  answered_at      timestamptz,
  primary key (session_id, question_id)
);

create index session_answers_question_idx
  on public.session_answers (question_id);

-- Every incorrect answer is retained and resurfaced through spaced
-- repetition (PRD 6.3).
create table public.wrong_answer_bank (
  user_id       uuid not null references public.users(id) on delete cascade,
  question_id   uuid not null references public.questions(id) on delete cascade,
  next_review_at timestamptz not null default now(),
  review_count  int not null default 0,
  last_wrong_at timestamptz not null default now(),
  retired_at    timestamptz,
  primary key (user_id, question_id)
);

create index wrong_answer_bank_due_idx
  on public.wrong_answer_bank (user_id, next_review_at)
  where retired_at is null;

create table public.bookmarks (
  user_id     uuid not null references public.users(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, question_id)
);

create table public.user_topic_mastery (
  user_id      uuid not null references public.users(id) on delete cascade,
  sub_topic_id uuid not null references public.sub_topics(id) on delete cascade,
  accuracy     int not null default 0,
  sample_size  int not null default 0,
  correct_count int not null default 0,
  updated_at   timestamptz not null default now(),
  primary key (user_id, sub_topic_id),
  constraint user_topic_mastery_accuracy_range
    check (accuracy between 0 and 100)
);

create table public.user_streaks (
  user_id            uuid primary key references public.users(id) on delete cascade,
  current_streak     int not null default 0,
  longest_streak     int not null default 0,
  last_practice_date date,
  updated_at         timestamptz not null default now()
);

-- A fresh set each day, the same for everyone, available from Basic upward
-- (PRD 6.7). Composed ahead of time by the admin panel or a scheduled job.
create table public.daily_challenges (
  challenge_date date primary key,
  created_at     timestamptz not null default now()
);

create table public.daily_challenge_questions (
  challenge_date date not null references public.daily_challenges(challenge_date) on delete cascade,
  question_id    uuid not null references public.questions(id) on delete cascade,
  sort_order     int not null default 0,
  primary key (challenge_date, question_id)
);

create table public.daily_challenge_participation (
  user_id        uuid not null references public.users(id) on delete cascade,
  challenge_date date not null references public.daily_challenges(challenge_date) on delete cascade,
  session_id     uuid references public.practice_sessions(id) on delete set null,
  started_at     timestamptz not null default now(),
  primary key (user_id, challenge_date)
);
