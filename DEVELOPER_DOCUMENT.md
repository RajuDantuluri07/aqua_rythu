# Aqua Rythu — Developer Document

**Version:** 1.0 (MVP)  
**Last Updated:** 2026-04-05  
**Flutter SDK:** >= 3.4.0 < 4.0.0  

---

## 1. Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x |
| State Management | Riverpod 2.6 (`flutter_riverpod`) |
| Backend / DB | Supabase (Postgres + Auth + RPC) |
| Local Storage | SharedPreferences (user profile, farm settings) |
| Routing | Named routes via `AppRoutes` |
| Formatting | `intl` package |

---

## 2. Project Structure

```
lib/
├── main.dart                    # App entry, Supabase init, AuthGate
├── routes/
│   └── app_routes.dart          # Named route registry
├── theme/
│   └── app_theme.dart           # MaterialTheme definition
├── models/
│   └── feed_model.dart          # Shared feed model
├── widgets/
│   └── app_bottom_bar.dart      # Global bottom navigation
├── shared/
│   └── constants/app_images.dart
│
├── core/                        # Domain-pure engine layer (no Flutter deps)
│   ├── engines/
│   │   ├── master_feed_engine.dart      # Orchestrates all 7 feed calc steps
│   │   ├── feed_calculation_engine.dart # Base feed from biomass
│   │   ├── adjustment_engine.dart       # Water/behaviour adjustments
│   │   ├── tray_engine.dart             # Tray leftover adjustments
│   │   ├── fcr_engine.dart              # FCR-based correction
│   │   ├── enforcement_engine.dart      # Yesterday's deviation correction
│   │   ├── feed_state_engine.dart       # Tray-adjustment logic + mode
│   │   ├── engine_constants.dart        # Survival/ABW/feed rate tables
│   │   └── models/
│   │       ├── feed_input.dart          # Input DTO to MasterFeedEngine
│   │       └── feed_output.dart         # Output DTO with alerts + reasons
│   ├── enums/
│   │   └── tray_status.dart             # full | partial | empty
│   ├── repositories/
│   │   └── feed_repository.dart
│   ├── utils/
│   │   ├── logger.dart                  # AppLogger (error/info)
│   │   └── feed_config.dart
│   └── validators/
│       └── feed_input_validator.dart    # Validates FeedInput + FeedOutput
│
├── services/                    # Supabase data access layer
│   ├── pond_service.dart        # Pond CRUD + getTodayFeed
│   ├── feed_service.dart        # feed_rounds CRUD
│   ├── feed_plan_generator.dart # Generates DOC 1–30 feed plan
│   ├── feed_plan_constants.dart # Round distribution + feed type schedule
│   ├── feed_calculation_service.dart
│   ├── farm_service.dart        # Farm CRUD
│   ├── sampling_service.dart    # Growth sampling
│   ├── smart_feed_engine.dart   # (Legacy, not used in MVP)
│   ├── tray_service.dart        # Tray data service
│   └── dashboard_service.dart
│
└── features/                    # UI feature modules
    ├── auth/                    # Login, signup, splash, OTP
    ├── dashboard/               # App-level dashboard + weather
    ├── farm/                    # Farm add/edit, new cycle setup
    ├── pond/                    # Pond dashboard (main daily screen)
    ├── feed/                    # Feed schedule, history, cards
    ├── tray/                    # Tray log screen + model + provider
    ├── water/                   # Water test screen + provider
    ├── growth/                  # Growth sampling screen + provider
    ├── harvest/                 # Harvest screen, summary
    ├── supplements/             # Supplement plans, mix screen
    └── profile/                 # User profile, farm settings
```

---

## 3. State Management Patterns

The app uses **Riverpod 2** with `StateNotifierProvider` and `FutureProvider`.

### Provider types used

| Pattern | Used For |
|---|---|
| `StateNotifierProvider` | Auth, Farm, PondDashboard, FeedSchedule, FeedHistory, Supplements |
| `StateNotifierProvider.family` | Per-pond providers (Water, Growth, Harvest, Tray) |
| `FutureProvider.family` | Smart feed (disabled), async pond data |
| `Provider` / `Provider.family` | Derived state (waterHealth, DOC calculation) |

