-- What the carrier thought of this number before the code went out.
--
-- The charging spec is ambiguous about its own otp-verify: the reference
-- says it "verifies the OTP and completes the subscription", while the
-- typical flow lists subscribing as a separate later step. The difference
-- decides whether logging in starts charging somebody.
--
-- Rather than trust either reading, the status is recorded when the code is
-- requested and compared after it is verified. A number that was not
-- subscribed before and is subscribed after was subscribed by the act of
-- logging in, which nobody asked for -- so the verify step undoes it.

alter table public.otp_requests
  add column subscriber_status text;

comment on column public.otp_requests.subscriber_status is
  'REGISTERED or UNREGISTERED as the carrier saw it when this code was
   issued, or null when the check could not be made. The baseline that
   tells a subscription the user asked for from one the OTP caused.';
