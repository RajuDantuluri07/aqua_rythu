# AquaRythu Subscription Operations - SQL Snippets

**Note:** These snippets assume a `subscriptions` table structure. If this table doesn't exist yet, create it using the schema at the bottom of this file.

---

## 1. USER LOOKUP BY PHONE

```sql
SELECT id, email, phone, name, created_at 
FROM profiles 
WHERE phone = '+91XXXXXXXXXX'
LIMIT 1;
```

## 2. USER LOOKUP BY EMAIL

```sql
SELECT id, email, phone, name, created_at 
FROM profiles 
WHERE email = 'farmer@example.com'
LIMIT 1;
```

## 3. CHECK USER SUBSCRIPTION STATUS

```sql
SELECT 
    p.id,
    p.email,
    p.phone,
    p.name,
    s.subscription_id,
    s.plan,
    s.status,
    s.activated_at,
    s.expires_at,
    s.payment_status,
    s.razorpay_subscription_id,
    s.updated_at,
    CASE 
        WHEN s.expires_at > NOW() AND s.status = 'active' THEN 'ACTIVE'
        WHEN s.expires_at <= NOW() AND s.status = 'active' THEN 'EXPIRED'
        WHEN s.status = 'cancelled' THEN 'CANCELLED'
        WHEN s.status = 'pending' THEN 'PENDING_ACTIVATION'
        ELSE 'UNKNOWN'
    END as effective_status
FROM profiles p
LEFT JOIN subscriptions s ON p.id = s.user_id
WHERE p.email = 'farmer@example.com';
```

## 4. ACTIVATE PRO SUBSCRIPTION

```sql
INSERT INTO subscriptions (
    user_id,
    plan,
    status,
    activated_at,
    expires_at,
    payment_status,
    razorpay_subscription_id,
    created_at,
    updated_at
)
VALUES (
    '<USER_ID>',
    'pro',
    'active',
    NOW(),
    NOW() + INTERVAL '30 days',
    'verified',
    '<RAZORPAY_SUBSCRIPTION_ID_OR_NULL>',
    NOW(),
    NOW()
)
ON CONFLICT (user_id) DO UPDATE SET
    plan = 'pro',
    status = 'active',
    activated_at = NOW(),
    expires_at = NOW() + INTERVAL '30 days',
    payment_status = 'verified',
    updated_at = NOW()
RETURNING *;
```

## 5. EXTEND SUBSCRIPTION (ADD DAYS)

```sql
UPDATE subscriptions
SET 
    expires_at = expires_at + INTERVAL '30 days',
    updated_at = NOW()
WHERE user_id = '<USER_ID>'
AND status = 'active'
RETURNING user_id, plan, status, expires_at, updated_at;
```

## 6. EXTEND SUBSCRIPTION (SET EXACT DATE)

```sql
UPDATE subscriptions
SET 
    expires_at = '<YYYY-MM-DD>'::date,
    updated_at = NOW()
WHERE user_id = '<USER_ID>'
RETURNING user_id, plan, status, expires_at, updated_at;
```

## 7. CANCEL SUBSCRIPTION

```sql
UPDATE subscriptions
SET 
    status = 'cancelled',
    updated_at = NOW()
WHERE user_id = '<USER_ID>'
RETURNING user_id, plan, status, updated_at;
```

## 8. RECORD FAILED PAYMENT

```sql
INSERT INTO subscription_payments (
    user_id,
    subscription_id,
    razorpay_payment_id,
    amount,
    currency,
    status,
    payment_method,
    error_message,
    attempted_at,
    created_at
)
VALUES (
    '<USER_ID>',
    '<SUBSCRIPTION_ID>',
    '<RAZORPAY_PAYMENT_ID>',
    <AMOUNT>,
    'INR',
    'failed',
    'card',
    '<ERROR_MESSAGE>',
    NOW(),
    NOW()
);
```

## 9. VERIFY PAYMENT & UPDATE SUBSCRIPTION

```sql
-- Check payment in payment tracking table
SELECT 
    sp.razorpay_payment_id,
    sp.amount,
    sp.status,
    sp.attempted_at,
    s.user_id,
    s.plan,
    s.status as sub_status
FROM subscription_payments sp
JOIN subscriptions s ON sp.subscription_id = s.id
WHERE sp.razorpay_payment_id = '<RAZORPAY_PAYMENT_ID>'
ORDER BY sp.attempted_at DESC
LIMIT 1;

-- Update subscription if payment verified
UPDATE subscriptions
SET 
    payment_status = 'verified',
    status = 'active',
    updated_at = NOW()
WHERE id = '<SUBSCRIPTION_ID>'
RETURNING *;
```