### Key providers

```dart
// Auth state
authProvider: StateNotifierProvider<AuthNotifier, AppAuthState>

// Farm list + selected farm
farmProvider: StateNotifierProvider<FarmNotifier, FarmState>

// Daily pond operations
pondDashboardProvider: StateNotifierProvider<PondDashboardNotifier, PondDashboardState>

// Feed schedule for the schedule editor
feedScheduleProvider: StateNotifierProvider<FeedScheduleNotifier, FeedScheduleState>

// Per-pond providers (scoped by pondId string)
waterProvider(pondId): StateNotifierProvider.family<WaterNotifier, List<WaterLog>, String>
growthProvider(pondId): StateNotifierProvider.family<GrowthNotifier, List<SamplingLog>, String>
harvestProvider(pondId): StateNotifierProvider.family<HarvestNotifier, List<HarvestEntry>, String>
trayProvider(pondId): StateNotifierProvider.family<TrayNotifier, List<TrayLog>, String>
```

### DOC calculation

DOC is computed on-the-fly as a derived provider:

```dart
final docProvider = Provider.family<int, String>((ref, pondId) {
  // Reads stockingDate from farmProvider and diffs with today
});
```

---

## 4. Supabase Integration

### Initialization

```dart
// main.dart
await Supabase.initialize(
  url: 'https://qzubiqetvsgaiwhshcex.supabase.co',
  anonKey: 'sb_publishable_vR-960VzTfuvGZeac79JVQ_XWtj2OPL',
);
```

> **Security issue:** URL and anon key are hardcoded. Move to a `.env` file or `--dart-define` build args and add `.env` to `.gitignore`.

### Auth flow

```
AuthNotifier.checkSession()
    └─► Supabase.auth.currentSession
        ├─ Found → isAuthenticated = true
        └─ Not found → show LoginScreen

signIn() → signInWithPassword() → _syncUserRecord() → isAuthenticated = true
signUp() → signUp() → _syncUserRecord() → isAuthenticated = true
signOut() → signOut() → clear farm/user providers → isAuthenticated = false
```

### Main tables

```sql
-- Pond feed schedule (one row per DOC per round)
feed_rounds (
  id uuid primary key,
  pond_id uuid references ponds(id),
  doc integer,
  round integer,           -- 1–4
  planned_amount float,    -- kg
  actual_amount float,     -- nullable
  status text,             -- 'pending' | 'completed'
  is_manual boolean,       -- farmer overrode the amount
  feed_type text,          -- '1R', '2R', '3S', etc.
  updated_at timestamp
)

-- Reference: base feed rates per DOC
feed_base_rates (
  doc integer primary key,
  base_feed_amount float   -- kg for 100K PL / 1 acre
)

-- Feed history summary
feed_history_logs (
  pond_id uuid,
  date timestamp,
  doc integer,
  rounds float[],
  expected_feed float,
  cumulative_feed float
)
```

### Supabase RPC used

```dart
// Atomic pond creation (creates pond + triggers feed plan)
supabase.rpc('create_pond_with_feed_plan', params: { ... })
```

---

## 5. Feed Plan Generation Flow

### Step 1: Pond creation

`PondService.createPond()` calls the Supabase RPC `create_pond_with_feed_plan` then immediately calls `generateFeedSchedule()`:

```dart
Future<void> generateFeedSchedule(String pondId) async {
  // Inserts 120 flat rows: DOC 1–30, rounds 1–4, planned_amount = 2.5 kg
  // This is a placeholder — actual amounts are set in Step 2
}
```

### Step 2: Feed schedule refinement

`FeedPlanGenerator.generateFeedPlan()` is called from the Feed Schedule screen or on dashboard auto-recovery:

```dart
// Fetches base rates from Supabase
// Normalises to 235 kg baseline for 100K PL / 1 acre
// Scales by stockingCount and pondArea
// Inserts correct amounts into feed_rounds
```

