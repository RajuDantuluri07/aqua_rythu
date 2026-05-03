import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { upsertSubscription } from '../_shared/upsert_subscription.ts'
import { logPayment } from '../_shared/payment_logger.ts'

const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })

async function hmacSha256(secret: string, message: string): Promise<string> {
  const enc = new TextEncoder()
  const key = await crypto.subtle.importKey(
    'raw', enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false, ['sign'],
  )
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(message))
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, '0')).join('')
}

serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })

  // ── Auth ──────────────────────────────────────────────────────────────────────
  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) return new Response('Unauthorized', { status: 401 })

  // ── Input validation (T24) ───────────────────────────────────────────────────
  let body: { payment_id: string; order_id: string; signature: string; plan_type: string; price: number }
  try { body = await req.json() } catch { return json({ error: 'Invalid JSON' }, 400) }

  const { payment_id, order_id, signature, plan_type, price } = body
  if (!payment_id || !order_id || !signature || !plan_type || price == null) {
    return json({ error: 'Missing required fields' }, 400)
  }

  // ── HMAC verification (T24) — before any DB work ──────────────────────────────
  const expected = await hmacSha256(RAZORPAY_KEY_SECRET, `${order_id}|${payment_id}`)
  if (expected !== signature) {
    return json({ error: 'Payment signature mismatch — request rejected' }, 400)
  }

  // ── Authenticate user ─────────────────────────────────────────────────────────
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  const { data: { user }, error: authError } = await supabase.auth.getUser(
    authHeader.slice('Bearer '.length),
  )
  if (authError || !user) return new Response('Unauthorized', { status: 401 })

  // ── T27: Persist payment proof in backend BEFORE creating subscription ─────────
  // Upsert so re-tries don't fail on duplicate payment_id
  await supabase.from('pending_payments').upsert(
    {
      user_id: user.id,
      order_id,
      payment_id,
      signature,
      plan_type: plan_type.toLowerCase(),
      price,
      status: 'pending',
      created_at: new Date().toISOString(),
    },
    { onConflict: 'payment_id', ignoreDuplicates: true },
  )

  // ── T28: Shared idempotent subscription creation (used by webhook too) ─────────
  try {
    const { subscription, alreadyExisted } = await upsertSubscription(supabase, {
      paymentId: payment_id,
      orderId: order_id,
      userId: user.id,
      planType: plan_type,
      price,
    })

    // T29: Log success
    await logPayment(supabase, {
      userId: user.id,
      orderId: order_id,
      paymentId: payment_id,
      status: 'success',
      source: 'client',
      errorMessage: alreadyExisted ? 'already_existed' : undefined,
    })

    return json(subscription)
  } catch (err) {
    // T29: Log failure — client can retry safely (T20)
    await logPayment(supabase, {
      userId: user.id,
      orderId: order_id,
      paymentId: payment_id,
      status: 'failed',
      source: 'client',
      errorMessage: String(err),
    })

    return json(
      { error: 'Subscription creation failed. Payment is safe — please retry.', code: 'DB_WRITE_FAILED' },
      503,
    )
  }
})
