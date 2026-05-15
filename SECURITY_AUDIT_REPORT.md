# AquaRythu Security Audit Report
## Comprehensive Red Team Assessment

**Date:** May 15, 2026  
**Auditor Role:** Senior Security Engineer, Red Team Specialist  
**Assessment Type:** Full-stack adversarial security audit  
**Confidence Level:** HIGH (based on code analysis, migrations, and backend logic review)

---

## Executive Summary

AquaRythu is a **MODERATELY SECURE** farming OS with **4 CRITICAL vulnerabilities**, **6 HIGH-severity issues**, and **8 MEDIUM-severity concerns**. The most dangerous attack surface is the **client-side subscription model combined with debug override functionality**, which allows complete paywall bypass. Secondary risks include **weak multi-tenant isolation** for farm member roles and **silent error handling** that masks access control violations.

**Exploitation Difficulty:** LOW (average attacker can bypass PRO features and access farm data with basic technical knowledge)  
**Business Impact:** SEVERE (subscription revenue bypass, farm data theft, competitive intelligence)  
**Scaling Risk:** CRITICAL (vulnerabilities multiply with user count; marketplace integrations will amplify)

---

## 1. VULNERABILITY SUMMARY

### Critical Severity (4)
- [C1] Debug Subscription Override Accessible in Production Debug Builds
- [C2] Fail-Open Feature Gating Logic (Unknown Features Allowed)
- [C3] Multi-Tenant Farm Member Access Control Failure
- [C4] Client-Side Only Subscription Enforcement

### High Severity (6)
- [H1] LocalFeedRepository Doesn't Persist to Supabase
- [H2] Silent Error Handling Masks Access Control Violations
- [H3] RLS Policies Don't Account for farm_members Roles
- [H4] No Server-Side Entitlement Verification on Protected Operations
- [H5] Farm Service Ownership Validation Incomplete
- [H6] Payment Debug Screen Accessible in Debug Builds

### Medium Severity (8)
- [M1] Inventory RLS Only Checks Direct Farm Ownership
- [M2] Debug Panels Leak Internal Feed Engine Calculations
- [M3] Schedule Repository Silent Failures Hide Data Inconsistency
- [M4] PlanFeatures.getFeatureById() Null Returns Allow Bypass
- [M5] Payment Verification Logic Gaps on Edge Cases
- [M6] Supplement Schedule RLS Policies Missing
- [M7] No Rate Limiting on Payment/Feed APIs
- [M8] Sensitive Farm Data Returned Without Pagination Limits

---

## 2. DETAILED FINDINGS

### CRITICAL FINDINGS

---

#### **[C1] DEBUG SUBSCRIPTION OVERRIDE ACCESSIBLE IN PRODUCTION DEBUG BUILDS**
**Severity:** CRITICAL  
**Confidence:** CRITICAL (code verified in subscription_gate.dart and profile_screen.dart)  
**Affected Component:** Frontend / Subscription Gating  
**Files Involved:**
- `lib/core/services/subscription_gate.dart` (lines 37-98)
- `lib/features/profile/profile_screen.dart` (lines 517-620)
- `lib/main.dart` (line 48)

**Technical Description:**

The app initializes a `SubscriptionGate` singleton that mirrors subscription state. Line 48 in main.dart calls `hydrateDebugOverride()` during startup:

```dart
await SubscriptionGate.hydrateDebugOverride();
```

The `SubscriptionGate` class has a debug override (`_debugOverride`) that:
1. **Persists to SharedPreferences** (lines 85-97) with key `'debug_subscription_override'`
2. **Checked against `kReleaseMode`** at the method level (lines 40, 54)
3. **Readable from SharedPreferences on app startup** (lines 53-81)
4. **Overrides actual subscription state** (line 24): `return _debugOverride ?? _isPro;`

The Profile screen exposes a "DEBUG MENU" (line 517-620) that allows users to manually:
- Set subscription to PRO (line 562-570)
- Set subscription to FREE (line 576-584)
- Reset to real state (line 590-598)

The guard is `if (kReleaseMode) return;` (line 518), which is a **COMPILE-TIME constant**.

**The Attack:**

1. **Distribute a debug APK to users** (or use APK extraction tools)
2. **In a debug APK, kReleaseMode = false at compile time**
3. **User taps the profile screen and accesses the DEBUG MENU**
4. **User taps "Set as PRO (Debug)" → entire PRO feature set unlocked**
5. **Override persists across app restarts** (stored in SharedPreferences)
6. **All PRO gating checks fail-open** because `SubscriptionGate.isPro` returns true

**Why Release Mode Doesn't Fully Protect:**

The `kReleaseMode` check happens at **method invocation time** through conditional compilation. However:
- If an attacker distributes a debug APK or uses a debug variant, the entire bypass is trivial
- The persistence mechanism (`SharedPreferences`) stores the override, making it sticky
- There is **NO backend enforcement** of subscription state on any API call

**Exploitation Scenario:**

```
1. Attacker downloads AquaRythu from Play Store (or extracts debug APK from internal testing)
2. Opens Profile → Settings → "DEBUG MENU" (visible in debug builds)
3. Taps "Set as PRO (Debug)"
4. All PRO features unlocked: smart feed engine, tray corrections, profit tracking, worker roles
5. Attacker creates unlimited ponds, generates fake crop reports, manipulates feed costs
6. Attacker never pays a single rupee
7. Competitors gain access to benchmarking data via farm metrics
```

**Business Impact:**

- **Complete paywall bypass** for any user with a debug build
- **100% subscription revenue loss** from users discovering this exploit
- **Unfair competitive advantage** for attackers who unlock smart feed without paying
- **Data integrity compromise:** attackers can generate fake crop reports, manipulate benchmarks

