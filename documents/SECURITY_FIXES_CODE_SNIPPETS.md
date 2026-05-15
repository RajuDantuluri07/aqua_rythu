# AquaRythu Security Fixes - Code Snippets

Ready-to-use code fixes for the 4 critical vulnerabilities.

---

## Fix 1: Remove Debug Subscription Override (4 hours)

### Step 1.1: Remove from main.dart

**File:** `lib/main.dart`

**BEFORE:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ... Supabase init ...
  
  // Hydrate debug subscription override (for QA testing in debug builds)
  try {
    await SubscriptionGate.hydrateDebugOverride();  // ❌ REMOVE THIS
  } catch (e) {
    debugPrint('SubscriptionGate debug override hydration failed: $e');
  }
  
  runApp(const ProviderScope(child: MyApp()));
}
```

**AFTER:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ... Supabase init ...
  
  // Debug override now disabled - subscription verified server-side
  
  runApp(const ProviderScope(child: MyApp()));
}
```

### Step 1.2: Disable setDebugOverride in subscription_gate.dart

**File:** `lib/core/services/subscription_gate.dart`

**BEFORE:**
```dart
static void setDebugOverride(bool? value) {
  if (kReleaseMode) return;
  _debugOverride = value;
}
```

**AFTER:**
```dart
static void setDebugOverride(bool? value) {
  // DEBUG OVERRIDE DISABLED - Subscription enforced server-side
  return;
}
```

### Step 1.3: Remove Debug Menu from profile_screen.dart

**File:** `lib/features/profile/profile_screen.dart`

**BEFORE:**
```dart
void _showDebugMenu() {
  if (kReleaseMode) return;
  
  showModalBottomSheet(
    context: context,
    builder: (sheetContext) => Container(
      child: Column(
        children: [
          const Text('🔧 DEBUG MENU'),
          // ... "Set as PRO", "Set as FREE", etc. ...
```

**AFTER:**
```dart
void _showDebugMenu() {
  // Debug menu completely disabled - no subscription override allowed
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Debug Feature Disabled'),
      content: const Text('Subscription override is no longer available. '
          'Contact support if you need to test PRO features.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

---

## Fix 2: Fail-Closed Feature Gating (2 hours)

### Step 2.1: Update AccessControlHooks

**File:** `lib/features/upgrade/access_control_hooks.dart`

**BEFORE:**
```dart
static bool canAccessFeature(WidgetRef ref, String featureId) {
  final subscriptionState = ref.read(subscriptionProvider);
  final feature = PlanFeatures.getFeatureById(featureId);

  if (feature == null) return true;  // ❌ FAIL-OPEN: Unknown = allowed

  if (!feature.isProFeature) return true;

  return subscriptionState.isPro;
}
```

**AFTER:**
```dart
static bool canAccessFeature(WidgetRef ref, String featureId) {
  final subscriptionState = ref.read(subscriptionProvider);
  final feature = PlanFeatures.getFeatureById(featureId);

  if (feature == null) {
    // FAIL-CLOSED: Unknown features are DENIED
    debugPrint('[AccessControl] Unknown feature requested: $featureId');
    return false;  // ✅ SAFE: Unknown = blocked
  }

  if (!feature.isProFeature) return true;

  return subscriptionState.isPro;
}
```

### Step 2.2: Add Tests

**File:** `test/features/upgrade/access_control_hooks_test.dart`

```dart
void main() {
  group('AccessControlHooks', () {
    test('Unknown features are denied (fail-closed)', () {
      final ref = ProviderContainer();
      final canAccess = AccessControlHooks.canAccessFeature(
        ref,
        'unknown_feature_12345',
      );
      expect(canAccess, false);  // ✅ Must be false
    });

    test('Free features are allowed for all users', () {
      final ref = ProviderContainer();
      final canAccess = AccessControlHooks.canAccessFeature(
        ref,
        'feed_schedule_basic',  // FREE feature
      );
      expect(canAccess, true);
    });

    test('PRO features denied for FREE users', () {
      final ref = ProviderContainer();
      ref.read(subscriptionProvider.notifier).state = 
        const SubscriptionState(currentPlan: PlanType.FREE);
      
      final canAccess = AccessControlHooks.canAccessFeature(
        ref,
        'smart_feed_engine',  // PRO feature
      );
      expect(canAccess, false);
    });
  });
}
```

---

## Fix 3: Farm Member RLS Policies (8 hours)

### Step 3.1: Create RLS Helper Function

**File:** `supabase/migrations/20260520000000_add_team_access_functions.sql`

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Helper function: Check if user can access a farm via ownership or team
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION can_access_farm(farm_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- User is the farm owner
  IF EXISTS (
    SELECT 1 FROM public.farms
    WHERE id = farm_id AND user_id = auth.uid()
  ) THEN
    RETURN TRUE;
  END IF;

  -- User is an active farm member
  IF EXISTS (
    SELECT 1 FROM public.farm_members
    WHERE farm_id = farm_id 
      AND email = auth.email()
      AND status = 'active'
  ) THEN
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════════════════
-- Helper function: Check if user can manage a farm (owner or partner only)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION can_manage_farm(farm_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- Only owner can manage
  IF EXISTS (
    SELECT 1 FROM public.farms
    WHERE id = farm_id AND user_id = auth.uid()
  ) THEN
    RETURN TRUE;
  END IF;

  -- Partner can manage
  IF EXISTS (
    SELECT 1 FROM public.farm_members
    WHERE farm_id = farm_id 
      AND email = auth.email()
      AND role = 'partner'
      AND status = 'active'
  ) THEN
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### Step 3.2: Update farm_members RLS

**File:** `supabase/migrations/20260520000000_update_farm_members_rls.sql`

```sql
-- Drop old policies
DROP POLICY IF EXISTS "farm_members_select" ON public.farm_members;
DROP POLICY IF EXISTS "farm_members_insert" ON public.farm_members;
DROP POLICY IF EXISTS "farm_members_delete" ON public.farm_members;

