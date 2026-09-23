# Smart IQ backend

Postgres schema, row level security and RPCs for the Supabase project
`Smart_IQ` (`glmryghkrpnmlqymsxuz`, ap-southeast-2). Every migration in
`migrations/` is applied to that project.

## Why the shape is what it is

Two decisions in the PRD drive almost everything here.

**Supabase Auth is not used** (PRD 4.4). Identity is our own: `users`,
`profiles`, `otp_requests`, `auth_sessions`. The OTP Edge Function signs a
JWT with the project JWT secret and sets `sub` to `users.id`, which is what
keeps `auth.uid()` and therefore ordinary RLS working. `app.current_user_id()`
is the single accessor that depends on that, so if the token shape ever
changes there is one place to fix.

**Questions are never plain-selectable** (PRD 9.3). RLS is enabled on
`questions` and its translation and option tables with no policy at all, so
they are invisible to the client. Sets come only from RPCs where the tier
gate, the quota check and the increment happen in one transaction. A
modified client cannot page through the bank without touching a counter.

## Access classes

| Class | Mechanism | What uses it |
| --- | --- | --- |
| A | PostgREST + RLS | Reference data and the user's own rows |
| B | `SECURITY DEFINER` RPC | Anything that consumes quota or writes a row the client is not trusted with |
| C | Edge Function | Third-party calls and token minting |

## RPCs

| Function | Purpose |
| --- | --- |
| `create_profile` | First sign-in profile, one per user |
| `get_entitlement` | Tier, limits and today's usage in one call |
| `get_categories`, `get_sub_topics` | Catalogue with live counts and the user's mastery |
| `get_practice_set` | Tier gate, quota, selection and session manifest |
| `get_mock_exam` | The same against the monthly allowance |
| `get_daily_challenge` | Today's shared set, resumable, one attempt per day |
| `submit_practice_session` | Server-side scoring, mastery, wrong-answer bank, streak |
| `get_progress` | The dashboard, entirely self-referential |
| `get_questions_by_ids` | Bookmarked, wrong-banked or previously served questions only |
| `get_current_affairs` | Published digests |
| `delete_account` | Cascading deletion in one transaction |
| `register_device_token` | Attaches this install's FCM token to the caller, detaching it from any other account |
| `enqueue_notification` | Service role only. Queues one push for one user, respecting their preferences |
| `claim_push_batch` | Service role only. Hands `push-dispatch` its next batch |

Errors carry a `hint` the client can branch on: `quota_exceeded`,
`upgrade_required`, `empty_set`, `already_submitted`.

## Limits

`tier_limits` is a narrow key/value table so the admin panel stays generic;
`tier_limits_effective` pivots it into the flat row the client reads. `-1`
means unlimited, booleans are stored as `0`/`1`. Seeded values are PRD 7.5
exactly, and are starting values, not constants. Counters reset on the Sri
Lanka day boundary via `app.sl_today()`, never the server's own date.

## What is not built yet

- **The remaining Edge Functions.** `otp-request`, `otp-verify`,
  `auth-refresh` and `push-dispatch` are built and deployed (see below);
  `/ai/chat`, `/payment-status` and `/webhooks/revenuecat` are not.
- **The question bank.** Schema and validation are ready; no questions are
  loaded. `assert_question_publishable` refuses to publish anything missing
  a correct option, a stem, an explanation or option content in any of the
  three languages.
- **The Appendix A taxonomy.** Three categories and thirteen family-level
  sub-topics are seeded. The 30 confirmed plus 32 proposed IQ types are not,
  because their Sinhala labels come from the content team and their Tamil
  labels are drafted and marked as needing review. That is a content import,
  not a schema migration.
- **Telco endpoints.** `msisdn_prefix_routing` is seeded with prefixes and
  carriers but every row is inactive with an empty endpoint, because PRD 7.2
  defers the specifics to provider documentation. Nothing routes until an
  operator fills one in.
- **Storage buckets.** `media_path` columns hold Storage object paths, not
  URLs, so the bucket can be created and the host changed without a data
  migration.

## Edge Functions

`functions/otp-request` and `functions/otp-verify` are the sign-in path, and
the only reason signup reaches the database at all. Both are public
(`verify_jwt = false` in `config.toml`) because a user asking for a code has
no session yet, in the same way GoTrue's own token endpoint is public. They
are rate limited on the MSISDN cooldown and on `attempt_count` instead.

