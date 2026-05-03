// Razorpay webhook receiver (T25)
//
// Receives payment.captured events from Razorpay and creates subscriptions
// independently of the client verify flow. This is the safety net — it works
// even if the client flow breaks after checkout success.
//
// Deploy: supabase functions deploy razorpay-webhook --no-verify-jwt
// Set in Razorpay dashboard:
//   Webhook URL: https://<project>.supabase.co/functions/v1/razorpay-webhook
//   Events: payment.captured
//   Secret: <RAZORPAY_WEBHOOK_SECRET> (different from API key secret)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { upsertSubscription } from '../_shared/upsert_subscription.ts'
import { logPayment } from '../_shared/payment_logger.ts'

const RAZORPAY_WEBHOOK_SECRET = Deno.env.get('RAZORPAY_WEBHOOK_SECRET')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

async function hmacSha256(secret: string, body: string): Promise<string> {
  const enc = new TextEncoder()
  const key = await crypto.subtle.importKey(
    'raw', enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false, ['sign'],
  )
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(body))
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, '0')).join('')
}

serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })

  const rawBody = await req.text()

  // ── Webhook signature validation (separate secret from API key) ───────────────
  const incomingSig = req.headers.get('X-Razorpay-Signature') ?? ''
  const expectedSig = await hmacSha256(RAZORPAY_WEBHOOK_SECRET, rawBody)

  if (incomingSig !== expectedSig) {
    return new Response('Webhook signature mismatch', { status: 400 })
  }

  let event: { event: string; payload: { payment: { entity: Record<string, unknown> } } }
  try {
    event = JSON.parse(rawBody)
  } catch {
    return new Response('Invalid JSON', { status: 400 })
  }

  // ── Only handle payment.captured — ignore all other events ───────────────────
  if (event.event !== 'payment.captured') {
    return new Response('OK', { status: 200 })
  }

  const payment = event.payload.payment.entity
  const paymentId = payment.id as string
  const orderId = payment.order_id as string
  const amount = payment.amount as number         // paise
  const userId = (payment.notes as Record<string, string>)?.user_id ?? ''

  if (!paymentId || !orderId) {
    return new Response('Missing payment_id or order_id', { status: 400 })
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  // T29: Log webhook received immediately
  await logPayment(supabase, {
    userId,
    orderId,
    paymentId,
    status: 'webhook_received',
    source: 'webhook',
  })

  // ── Resolve user_id + plan_type from payment_orders if not in notes ───────────
  let resolvedUserId = userId
  let planType = 'PRO'
  let price = amount / 100

  const { data: order } = await supabase
    .from('payment_orders')
    .select('user_id, plan_type, amount')
    .eq('order_id', orderId)
    .maybeSingle()

  if (order) {
    resolvedUserId = order.user_id
    planType = order.plan_type
    price = order.amount / 100
  }

  if (!resolvedUserId) {
    await logPayment(supabase, {
      userId: '',
      orderId,
      paymentId,
      status: 'failed',
      source: 'webhook',
      errorMessage: 'Cannot resolve user_id — no matching payment_order',
    })
    // Return 200 to Razorpay so it stops retrying; we cannot fix this.
    return new Response('OK — unresolvable user', { status: 200 })
  }

  // ── T28: Same shared upsert as the client verify path ────────────────────────
  try {
    await upsertSubscription(supabase, {
      paymentId,
      orderId,
      userId: resolvedUserId,
      planType,
      price,
    })

    await logPayment(supabase, {
      userId: resolvedUserId,
      orderId,
      paymentId,
      status: 'success',
      source: 'webhook',
    })

    return new Response('OK', { status: 200 })
  } catch (err) {
    await logPayment(supabase, {
      userId: resolvedUserId,
      orderId,
      paymentId,
      status: 'failed',
      source: 'webhook',
      errorMessage: String(err),
    })

    // Return 500 so Razorpay retries the webhook
    return new Response('Subscription creation failed', { status: 500 })
  }
})
