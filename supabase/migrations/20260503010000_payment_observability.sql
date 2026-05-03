-- Payment observability migration
-- Tickets 26 (payment_orders), 27 (pending_payments), 29 (payment_logs)

-- ── T26: Order tracking — server-side source of truth ────────────────────────
CREATE TABLE IF NOT EXISTS payment_orders (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id    TEXT NOT NULL UNIQUE,          -- Razorpay order ID
  user_id     UUID NOT NULL REFERENCES auth.users(id),
  status      TEXT NOT NULL DEFAULT 'created', -- created | paid | failed
  amount      INTEGER NOT NULL,              -- paise
  plan_type   TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS payment_orders_user_idx ON payment_orders (user_id);
CREATE INDEX IF NOT EXISTS payment_orders_order_id_idx ON payment_orders (order_id);

ALTER TABLE payment_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own orders"   ON payment_orders FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Service inserts orders"  ON payment_orders FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service updates orders"  ON payment_orders FOR UPDATE USING (auth.uid() = user_id);

-- ── T27: Pending payment proof — cross-device fallback ───────────────────────
CREATE TABLE IF NOT EXISTS pending_payments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id),
  order_id    TEXT NOT NULL,
  payment_id  TEXT NOT NULL UNIQUE,         -- prevents duplicate pending rows
  signature   TEXT NOT NULL,
  plan_type   TEXT NOT NULL,
  price       NUMERIC(10,2) NOT NULL,
  status      TEXT NOT NULL DEFAULT 'pending', -- pending | verified
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS pending_payments_user_idx ON pending_payments (user_id);

ALTER TABLE pending_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own pending"   ON pending_payments FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own pending" ON pending_payments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own pending" ON pending_payments FOR UPDATE USING (auth.uid() = user_id);

-- ── T29: Payment logs — append-only observability ────────────────────────────
CREATE TABLE IF NOT EXISTS payment_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES auth.users(id),
  order_id      TEXT,
  payment_id    TEXT,
  status        TEXT NOT NULL,  -- created | success | failed | retry | webhook_received
  source        TEXT NOT NULL,  -- client | webhook
  error_message TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS payment_logs_user_idx ON payment_logs (user_id);
CREATE INDEX IF NOT EXISTS payment_logs_order_idx ON payment_logs (order_id);

ALTER TABLE payment_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own logs" ON payment_logs FOR SELECT USING (auth.uid() = user_id);
-- Logs are written by service-role from edge functions; no client INSERT policy needed.
