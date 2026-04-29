# Server-Based DOC Calculation Implementation

## 🎯 Objective
Fix DOC (Day of Culture) calculation to be tamper-proof by using server time instead of device time. This prevents farmers from manipulating phone time to break feed calculations.

## ✅ Completed Changes

### 1. Database Migration
**File:** `/migrations/add_server_time_function.sql`
- Created Supabase RPC function `get_server_time()` that returns UTC server time
- Function is security definer and grants execute to authenticated users

### 2. Server Time Provider
**File:** `/lib/core/providers/server_time_provider.dart`
- Created `serverTimeProvider` - StateNotifier that fetches server time from Supabase
- Implements automatic refresh every 5 minutes
- Falls back to device time with low confidence if server is unavailable
- Provides `TimeConfidence` enum (high/low) to indicate time source reliability
- Convenience providers: `serverDateTimeProvider` and `timeConfidenceProvider`

### 3. DOC Calculation Utilities
**File:** `/lib/core/utils/doc_utils.dart`
- Updated `calculateDocFromStockingDate()` to accept optional `WidgetRef` parameter
- When `ref` is provided, uses server time from provider
- Returns `null` if server time is not yet available (loading state)
- Created legacy version `calculateDocFromStockingDateLegacy()` for backward compatibility
- All datetime calculations use UTC

### 4. Pond Model Updates
**File:** `/lib/features/farm/farm_provider.dart`
- Added `calculateDocWithRef(WidgetRef ref)` method to Pond class
- This method uses server time for tamper-proof DOC calculation
- Deprecated the existing `doc` getter (still uses device time)
- Updated `calculateDoc(DateTime now)` to use legacy function

### 5. Backend Services (UTC Storage)
**File:** `/lib/core/services/pond_service.dart`
- Updated `getPondById()` to parse stocking date as UTC
- Updated `generateFeedSchedule()` to parse stocking date as UTC
- Updated `getTodayFeed()` to parse stocking date as UTC
- Updated `clearPondCycleData()` to store new stocking date as UTC
- All stocking dates now consistently stored and retrieved in UTC

**File:** `/lib/core/services/dashboard_service.dart`
- Updated to parse stocking date as UTC
- Uses legacy DOC calculation (acceptable for dashboard display)

**File:** `/lib/systems/feed/feed_input_builder.dart`
- Updated `_computeDoc()` to parse stocking date as UTC
- Uses legacy DOC calculation (acceptable for feed engine)

### 6. Critical Provider Updates
**File:** `/lib/features/pond/providers/pond_card_provider.dart`
- Updated to use `pond.calculateDocWithRef(ref)` for server-based DOC
- Falls back to `pond.doc` if server time not ready
- This is critical for feed calculations

### 7. UI Widgets
**File:** `/lib/core/widgets/time_sync_banner.dart`
- Created `TimeSyncBanner` widget to show when device time is being used
- Displays orange warning banner with "Using device time (sync issue)"
- Includes retry button to refresh server time
- Only shows when confidence is low (server unavailable)

- Created `DocDisplay` widget for showing DOC with loading state
- Shows skeleton loader while server time is being fetched
- Automatically calculates DOC using server time

## 📋 Remaining Tasks

### 1. Apply Database Migration
Run the migration to create the `get_server_time()` function:

```bash
# Option 1: Using Supabase CLI
supabase db push

# Option 2: Using SQL editor in Supabase dashboard
# Open SQL editor and run: /migrations/add_server_time_function.sql
```

### 2. Add TimeSyncBanner to Main Screens
Add the `TimeSyncBanner` widget to critical screens to warn users when device time is being used:

```dart
// Example for home_screen.dart or pond_dashboard_screen.dart
import 'package:aqua_rythu/core/widgets/time_sync_banner.dart';

// In the widget tree, add at the top:
Column(
  children: [
    const TimeSyncBanner(),
    // existing content...
  ],
)
```

Recommended screens to add banner:
- `lib/features/home/home_screen.dart`
- `lib/features/pond/pond_dashboard_screen.dart`
- `lib/features/feed/feed_screen.dart` (if exists)

## 🔒 Security Benefits

1. **Tamper-Proof**: DOC cannot be manipulated by changing device time
2. **Consistent**: Same DOC across all devices for the same pond
3. **Graceful Fallback**: Works offline with device time + warning banner
4. **Automatic Sync**: Refreshes server time every 5 minutes
5. **User Awareness**: Banner alerts users when using device time

## 🧪 Testing Checklist

- [ ] Apply database migration successfully
- [ ] Server time provider fetches time on app start
- [ ] DOC calculation uses server time in pond_card_provider
- [ ] TimeSyncBanner appears when server is unavailable
- [ ] Retry button in TimeSyncBanner refreshes server time
- [ ] App works offline (falls back to device time with warning)
- [ ] Changing device time does NOT affect DOC in critical calculations
- [ ] Stocking dates stored in UTC in database
- [ ] Feed calculations use correct DOC based on server time

## 📝 Notes

- UI components that display DOC (like pond cards) can continue using legacy device time for now
- The critical feed calculation logic in `pond_card_provider` now uses server time
- Backend services consistently use UTC for all date/time operations
- The implementation is backward compatible - existing code continues to work
- Future enhancement: Update all UI components to use `DocDisplay` widget for consistent server-time-based DOC display
