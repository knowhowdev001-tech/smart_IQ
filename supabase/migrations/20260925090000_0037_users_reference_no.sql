-- The carrier's reference for the OTP that completed a signup, on the user.
--
-- otp_requests.reference_no already holds it, but per code: finding the
-- one that made the account meant digging through every code the number
-- was ever sent. This keeps it on the account itself.
--
-- Named "referenceNo" as asked, so it has to be double-quoted in SQL.
-- Postgres cannot place a column beside another; it goes at the end.
--
-- Only a carrier-verified code fills it, and only signup uses the carrier.
-- Accounts made through our own code or the test number have none.

alter table public.users add column "referenceNo" text;

comment on column public.users."referenceNo" is
  'Carrier referenceNo of the OTP that verified this number at signup';

-- Existing accounts: the latest carrier code this number verified.
update public.users u
set "referenceNo" = o.reference_no
from (
  select distinct on (msisdn) msisdn, reference_no
  from public.otp_requests
  where consumed_at is not null
    and reference_no is not null
    and reference_no <> 'test-bypass'
  order by msisdn, consumed_at desc
) o
where o.msisdn = u.msisdn;