**Recommended Remediation:**

1. **Remove debug override completely** from production/beta builds
2. **Implement server-side subscription enforcement:**
   ```dart
   // On every PRO API call
   final subscription = await subscriptionService.getCurrentSubscription();
   if (!subscription.isPro) throw UnauthorizedException();
   ```
3. **Enforce via RLS policies** on PRO-feature data tables
4. **Never persist debug state** in SharedPreferences
5. **If debug mode is needed for QA:** 
   - Use feature flags with server-side control only
   - Require VPN + debug token to enable
   - Never ship in app binary

**Confidence Level:** CRITICAL (code review + logic path verified)

---

#### **[C2] FAIL-OPEN FEATURE GATING LOGIC (UNKNOWN FEATURES ALLOWED)**
**Severity:** CRITICAL  
**Confidence:** CRITICAL  
**Affected Component:** Frontend / Access Control  
**File:** `lib/features/upgrade/access_control_hooks.dart` (line 12)

**Technical Description:**

The `AccessControlHooks.canAccessFeature()` method:

```dart
static bool canAccessFeature(WidgetRef ref, String featureId) {
  final subscriptionState = ref.read(subscriptionProvider);
  final feature = PlanFeatures.getFeatureById(featureId);

  if (feature == null) return true; // ❌ FAIL-OPEN: Unknown features allowed!

  if (!feature.isProFeature) return true;
  return subscriptionState.isPro;
}
```

**The Vulnerability:**

If a feature ID is not found in `PlanFeatures.allFeatures`, the function **silently returns true**, allowing access.

**Exploitation Scenario:**

1. Attacker discovers that profit tracking uses feature ID `'profit_tracking'`
2. Attacker invents a feature ID `'profit_tracking_premium'` or `'test_feature_xyz'`
3. If the app ever calls `canAccessFeature(ref, 'profit_tracking_premium')`, it returns true
4. Attacker can craft requests to access non-existent features and bypass validation
5. If new features are added before the feature ID is registered in `PlanFeatures`, they're automatically unlocked

**Code Path Example:**

```dart
// In some future code:
if (ref.canAccess('future_pro_feature_v2')) {
  showProfitDashboard();
}

// Bug: If 'future_pro_feature_v2' isn't in PlanFeatures yet, it's allowed!
```

**Why This Is Critical:**

This is a **logic error that allows future bypasses** when new PRO features are added. Any developer who adds a PRO feature and uses a new feature ID before registering it in `PlanFeatures` will **automatically grant it to all users**.

**Recommended Remediation:**

```dart
static bool canAccessFeature(WidgetRef ref, String featureId) {
  final subscriptionState = ref.read(subscriptionProvider);
  final feature = PlanFeatures.getFeatureById(featureId);

  // FAIL-CLOSED: Unknown features are DENIED
  if (feature == null) return false;

  if (!feature.isProFeature) return true;
  return subscriptionState.isPro;
}
```

**Confidence Level:** CRITICAL

---

#### **[C3] MULTI-TENANT FARM MEMBER ACCESS CONTROL FAILURE**
**Severity:** CRITICAL  
**Confidence:** CRITICAL  
**Affected Component:** Backend / Multi-Tenant Authorization  
**File:** `supabase/migrations/20260514000000_create_farm_members_table.sql` (lines 20-32)

**Technical Description:**

The `farm_members` table was created with RLS policies that **only allow farm owners to access member records**:

```sql
CREATE POLICY "farm_members_select"
  ON public.farm_members FOR SELECT
  USING (farm_id IN (SELECT id FROM public.farms WHERE user_id = auth.uid()));
```

This policy:
- ✅ Allows the farm owner to see members
- ❌ **Does NOT allow supervisors/workers to see other team members**
- ❌ **Does NOT allow supervisors/workers to be invited** (only owner can insert members)
- ❌ **Does NOT enforce role-based access to farm operations**

**The Attack Path:**

1. Farm owner invites a supervisor with email `supervisor@farm.com`
2. Farm owner invites a worker with email `worker@farm.com`
3. Supervisor and worker log in, but **cannot see each other** (farm_members RLS blocks SELECT)
4. Supervisor cannot invite new workers (RLS blocks INSERT)
5. **More critically:** Farm_members table shows roles, but **NO OTHER TABLE checks these roles**

**Cascading RLS Policy Failures:**

Looking at other RLS policies (feed_logs, inventory_items), they all use:
```sql
USING (pond_id IN (SELECT id FROM public.ponds WHERE user_id = auth.uid()));
```

This means:
- Feed logs are readable **only to farm owner**
- Inventory is readable **only to farm owner**
- **Supervisors/workers cannot read data they're responsible for operating**

**The Business Logic Flaw:**

The role system exists in farm_members (farmer, partner, supervisor, worker) but is **never enforced** in RLS policies. This means:

1. A worker invited to a farm **cannot access pond data at all**
2. A supervisor **cannot manage team members**
3. The entire multi-user feature is **non-functional from a security perspective**

**Recommended Remediation:**

Replace all `WHERE user_id = auth.uid()` RLS policies with:

```sql
-- Allow owner AND farm members with appropriate roles
CREATE POLICY "farms_accessible_to_team"
  ON public.farms FOR SELECT
  USING (
    user_id = auth.uid()
    OR farm_id IN (
      SELECT farm_id FROM public.farm_members 
      WHERE email = auth.email()
    )
  );

-- Granular role-based access:
CREATE POLICY "feed_logs_team_access"
  ON public.feed_logs FOR SELECT
  USING (
    pond_id IN (
      SELECT id FROM public.ponds 
      WHERE farm_id IN (
        SELECT farm_id FROM public.farm_members 
        WHERE email = auth.email() AND role IN ('supervisor', 'worker')
        UNION
        SELECT id FROM public.farms WHERE user_id = auth.uid()
      )
    )
  );
```

