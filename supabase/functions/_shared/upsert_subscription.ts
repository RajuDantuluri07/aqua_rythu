// Shared idempotent subscription creation used by both
// verify-razorpay-payment (client path) and razorpay-webhook (server path).
// This ensures both paths always converge to the same final state (T28).

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

export interface UpsertParams {
  paymentId: string
  orderId: string
  userId: string
  planType: string
  price: number
}

export interface UpsertResult {
  subscription: Record<string, unknown>
  alreadyExisted: boolean
}

export async function upsertSubscription(
  supabase: SupabaseClient,
  params: UpsertParams,
): Promise<UpsertResult> {
  const { paymentId, orderId, userId, planType, price } = params

  // ── Idempotency: return existing row for duplicate payment_id (T19/T28) ──────
  const { data: existing } = await supabase
    .from('subscriptions')
    .select()
    .eq('payment_id', paymentId)
    .maybeSingle()

  if (existing) {
    return { subscription: existing, alreadyExisted: true }
  }

  const now = new Date().toISOString()

  const { data, error } = await supabase
    .from('subscriptions')
    .insert({
      user_id: userId,
      farm_id: userId,
      plan_type: planType.toLowerCase(),
      start_date: now,
      status: 'active',
      price,
      currency: 'INR',
      payment_id: paymentId,
      order_id: orderId,
      created_at: now,
    })
    .select()
    .single()

  // ── Race condition: unique violation means another request got here first ─────
  if (error?.code === '23505') {
    const { data: raceRow } = await supabase
      .from('subscriptions')
      .select()
      .eq('payment_id', paymentId)
      .single()
    return { subscription: raceRow!, alreadyExisted: true }
  }

  if (error) throw new Error(`Subscription insert failed: ${error.message}`)

  // ── Mark payment_orders as paid ───────────────────────────────────────────────
  await supabase
    .from('payment_orders')
    .update({ status: 'paid' })
    .eq('order_id', orderId)

  // ── Mark pending_payments as verified ─────────────────────────────────────────
  await supabase
    .from('pending_payments')
    .update({ status: 'verified' })
    .eq('payment_id', paymentId)

  return { subscription: data, alreadyExisted: false }
}