`otp-verify` is where a signup becomes a row: it upserts `users` on the
unique MSISDN, writes the device into `auth_sessions`, and mints the HS256
JWT with `sub` set to `users.id`. The profile is not created there — PRD 6.1
step 5 has a verified user without one, and `create_profile` is what makes it.

`functions/auth-refresh` keeps a signed-in device signed in. The access
token lasts an hour, so without it a returning user was sent back to the
landing screen; the app now renews the token five minutes before it expires,
on whatever request comes first. The refresh token is single-use and rotates
on every call, the session is looked up by its hash rather than by the token,
and a device idle for 90 days has to sign in again. A refusal
(`session_expired`, `account_suspended`) clears the local session, while a
network failure keeps it: being offline is not being signed out.

`functions/push-dispatch` sends push notifications (PRD 6.8); see
[Push notifications](#push-notifications) below.

### Secrets

Set these under Project Settings → Edge Functions → Secrets, or with
`supabase secrets set`. Nothing works without the first two:

| Secret | What it is |
| --- | --- |
| `APP_JWT_SECRET` | The project's JWT secret (Settings → API → JWT Settings). What the minted token is signed with, and therefore what makes PostgREST accept it. Set it under **this** name: the CLI refuses to set anything prefixed `SUPABASE_` (`Env name cannot start with SUPABASE_, skipping`), so `SUPABASE_JWT_SECRET` is read first but can only be set on a platform that allows the prefix. |
| `OTP_PEPPER` | A long random string, never rotated casually — rotating it invalidates every live OTP and every refresh token. |
| `CHARGING_BASE_URL` | The Mobile Charging API's root. Signup and login send the OTP through it, so an unset value stops both: the functions fail closed rather than issuing a code nobody can receive. |
| `CHARGING_API_KEY` | Its `X-API-Key`. Server-side only — this key can subscribe numbers and send SMS, and an APK is decompilable. |
| `CHARGING_SECRET` | Its body `secret`. Both this and the key are required on every call; either missing is a 401. |
| `TEST_MSISDN` | One number, E.164 (`+94787332965`). **Development only.** |
| `TEST_OTP` | The code that number accepts. **Development only.** |

`TEST_MSISDN` and `TEST_OTP` let one number verify without an SMS, so
development does not cost a message and a relayed code per login. The bypass
exists only while **both** are set, which makes unsetting either one the kill
switch — no deploy needed. Its use is logged as `TEST BYPASS` on both
functions.

Between them they are a working login for that one number, so unset them
before the app is public. They replaced `ALLOW_DEV_OTP` and `OTP_FIXED_CODE`,
which were worse in the way that matters: those issued a constant that this
repository contains and that verified for *every* number, which is a password
for every account in the database.

Every other number goes to the carrier, whether or not the test pair is set.

`OTP_PEPPER` now has a development fallback in `_shared/tokens.ts`, so the
flow runs on a project with no secrets configured. That fallback is committed
to this repository and therefore protects nothing: an `otp_requests` row
hashed with it can be reversed by trying a million six-digit codes. Set a
real `OTP_PEPPER` before the table holds anyone's actual number.

## Loading questions

Questions span five tables (question, options and their translations in three
languages), so they are loaded through a flat staging table rather than by
hand. One spreadsheet row is one question.

1. Fill in a CSV with the columns of `public.question_import`:
   `batch, sub_topic_key, difficulty, stem_en|si|ta, explanation_en|si|ta,
   option_a|b|c|d_en|si|ta, correct_option, shuffle_options`.
   `sub_topic_key` is a key from `sub_topics` (`gk-geography`, `iq-age`,
   ...), `correct_option` is `A`-`D`, and blank option columns simply mean
   fewer than four choices. Sinhala and Tamil fall back to the English cell
   when left empty, because a blank one cannot be published.
2. Dashboard -> Table editor -> `question_import` -> Import data from CSV.
3. `select app.import_questions('<batch>');`

It returns `{imported, failed, errors[]}`. Each row is imported in its own
block, so a bad row records its reason in `question_import.error` and the rest
of the batch still lands; fix those rows and re-run, since imported rows are
skipped.

`supabase/seed/placeholder_questions.csv` is the bank the app runs on today:
120 placeholder questions (batch `placeholder-v1`), five in each of the 24
answerable sub-topics of the 0024 taxonomy. The two `mock-*` sub-topics get
none, because a mock exam draws from the whole bank rather than one
sub-topic. Its Sinhala and Tamil cells are empty, so the importer falls back
to English and nothing masquerades as a translation. Remove it once real
questions are in:

```sql
delete from public.questions where id in (
  select question_id from public.question_import
  where batch = 'placeholder-v1');
delete from public.question_import where batch = 'placeholder-v1';
```

`supabase/seed/fake_questions.csv` is the earlier 65-question set, written
against the 0013 sub-topic keys that 0024 replaced. It is kept only as a
record of the format and will not import as it stands.

Two things to do by hand after a first import, because neither waits for the
next cron run:

```sql
select app.job_build_daily_challenge();  -- otherwise today's card errors
```

and check that every sub-topic has questions -- `get_practice_set` raises
`empty_set` the moment one with none is tapped.

The daily challenge composes itself: `app.job_build_daily_challenge()` runs at
06:00 SL (an hour before the notification) and picks ten live questions,
preferring ones not used in the last 30 days.

## Push notifications

`notifications` is both the in-app inbox and the push outbox (migration
0020). Nothing sends a push directly: every trigger inserts a row, and
`push-dispatch` drains the `pending` ones through FCM.

| Kind | Fires | From |
| --- | --- | --- |
| `daily_challenge` | 07:00 SL, if today's challenge exists and the user's tier includes it and they have not started it | `app.job_daily_challenge()` |
| `streak` | 20:00 SL, if they practised yesterday but not today | `app.job_streak_at_risk()` |
| `digest` | When a `current_affairs` row goes `live` | trigger on `current_affairs` |
| `charge_failed` | When a `telco_charges` row is `failed`; the RevenueCat webhook calls `enqueue_notification` | trigger on `telco_charges` |
| `renewal` | 10:00 SL, `renewal_reminder_days` before a RevenueCat plan's `valid_until` | `app.job_renewal_reminder()` |
| `inactivity` | 18:00 SL, once per stretch of `inactivity_days` without practice or sign-in | `app.job_inactivity()` |

- **Preferences** are checked when the row is written (`app.push_audience`).
  A kind the user turned off produces nothing, not even an inbox entry.
- **Duplicates** are prevented by `dedupe_key`, so re-running a job is safe.
- **Copy** lives in `notification_templates`, in all three languages, because
  a push is rendered while the app is closed. Edit that table to change
  wording. The Sinhala and Tamil rows are drafts and need review by the
  content team.
- **Tunables** are in `app_settings`: `inactivity_days` and
  `renewal_reminder_days`. Change send times with `cron.alter_job`. pg_cron
  runs in UTC, and SL is UTC+05:30.

### Turning it on

1. Create a Firebase project, and add an Android app (`lk.knowhow.smart_iq`)
   and an iOS app (`lk.knowhow.smartIq`). Upload an APNs auth key (.p8)
   under Cloud Messaging.
2. Run `flutterfire configure --project=smartiq-notification`. It writes
   `lib/firebase_options.dart` and `android/app/google-services.json`. This
   is already done for Android and iOS.
3. Set the Edge Function secrets and deploy:
   ```
   npx supabase secrets set FCM_SERVICE_ACCOUNT="$(cat service-account.json)" PUSH_DISPATCH_SECRET=<random>
   npx supabase functions deploy push-dispatch
   ```
   `FCM_SERVICE_ACCOUNT` is the JSON key of a service account with the
   *Firebase Cloud Messaging API Admin* role.
4. Tell the database where to call, using the same secret:
   ```sql
   select vault.create_secret('https://glmryghkrpnmlqymsxuz.supabase.co/functions/v1/push-dispatch', 'push_dispatch_url');
   select vault.create_secret('<same random>', 'push_dispatch_secret');
   ```
   Until both exist, `app.kick_push_dispatch()` does nothing and rows just
   accumulate in the inbox.

To check it's working: `select * from cron.job_run_details order by start_time desc`,
`select push_status, count(*) from notifications group by 1`, and the
`push-dispatch` function logs, which print a per-run tally.

## Working on it

Migrations are applied through the Supabase MCP tools or the CLI. To pull
the remote schema into this folder:

```
npx supabase link --project-ref glmryghkrpnmlqymsxuz
npx supabase db pull
```

The schema is verified by transactional smoke tests rather than a test
suite: create a user, impersonate them with `set local role authenticated`
and a `request.jwt.claims` setting, exercise the RPCs, then `rollback`.