-- ✅ NEW: Team members can see each other
CREATE POLICY "farm_members_select"
  ON public.farm_members FOR SELECT
  USING (can_access_farm(farm_id));

-- ✅ NEW: Only owner/partner can add members
CREATE POLICY "farm_members_insert"
  ON public.farm_members FOR INSERT
  WITH CHECK (can_manage_farm(farm_id));

-- ✅ NEW: Only owner/partner can remove members
CREATE POLICY "farm_members_delete"
  ON public.farm_members FOR DELETE
  USING (can_manage_farm(farm_id));
```

### Step 3.3: Update ponds RLS

**File:** `supabase/migrations/20260520000000_update_ponds_rls.sql`

```sql
-- Drop old policy
DROP POLICY IF EXISTS "ponds_select" ON public.ponds;

-- ✅ NEW: Team can read ponds
CREATE POLICY "ponds_select"
  ON public.ponds FOR SELECT
  USING (can_access_farm(farm_id));

-- ✅ Keep owner-only writes (optional: allow partner writes too)
DROP POLICY IF EXISTS "ponds_insert" ON public.ponds;
CREATE POLICY "ponds_insert"
  ON public.ponds FOR INSERT
  WITH CHECK (can_manage_farm(farm_id));
```

### Step 3.4: Update feed_logs RLS

**File:** `supabase/migrations/20260520000000_update_feed_logs_rls.sql`

```sql
DROP POLICY IF EXISTS "feed_logs_select" ON public.feed_logs;
DROP POLICY IF EXISTS "feed_logs_insert" ON public.feed_logs;

-- ✅ Team can read feed logs
CREATE POLICY "feed_logs_select"
  ON public.feed_logs FOR SELECT
  USING (
    pond_id IN (
      SELECT id FROM public.ponds
      WHERE farm_id IN (
        SELECT id FROM public.farms WHERE user_id = auth.uid()
        UNION
        SELECT farm_id FROM public.farm_members
        WHERE email = auth.email() AND status = 'active'
      )
    )
  );

-- Workers can insert/update feed logs
CREATE POLICY "feed_logs_insert"
  ON public.feed_logs FOR INSERT
  WITH CHECK (
    pond_id IN (
      SELECT id FROM public.ponds
      WHERE farm_id IN (
        SELECT id FROM public.farms WHERE user_id = auth.uid()
        UNION
        SELECT farm_id FROM public.farm_members
        WHERE email = auth.email() AND status = 'active'
      )
    )
  );
```

### Step 3.5: Update inventory_items RLS

**File:** `supabase/migrations/20260520000000_update_inventory_rls.sql`

```sql
DROP POLICY IF EXISTS "inventory_items_select" ON public.inventory_items;
DROP POLICY IF EXISTS "inventory_items_insert" ON public.inventory_items;

CREATE POLICY "inventory_items_select"
  ON public.inventory_items FOR SELECT
  USING (can_access_farm(farm_id));

CREATE POLICY "inventory_items_insert"
  ON public.inventory_items FOR INSERT
  WITH CHECK (can_access_farm(farm_id));
