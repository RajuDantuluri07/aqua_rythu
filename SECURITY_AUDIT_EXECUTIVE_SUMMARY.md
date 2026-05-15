# AquaRythu Security Audit - Executive Summary

**Status:** 🔴 **CRITICAL - NOT PRODUCTION READY**  
**Date:** May 15, 2026  
**Overall Score:** 5/10 (CRITICAL RISK)

---

## STOP - Read This First

**DO NOT SHIP TO FARMERS** until these 4 critical vulnerabilities are fixed:

### 1. ✋ DEBUG SUBSCRIPTION OVERRIDE ACCESSIBLE IN PRODUCTION

**Problem:** Users can tap Profile → DEBUG MENU → "Set as PRO" to unlock all premium features without paying.

**Why It Works:**
- Debug override persists in SharedPreferences
- `kReleaseMode` is compile-time constant (false in debug APKs)
- If any debug APK reaches users, the entire paywall is bypassed

**Impact:** 100% subscription revenue loss + competitor access to premium intelligence

**Fix Time:** 4 hours
- Remove all debug override code paths
- Or: Never distribute debug APKs; build release versions for testing

---

### 2. ✋ FAIL-OPEN FEATURE GATING

**Problem:** Line 12 in `access_control_hooks.dart`:
```dart
if (feature == null) return true;  // Unknown features allowed!
```

**Impact:** Any feature ID not in the system is automatically unlocked for all users

**Fix Time:** 2 hours - Change to `return false;`

---

### 3. ✋ MULTI-TENANT ACCESS CONTROL FAILURE

**Problem:** RLS policies only check farm owner (`user_id = auth.uid()`), not farm team members

**Impact:** 
- Supervisors/workers cannot access farm data they're supposed to manage
- Entire multi-user team feature is non-functional
- Opens potential for escalation if policies are weak elsewhere

**Affected Tables:** farms, ponds, feed_logs, inventory_items, expenses, supplement_schedules

**Fix Time:** 8 hours - Update all RLS policies to include farm_members

---

### 4. ✋ NO SERVER-SIDE SUBSCRIPTION ENFORCEMENT

**Problem:** All subscription checks are client-side via `SubscriptionGate` singleton

**Impact:** Attacker can bypass Flutter app and call APIs directly:
- Use Postman/REST client to call Supabase
- No backend check of subscription status
- PRO operations happen without payment

**Fix Time:** 16 hours - Add edge function guard on all PRO endpoints

---

## Quick Risk Assessment

| Vulnerability | Likelihood | Impact | Effort to Fix |
|---------------|-----------|--------|---------------|
| Debug override bypass | **CERTAIN** (1 tap) | **CRITICAL** (all features unlocked) | 4 hrs |
| Fail-open gating | **HIGH** (new features) | **CRITICAL** (future bypasses) | 2 hrs |
| Farm member access | **MEDIUM** (incomplete feature) | **HIGH** (team access broken) | 8 hrs |
| Client-side subscription | **MEDIUM** (requires REST client) | **CRITICAL** (no payment needed) | 16 hrs |
| RLS policy gaps | **MEDIUM** (requires enumeration) | **HIGH** (IDOR data access) | 8 hrs |
| Silent error handling | **HIGH** (everywhere) | **MEDIUM** (hides issues) | 8 hrs |

---

## Immediate Actions (This Week)

### Priority 1: Disable Debug Features
- [ ] Remove `SubscriptionGate.setDebugOverride()` calls from production builds
- [ ] Remove DEBUG MENU from profile_screen.dart (or gate behind strong passcode)
- [ ] Remove payment_debug_screen.dart from release builds
- [ ] Verify no debug APKs are in distribution channels

**Time Estimate:** 4 hours  
**Risk Mitigation:** Blocks 95% of attacks

### Priority 2: Fail-Closed Feature Gating
- [ ] Change line 12 in access_control_hooks.dart: `if (feature == null) return false;`
- [ ] Add test: "Unknown feature IDs should be denied"

