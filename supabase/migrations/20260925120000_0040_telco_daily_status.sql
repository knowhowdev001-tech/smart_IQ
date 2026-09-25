-- One telco_charges row per user per Sri Lanka day.
--
-- The charging provider sends no charge callbacks, and its charging-info
-- returns no records, so there is no per-charge event to store. Until there
-- is, each successful subscriber-status check (payment-status on app open,
-- otp-verify at signup) upserts the day's row with what the carrier said:
-- status is its subscriptionStatus lowercased ('registered', 'unregistered',
-- or whatever else it sends), raw_callback its whole reply. A second check
-- the same day updates the row rather than adding one, which is what this
-- index is for.
--
-- The charge_failed push (0020) fires only on status 'failed', which no
-- carrier status maps to, so a daily row never sends one.

create unique index telco_charges_user_day_idx
  on public.telco_charges (user_id, charge_date);