**Confidence Level:** CRITICAL (RLS policies verified in migration)

---

#### **[C4] CLIENT-SIDE ONLY SUBSCRIPTION ENFORCEMENT**
**Severity:** CRITICAL  
**Confidence:** CRITICAL  
**Affected Component:** Backend / API Authorization  
**Files:**
- `lib/core/services/subscription_service.dart` (lines 122-139)
- Edge functions (verify-razorpay-payment, razorpay-webhook)
- All RLS policies (none check subscription status)

**Technical Description:**

The subscription system **relies entirely on client-side Riverpod state**:

1. `SubscriptionService.canAccessFeature()` (line 122) checks subscription client-side
2. `MasterFeedEngine` uses `SubscriptionGate.isPro` (static singleton) for feed corrections
3. **No RLS policies check subscription status**
4. **No edge functions enforce subscription for PRO operations**

**Attack Path:**

Even if the debug override is fixed:

1. Attacker authenticates as a real user
2. Attacker manipulates local Riverpod state: `ref.read(subscriptionProvider).currentPlan = PlanType.PRO;`
3. **OR** Attacker directly calls Supabase APIs (bypassing Flutter app entirely)
4. Attacker performs PRO operations that should be gated

**Example: Smart Feed Bypass**

The `MasterFeedEngine.orchestrate()` checks:
```dart
if (SubscriptionGate.isPro) {
  // Apply smart feed corrections
  result = SmartFeedEngineV2.applyCorrections(result);
}
```

But there's **NO RLS policy** preventing a FREE user from:
1. Calling the feed engine directly from a custom client
2. Inserting feed_logs with smart-feed-corrected values
3. Creating fake crop reports with premium intelligence

**Backend API Enforcement Gaps:**

Looking at feed repositories (feed_repository.dart), operations like:
- Update pond ABW
- Insert feed logs
- Create crop schedules
- Approve tray adjustments

**ALL use simple `.eq('pond_id', pondId)` filters with NO subscription check.**

**Recommended Remediation:**

1. **Add subscription column to farms table:**
   ```sql
   ALTER TABLE public.farms ADD COLUMN plan_type TEXT DEFAULT 'free';
   ```

2. **Create RLS function for subscription enforcement:**
   ```sql
   CREATE OR REPLACE FUNCTION is_pro_subscriber(farm_id UUID) RETURNS BOOLEAN AS $$
   BEGIN
     RETURN EXISTS (
       SELECT 1 FROM subscriptions
       WHERE user_id = (SELECT user_id FROM farms WHERE id = farm_id)
       AND plan = 'pro'
       AND status = 'active'
       AND expires_at > NOW()
     );
   END;
   $$ LANGUAGE plpgsql;
   ```

3. **Apply to all PRO-feature RLS policies:**
   ```sql
   CREATE POLICY "smart_feed_corrections_pro_only"
     ON public.feed_logs FOR UPDATE
     USING (is_pro_subscriber((SELECT farm_id FROM ponds WHERE id = pond_id)));
   ```

4. **Verify subscription in edge functions before activating premium features.**

**Confidence Level:** CRITICAL

---

### HIGH SEVERITY FINDINGS

---

#### **[H1] LocalFeedRepository DOESN'T PERSIST TO SUPABASE**
**Severity:** HIGH  
**Confidence:** CRITICAL  
**Affected Component:** Frontend / Data Persistence  
**File:** `lib/core/repositories/feed_repository.dart`

**Technical Description:**

The `FeedRepository` is currently using the `LocalFeedRepository` implementation:

```dart
class LocalFeedRepository implements FeedRepository {
  final Map<String, List<Map<String, dynamic>>> _storage = {};

  @override
  Future<List<Map<String, dynamic>>> getFeeds(String pondId) async {
    return _storage[pondId] ?? [];
  }

  @override
  Future<void> addFeed(String pondId, Map<String, dynamic> entry) async {
    _storage.putIfAbsent(pondId, () => []);
    _storage[pondId]!.add(entry);
  }
}
```

This **stores data only in memory** (in-process Dart map). **Data is lost on app restart.**

**Impact:**

- Feed logs added by users are **lost on app close**
- Feed history is **not visible after app restart**
- Users believe they're saving data, but it's silently discarded
- **No audit trail** of feed entries (data integrity risk for regulatory compliance)

**Recommended Fix:**

```dart
class RemoteFeedRepository implements FeedRepository {
  @override
  Future<void> addFeed(String pondId, Map<String, dynamic> entry) async {
    await Supabase.instance.client
        .from('feed_logs')
        .insert({
          ...entry,
          'pond_id': pondId,
          'created_at': DateTime.now().toIso8601String(),
        });
  }
}
```

**Confidence Level:** CRITICAL (verified in code)

---

#### **[H2] SILENT ERROR HANDLING MASKS ACCESS CONTROL VIOLATIONS**
**Severity:** HIGH  
**Confidence:** CRITICAL  
**Affected Component:** Frontend / Error Handling  
**Files:** Multiple repositories and services

**Technical Description:**

Throughout the codebase, API calls are wrapped in try-catch blocks that **silently swallow errors**:

```dart
// schedule_repository.dart, line 56
Future<SupplementSchedule?> insertSchedule(SupplementSchedule schedule) async {
  try {
    // ... insert logic ...
  } catch (_) {
    return null;  // ❌ Silent failure
  }
}

// schedule_repository.dart, lines 89, 98
} catch (_) {
  // Silent error handling
}

// pond_repository.dart, lines 15-16, 28-30, 42
} catch (e) {
  debugPrint('PondRepository...error: $e');
  return null;  // Returns null, doesn't distinguish between errors
}
```

