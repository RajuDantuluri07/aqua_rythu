import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { logPayment } from '../_shared/payment_logger.ts'

const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID')!
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  // Auth — user JWT is sent automatically by Supabase Flutter client (T26)
  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response('Unauthorized', { status: 401 })
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  const jwt = authHeader.slice('Bearer '.length)
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser(jwt)

  if (authError || !user) {
    return new Response('Unauthorized', { status: 401 })
  }

  const { amount, currency = 'INR', receipt, plan_type = 'PRO' } = await req.json()

  // Create order with Razorpay
  const credentials = btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`)
  const rzpResponse = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Basic ${credentials}`,
    },
    body: JSON.stringify({ amount, currency, receipt }),
  })

  const order = await rzpResponse.json()

  if (!rzpResponse.ok || !order.id) {
    return new Response(
      JSON.stringify({ error: 'Razorpay order creation failed', details: order }),
      { status: rzpResponse.status, headers: { 'Content-Type': 'application/json' } },
    )
  }

  // T26: Record order as server-side source of truth
  await supabase.from('payment_orders').insert({
    order_id: order.id,
    user_id: user.id,
    status: 'created',
    amount,
    plan_type: plan_type.toLowerCase(),
    created_at: new Date().toISOString(),
  })

  // T29: Log order creation
  await logPayment(supabase, {
    userId: user.id,
    orderId: order.id,
    status: 'created',
    source: 'client',
  })

  return new Response(JSON.stringify(order), {
    headers: { 'Content-Type': 'application/json' },
  })
})