**Normalisation formula:**
```
normalizationFactor = 235.0 / sum(baseRates[DOC 1..30])
scaleFactor = (stockingCount / 100000) × (pondArea / 1.0)
totalFeed[doc] = baseRate[doc] × normalizationFactor × scaleFactor
roundAmount = totalFeed[doc] × 0.25  (equal distribution)
```

### Step 3: Daily dashboard load

`PondService.getTodayFeed()` computes today's DOC and fetches those 4 `feed_rounds` rows.

**Current limitation:** Returns empty if DOC > 30 (line 121–123 in pond_service.dart).

---

## 6. Master Feed Engine (Smart Feeding — Post-DOC 30)

> All engines in `lib/core/engines/` are stateless static classes.

### Input / Output

```dart
// Input DTO
FeedInput {
  int seedCount, doc;
  double? abw;          // null = use standard curve
  double feedingScore;  // 1–5
  double intakePercent; // 0–100
  double dissolvedOxygen, temperature, phChange, ammonia;
  int mortality;
  List<TrayStatus> trayStatuses;
  double? lastFcr, actualFeedYesterday;
}

// Output DTO
FeedOutput {
  double recommendedFeed, baseFeed, finalFactor;
  List<String> alerts, reasons;
  double adjustmentPercent;  // computed
  bool isCriticalStop;       // computed
}
```

### Pipeline

```
MasterFeedEngine.run(input)
  1. FeedInputValidator.validate(input)       → throws on bad input
  2. FeedCalculationEngine.calculateFeed()    → baseFeed (kg)
  3. AdjustmentEngine.calculate(input)        → factor [0.5, 1.2]
     └─ if factor == 0.0 → STOP (DO critical)
  4. TrayEngine.apply()                       → adjust by leftover
  5. FCREngine.correction(lastFcr)            → factor [0.85, 1.15]
  6. EnforcementEngine.apply()                → correct for yesterday
  7. Safety clamp: normal [60%, 130%], crisis [50%, 110%] of baseFeed
  8. FeedInputValidator.validateOutput()      → fallback to baseFeed on anomaly
  → FeedOutput
```

### Base feed formula

```
biomass = seedCount × survival(DOC) × avgWeight(DOC) / 1000    (kg)
baseFeed = biomass × feedPercent(ABW)
```

**Feed % by ABW:**
| ABW | Feed % of biomass |
ABW	Feed % (Range)
< 1g	12–15%
1–3g	8–10%
3–5g	7–8%
5–8g	5–6%
8–12g	4–4.5%
12–18g	3–3.5%
18–25g	2.5–3%
> 25g	2–2.5%

---

## 7. Routing

Routes are registered in `AppRoutes.routes` and navigated via `Navigator.pushNamed()`.

| Route | Screen | Notes |
|---|---|---|
| `/login` | LoginScreen | — |
| `/profile` | ProfileScreen | — |
| `/dashboard` | DashboardScreen | — |
| `/pond-dashboard` | PondDashboardScreen | — |
| `/add-farm` | AddFarmScreen | — |
| `/add-pond` | AddPondScreen | — |
| `/edit-pond` | EditPondScreen | — |
| `/feed-schedule` | — | **Throws `UnimplementedError`** — requires pondId argument; navigate via `MaterialPageRoute` directly |

---

## 8. Known Code Issues & Tech Debt

### Critical

| Issue | Location | Impact |
|---|---|---|
| Supabase credentials hardcoded | `main.dart:17–20` | Credentials in source code / git history |
| `getTodayFeed` returns empty for DOC > 30 | `pond_service.dart:121` | Pond dashboard breaks after day 30 |
| `smartFeedProvider` throws `UnimplementedError` | `smart_feed_provider.dart:29` | Any widget using it will crash |
| `/feed-schedule` route throws | `app_routes.dart:29` | Navigator.pushNamed to that route crashes |
| `saveFeedPlans` deletes all then inserts | `feed_service.dart:155–160` | If insert fails after delete, all feed data is lost |

### Data Persistence Gaps

| Feature | Storage | Risk |
|---|---|---|
| Water logs | In-memory only | Lost on app restart |
| Growth samples | In-memory only | Lost on app restart |
| Harvest entries | In-memory only | Lost on app restart |
| Tray logs | SharedPreferences | Persists locally, not synced |

