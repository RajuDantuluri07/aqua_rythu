// Append-only payment event logger (T29).
// Fire-and-forget: logging must never block or break the main payment flow.

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

export type PaymentLogStatus =
  | 'created'
  | 'success'
  | 'failed'
  | 'retry'
  | 'webhook_received'

export type PaymentLogSource = 'client' | 'webhook'

export interface LogPaymentParams {
  userId: string
  orderId: string
  paymentId?: string
  status: PaymentLogStatus
  source: PaymentLogSource
  errorMessage?: string
}

export async function logPayment(
  supabase: SupabaseClient,
  params: LogPaymentParams,
): Promise<void> {
  try {
    await supabase.from('payment_logs').insert({
      user_id: params.userId,
      order_id: params.orderId,
      payment_id: params.paymentId ?? null,
      status: params.status,
      source: params.source,
      error_message: params.errorMessage ?? null,
      created_at: new Date().toISOString(),
    })
  } catch {
    // Intentionally swallow — observability must not break payments.
  }
}