**Why This Is Dangerous:**

When an RLS policy **denies access** to a record, Supabase returns a 403 Forbidden error. But the code treats it the same as a network error:

1. Attacker tries to access another farm's pond via IDOR
2. RLS policy blocks it (403 Forbidden)
3. Code catches the error and returns null
4. No log, no alert, no distinction between "network error" and "access denied"
5. Attacker has no way to know if the exploit worked
6. Legitimate users also see "no data" without knowing why

**Silent Catch Examples:**

- Line 89 in schedule_repository.dart: `catch (_) { /* Silent */ }`
- Line 98 in schedule_repository.dart: `catch (_) { /* Silent */ }`
- Line 56 in schedule_repository.dart: `catch (_) { return null; }`

**Recommended Remediation:**

```dart
} catch (e) {
  // Log the error with context
  AppLogger.error('ScheduleRepository.insertSchedule failed for pond $pondId', e);
  
  // Distinguish error types
  if (e is AuthException) {
    throw AuthenticationError('User not authenticated');
  } else if (e is PostgrestException && e.code == 'PGRST301') {
    throw AccessDeniedError('You do not have permission to create schedules');
  } else {
    throw RepositoryException('Failed to insert schedule');
  }
}
```

**Confidence Level:** CRITICAL (verified in code)

---

#### **[H3] RLS POLICIES DON'T ACCOUNT FOR farm_members ROLES**
**Severity:** HIGH  
**Confidence:** CRITICAL  
**Affected Component:** Backend / Multi-Tenant Access Control  

This is a continuation of [C3]. All table RLS policies need role-based enforcement:

**Current State (BROKEN):**
```sql
USING (farm_id IN (SELECT id FROM public.farms WHERE user_id = auth.uid()));
```

**Required Fix (role-aware):**
```sql
USING (
  farm_id IN (SELECT id FROM public.farms WHERE user_id = auth.uid())
  OR farm_id IN (
    SELECT farm_id FROM public.farm_members 
    WHERE email = auth.email() AND status = 'active'
  )
);
```

