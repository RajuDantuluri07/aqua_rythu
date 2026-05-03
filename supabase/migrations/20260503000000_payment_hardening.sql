-- Payment hardening migration
-- Tickets 19, 23, 24

-- Add Razorpay tracking columns (idempotency + audit trail)
ALTER TABLE subscriptions
  ADD COLUMN IF NOT EXISTS payment_id   TEXT,
  ADD COLUMN IF NOT EXISTS order_id     TEXT,
  ADD COLUMN IF NOT EXISTS end_date     TIMESTAMPTZ;

-- T19: Unique constraint so duplicate verifications return the same row,
-- not a second row. Existing rows have NULL payment_id — NULLs are not
-- considered equal in UNIQUE constraints, so old rows are unaffected.
CREATE UNIQUE INDEX IF NOT EXISTS subscriptions_payment_id_unique
  ON subscriptions (payment_id)
  WHERE payment_id IS NOT NULL;

-- T23: Auto-expire subscriptions whose end_date has passed.
-- Safe to run repeatedly (IF NOT EXISTS guard).
CREATE OR REPLACE FUNCTION expire_subscriptions() RETURNS void
  LANGUAGE sql AS $$
    UPDATE subscriptions
    SET    status = 'expired'
    WHERE  status = 'active'
      AND  end_date IS NOT NULL
      AND  end_date < NOW();
  $$;
