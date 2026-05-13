-- Standardize plan types and add expiry indexing

-- Add CHECK constraints to lock down valid plan types
ALTER TABLE payment_orders
  ADD CONSTRAINT payment_orders_plan_type_check
  CHECK (plan_type IN ('full_crop', 'yearly_pro'));

ALTER TABLE pending_payments
  ADD CONSTRAINT pending_payments_plan_type_check
  CHECK (plan_type IN ('full_crop', 'yearly_pro'));

-- Index for expire_subscriptions() performance
CREATE INDEX IF NOT EXISTS idx_subscriptions_expires_at
  ON subscriptions (expires_at)
  WHERE expires_at IS NOT NULL;