**Time Estimate:** 2 hours  
**Risk Mitigation:** Blocks future feature bypasses

### Priority 3: Farm Member RLS Policies
- [ ] Update all table RLS policies to check farm_members
- [ ] Test that supervisors can read their farm's data
- [ ] Test that workers cannot read data from farms they're not part of

**Time Estimate:** 8 hours  
**Risk Mitigation:** Enables team features securely

### Priority 4: Server-Side Subscription Verification
- [ ] Create `check-user-subscription` edge function
- [ ] Apply to all PRO endpoints (smart feed, profit reports, etc.)
- [ ] Test: Call endpoints with FREE account, should get 403

**Time Estimate:** 16 hours  
**Risk Mitigation:** Requires actual subscription for features

**Total Time: 30 hours (~1 week for experienced team)**

---

## Medium Priority (Month 1)

- [ ] Enable proper error logging (replace `catch (_)` blocks)
- [ ] Add RLS policies to supplement_schedules (currently missing)
- [ ] Implement rate limiting on payment APIs
- [ ] Validate ABW/density values (clamp to safe ranges)
- [ ] Paginate all list endpoints
- [ ] Implement audit logging for sensitive operations

---

## Not Ready For Production Until:

- ✅ Debug override completely removed
- ✅ Server-side subscription enforcement in place
- ✅ Farm member RLS policies working
- ✅ All table RLS policies reviewed
- ✅ Error logging enabled
- ✅ Security tests added to CI/CD
- ✅ Penetration test completed

---

## Deployment Recommendation

### Current State: 🔴 DO NOT SHIP

**Why Not:**
- Any user with debug APK gets unlimited free features
- Supervisors/workers can't use the app (RLS blocks them)
- Competitors could access farm data if RLS is misconfigured
- No audit trail of PRO operations

### After Priority 1-4 Fixes: 🟡 BETA ONLY

**With Controls:**
- Limit to 100 users for intensive monitoring
- Monitor all RLS denials
- Monitor for enumeration attempts
- Have security team on-call
- Can roll back quickly if issues found

### After Medium Priority Fixes: 🟢 PRODUCTION READY

---

## Risk Scorecard

```
Authentication:        ⚠️  7/10  (Supabase handles well)
Authorization:         🔴  3/10  (RLS incomplete, no team access)
Input Validation:      🔴  4/10  (No feed amount validation)
Subscription Gating:   🔴  2/10  (All client-side, debug override)
API Security:          🔴  4/10  (No server-side checks)
Data Isolation:        🔴  3/10  (Farm members not enforced)
Error Handling:        🔴  4/10  (Silent failures everywhere)
Infrastructure:        🟡  7/10  (Supabase well-configured)
─────────────────────────────────
OVERALL:               🔴  4/10  (CRITICAL)
```

---

## Key Metrics to Track Post-Deployment

1. **Subscription Bypass Attempts:** Monitor for users calling PRO endpoints without subscription
2. **RLS Denial Rate:** >1% of API calls failing should trigger investigation
3. **Enumeration Attempts:** User scanning sequential IDs should be blocked/logged
4. **Farm Member Access:** Track that supervisors can read their assigned ponds
5. **Payment Verification Failures:** Should be ~0.1% (card issues, etc.)
6. **Debug Feature Usage:** Should be 0 in production

---

## Support Contacts

- **Security Lead:** [To be assigned]
- **On-Call Response Time:** Immediately for 🔴 critical issues
- **Escalation Path:** Head of Engineering → CEO for security incidents

---

## Conclusion

AquaRythu has **solid payment infrastructure** (Razorpay integration looks correct) but **critical gaps in authorization and subscription enforcement**. The 4 issues above are easily fixable but will significantly impact the product. Team should prioritize these immediately.

**Estimated time to production-ready: 2-3 weeks**

---

*For detailed findings, see SECURITY_AUDIT_REPORT.md*
