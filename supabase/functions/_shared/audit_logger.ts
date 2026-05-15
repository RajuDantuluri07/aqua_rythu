// Security-critical event audit logger.
//
// Writes to payment_audit_logs via service_role — never client-accessible.
// Fire-and-forget: must never block or break the main payment flow.

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

export type AuditEventType =
  | 'payment_verified'
  | 'replay_attempt'
  | 'signature_mismatch'
  | 'amount_mismatch'
  | 'payment_not_captured'
  | 'duplicate_verification'
  | 'subscription_activated'
  | 'expired_access_attempt'
  | 'webhook_replay'
  | 'razorpay_api_error'

export type AuditSeverity = 'info' | 'warn' | 'critical'

export interface AuditLogParams {
  eventType: AuditEventType
  userId?: string
  paymentId?: string
  orderId?: string
  severity?: AuditSeverity
  details?: Record<string, unknown>
}

export async function logAudit(
  supabase: SupabaseClient,
  params: AuditLogParams,
): Promise<void> {
  try {
    await supabase.from('payment_audit_logs').insert({
      event_type: params.eventType,
      user_id:    params.userId    ?? null,
      payment_id: params.paymentId ?? null,
      order_id:   params.orderId   ?? null,
      severity:   params.severity  ?? 'info',
      details:    params.details   ?? null,
      created_at: new Date().toISOString(),
    })
  } catch {
    // Intentionally swallow — audit logging must never break payments.
  }
}
