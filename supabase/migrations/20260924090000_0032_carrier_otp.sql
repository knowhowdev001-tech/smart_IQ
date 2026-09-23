-- The OTP now lives at the carrier.
--
-- Our own code was a stand-in for an SMS gateway we did not have: hashed,
-- single-use and never delivered, so production either issued the constant
-- development code or a random one nobody received. The Mobile Charging API
-- sends the real thing and checks it, returning a reference we quote back at
-- verify time.
--
-- The row stays, because the carrier does none of what it is for: the resend
-- cooldown, the attempt cap that stops a six-digit code being guessed, and
-- an audit trail of who asked for a code and from where.

alter table public.otp_requests
  add column reference_no text,
  alter column otp_hash drop not null;

comment on column public.otp_requests.reference_no is
  'The carrier''s handle for this OTP, returned by its otp-request and
   required by its otp-verify. Null only on rows written before the
   gateway existed.';

comment on column public.otp_requests.otp_hash is
  'Hash of a code this service issued itself. Unused since the carrier took
   over delivery -- kept so the rows written before it remain readable.';