```

---

## Fix 4: Server-Side Subscription Verification (16 hours)

### Step 4.1: Create Edge Function for Subscription Check

**File:** `supabase/functions/check-user-subscription/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

serve(async (req: Request) => {
  // Verify JWT token from request
  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response('Unauthorized', { status: 401 })
  }

  const token = authHeader.slice('Bearer '.length)
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  // Get user from token
  const { data: { user }, error: authError } = await supabase.auth.getUser(token)
  if (authError || !user) {
    return new Response('Invalid token', { status: 401 })
  }

  // Check subscription status
  const { data: subscription, error: subError } = await supabase
    .from('subscriptions')
    .select('plan, expires_at, status')
    .eq('user_id', user.id)
    .eq('status', 'active')
    .gte('expires_at', new Date().toISOString())
    .order('expires_at', { ascending: false })
    .limit(1)
    .single()

  if (subError || !subscription) {
    return new Response(JSON.stringify({
      plan: 'free',
      isPro: false,
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({
    plan: subscription.plan,
    isPro: subscription.plan === 'pro',
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})
```

### Step 4.2: Create Protected Endpoint Example

**File:** `supabase/functions/apply-smart-feed/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })

serve(async (req: Request) => {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return json({ error: 'Unauthorized' }, 401)
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  const { data: { user }, error: authError } = await supabase.auth.getUser(
    authHeader.slice('Bearer '.length)
  )
  if (authError || !user) {
    return json({ error: 'Invalid token' }, 401)
  }

  // ✅ CRITICAL: CHECK SUBSCRIPTION BEFORE PROCEEDING
  const { data: subscription, error: subError } = await supabase
    .from('subscriptions')
    .select('plan')
    .eq('user_id', user.id)
    .eq('status', 'active')
    .gte('expires_at', new Date().toISOString())
    .single()

  if (subError || !subscription || subscription.plan !== 'pro') {
    return json(
      { error: 'PRO subscription required for smart feed engine' },
      403
    )
  }

  // Parse request body
  let body
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Invalid JSON' }, 400)
  }

  const { pond_id, feed_input } = body
  if (!pond_id || !feed_input) {
    return json({ error: 'Missing pond_id or feed_input' }, 400)
  }

  // ✅ Verify user owns this pond
  const { data: farm, error: farmError } = await supabase
    .from('ponds')
    .select('farm_id')
    .eq('id', pond_id)
    .single()

  if (farmError || !farm) {
    return json({ error: 'Pond not found' }, 404)
  }

  const { data: farmOwner, error: ownerError } = await supabase
    .from('farms')
    .select('user_id')
    .eq('id', farm.farm_id)
    .single()

  if (ownerError) {
    return json({ error: 'Farm access denied' }, 403)
  }

  // Check ownership or team membership
  if (farmOwner.user_id !== user.id) {
    const { data: memberCheck } = await supabase
      .from('farm_members')
      .select('role')
      .eq('farm_id', farm.farm_id)
      .eq('email', user.email)
      .single()

    if (!memberCheck) {
      return json({ error: 'You do not have access to this farm' }, 403)
    }
  }

  // ✅ NOW we can safely apply smart feed corrections
  try {
    const corrections = applySmartFeedCorrections(feed_input)
    return json({ corrections }, 200)
  } catch (err) {
    return json({ error: `Smart feed failed: ${err.message}` }, 500)
  }
})

function applySmartFeedCorrections(feedInput: unknown): unknown {
  // Implementation of smart feed logic here
  return { ...feedInput, corrected: true }
}
```

### Step 4.3: Update Dart Client to Call Backend

**File:** `lib/core/services/smart_feed_service.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SmartFeedService {
  final _supabase = Supabase.instance.client;

  /// Apply smart feed corrections via backend (subscription verified on server)
  Future<Map<String, dynamic>> applySmartFeedCorrections({
    required String pondId,
    required Map<String, dynamic> feedInput,
  }) async {
    // Get the user's JWT token
    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('User not authenticated');

    try {
      // ✅ Call edge function (server verifies subscription)
      final response = await _supabase.functions.invoke(
        'apply-smart-feed',
        body: {
          'pond_id': pondId,
          'feed_input': feedInput,
        },
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      return response.data as Map<String, dynamic>;
    } on Exception catch (e) {
      if (e.toString().contains('403')) {
        throw Exception('PRO subscription required for smart feed engine');
      }
      rethrow;
    }
  }
}
```

### Step 4.4: Update MasterFeedEngine to Use Backend

**File:** `lib/systems/feed/master_feed_engine.dart`

```dart
import 'package:aqua_rythu/core/services/smart_feed_service.dart';

class MasterFeedEngine {
  static final SmartFeedService _smartFeedService = SmartFeedService();

  /// Orchestrate full feed pipeline with server-side subscription checks
  static Future<OrchestratorResult> orchestrateForPond({
    required String pondId,
    required FeedInput input,
  }) async {
    // Step 1: Calculate base feed (always allowed)
    final baseFeed = compute(
      doc: input.doc,
      stockingType: input.stockingType,
      density: input.density,
    );

    // Step 2: Try smart feed (if user has subscription)
    try {
      // ✅ Call backend - subscription checked server-side
      final smartResult = await _smartFeedService.applySmartFeedCorrections(
        pondId: pondId,
        feedInput: {
          'doc': input.doc,
          'base_feed': baseFeed,
          'density': input.density,
        },
      );

      return OrchestratorResult(
        recommendedFeed: smartResult['corrections']['adjusted_feed'] ?? baseFeed,
        stage: FeedStage.intelligent,
        confidence: 0.95,
      );
    } on Exception catch (e) {
      // If subscription check fails, fall back to basic feed
      if (e.toString().contains('PRO subscription required')) {
        return OrchestratorResult(
          recommendedFeed: baseFeed,
          stage: FeedStage.blind,
          message: 'Smart feed unavailable. Upgrade to PRO to unlock.',
        );
      }
      rethrow;
    }
  }
}
```

---

## Fix 5: Proper Error Handling (8 hours)

### Step 5.1: Replace Silent Catches

**File:** `lib/core/repositories/schedule_repository.dart`

**BEFORE:**
```dart
} catch (_) {
  return null;
}
```

**AFTER:**
```dart
} catch (e) {
  AppLogger.error(
    'ScheduleRepository.insertSchedule failed',
    e,
    stackTrace: StackTrace.current,
  );
  
  if (e is PostgrestException) {
    if (e.code == 'PGRST301') {
      throw AccessDeniedException('You lack permission for this operation');
    }
  }
  
  throw RepositoryException('Schedule operation failed: ${e.toString()}');
}
```

### Step 5.2: Create Exception Hierarchy

**File:** `lib/core/exceptions/repository_exceptions.dart`

```dart
abstract class RepositoryException implements Exception {
  final String message;
  const RepositoryException(this.message);
  
  @override
  String toString() => message;
}

class AccessDeniedException extends RepositoryException {
  const AccessDeniedException(String message) : super(message);
}

class AuthenticationException extends RepositoryException {
  const AuthenticationException(String message) : super(message);
}

class NotFoundExeption extends RepositoryException {
  const NotFoundExeption(String message) : super(message);
}

class ValidationException extends RepositoryException {
  const ValidationException(String message) : super(message);
}
```

---

## Summary: Implementation Checklist

```
[ ] Fix 1: Remove Debug Override
    [ ] Remove hydrateDebugOverride() call from main.dart
    [ ] Disable setDebugOverride() method
    [ ] Remove DEBUG MENU from profile_screen
    [ ] Test: Try to access debug menu (should not appear)

[ ] Fix 2: Fail-Closed Gating
    [ ] Change `if (feature == null) return false;`
    [ ] Add unit tests
    [ ] Test: Unknown features should be blocked

[ ] Fix 3: Farm Member RLS
    [ ] Create migration: add team access functions
    [ ] Update farm_members policies
    [ ] Update ponds policies
    [ ] Update feed_logs policies
    [ ] Update inventory_items policies
    [ ] Test: Supervisor can read farm ponds
    [ ] Test: Worker can log feed entries

[ ] Fix 4: Server-Side Subscription Check
    [ ] Create check-user-subscription edge function
    [ ] Create apply-smart-feed edge function (protected)
    [ ] Create SmartFeedService in Dart
    [ ] Update MasterFeedEngine to call backend
    [ ] Test: FREE user cannot call smart-feed endpoint

[ ] Fix 5: Proper Error Handling
    [ ] Create exception hierarchy
    [ ] Replace all silent catches
    [ ] Add logging to all error paths
    [ ] Test: RLS denials are logged

[ ] Testing & Deployment
    [ ] Run security tests
    [ ] Penetration test with real attacks
    [ ] Monitor logs for anomalies
    [ ] Beta launch with 100 users
    [ ] Full production launch
```

**Total Time: ~30 hours for experienced team**

---

*Generated from Security Audit Report by Senior Security Engineer*