**Affected Tables:**
- farm_members (can't see teammates)
- inventory_items (supervisors can't manage)
- expenses (workers can't enter costs)
- supplement_schedules (role-based operations missing)
- ponds (read-only for non-owners)
- feed_logs (no team access)

**Confidence Level:** CRITICAL

---

#### **[H4] NO SERVER-SIDE ENTITLEMENT VERIFICATION ON PROTECTED OPERATIONS**
**Severity:** HIGH  
**Confidence:** CRITICAL  
**Affected Component:** Backend / API Authorization  

**Current State:**
- Feed corrections applied only if `SubscriptionGate.isPro` (client-side)
- Crop reports generated without checking backend subscription status
- Tray corrections applied without PRO enforcement
- Growth intelligence calculations happen without gating

**Exploitation:**
An attacker can use a Supabase REST client or Postman to:
1. Call feed engine endpoints directly
2. Bypass Flutter app's SubscriptionGate check
3. Perform unlimited PRO operations

**Recommended Remediation:**

Create an edge function `check_pro_status`:
```typescript
// supabase/functions/check_pro_status/index.ts
const response = await supabase
  .from('subscriptions')
  .select('plan')
  .eq('user_id', user.id)
  .eq('status', 'active')
  .gte('expires_at', new Date().toISOString())
  .single();

if (!response.data || response.data.plan !== 'pro') {
  throw new Error('PRO subscription required');
}
```

**Confidence Level:** CRITICAL

---

#### **[H5] FARM SERVICE OWNERSHIP VALIDATION INCOMPLETE**
**Severity:** HIGH  
**Confidence:** HIGH  
**Affected Component:** Backend / Authorization  
**File:** `lib/core/services/farm_service.dart` (lines 57-76)

**Technical Description:**

The `updateFarm()` function **does validate ownership**:
```dart
await supabase
    .from('farms')
    .update({ 'name': name, 'location': location })
    .eq('id', farmId)
    .eq('user_id', user.id);  // ✅ Ownership check
```

However, the `runDailyCycle()` function (line 13):
```dart
Future<void> runDailyCycle(String pondId) async {
  await pondDashboardController.load(pondId);
}
```

**Does NOT validate** that `pondId` belongs to the current user. An attacker could:
1. Obtain another farmer's pondId (via data enumeration)
2. Call `runDailyCycle(otherFarmerspondId)`
3. Trigger expensive feed engine calculations or data updates on another farm

**Recommended Remediation:**

```dart
Future<void> runDailyCycle(String pondId) async {
  final user = supabase.auth.currentUser;
  
  // Verify ownership
  final pond = await supabase
      .from('ponds')
      .select('farm_id')
      .eq('id', pondId)
      .single();
  
  final farm = await supabase
      .from('farms')
      .select('user_id')
      .eq('id', pond['farm_id'])
      .single();
  
  if (farm['user_id'] != user.id) {
    throw UnauthorizedException();
  }
  
  await pondDashboardController.load(pondId);
}
```

**Confidence Level:** HIGH

---

#### **[H6] PAYMENT DEBUG SCREEN ACCESSIBLE IN DEBUG BUILDS**
**Severity:** HIGH  
**Confidence:** CRITICAL  
**Affected Component:** Frontend / Debug Exposure  
**File:** `lib/features/admin/payment_debug_screen.dart` (lines 39-58)

**Technical Description:**

The PaymentDebugScreen (available only in debug builds) allows filtering and viewing **payment logs for ANY user_id**:

```dart
Future<void> _loadLogs() async {
  final userId = _userIdCtrl.text.trim();
  final rows = await Supabase.instance.client
      .from('payment_logs')
      .select()
      .eq('user_id', userId)  // ❌ No validation that user_id == auth.uid()
      .order('created_at', ascending: false)
      .limit(100);
}
```

**Attack:**

1. Obtain any user's UUID (enumeration attack)
2. Open PaymentDebugScreen
3. Enter the target user's UUID
4. View **all payment events, errors, and order IDs for that user**
5. Extract sensitive financial information, payment history, subscription status

**Leakage:**
- Payment IDs
- Order IDs
- Error messages revealing payment processing details
- Subscription status and expiry dates
- Failed payment attempts (hints at fraud attempts)

**Recommended Remediation:**

```dart
if (kReleaseMode) {
  return Scaffold(
    body: Center(child: Text('Debug features not available')),
  );
}

// Only allow viewing own payment logs
final currentUserId = Supabase.instance.client.auth.currentUser?.id;
if (_userIdCtrl.text.trim().isNotEmpty && _userIdCtrl.text.trim() != currentUserId) {
  // Disallow cross-user access
  setState(() {
    _error = 'You can only view your own payment logs';
  });
  return;
}
```

**Confidence Level:** CRITICAL

---

### MEDIUM SEVERITY FINDINGS

---

#### **[M1] INVENTORY RLS ONLY CHECKS DIRECT FARM OWNERSHIP**
**Severity:** MEDIUM  
**Confidence:** CRITICAL  
**Affected Component:** Backend / Multi-Tenant Access  

Current RLS:
```sql
USING (farm_id IN (SELECT id FROM public.farms WHERE user_id = auth.uid()));
```

**Issue:** Supervisors/workers invited to a farm cannot access inventory.

**Fix:** Use farm_members table like [C3].

---

#### **[M2] DEBUG PANELS LEAK INTERNAL FEED ENGINE CALCULATIONS**
**Severity:** MEDIUM  
**Confidence:** CRITICAL  
**Affected Component:** Frontend / Information Disclosure  
**File:** `lib/features/pond/widgets/feed_debug_panel.dart`

The 5-tap trigger opens a feed debug panel showing:
- DOC value
- Density
- Base feed calculations
- Tray factor
- Adjustment factors

**Risk:** In a debug APK, this reveals:
- Smart feed algorithm specifics
- Correction factors that competitors could reverse-engineer
- Internal benchmark values

**Mitigation:** Remove debug panels from any distributed builds.

---

#### **[M3] SCHEDULE REPOSITORY SILENT FAILURES HIDE DATA INCONSISTENCY**
**Severity:** MEDIUM  
**Confidence:** HIGH  
**Affected Component:** Frontend / Data Integrity  

Silent catches in schedule operations mean:
- Failed insertions return null without logging
- No way to know if a schedule was actually created
- Data consistency issues accumulate

See [H2] for detailed mitigation.

---

#### **[M4] PlanFeatures.getFeatureById() NULL RETURNS ALLOW BYPASS**
**Severity:** MEDIUM  
**Confidence:** CRITICAL  

See [C2] for detailed finding and fix.

---

#### **[M5] PAYMENT VERIFICATION LOGIC GAPS ON EDGE CASES**
**Severity:** MEDIUM  
**Confidence:** HIGH  
**Affected Component:** Backend / Payment Verification  
**File:** `supabase/functions/verify-razorpay-payment/index.ts` (lines 85-95)

The upsert for `pending_payments` uses:
```typescript
{ onConflict: 'payment_id', ignoreDuplicates: true }
```

**Issue:** If a payment_id is reused (unlikely but possible in edge cases), the upsert silently ignores it. If an attacker somehow obtains a valid payment_id, they could:
1. Submit it twice
2. On second submission, the upsert returns silently
3. Subscription might be created twice (race condition)

**Mitigation:** Log all upsert operations and monitor for duplicates.

---

#### **[M6] SUPPLEMENT SCHEDULE RLS POLICIES MISSING**
**Severity:** MEDIUM  
**Confidence:** CRITICAL  
**Affected Component:** Backend / Authorization  

The `supplement_schedules` table created in migration 20260514070000 has **NO RLS policies defined**.

```sql
CREATE TABLE IF NOT EXISTS public.supplement_schedules (...)
-- ❌ No ALTER TABLE... ENABLE ROW LEVEL SECURITY;
-- ❌ No CREATE POLICY statements
```

This means **any authenticated user can read/write all supplement schedules across all farms**.

**Recommended Fix:**

```sql
ALTER TABLE public.supplement_schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "supplement_schedules_farm_access"
  ON public.supplement_schedules FOR SELECT
  USING (
    farm_id IN (SELECT id FROM public.farms WHERE user_id = auth.uid())
    OR farm_id IN (
      SELECT farm_id FROM public.farm_members 
      WHERE email = auth.email()
    )
  );

-- Similar INSERT/UPDATE/DELETE policies
```

---

#### **[M7] NO RATE LIMITING ON PAYMENT/FEED APIS**
**Severity:** MEDIUM  
**Confidence:** MEDIUM  
**Affected Component:** Backend / DoS Prevention  

**Risk:**
- Attacker can spam payment verification calls
- Feed engine calculations can be abused for resource exhaustion
- No protection against credential stuffing on Razorpay webhook

**Mitigation:**
- Add rate limiting to edge functions (10 req/min per user for payments)
- Throttle feed engine calls (1 per 60s per pond)
- Monitor for unusual patterns

---

#### **[M8] SENSITIVE FARM DATA RETURNED WITHOUT PAGINATION LIMITS**
**Severity:** MEDIUM  
**Confidence:** MEDIUM  
**Affected Component:** Backend / Data Exposure  
**File:** `lib/features/farm/farm_provider.dart`

The app likely fetches:
```dart
.select('*, ponds(*)')
```

**Issue:** 
- A farm with 10,000 ponds returns all 10,000 in one query
- Network bandwidth exhaustion
- Potential information leakage of pond count

**Mitigation:**
```dart
.limit(100)  // Paginate
.order('created_at', ascending: false)
```

---

## 3. ATTACK CHAINS (Multi-Step Exploits)

### Attack Chain 1: Complete Paywall Bypass + Data Theft
**Difficulty:** LOW  
**Time to Execute:** 5 minutes

```
1. Obtain AquaRythu debug APK (via internal testing leak or Play Store debug variant)
2. Install on Android device
3. Open app → Profile → Settings → "DEBUG MENU"
4. Tap "Set as PRO (Debug)" → Unlock all PRO features
5. Create unlimited farms & ponds
6. Access smart feed intelligence (PRO feature)
7. Export crop reports (PRO feature)
8. View competitor metrics via cross-farm comparison (if accessible)
9. Never paid a single rupee
```

### Attack Chain 2: Cross-Farm Data Access via IDOR
**Difficulty:** MEDIUM  
**Time to Execute:** 30 minutes

```
1. Create legitimate farm account + authenticate
2. Enumerate pond IDs (sequential UUIDs are sometimes predictable)
3. Use GraphQL or REST APIs to query another farmer's ponds
4. RLS policies fail silently (catch blocks swallow 403 errors)
5. If RLS is misconfigured, retrieve another farm's:
   - Feed logs
   - Tray data
   - Growth metrics
   - Profitability reports
6. Gain competitive intelligence on farming practices
```

### Attack Chain 3: Supervisor Privilege Escalation
**Difficulty:** MEDIUM  
**Time to Execute:** 1 hour

```
1. Attacker is added as a "supervisor" to a farm
2. Supervisor RLS policies are NOT implemented (see [C3])
3. Attacker cannot see farm_members or other team
4. But: If RLS policies are weak elsewhere, attacker might access:
   - Inventory data (to see what competitors are buying)
   - Expense records (to see cost structure)
   - Harvest reports (to infer profitability)
5. Create fake crop reports that inflate profitability
6. Influence farm investment decisions
```

### Attack Chain 4: Subscription Verification Bypass + Feed Manipulation
**Difficulty:** MEDIUM  
**Time to Execute:** 2 hours

```
1. Attacker authenticates as FREE user
2. Uses Supabase JWT to directly call feed APIs (bypassing Flutter app)
3. No server-side subscription check (see [C4])
4. Attacker submits malicious feed_log entries:
   - Feed amount of 0 kg (to see if system accepts it)
   - Negative feed amounts (inventory attack)
   - Extremely high density values (to break calculations)
5. Smart feed engine processes corrupted data
6. Reports generated based on poisoned data
7. Farm's decision-making compromised
```

---

## 4. BUSINESS LOGIC VULNERABILITIES

### Feed Engine Manipulation

**Issue:** The `MasterFeedEngine` relies on client-side `SubscriptionGate.isPro` to decide whether to apply smart corrections:

```dart
if (SubscriptionGate.isPro) {
  result = SmartFeedEngineV2.applyCorrections(result);
}
```

**Attack:** Even after the debug override is fixed, if an attacker can set a feed's `tray_leftover` value to an extreme number (e.g., -999), the engine might:
- Calculate negative adjustments
- Return negative feed recommendations
- Corrupt the pond's ABW calculations

**Recommendation:** Add input validation in `MasterFeedEngine.compute()`:

```dart
const double kMaxTrayLeftover = 99.0;
const double kMinTrayLeftover = 0.0;

if (trayLeftover < kMinTrayLeftover || trayLeftover > kMaxTrayLeftover) {
  trayLeftover = 0;  // Clamp to safe range
  AppLogger.warn('Tray leftover out of range: $trayLeftover');
}
```

### Sampling & ABW Manipulation

**Issue:** Workers can submit arbitrary ABW values, which feed into growth intelligence calculations. No validation on ABW change delta.

**Attack:** Submit ABW of 1g (from 2g previous day) to trigger emergency feed reductions, then submit 50g next day to trigger expensive correction logic, draining resources.

**Mitigation:** Validate ABW change vs. biologically possible growth rates:
```dart
const double maxDailyGrowthRate = 0.15;  // 15% max growth/day
final previousAbw = 2.0;
final submittedAbw = 1.0;
final growthRate = (submittedAbw - previousAbw) / previousAbw;

if (growthRate < -0.15 || growthRate > 0.15) {
  throw ValidationError('ABW change $growthRate exceeds biological limits');
}
```

---

## 5. INFRASTRUCTURE & DEPLOYMENT RISKS

### AppConfig Key Validation

**Current:**
```dart
static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

static void validate() {
  assert(supabaseUrl.isNotEmpty, 'SUPABASE_URL is not set...');
}
```

**Risk:** If build args are passed as empty strings, the assert passes (empty string != empty). Then runtime calls fail cryptically.

**Fix:**
```dart
static void validate() {
  assert(supabaseUrl.isNotEmpty && supabaseUrl.startsWith('https://'),
      'SUPABASE_URL is invalid');
}
```

### Razorpay Key Exposure

The `razorpayKeyId` is stored in Flutter app binary (compiled as const):
```dart
static const razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID');
```

**Risk:** Decompiling the APK leaks the Razorpay public key (acceptable risk since it's meant to be public, but combined with other issues, could aid attacks).

---

## 6. DEPENDENCY & THIRD-PARTY RISKS

### Vulnerable Dependencies

Check for outdated packages:
- `supabase_flutter`: Verify latest version has no RLS bugs
- `razorpay_flutter`: Ensure signature validation is cryptographically sound
- `flutter_riverpod`: No known security issues, but verify state serialization
- All packages should be pinned to specific versions, not `any`

**Recommendation:** Run `flutter pub audit` regularly.

---

## 7. SECURE DESIGN RECOMMENDATIONS

### Architecture: Subscription Enforcement

**Current (Vulnerable):**
```
Client → [SubscriptionGate.isPro check] → Proceed/Block
```

**Recommended (Secure):**
```
Client → Edge Function → [Backend subscription verification] → Supabase RLS → Data
         ↓ (if denied)
    Respond 403 + Upgrade Dialog
```

### Implementation Steps:

1. **Create RLS function:**
   ```sql
   CREATE OR REPLACE FUNCTION user_subscription_plan(user_id UUID) RETURNS TEXT AS $$
   SELECT plan FROM subscriptions
   WHERE user_id = $1 AND status = 'active' AND expires_at > NOW()
   LIMIT 1;
   $$ LANGUAGE SQL;
   ```

2. **Add plan_type to farms:**
   ```sql
   ALTER TABLE farms ADD COLUMN plan_type TEXT GENERATED ALWAYS AS 
   (user_subscription_plan(user_id)) STORED;
   ```

3. **RLS policies check subscription:**
   ```sql
   CREATE POLICY "smart_feed_pro_only"
     ON feed_logs FOR UPDATE
     USING (
       (SELECT plan_type FROM farms WHERE id = 
         (SELECT farm_id FROM ponds WHERE id = pond_id)) = 'pro'
     );
   ```

4. **Edge function guards PRO endpoints:**
   ```typescript
   const { plan_type } = await checkUserPlan(user.id);
   if (plan_type !== 'pro') {
     throw new Error('PRO subscription required', 403);
   }
   ```

### Multi-Tenant Isolation Hardening

1. **Every RLS policy must account for farm_members**
2. **Create helper RLS function:**
   ```sql
   CREATE OR REPLACE FUNCTION can_access_farm(farm_id UUID) RETURNS BOOLEAN AS $$
   SELECT EXISTS (
     SELECT 1 FROM farms WHERE id = farm_id AND user_id = auth.uid()
     UNION
     SELECT 1 FROM farm_members 
     WHERE farm_id = farm_id AND email = auth.email() AND status = 'active'
   );
   $$ LANGUAGE SQL SECURITY DEFINER;
   ```

3. **All table RLS policies use this helper:**
   ```sql
   CREATE POLICY "ponds_accessible"
     ON ponds FOR SELECT
     USING (can_access_farm(farm_id));
   ```

### Logging & Monitoring

1. **Enable PostgreSQL logs for RLS denials:**
   ```sql
   ALTER SYSTEM SET log_statement = 'all';
   -- Monitor for 403 Forbidden patterns
   ```

2. **Alert on suspicious patterns:**
   - Multiple RLS denials from same user in short time
   - Enumeration attempts (sequential ID scanning)
   - Cross-farm access attempts

3. **Audit trail for sensitive operations:**
   ```sql
   CREATE TABLE audit_logs (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     user_id UUID,
     action TEXT,
     table_name TEXT,
     record_id UUID,
     timestamp TIMESTAMPTZ DEFAULT NOW()
   );
   ```

### Defense in Depth Checklist

- ✅ **Client-side validation:** Nice to have, not a security boundary
- ❌ **Server-side RLS:** CRITICAL - must be enforced
- ❌ **API authentication:** Every edge function must verify JWT
- ❌ **Subscription verification:** Every PRO operation must check backend
- ❌ **Input validation:** Clamp ABW, density, feed amounts to safe ranges
- ❌ **Error handling:** Never silently fail on authorization errors
- ❌ **Audit logging:** Track sensitive data access
- ❌ **Rate limiting:** Prevent brute force & DoS
- ❌ **HTTPS only:** Enforce in production
- ❌ **Secrets rotation:** Razorpay keys, JWT signing keys

---

## 8. SCORING SUMMARY

| Category | Score | Status |
|----------|-------|--------|
| Authentication & Sessions | 7/10 | ⚠️ Weak |
| Authorization & Access Control | 3/10 | 🔴 CRITICAL |
| Input Validation | 4/10 | 🔴 CRITICAL |
| API Security | 4/10 | 🔴 CRITICAL |
| Business Logic | 5/10 | 🔴 HIGH |
| Data Protection | 6/10 | 🟡 MEDIUM |
| Infrastructure | 7/10 | ⚠️ MEDIUM |
| Dependency Security | 7/10 | ⚠️ MEDIUM |
| **Overall** | **5/10** | **🔴 CRITICAL** |

---

## 9. REMEDIATION PRIORITY

### Immediate (Before Shipping to Farmers - Week 1)

1. ✅ **Remove debug subscription override** from all production code paths
   - Estimated effort: 4 hours
   - Impact: Blocks #1 critical vulnerability

2. ✅ **Implement server-side subscription verification** on all PRO endpoints
   - Estimated effort: 16 hours
   - Impact: Blocks #4 critical vulnerability

3. ✅ **Fix RLS policies for farm_members roles** (supervisor/worker access)
   - Estimated effort: 8 hours
   - Impact: Blocks #3 critical vulnerability

4. ✅ **Change feature gating to fail-closed**
   - Estimated effort: 2 hours
   - Impact: Blocks #2 critical vulnerability

5. ✅ **Enable proper error logging** (replace silent catches)
   - Estimated effort: 8 hours
   - Impact: Enables detection of remaining issues

### Short-term (Month 1)

6. ✅ Implement RLS policies for all tables (supplement_schedules, etc.)
7. ✅ Add rate limiting to payment & feed APIs
8. ✅ Implement audit logging for sensitive operations
9. ✅ Add input validation to feed engine (clamp ABW, density, etc.)
10. ✅ Paginate all list endpoints

### Medium-term (Month 2-3)

11. ✅ Implement subscription plan column in farms table
12. ✅ Move all feature checks to backend
13. ✅ Set up monitoring alerts for RLS denials & enumeration attempts
14. ✅ Security test marketplace integrations before launch
15. ✅ Load test with adversarial input patterns

---

## 10. TESTING RECOMMENDATIONS

### Security Test Cases

1. **Debug Override Bypass:**
   ```dart
   // Should be impossible in release builds
   test('subscription override not available in release mode', () {
     expect(kReleaseMode, true);
     expect(SubscriptionGate.setDebugOverride(true), null);  // No-op
     expect(SubscriptionGate.isPro, false);  // Unchanged
   });
   ```

2. **IDOR via pond access:**
   ```dart
   // Create User A's pond, then try to access with User B's auth
   test('user B cannot access user A pond', () async {
     final pondA = await createPond(userA);
     final response = await supabaseB.from('ponds').select().eq('id', pondA.id);
     expect(response, isEmpty);  // RLS should deny
   });
   ```

3. **Farm member role enforcement:**
   ```dart
   // Invite supervisor, check they can access ponds
   test('supervisor can read farm ponds after invitation', () async {
     await inviteSupervisor('supervisor@test.com');
     final response = await supabase(supervisorAuth).from('ponds').select()
       .eq('farm_id', farmId);
     expect(response.length, greaterThan(0));
   });
   ```

4. **Subscription verification on PRO operations:**
   ```dart
   // Try to call smart feed with FREE account
   test('free user cannot trigger smart feed engine', () async {
     final result = await supabase.functions.invoke('apply-smart-feed', 
       body: { 'pond_id': pondId });
     expect(result.error, contains('PRO subscription required'));
   });
   ```

### Penetration Test Scenarios

1. **APK Decompilation & Debug Feature Activation**
2. **Cross-Farm IDOR Enumeration**
3. **Razorpay Signature Forgery**
4. **SQLi via pond/farm names** (should be parameterized)
5. **RLS Policy Bypass via subquery injection**
6. **Feed Data Poisoning** (negative amounts, extreme values)
7. **Concurrent Payment Verification** (race conditions)

---

## 11. COMPLIANCE & REGULATORY NOTES

### Data Privacy (GDPR/India Privacy Act)

- ⚠️ Payment data partially exposed in payment_debug_screen
- ⚠️ No explicit data retention policy for feed logs
- ⚠️ Cross-farm data access could violate farmer confidentiality

### Financial/Anti-Fraud

- ⚠️ No dispute handling for failed payments
- ⚠️ No chargeback protection mechanisms
- ⚠️ Razorpay webhook validation is correct, but no backup verification

---

## 12. CONCLUSION

AquaRythu has **significant security gaps** that make it **unsuitable for production use** with real farmers' financial data without immediate remediation.

**Primary Risks:**
1. Complete subscription paywall bypass (debug override + fail-open gating)
2. No server-side authorization enforcement
3. Multi-tenant isolation incomplete (farm_members roles not enforced)

**Overall Assessment:** 🔴 **CRITICAL RISK**  
**Can Deploy To Farmers:** ❌ NO (not without fixing C1-C4)  
**Timeline to Safe Launch:** 2-3 weeks (if team prioritizes properly)

**Recommended Actions:**
1. Immediately pull any debug APKs from distribution
2. Implement all C1-C4 fixes before next release
3. Conduct comprehensive RLS policy audit
4. Add automated security tests to CI/CD
5. Set up production monitoring for suspicious access patterns

---

## Appendix A: Vulnerable Code Snippets & Safe Alternatives

### Pattern 1: Silent Error Handling (VULNERABLE)

```dart
// ❌ BAD
try {
  await supabase.from('schedules').insert(data);
} catch (_) {
  return null;
}

// ✅ GOOD
try {
  return await supabase.from('schedules').insert(data).select().single();
} catch (e) {
  if (e is PostgrestException) {
    if (e.code == 'PGRST301') {  // Authorization error
      throw AccessDeniedException('User lacks permission');
    }
  }
  throw RepositoryException('Insert failed: ${e.toString()}');
}
```

### Pattern 2: Client-Side Subscription Check (VULNERABLE)

```dart
// ❌ BAD - All logic is client-side
if (SubscriptionGate.isPro) {
  return SmartFeedEngineV2.applyCorrections(input);
}

// ✅ GOOD - Backend enforces subscription
const response = await supabase.functions.invoke('apply-smart-feed-corrections', 
  body: { 'feed_input': input }
);
// Edge function verifies subscription before processing
```

### Pattern 3: Fail-Open Feature Gating (VULNERABLE)

```dart
// ❌ BAD
if (feature == null) return true;  // Unknown = allowed

// ✅ GOOD
if (feature == null) return false;  // Unknown = denied (fail-closed)
```

### Pattern 4: Missing Role-Based RLS (VULNERABLE)

```sql
-- ❌ BAD - Only checks owner
CREATE POLICY "pond_access"
  ON ponds FOR SELECT
  USING (farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid()));

-- ✅ GOOD - Includes team members
CREATE POLICY "pond_access"
  ON ponds FOR SELECT
  USING (
    farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
    OR farm_id IN (
      SELECT farm_id FROM farm_members 
      WHERE email = auth.email() AND status = 'active'
    )
  );
```

---

**Report Completed:** May 15, 2026  
**Auditor:** Senior Security Engineer (Red Team)  
**Classification:** CONFIDENTIAL - Internal Use Only
