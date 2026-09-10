-- Content bank (PRD 8, "Content"; PRD 5.4 for composition rules).
--
-- Two rules shape this schema. First, the correct answer lives on
-- `questions`, never on a translation, so it cannot diverge between
-- languages. Second, stem, option and explanation may each be text, image,
-- or both (PRD 5.4.1), so every text column is nullable and completeness is
-- checked at publish time rather than on every draft row.

create table public.categories (
  id            uuid primary key default gen_random_uuid(),
  key           text not null unique,
  display_names jsonb not null,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now(),
  constraint categories_names_complete check (
    display_names ? 'si' and display_names ? 'ta' and display_names ? 'en'
  )
);

create table public.sub_topics (
  id            uuid primary key default gen_random_uuid(),
  category_id   uuid not null references public.categories(id) on delete cascade,
  key           text not null unique,
  display_names jsonb not null,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now(),
  constraint sub_topics_names_complete check (
    display_names ? 'si' and display_names ? 'ta' and display_names ? 'en'
  )
);

create index sub_topics_category_idx
  on public.sub_topics (category_id, sort_order);

create table public.questions (
  id                uuid primary key default gen_random_uuid(),
  sub_topic_id      uuid not null references public.sub_topics(id) on delete restrict,
  difficulty        public.difficulty not null default 'medium',
  correct_option_id uuid,
  -- PRD 5.4.1: disable shuffling where options are positional, such as
  -- "A and B only" or "None of the above".
  shuffle_options   boolean not null default true,
  -- Language-neutral stem image. media_path is a Storage object path, never
  -- a URL, so the storage host can change without a data migration.
  stem_media_path   text,
  status            public.question_status not null default 'draft',
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index questions_live_idx
  on public.questions (sub_topic_id, difficulty)
  where status = 'live';

create trigger questions_touch_updated_at
  before update on public.questions
  for each row execute function app.touch_updated_at();

create table public.question_options (
  id          uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete cascade,
  option_key  text not null,
  sort_order  int not null default 0,
  media_path  text,
  unique (question_id, option_key)
);

create index question_options_question_idx
  on public.question_options (question_id, sort_order);

alter table public.questions
  add constraint questions_correct_option_fk
  foreign key (correct_option_id)
  references public.question_options(id) on delete restrict
  deferrable initially deferred;

create table public.question_translations (
  question_id     uuid not null references public.questions(id) on delete cascade,
  language        public.language_code not null,
  stem_text       text,
  -- Per-language override. Null means fall back to questions.stem_media_path.
  stem_media_path text,
  stem_media_alt  text,
  explanation_text text,
  updated_at      timestamptz not null default now(),
  primary key (question_id, language)
);

create trigger question_translations_touch_updated_at
  before update on public.question_translations
  for each row execute function app.touch_updated_at();

create table public.question_option_translations (
  option_id   uuid not null references public.question_options(id) on delete cascade,
  language    public.language_code not null,
  option_text text,
  media_path  text,
  media_alt   text,
  primary key (option_id, language)
);

-- Explanations support an ordered sequence of images for step-by-step
-- working (PRD 5.4.2), which is why this is a table and not a column. A
-- null language means the asset is shared across all three languages.
create table public.question_explanation_media (
  id          uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete cascade,
  language    public.language_code,
  sort_order  int not null default 0,
  media_path  text not null,
  media_alt   text,
  caption     text
);

create index question_explanation_media_question_idx
  on public.question_explanation_media (question_id, language, sort_order);

create table public.current_affairs (
  id           uuid primary key default gen_random_uuid(),
  publish_date date not null,
  type         public.current_affairs_type not null,
  status       public.question_status not null default 'draft',
  created_at   timestamptz not null default now()
);

create index current_affairs_published_idx
  on public.current_affairs (publish_date desc)
  where status = 'live';

create table public.current_affairs_translations (
  item_id  uuid not null references public.current_affairs(id) on delete cascade,
  language public.language_code not null,
  title    text not null,
  summary  text,
  body     text,
  primary key (item_id, language)
);

-- ------------------------------------------------ publish-time validation --

-- Completeness spans four tables, so it cannot be a check constraint. It is
-- enforced when a question goes live, which also lets the content team save
-- half-finished drafts (PRD 5.3 requires all three languages on anything
-- learners actually see).
create or replace function app.assert_question_publishable()
returns trigger
language plpgsql
as $$
declare
  lang public.language_code;
  shared_stem_media text;
  missing int;
begin
  if new.status is distinct from 'live' then
    return new;
  end if;

  if new.correct_option_id is null then
    raise exception 'question % has no correct option', new.id
      using errcode = 'check_violation';
  end if;

  if not exists (
    select 1 from public.question_options o
    where o.question_id = new.id and o.id = new.correct_option_id
  ) then
    raise exception 'correct option of question % belongs to another question',
      new.id using errcode = 'check_violation';
  end if;

  shared_stem_media := new.stem_media_path;

  foreach lang in array enum_range(null::public.language_code) loop
    -- Stem: text, image, or both, but not neither (PRD 5.4.1).
    if not exists (
      select 1 from public.question_translations t
      where t.question_id = new.id
        and t.language = lang
        and (
          length(btrim(coalesce(t.stem_text, ''))) > 0
          or t.stem_media_path is not null
          or shared_stem_media is not null
        )
    ) then
      raise exception 'question % has no % stem', new.id, lang
        using errcode = 'check_violation';
    end if;

    -- Explanation: text, an ordered image sequence, or both (PRD 5.3).
    if not exists (
      select 1 from public.question_translations t
      where t.question_id = new.id
        and t.language = lang
        and length(btrim(coalesce(t.explanation_text, ''))) > 0
    ) and not exists (
      select 1 from public.question_explanation_media m
      where m.question_id = new.id
        and (m.language = lang or m.language is null)
    ) then
      raise exception 'question % has no % explanation', new.id, lang
        using errcode = 'check_violation';
    end if;

    -- Every option needs content in every language. Composition is per
    -- option, so a text option may sit beside three diagrams.
    select count(*) into missing
    from public.question_options o
    where o.question_id = new.id
      and not exists (
        select 1 from public.question_option_translations ot
        where ot.option_id = o.id
          and ot.language = lang
          and (
            length(btrim(coalesce(ot.option_text, ''))) > 0
            or ot.media_path is not null
          )
      )
      and o.media_path is null;

    if missing > 0 then
      raise exception 'question % has % option(s) with no % content',
        new.id, missing, lang using errcode = 'check_violation';
    end if;
  end loop;

  if (select count(*) from public.question_options where question_id = new.id) < 2 then
    raise exception 'question % needs at least two options', new.id
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create constraint trigger questions_publishable
  after insert or update of status, correct_option_id on public.questions
  deferrable initially deferred
  for each row execute function app.assert_question_publishable();