## 10. LIST ALL ACTIVE PRO SUBSCRIBERS

```sql
SELECT 
    p.id,
    p.email,
    p.phone,
    p.name,
    s.plan,
    s.activated_at,
    s.expires_at,
    s.payment_status,
    CASE 
        WHEN s.expires_at > NOW() THEN 'ACTIVE'
        WHEN s.expires_at <= NOW() THEN 'EXPIRED'
    END as status
FROM subscriptions s
JOIN profiles p ON s.user_id = p.id
WHERE s.plan = 'pro'
AND s.status = 'active'
AND s.expires_at > NOW()
ORDER BY s.expires_at ASC;
```

## 11. FIND EXPIRING SOON (NEXT 7 DAYS)

```sql
SELECT 
    p.email,
    p.phone,
    p.name,
    s.plan,
    s.expires_at,
    (s.expires_at - NOW())::interval as days_until_expiry
FROM subscriptions s
JOIN profiles p ON s.user_id = p.id
WHERE s.status = 'active'
AND s.expires_at > NOW()
AND s.expires_at <= NOW() + INTERVAL '7 days'
ORDER BY s.expires_at ASC;
```

## 12. FIND RECENTLY EXPIRED

```sql
SELECT 
    p.email,
    p.phone,
    p.name,
    s.plan,
    s.expires_at,
    (NOW() - s.expires_at)::interval as days_expired
FROM subscriptions s
JOIN profiles p ON s.user_id = p.id
WHERE s.status = 'active'
AND s.expires_at <= NOW()
ORDER BY s.expires_at DESC
LIMIT 20;
```

## 13. BULK STATUS REPORT

```sql
SELECT 
    COUNT(*) FILTER (WHERE s.status = 'active' AND s.expires_at > NOW()) as active_subs,
    COUNT(*) FILTER (WHERE s.status = 'active' AND s.expires_at <= NOW()) as expired_subs,
    COUNT(*) FILTER (WHERE s.status = 'cancelled') as cancelled_subs,
    COUNT(*) FILTER (WHERE s.status = 'pending') as pending_subs,
    COUNT(DISTINCT p.id) as total_users_with_history
FROM subscriptions s
RIGHT JOIN profiles p ON s.user_id = p.id;
```

---

## Database Schema (Create if needed)

If the subscription tables don't exist, run these migrations:

```sql
-- Create subscriptions table
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'pro')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'cancelled', 'expired')),
    activated_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    payment_status TEXT CHECK (payment_status IN ('pending', 'failed', 'verified', 'refunded')),
    razorpay_subscription_id TEXT UNIQUE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create subscription_payments table for payment tracking
CREATE TABLE IF NOT EXISTS subscription_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    razorpay_payment_id TEXT UNIQUE NOT NULL,
    razorpay_order_id TEXT,
    amount DECIMAL(10, 2) NOT NULL,
    currency TEXT DEFAULT 'INR',
    status TEXT CHECK (status IN ('pending', 'failed', 'success')) DEFAULT 'pending',
    payment_method TEXT,
    error_message TEXT,
    attempted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_expires_at ON subscriptions(expires_at);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_user_id ON subscription_payments(user_id);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_razorpay_id ON subscription_payments(razorpay_payment_id);
```

---

## Usage Notes

1. **Always update `updated_at`** when modifying subscription records
2. **Use transactions** for critical operations (payment + subscription updates)
3. **Store Razorpay IDs** for audit trail and reconciliation
4. **Test snippets** in Supabase dashboard before running in production
5. **Keep payment records immutable** — never delete or modify, only add records
6. **Monitor expiring subscriptions** daily for renewal reminders

---

## Quick Copy-Paste Variables

Replace these in snippets:
- `<USER_ID>` → user's UUID from profiles.id
- `<SUBSCRIPTION_ID>` → subscription UUID
- `<RAZORPAY_SUBSCRIPTION_ID>` → ID from Razorpay API response
- `<RAZORPAY_PAYMENT_ID>` → ID from Razorpay payment webhook
- `<YYYY-MM-DD>` → date in ISO format (e.g., 2026-06-13)
- `<AMOUNT>` → numeric amount (e.g., 4999.00)