### Code Quality

| Issue | Location |
|---|---|
| `pond_model.dart` is empty | `lib/features/pond/pond_model.dart` | Pond model is defined inline elsewhere |
| Double import of `PondService` | `pond_dashboard_provider.dart:1,9` | Redundant import |
| `print()` statements throughout | Services, providers | Replace with `AppLogger` |
| `pond_dashboard_screen.dart` imports `smart_feed_round_card.dart` | Line 24 | Unused file |
| `feed_round_card.dart` imported but also demo variant imported | Screen | Check which is canonical |
| `generateFeedSchedule` inserts flat 2.5 kg, `generateFeedPlan` uses scientific rates | Both in PondService | Two competing generators; unclear which runs when |

---

## 9. Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.6.1    # State management
  supabase_flutter: ^2.5.0    # Backend + auth
  intl: ^0.20.2               # Date/number formatting
  shared_preferences: ^2.3.3  # Local key-value storage
  sms_autofill: ^2.4.1        # OTP auto-read

dev_dependencies:
  flutter_lints: ^3.0.0
```

---

## 10. Running the Project

```bash
# Install deps
flutter pub get

# Run on device/emulator
flutter run

# Run tests
flutter test

# Build release APK
flutter build apk --release
```

**Required:** Active internet connection (Supabase calls are not cached locally).

---

## 11. Environment Setup

The app currently has no `.env` support. Supabase credentials are in `main.dart`. To improve this:

```bash
# Add flutter_dotenv or use --dart-define
flutter run \
  --dart-define=SUPABASE_URL=https://... \
  --dart-define=SUPABASE_ANON_KEY=sb_...
```

Then in `main.dart`:
```dart
const url = String.fromEnvironment('SUPABASE_URL');
const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
```

---

## 12. Adding a New Feature — Checklist

1. Create folder under `lib/features/<feature>/`
2. Define model in `<feature>_model.dart` or alongside the provider
3. Define state + notifier in `<feature>_provider.dart`
4. If Supabase needed: create or extend a service in `lib/services/`
5. Build screens in `<feature>_screen.dart`
6. Register route in `app_routes.dart` if navigated by name
7. Add to bottom bar or dashboard quick-links if needed
8. Write unit tests in `test/`

---

## 13. Testing

**Existing tests:**
- `test/feed_calculation_test.dart` — unit tests for `FeedCalculationEngine`
- `test/widget_test.dart` — scaffold widget test

**Recommended test coverage to add:**
- `AdjustmentEngine` with edge cases (DO < 4, mortality thresholds)
- `EnforcementEngine` over/underfeed scenarios
- `FCREngine` boundary conditions
- `FeedPlanGenerator` scaling formula
- `WaterLog.getHealthScore()` with both farm types
- Provider integration tests for `PondDashboardNotifier`

---

## 14. Supabase Database Migration Notes

The `migrations/` folder at project root contains SQL migration scripts. Run these against the Supabase project before deploying new features.

Key RPC:
```sql
-- create_pond_with_feed_plan(p_farm_id, p_name, p_area, p_stocking_date,
--   p_seed_count, p_pl_size, p_num_trays, p_user_id)
-- Returns: pond_id (uuid)
```

---

## 15. Recommended Next Steps (Priority Order)

1. **Fix DOC > 30 empty feed** — Remove the `doc > 30` guard in `getTodayFeed`, implement Smart Feed activation for post-DOC 30 ponds
2. **Secure credentials** — Move Supabase keys out of source code
3. **Persist water/growth/harvest to Supabase** — These are the most valuable agronomic data points
4. **Fix `saveFeedPlans` atomicity** — Wrap delete+insert in a Supabase transaction or RPC
5. **Enable Smart Feed Engine** — Wire `MasterFeedEngine` to replace static feed plan for DOC 31+
6. **Remove `smartFeedProvider`** or make it non-throwing — currently a live crash risk
7. **Replace all `print()` with `AppLogger`**
8. **Resolve dual feed generator ambiguity** — `generateFeedSchedule` (flat 2.5 kg) vs `generateFeedPlan` (scientific)
