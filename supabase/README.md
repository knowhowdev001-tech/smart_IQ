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
| C | Edge Function | Third-party calls and token minting — **not yet built** |

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

Errors carry a `hint` the client can branch on: `quota_exceeded`,
`upgrade_required`, `empty_set`, `already_submitted`.

## Limits

`tier_limits` is a narrow key/value table so the admin panel stays generic;
`tier_limits_effective` pivots it into the flat row the client reads. `-1`
means unlimited, booleans are stored as `0`/`1`. Seeded values are PRD 7.5
exactly, and are starting values, not constants. Counters reset on the Sri
Lanka day boundary via `app.sl_today()`, never the server's own date.

## What is not built yet

- **Edge Functions.** `/auth/otp/request`, `/auth/otp/verify`,
  `/auth/refresh`, `/ai/chat`, `/payment-status`, `/webhooks/revenuecat`.
  The tables they write are in place; the functions are not. Until they
  exist the app cannot sign anyone in against this database.
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
