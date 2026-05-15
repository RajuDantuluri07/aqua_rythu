# AquaRythu Flutter Project - Comprehensive Analysis

**Project Type**: Cross-platform aquaculture farm management application  
**Technology Stack**: Flutter, Supabase, Riverpod, SharedPreferences  
**Target Users**: Shrimp/fish farmers in India (Primary: Telugu language support)  
**Status**: Active development with feature gating system

---

## 1. OVERALL ARCHITECTURE

### Architecture Pattern: **Clean Architecture + Riverpod State Management**

The project follows a layered architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────────────┐
│                          UI LAYER (Features)                        │
│  (Screens, Widgets, Dialog, User-facing Components)                 │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    STATE MANAGEMENT LAYER                           │
│  (Riverpod Providers - NotifierProviders, StateNotifiers)           │
├─────────────────────────────────────────────────────────────────────┤
│ - Auth Provider (login, OTP, session)                               │
│ - Farm/Pond Providers (data fetching, switching)                    │
│ - Feed Schedule Provider (feed planning & tracking)                 │
│ - Feature Gate / Subscription Provider (access control)             │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                 BUSINESS LOGIC LAYER (Systems)                      │
│  (Specialized engines for domain-specific calculations)             │
├─────────────────────────────────────────────────────────────────────┤
│ - Feed Engines (Master, Blind Feeding, Smart V2, Base Resolver)    │
│ - Growth Engine (FCR, Expected ABW, Growth Curves)                  │
│ - Decision Engines (Profit, Safe Decision, Action, Daily Action)    │
│ - Planning Engines (Feed Plan Generation, Tray Factor, Supplement)  │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                   DATA SERVICES LAYER                               │
│  (Repository pattern + Supabase wrapper services)                   │
├─────────────────────────────────────────────────────────────────────┤
│ Core Services:                                                       │
│ - FeedService (feed logs, schedule, base feed)                      │
│ - PondService (pond CRUD, lifecycle)                                │
│ - InventoryService (stock tracking, auto-feed deduction)            │
│ - ExpenseService (cost tracking, category management)               │
│ - FarmService (farm management, members)                            │
│ - HarvestService (harvest records, profit calculation)              │
│ - SystemSyncService (feed → inventory → expense flow)               │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    MODELS & DATA TYPES                              │
│  (Pure data classes with serialization)                             │
├─────────────────────────────────────────────────────────────────────┤
│ - Farm, Pond, Crop, Harvest, Expense, Inventory models              │
│ - Growth Curve, Farm Profile (personalized growth modeling)         │
│ - Feed Models (Input, Output, Debug Info, Orchestrator Result)      │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    DATABASE LAYER (Supabase)                        │
│  (PostgreSQL with RLS, Triggers, Functions, Views)                  │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Design Principles

1. **Single Responsibility**: Each layer has a clear, specific purpose
2. **Dependency Inversion**: Services depend on abstractions, not concrete implementations
3. **Pure Functions**: Business logic engines are pure (no side effects)
4. **State Isolation**: Riverpod manages all reactive state; Services are stateless
5. **Fail-Fast**: Input validation at service boundaries
6. **Calculation Synchronization**: SystemSyncService ensures feed → inventory → expense consistency

### Entry Point & Initialization

**File**: [lib/main.dart](lib/main.dart)

Startup sequence:
1. Supabase initialization with environment variables
2. SharedPreferences hydration (farm settings, user preferences)
3. SubscriptionGate debug override (QA testing)
4. Riverpod ProviderScope wraps entire app
5. AuthGate checks session (shows splash → login → home)
6. Language/Locale setup (English + Telugu)

---

## 2. MODULE STRUCTURE

### Directory Organization

```
lib/
├── core/                    # Cross-cutting concerns
│   ├── business/           # Core business logic (SystemSyncService)
│   ├── config/             # Configuration (AppConfig, FeatureFlags)
│   ├── constants/          # App-wide constants
│   ├── engines/            # EMPTY (feed engines moved to systems/)
│   ├── language/           # i18n (English, Telugu)
│   ├── models/             # Data models (Farm, Harvest, Expense, etc.)
│   ├── providers/          # Riverpod providers (AppConfig, ServerTime)
│   ├── repositories/       # Data repositories (Feed, Pond, Tray)
│   ├── services/           # Data access services (30+ services)
│   ├── theme/              # Material theme & styling
│   ├── utils/              # Utilities (Logger, DOC calculations)
│   ├── validators/         # Input validation
│   └── widgets/            # Reusable UI components
│
├── features/               # Feature-specific modules (user-facing)
│   ├── admin/              # Admin controls (payment debug) [DISABLED]
│   ├── auth/               # Authentication (login, OTP, splash)
│   ├── common/             # Shared feature utilities
│   ├── dashboard/          # Farm-level dashboard
│   ├── expense/            # Expense tracking (FEATURE GATED)
│   ├── farm/               # Farm management (create, edit, switch)
│   ├── feed/               # Feed schedule & history (CORE FEATURE)
│   ├── growth/             # Sampling & mortality tracking
│   ├── harvest/            # Harvest records (FEATURE GATED)
│   ├── home/               # Home screen (entry point)
│   ├── inventory/          # Inventory management (FEATURE GATED)
│   ├── pond/               # Pond dashboard & lifecycle
│   ├── profit/             # Profit tracking (FEATURE GATED)
│   ├── profile/            # User profile & farm settings
│   ├── supplements/        # Supplement mix planning (FEATURE GATED)
│   ├── tray/               # Tray management & scoring
│   ├── upgrade/            # Subscription UI
│   └── water/              # Water testing (FEATURE GATED)
│
├── systems/                # Specialized domain engines & planning
│   ├── config/             # Tray factor configuration
│   ├── feed/               # Feed calculation engines (CRITICAL)
│   ├── growth/             # Growth metrics (FCR engine)
│   ├── planning/           # Feed plan generation
│   ├── pond/               # Pond lifecycle calculations
│   ├── supplements/        # Supplement recommendations
│   ├── tray/               # Tray management logic
│   └── water/              # Water parameters
│
├── routes/                 # Navigation routes
├── widgets/                # Global reusable widgets
├── main.dart              # App entry point
```

---

### Detailed Module Breakdown

#### **FEATURES - Authentication & Onboarding** (lib/features/auth/)
**Purpose**: User authentication and session management

| File | Responsibility |
|------|-----------------|
| `auth_provider.dart` | StateNotifier for login/signup, OTP handling, session checks |
| `login_screen.dart` | Email/password or phone-based login UI |
| `otp_screen.dart` | One-time password verification |
| `splash_screen.dart` | App startup splash screen |
| `forgot_password_dialog.dart` | Password reset flow |

**Key Logic**:
- Supabase Auth integration (email + password, SMS OTP)
- Session persistence across app restarts
- User record sync with profiles table
- Friendly error messages (network, invalid credentials, etc.)

---

#### **FEATURES - Farm Management** (lib/features/farm/)
**Purpose**: Multi-farm support, farm creation, and member management

| File | Responsibility |
|------|-----------------|
| `farm_provider.dart` | Riverpod providers for farm data (list, selected farm) |
| `add_farm_screen.dart` | Create new farm UI |
| `farm_detail_sheet.dart` | View/edit farm information |
| `farm_switcher_sheet.dart` | Switch between user's farms |
| `farms_list_sheet.dart` | List all farms |
| `new_cycle_setup_screen.dart` | Initialize crop/cycle for a farm |
| `add_member_sheet.dart` | Add team members to farm |

**Core Data Models**:
```dart
class Pond {
  String id, name, farmId
  double area
  DateTime stockingDate
  int seedCount, plSize, numTrays
  PondStatus status
  SeedType seedType
  // Feed config
  int initialFeedRounds, postWeekFeedRounds
  double? anchorFeed, fcr
  // Smart Feed
  bool isSmartFeedEnabled
  // Monitoring
  double? currentAbw
  DateTime? latestSampleDate
  // Harvest tracking
  int? stockCount
  String harvestStage
  DateTime? lastHarvestDate
}
```

---

#### **FEATURES - Feed Management** (lib/features/feed/)
**Purpose**: Daily feed scheduling and history tracking

| File | Responsibility |
|------|-----------------|
| `feed_schedule_screen.dart` | Plan and adjust daily feeds |
| `feed_schedule_provider.dart` | State for feed schedule editing & saving |
| `feed_history_screen.dart` | View all past feeds for a pond |
| `feed_history_provider.dart` | Cumulative feed tracking |
| `feed_hero_card.dart` | Visual feed recommendation card |
| `feed_timeline_card.dart` | Historical feed entry display |
| `models/feed_input.dart` | Input data for feed engines |
| `enums/feed_stage.dart` | Blind → Transitional → Intelligent |

**Critical Features**:
- Master Feed Engine calculation pipeline
- 4-round daily feed distribution (customizable)
- Manual override per round (farmer controls)
- Automatic redistribution (if engineer allows)
- ROI tracking and confidence levels

---

#### **FEATURES - Pond Lifecycle** (lib/features/pond/)
**Purpose**: Pond creation, editing, and monitoring

| File | Responsibility |
|------|-----------------|
| `pond_dashboard_screen.dart` | Pond overview (ABW, DOC, status) |
| `pond_dashboard_provider.dart` | Fetch and refresh pond data |
| `add_pond_screen.dart` | Create new pond |
| `edit_pond_screen.dart` | Modify pond settings |
| `models/pond_*.dart` | Pond data structures |

**Key Operations**:
- Pond CRUD (Create via PondService)
- DOC calculation (Days of Culture)
- Stocking density tracking
- Tray count management
- Feed schedule auto-generation

---

#### **FEATURES - Inventory** (lib/features/inventory/)
**Purpose**: Stock tracking with auto-feed deduction

| File | Responsibility |
|------|-----------------|
| `inventory_dashboard_screen.dart` | Stock summary (farm-level) |
| `inventory_setup_screen.dart` | Initial inventory setup |
| `add_stock_screen.dart` | Purchase new stock |
| `adjust_stock_screen.dart` | Manual adjustments (waste, etc.) |
| `purchase_history_screen.dart` | View all purchases |
| `inventory_provider.dart` | State management |

**System Design**:
- **Zero-Manual for Feed**: Feed auto-tracked via feed logs (no manual purchase entry)
- **Manual for Other Items**: Medicine, equipment, etc. require manual entry
- **Farm-Level Only** (except feed per-crop): Farm-level stock only; crops don't have separate inventory
- **Automatic Deduction**: Feed quantity from feed logs deducted from inventory daily
- **Stock Verification**: Physical count reconciliation via `verify_inventory` RPC

---

#### **FEATURES - Expense Tracking** (lib/features/expense/)
**Purpose**: Operational cost logging

| File | Responsibility |
|------|-----------------|
| `expense_summary_screen.dart` | Crop-level expense summary |
| `add_expense_screen.dart` | Log new expense |
| `edit_expense_screen.dart` | Modify expense |
| `expense_provider.dart` | Expense state |

**Categories**: Labour, Electricity, Diesel, Sampling, Other

**Design**:
- Expense logs include crop_id (so they belong to a crop cycle)
- Optional pond_id for granular tracking
- Feed cost auto-calculated from inventory (no manual feed expense entry)

---

#### **FEATURES - Growth & Sampling** (lib/features/growth/)
**Purpose**: Monitor shrimp growth and health

| File | Responsibility |
|------|-----------------|
| `sampling_screen.dart` | Record pond sample data |
| `sampling_log.dart` | View sampling history |
| `growth_provider.dart` | Riverpod for growth data |
| `mortality_provider.dart` | Mortality tracking |

**Data Captured**:
- Average Body Weight (ABW) in grams
- Sample date
- Mortality count
- Growth performance scoring

---

#### **FEATURES - Harvest** (lib/features/harvest/)
**Purpose**: Final harvest recording and yield tracking

| File | Responsibility |
|------|-----------------|
| `harvest_screen.dart` | Harvest entry UI |
| `harvest_record_screen.dart` | Single harvest record view |
| `harvest_summary_screen.dart` | All harvests for crop |
| `harvest_provider.dart` | Harvest state |

**Calculation**:
- Total harvest weight (kg)
- Market price per kg
- Revenue = weight × price
- Final profit = revenue - total expenses

---

#### **FEATURES - Supplements** (lib/features/supplements/)
**Purpose**: Supplement recommendation and planning

| File | Responsibility |
|------|-----------------|
| `supplement_mix_screen.dart` | Plan supplement additions |
| `supplement_provider.dart` | Supplement recommendations |

**Integration**: Water quality testing → supplement recommendations

---

#### **FEATURES - Water Testing** (lib/features/water/)
**Purpose**: Water quality parameter monitoring

| File | Responsibility |
|------|-----------------|
| `water_test_screen.dart` | Log water test parameters |
| `water_provider.dart` | Water quality data |

**Monitored Parameters**: pH, salinity, temperature, dissolved oxygen, etc.

---

#### **FEATURES - Profile & Settings** (lib/features/profile/)
**Purpose**: User profile management and farm settings

| File | Responsibility |
|------|-----------------|
| `profile_screen.dart` | User profile view |
| `farm_settings_screen.dart` | Farm-specific settings (persisted locally) |
| `farm_settings_provider.dart` | SharedPreferences-backed farm config |
| `user_provider.dart` | User profile Riverpod provider |
| `legal_screen.dart` | Terms & conditions |

**Farm Settings Stored Locally**:
```dart
FarmProfileData {
  String farmId
  String farmName
  FarmCharacteristics (water type, soil pH, etc.)
  GrowthAdjustmentFactors (personalized growth calibration)
  HistoricalPerformance (past cycles' data)
}
```

---

#### **FEATURES - Dashboard** (lib/features/dashboard/)
**Purpose**: Farm-level overview and key metrics

| File | Responsibility |
|------|-----------------|
| `dashboard_screen_fixed.dart` | Overall farm KPIs |
| `farm_dashboard_provider.dart` | Aggregate data from all ponds |

**Metrics**:
- Total ponds (active/completed)
- Average ABW across ponds
- Feed consumption trend
- Estimated profit (if harvest data exists)
- Cost breakdown (feed, labour, electricity, etc.)

---

#### **FEATURES - Home** (lib/features/home/)
**Purpose**: Main entry screen after login

| File | Responsibility |
|------|-----------------|
| `home_screen.dart` | Navigation hub to dashboard, ponds, profile |

---

#### **FEATURES - Upgrade/Subscription** (lib/features/upgrade/)
**Purpose**: Feature gating and subscription management

| File | Responsibility |
|------|-----------------|
| `subscription_provider.dart` | Subscription status (Pro, Free tier) |

**Implementation**:
- Feature gates enforce PRO tier for: Expense, Inventory, Profit, Harvest, Supplements, Water
- Core features (Feed, Pond, Growth) are Free tier
- Payment via Razorpay integration

---

#### **FEATURES - Tray Management** (lib/features/tray/)
**Purpose**: Tray-based feeding system (alternative to density-based)

| File | Responsibility |
|------|-----------------|
| `tray_*.dart` | Tray input, scoring, and adjustments |

**System**:
- Tray count indicates biomass (shrimp in tray = amount they're eating)
- Tray leftover % indicates feed efficiency
- Adjusts base feed recommendation based on tray behavior

---

### CORE SERVICES LAYER

#### **Service Organization** (lib/core/services/)

30+ specialized services handling data access, auth, and integrations:

| Service | Purpose |
|---------|---------|
| `feed_service.dart` | Feed log CRUD, base feed calculation, inventory integration |
| `pond_service.dart` | Pond creation, feed schedule generation, lifecycle |
| `inventory_service.dart` | Stock tracking, purchases, adjustments, verification |
| `expense_service.dart` | Expense CRUD, category validation |
| `farm_service.dart` | Farm CRUD, member management, farm switching |
| `harvest_service.dart` | Harvest recording, profit calculation |
| `subscription_gate.dart` | Feature access control (Pro tier enforcement) |
| `feed_safety_service.dart` | Feed quantity validation (bounds checking) |
| `feed_config_service.dart` | DOC-based feed amounts, stocking type configs |
| `sampling_service.dart` | Growth sample CRUD, ABW validation |
| `tray_service.dart` | Tray scoring, leftover % tracking |
| `supplement_service.dart` | Supplement recommendations |
| `admin_security_service.dart` | Admin passcode management (currently disabled) |
| `payment_service.dart` | Razorpay integration |
| `network_service.dart` | Offline detection, retry logic |
| `app_config_service.dart` | Server-side app configuration |
| `dashboard_service.dart` | Aggregate farm metrics |
| And more... | |

---

## 3. MAJOR SYSTEMS

### A. FEED MANAGEMENT SYSTEM (lib/systems/feed/)

**Purpose**: Calculate daily feed recommendations using scientific algorithms

**Architecture**: Multi-stage pipeline

```
Input Data (from DB)
        ↓
┌───────────────────────────────────────────────────────┐
│ MASTER FEED ENGINE (master_feed_engine.dart)           │
│ Single source of truth for all feed computation        │
├───────────────────────────────────────────────────────┤
│ 1. Input Validation                                    │
│    - DOC range, density, biomass checks                │
│    - Subscription access (Pro only for Smart V2)       │
│                                                         │
│ 2. Base Feed Calculation                               │
│    - DOC ramp (increasing feed with growth)            │
│    - Density scaling (adjust for stocking density)     │
│    - Stocking type specific (seed vs PL vs wild)       │
│                                                         │
│ 3. Feed Stage Resolution                               │
│    - Blind Feeding (DOC 1-30)                          │
│    - Transitional (DOC 30-40)                          │
│    - Intelligent (DOC > 40)                            │
│                                                         │
│ 4. Feed Intelligence Layer                             │
│    - Compare expected vs actual feed                   │
│    - Detect deviations from growth curve               │
│    - Accumulate insights                               │
│                                                         │
│ 5. Smart Corrections (V2) [PRO ONLY]                   │
│    - Tray factor adjustment                            │
│    - Growth adjustment                                 │
│    - Environment factor adjustment                     │
│    - FCR-based correction                              │
│                                                         │
│ 6. Decision Engine                                     │
│    - Increase / Reduce / Maintain / Stop decision      │
│                                                         │
│ 7. Recommendation                                      │
│    - Next feed amount & timing                         │
│                                                         │
│ OUTPUT: OrchestratorResult                             │
│ {                                                       │
│   finalFeed: double,                                   │
│   confidence: 'high'|'medium'|'low',                  │
│   reason: String,                                      │
│   debugInfo: FeedDebugData,                            │
│   corrections: [...]                                   │
│ }                                                       │
└───────────────────────────────────────────────────────┘
```

**Key Engines**:

1. **BlindFeedingEngine** (`blind_feeding_engine.dart`)
   - DOC 1-30: Fixed ramp (0.2% → 2% of biomass)
   - No adaptation based on growth
   - Safe, predictable starting phase

2. **FeedBaseResolver** (`feed_base_resolver.dart`)
   - Determines base feed per 100K shrimp based on DOC
   - Incorporates stocking type (affects growth rate)

3. **FeedIntelligenceLayer** (`feed_intelligence_layer.dart`)
   - Tracks expected vs actual ABW
   - Flags growth deviations
   - Confidence scoring

4. **SmartFeedEngineV2** (`smart_feed_engine_v2.dart`) [DISABLED IN V1]
   - Applied for DOC > 30
   - Requires PRO subscription
   - Uses: tray response, growth data, environmental factors

5. **FeedDecisionEngine**
   - Decision logic: Increase | Reduce | Maintain | Stop
   - Priority: Safety > Savings > Optimization

6. **TrayFactorService** (`tray_factor_service.dart`)
   - Tray leftover % → adjustment factor
   - High leftovers = reduce feed
   - Low leftovers = can increase feed

7. **EnvFactorService** (`env_factor_service.dart`)
   - Water temperature, salinity, dissolved oxygen
   - Adjust feed based on environmental stress

**Calculation Flow** (Example: DOC 45, Seed type, 80K density, 2 trays):
```
Base calculation:
- Get expected ABW for DOC 45 from growth curve
- Base feed = DOC_ramp × stocking_type_factor
- Density scaling = (80,000 / 100,000)
- Tray factor = (2 trays) → adjustment based on leftover %
- Final = base × density × tray_adjustment
```

**Output to FeedSchedule**:
- Daily feed amount (kg)
- Distributed across 4 rounds
- Farmer can manually adjust per-round
- Auto-redistribution respects manual overrides

---

### B. GROWTH & MONITORING SYSTEM (lib/systems/growth/)

**Purpose**: Track shrimp development and health metrics

**Core Models**:

```dart
class GrowthCurve {
  static double getExpectedAbw(int doc) {
    // DOC-based ABW table (scientific standard for L. vannamei)
    if (doc <= 30) return 0.01 + (doc * 0.033); // Nursery
    if (doc <= 60) return 1.0 + ((doc - 30) * 0.233); // Early grow-out
    if (doc <= 90) return 8.0 + ((doc - 60) * 0.233); // Mid grow-out
    return 15.0 + ((doc - 90) * 0.333); // Late grow-out → 25g at DOC 120
  }
  
  static double getExpectedFcr(int doc) {
    // Feed Conversion Ratio increases with size
    if (doc <= 30) return 1.0;
    if (doc <= 60) return 1.2;
    if (doc <= 90) return 1.4;
    return 1.6;
  }
}

class FarmProfile {
  // Personalized growth model for each farm
  FarmCharacteristics characteristics; // water type, soil pH, location
  GrowthAdjustmentFactors growthFactors; // historical performance
  HistoricalPerformance performance; // past cycle data
  
  // Adaptive ABW = GrowthCurve.ABW × growthFactors.adjustment
}
```

**FCR Engine** (`fcr_engine.dart`):
- Feed Conversion Ratio = feed_given / weight_gained
- Tracks efficiency of feed → growth conversion
- Alerts if FCR > expected (indicates illness or poor feed quality)

**Pond Cycle Engine** (`pond_cycle_engine.dart`):
- DOC progression tracking
- Cycle stages: Nursery → Grow-out → Pre-harvest
- Harvest trigger recommendations

---

### C. INVENTORY SYSTEM (lib/systems/... + lib/core/services/inventory_service.dart)

**Purpose**: Track stock (feed, medicine, equipment) with automatic feed deduction

**Key Design**:

```
┌─────────────────────────────────────────────┐
│ INVENTORY STOCK (farm-level)                │
├─────────────────────────────────────────────┤
│ Feed Item:                                  │
│ - is_auto_tracked = TRUE                    │
│ - quantity auto-reduced by daily feed logs  │
│ - no manual purchase entry needed           │
│                                             │
│ Other Items (Medicine, Equipment):          │
│ - is_auto_tracked = FALSE                   │
│ - manual purchase entry required            │
│ - manual adjustments for waste/usage        │
└─────────────────────────────────────────────┘

Data Flow:
Feed Log (amount: 10kg) → Inventory Consumption → Stock Reduced
            ↓
    FeedService.saveFeed()
            ↓
    Supabase RPC: safe_insert_feed_log()
            ↓
    Trigger: create_feed_inventory_trigger.sql
            ↓
    Automatic entry in inventory_consumption
            ↓
    Stock updated in inventory_stock_view
```

**Stock Verification**: 
- Physical count vs system count
- `verify_inventory` RPC records discrepancies
- History tracking for auditing

**Pond Usage Breakdown**:
- Feed item → which ponds used it → quantity per pond
- Helps identify high-consumption ponds

---

### D. EXPENSE TRACKING SYSTEM

**Purpose**: Log and categorize operational costs

**Categories**:
- Labour (worker wages, contractor fees)
- Electricity (aeration, pumps, lighting)
- Diesel (generator, emergency supplies)
- Sampling (lab analysis, testing services)
- Other (miscellaneous costs)

**Data Model**:
```dart
class Expense {
  String cropId; // belongs to a crop cycle
  String? pondId; // optional: granular tracking
  ExpenseCategory category;
  double amount;
  DateTime date;
}
```

**Profit Calculation Integration**:
```
Estimated Profit = Expected Revenue - Total Expenses
  where:
    Expected Revenue = expected harvest weight × market price
    Total Expenses = Feed Cost + Labour + Electricity + Diesel + Sampling + Other

Final Profit = Actual Revenue - Total Expenses
  where:
    Actual Revenue = actual harvest weight × market price
```

**Feed Cost Handling**:
- Feed cost is automatically calculated from inventory system
- No manual "feed expense" entry required
- Cost per unit × quantity deducted
- Automatically rolled into profit calculation

---

### E. POND LIFECYCLE MANAGEMENT

**Purpose**: Manage pond from stocking through harvest

**States**: 
- `active` - currently running cycle
- `completed` - cycle finished, can start new one

**Key Operations**:

1. **Pond Creation** (PondService)
   - Basic info: name, area, stocking date, seed details
   - Auto-generate feed schedule using FeedPlanGenerator
   - Create initial records in pond_daily_feed (for ROI tracking)

2. **Feed Schedule Generation** (FeedPlanGenerator)
   - DOC 1-120 feed amounts (DOC-based table)
   - Scale for farm area, stocking type, density
   - Store in planned_feed_schedule view

3. **Daily Operations**
   - Record feed (updates inventory)
   - Record samples (ABW, mortality)
   - Log water parameters
   - Adjust feed if needed

4. **Harvest**
   - Record final weight and price
   - Calculate final profit
   - Mark pond as `completed`
   - Generate next cycle option

**Tray Counting** (Alternative to Density):
- Tray = proxy for shrimp count (tray full = shrimp eating well)
- Leftover % in tray = feed adjustment factor
- More direct than ABW sampling

---

### F. PLANNING & DECISION SYSTEMS

**Feed Plan Constants** (lib/systems/planning/):
```dart
// DOC-based feed table (kg per 100K shrimp)
const Map<int, double> feedByDoc = {
  1: 0.2,
  7: 0.8,
  30: 2.5,
  45: 3.8,
  60: 5.2,
  90: 6.5,
  120: 7.0,
  // interpolate for in-between DOCs
};

// Adjust by stocking type (seed vs PL vs wild-caught)
const Map<SeedType, double> stockingTypeAdjustment = {
  seed: 1.0, // baseline
  pl: 0.95, // slightly more mature, less feed
  wild: 0.90, // most efficient
};
```

**Decision Priority Service**:
1. Safety (never exceed absolute max feed)
2. Cost savings (reduce feed if growth on track)
3. Optimization (fine-tune for ROI)

**Action Engine** (`profit_decision_engine.dart`):
- Harvest timing recommendation
- Partial harvest vs full harvest
- Economic trigger: when to stop feeding and harvest

**Daily Action Engine**:
- Aeration recommendations
- Water change frequency
- Sampling schedule

---

## 4. BUSINESS LOGIC INVENTORY

### A. Feed Calculation Algorithms

**1. Base Feed Calculation**:
```
Base Feed (kg per 100K shrimp) = DOC Ramp Value
  DOC 1-30: 0.2% → 2.5% of stocking biomass
  DOC 31-60: 2.5% → 5.2% (follow growth curve)
  DOC 61-120: 5.2% → 7.0% (saturation phase)

Adjusted Feed = Base Feed × (Actual Density / 100,000)
  Example: 2.5 kg (base) × (80,000 / 100,000) = 2.0 kg
```

**2. Stocking Type Factors**:
```
Seed Shrimp (PL: 1-15g) × 1.0 (baseline, slower growth)
Post-Larval (PL: 16-25g) × 0.95 (more developed, faster growth)
Wild-Caught × 0.90 (already adapted, most efficient)
```

**3. Tray Adjustment** (if trays active):
```
Tray Leftover % → Adjustment Factor
  < 10% leftovers → 1.1× (increase feed, shrimp hungry)
  10-30% leftovers → 1.0× (maintain)
  > 30% leftovers → 0.9× (decrease feed, overfeeding)
```

**4. Growth Curve Interpolation** (GrowthCurve.dart):
```
Expected ABW at DOC 45:
  Linear interpolation between DOC 30 (1g) and DOC 60 (8g)
  = 1 + ((45-30)/(60-30)) × (8-1)
  = 1 + (15/30) × 7
  = 4.5g

Acceptable Range: ±20% of expected
  Min: 4.5 × 0.8 = 3.6g
  Max: 4.5 × 1.2 = 5.4g
```

---

### B. Inventory Management Logic

**Automatic Feed Deduction**:
```
Feed Log Recorded (10kg)
    ↓
Trigger: create_feed_inventory_trigger.sql
    ↓
INSERT inventory_consumption {
  item_id: feed_item_id,
  source: 'feed_auto',
  quantity_used: 10.0,
  cost_at_consumption: 10.0 × price_per_unit,
  date: TODAY
}
    ↓
inventory_stock_view AUTO-UPDATED
  expected_stock -= 10.0
```

**Stock Verification**:
```
Farmer counts actual stock: 180kg
System shows: 185kg (discrepancy: -5kg)

Call verify_inventory(item_id, 180)
  ↓
Adjustment record created
  ↓
History logged (for audit trail)
```

**Farm-Level Stock Consolidation**:
- All inventory is farm-level (not per-pond, except feed)
- Feed consumption is mapped per-pond but totaled at farm level
- Prevents fragmentation of stock

---

### C. Expense Calculation & Profit

**Profit = Revenue - Total Costs**

```
Revenue Calculation:
  Estimated: Expected Harvest Weight × Current Market Price
  Final: Actual Harvest Weight × Market Price (from Harvest log)

Total Costs:
  Feed Cost (from inventory system)
  + Labour Costs
  + Electricity Costs
  + Diesel Costs
  + Sampling Costs
  + Other Costs

Profit = Revenue - Total Costs
  Estimated Profit: Updated daily (as DOC advances, expected weight increases)
  Final Profit: Once harvest is recorded
```

**Cost Breakdown Reporting**:
- % of total: Feed cost / total cost
- Cost per kg harvest: total cost / harvest weight
- Feed efficiency: feed cost / kg weight gained

---

### D. Growth Monitoring Logic

**Sampling & Performance Scoring**:
```
Sample Input:
  Date: TODAY
  ABW: 4.2g (sampled)
  DOC: 45
  Mortality: 3%

Expected ABW for DOC 45: 4.5g (from growth curve)
Acceptable Range: 3.6g - 5.4g

Performance Assessment:
  4.2g is within range → GOOD (within ±20%)
  BUT below expected → SLIGHT CONCERN (98% of expected)
  
Confidence Score:
  1.0 (100%) if sample is fresh (< 3 days old)
  × 0.8 if 7-14 days old
  × 0.6 if 14-21 days old
  × 0.4 if > 21 days old
```

**Mortality Impact**:
```
Initial Stocking: 100,000 shrimp
Mortality this cycle: 3,000
Active Stock: 97,000 (97%)

Feed adjusted for active stock (not initial stocking)
  if not adjusted → overfeeding (waste, cost)
  if adjusted → optimized feed per active shrimp
```

---

### E. Sampling Factor Service

**Sampling Frequency Guidance**:
```
DOC 1-7: Every 2-3 days (rapid growth, variable)
DOC 8-30: Every 3-5 days (monitoring phase)
DOC 31-60: Every 5-7 days (stable phase)
DOC 61+: Every 7-10 days (pre-harvest monitoring)

Skipped Sampling → Confidence decreases → Feed decisions flagged as "low confidence"
```

---

### F. System Synchronization Flow

**Data Consistency Guarantee** (SystemSyncService):

```
Farmer records daily feed: 10kg in 4 rounds
    ↓
FeedService.saveFeed() → Supabase
    ↓
Automatic Trigger (inventory_feed_trigger):
    Creates inventory_consumption entry
    Updates inventory_stock (-10kg)
    ↓
FeedService._checkInventoryStock():
    Validates stock is sufficient
    Logs warnings if negative/low
    ↓
All three systems in sync:
  ✓ Feed log recorded (feed system)
  ✓ Stock reduced (inventory system)
  ✓ Cost auto-calculated (expense system)
```

---

## 5. DATABASE SCHEMA OVERVIEW

### Core Tables & Key Relationships

**Users & Farms**:
```sql
auth.users (Supabase Auth)
  ├─→ profiles (user metadata: name, phone, farm_member_ids)
  └─→ farms (farm_name, location, area)
      ├─→ ponds (farm_id, name, area, stocking_date, status)
      │   ├─→ crops (farm_id, pond_id, stocking_date, status)
      │   ├─→ pond_daily_feed (DOC, feed amounts, ROI tracking)
      │   ├─→ sampling (ABW, mortality, water params)
      │   └─→ feed_logs (daily feed records, auto-inventory trigger)
      │
      ├─→ inventory_items (farm-level, category: feed/medicine/equipment)
      │   ├─→ inventory_purchases (stock additions)
      │   ├─→ inventory_consumption (auto feed deduction)
      │   ├─→ inventory_adjustments (waste, verification)
      │   └─→ inventory_stock_view (computed: expected stock)
      │
      ├─→ expenses (crop_id, category, amount, date)
      │
      └─→ harvests (crop_id, weight, price_per_kg, date)
```

**Tray Management**:
```sql
tray_scoring (pond_id, DOC, leftover_percent, health_status)
  → Drives tray_factor_service adjustments
```

**Key Migrations (45+)**:

| File | Purpose |
|------|---------|
| `create_pond_daily_feed_table.sql` | Feed baseline + ROI tracking (cumulative savings) |
| `create_inventory_items_table.sql` | Stock item definitions (feed, medicine, etc.) |
| `create_inventory_purchases_table.sql` | Stock additions |
| `create_inventory_consumption_table.sql` | Stock deductions (auto-triggered by feed logs) |
| `create_inventory_stock_view.sql` | Computed view of current stock |
| `create_expenses_table.sql` | Operational costs |
| `create_harvest_table.sql` | Final harvest records |
| `create_feed_inventory_trigger.sql` | AUTO-DEDUCT feed from inventory when logged |
| `create_admin_audit_log.sql` | Admin action tracking |
| `add_smart_feed_activation.sql` | Smart Feed V2 feature flag column |
| `add_server_time_function.sql` | Server-side time (prevent timezone issues) |

**Security** (Row Level Security / RLS):
- Each user sees only their own farms/data
- Farm members see farm data (if access granted)
- Supabase enforces at DB layer (not just app)

**Advanced Features**:
- **Triggers**: Auto-deduct feed from inventory, update cumulative savings
- **Functions**: `safe_insert_feed_log()` (prevent duplicates), `verify_inventory()`, `calculate_stock()`
- **Views**: `inventory_stock_view`, `planned_feed_schedule`, `inventory_pond_usage_view`
- **Indexes**: Optimized for common queries (pond_id, date, category)

---

## 6. ROUTE & NAVIGATION STRUCTURE

**File**: [lib/routes/app_routes.dart](lib/routes/app_routes.dart)

### Route Hierarchy

```
/ (home - entry point after login)
├─ /login (LoginScreen)
├─ /profile (ProfileScreen - user settings)
├─ /farm-setup (add, edit, switch farms)
│  ├─ /add-farm (create new farm)
│  ├─ /new-cycle-setup (start new crop cycle)
│  └─ /farm-detail (view/edit farm)
│
├─ /dashboard (farm-level overview)
│
├─ /pond-dashboard (pond list & selection)
│  ├─ /edit-pond/{pondId} (modify pond settings)
│  ├─ /feed-schedule/{pondId} (daily feed planning)
│  ├─ /feed-history/{pondId} (cumulative feed view)
│  ├─ /tray-log (tray management & scoring)
│  ├─ /sampling (ABW & mortality recording)
│  └─ /harvest/{pondId} (harvest entry & history)
│
├─ /inventory (GATED)
│  ├─ /inventory-setup (initial setup)
│  ├─ /inventory-dashboard (stock overview)
│  ├─ /add-stock (purchase entry)
│  ├─ /adjust-stock (manual adjustments)
│  └─ /purchase-history (audit trail)
│
├─ /expense (GATED)
│  ├─ /expense-summary/{cropId} (cost breakdown)
│  ├─ /add-expense (log new cost)
│  └─ /edit-expense/{expenseId}
│
├─ /profit (GATED)
│  └─ Profit tracking & forecasting
│
├─ /water (GATED)
│  └─ /water-test (water parameter logging)
│
├─ /supplements (GATED)
│  └─ /supplement-mix (recommendations)
│
├─ /upgrade
│  └─ Subscription UI (Razorpay payment)
│
└─ /admin (DISABLED)
   ├─ /admin/passcode (security)
   └─ /admin/dashboard (analytics)
```

### Navigation Patterns

**Named Routes** (with argument passing):
```dart
// Navigate with arguments
Navigator.pushNamed(
  context, 
  AppRoutes.feedSchedule,
  arguments: pondId,
);

// Retrieve in route handler
final pondId = ModalRoute.of(context)?.settings.arguments as String?;
```

**Feature Gates** (in route builder):
```dart
routes[inventoryDashboard] = (context) => 
  FeatureFlags.isInventoryVisible
    ? const InventoryDashboardScreen()
    : const _FeatureDisabledScreen(featureName: 'Inventory');
```

**Deep Linking**: Routes support direct deep links (e.g., from notifications)

---

## 7. STATE MANAGEMENT WITH RIVERPOD

### Key Providers

**Authentication**:
```dart
authProvider // AuthNotifier - manages login, signup, session
→ userProvider // Current user profile
→ farmProvider // Selected farm & ponds list
```

**Feed System**:
```dart
feedScheduleProvider // Current day's feed plan (editable)
feedHistoryProvider // Cumulative feed data
→ pondProvider // Pond data (ABW, DOC, etc.)
```

**Feature Access**:
```dart
isProProvider // Subscription status (gating)
featureGateProvider // Individual feature availability
```

**Farm Profile** (local storage):
```dart
farmSettingsProvider // Persisted farm characteristics (SharedPreferences)
→ growthFactorsProvider // Growth adjustments
→ historicalPerformanceProvider // Past cycle data
```

**Subscription**:
```dart
subscriptionProvider // Pro/Free tier
→ paymentProvider // Razorpay integration
```

### Riverpod Pattern Used

1. **StateNotifier** (mutable state):
   ```dart
   class AuthNotifier extends StateNotifier<AppAuthState> {
     Future<bool> signIn(String email, String password) async { ... }
   }
   ```

2. **FutureProvider** (async data fetching):
   ```dart
   final pondDataProvider = FutureProvider((ref) async {
     return await pondService.getPond(pondId);
   });
   ```

3. **StreamProvider** (real-time updates):
   ```dart
   final farmDataProvider = StreamProvider((ref) {
     return supabase.from('farms').stream();
   });
   ```

4. **Computed Providers** (derived state):
   ```dart
   final totalFeedProvider = Provider((ref) {
     final schedule = ref.watch(feedScheduleProvider);
     return schedule.days.fold(0.0, (sum, day) => sum + day.total);
   });
   ```

---

## 8. FEATURE GATING SYSTEM

**File**: [lib/core/config/feature_flags.dart](lib/core/config/feature_flags.dart)

### Two-Layer Gating

**Layer 1: Launch Flags** (FeatureFlags.dart)
```dart
static const bool inventoryEnabled = false; // Not launched yet
static const bool expenseEnabled = false;
static const bool enableAllFeaturesForDev = true; // Dev override
```
- Controls: Can I see this screen at all?
- Dev Override: `kDebugMode && enableAllFeaturesForDev` bypasses flags

**Layer 2: Subscription Gates** (SubscriptionGate + FeatureGate)
```dart
isProProvider // Checks: Does user have Pro subscription?
```
- Controls: Am I allowed to use this feature?
- Even if launched, Pro tier required for some features

### Gated Features
- ✅ Feed, Pond, Growth, Dashboard, Home, Profile (FREE tier)
- 🔒 Inventory, Expense, Profit, Water, Supplements, Harvest (PRO tier)

### Implementation in Screens
```dart
// Route definition
inventoryDashboard: (context) => 
  FeatureFlags.isInventoryVisible
    ? (isProUser ? InventoryDashboardScreen() : ProUpgradeDialog())
    : FeatureDisabledScreen();
```

---

## 9. AUTHENTICATION & USER MANAGEMENT

### Auth Flow

```
Splash Screen (check session)
    ↓
IF authenticated AND session valid → Home
    ↓
ELSE → Login Screen
    ↓
Email/Phone OTP Login
    ↓
Supabase Auth.signInWithPassword() / signInWithOtp()
    ↓
Create/update user record in profiles table
    ↓
Set up farm (if first time)
    ↓
Home Screen
```

### Session Persistence

```dart
// AuthGate checks session on app start
Future<void> checkSession() async {
  final session = _supabase.auth.currentSession;
  if (session != null) {
    state = state.copyWith(isAuthenticated: true);
  } else {
    state = state.copyWith(isAuthenticated: false);
  }
  // Restore hydrated farm settings, user preferences from SharedPreferences
}
```

### Multi-User / Multi-Farm

- One user can own multiple farms
- Farm switcher UI (FarmSwitcherSheet) shows all user farms
- Each farm has independent pond lists, inventory, expense tracking
- Farm context passed through entire app navigation

---

## 10. LOCALIZATION (i18n)

**File**: [lib/core/language/](lib/core/language/)

**Supported Languages**:
- English (en)
- Telugu (te) - primary market

**Implementation**:
```dart
languageProvider // Riverpod locale selector
↓
AppLocalizationsDelegate // Flutter Localizations system
↓
app_localizations.yaml (key-value strings)
```

**Usage in UI**:
```dart
Text(AppLocalizations.of(context).translate('feed_schedule'))
```

---

## 11. CONFIGURATION & CONSTANTS

### App Configuration

**File**: [lib/core/config/app_config.dart](lib/core/config/app_config.dart)
```dart
AppConfig {
  supabaseUrl // From --dart-define (env var)
  supabaseAnonKey // From --dart-define (env var)
  razorpayKeyId // From --dart-define (env var)
}
```

**Build Command**:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=RAZORPAY_KEY_ID=...
```

### Feed Plan Constants

**File**: [lib/systems/planning/feed_plan_constants.dart](lib/systems/planning/feed_plan_constants.dart)
```dart
// DOC → Feed amount lookup (base kg per 100K shrimp)
const DOC_FEED_RAMP = { 1: 0.2, 7: 0.8, 30: 2.5, 45: 3.8, ... }

// Adjustments by stocking type
const STOCKING_TYPE_ADJUSTMENTS = { seed: 1.0, pl: 0.95, wild: 0.90 }

// Density scaling base
const DENSITY_BASE = 100000

// Safe feed bounds
const MIN_FEED_KG = 0.1
const MAX_FEED_KG = 50.0
```

---

## 12. CRITICAL DEPENDENCIES

From `pubspec.yaml`:

| Dependency | Purpose | Version |
|-----------|---------|---------|
| `supabase_flutter` | Backend, Auth, Database | 2.5.0 |
| `flutter_riverpod` | State management | 2.6.1 |
| `shared_preferences` | Local key-value storage | 2.3.3 |
| `sms_autofill` | OTP auto-fill | 2.4.1 |
| `razorpay_flutter` | Payment gateway | 1.3.6 |
| `intl` | Localization | 0.19.0 |
| `lottie` | Animations | 3.1.0 |
| `url_launcher` | External links | 6.3.0 |
| `flutter_localizations` | i18n support | SDK |

---

## 13. ERROR HANDLING & LOGGING

### Logger Service

**File**: [lib/core/utils/logger.dart](lib/core/utils/logger.dart)

```dart
AppLogger {
  .info(message) // Info logs
  .warn(message) // Warnings
  .error(message) // Errors (with stack trace)
  .debug(message) // Debug (debug builds only)
}
```

### Network Resilience

**File**: [lib/core/services/network_service.dart](lib/core/services/network_service.dart)
- Offline detection
- Automatic retry logic
- Timeout handling (with NetworkTimeoutService)

### Friendly Error Messages

```dart
// Service layer
throw FeedValidationException('Feed exceeds maximum limit');

// App layer catches and displays
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(label: Text(error.message)),
);
```

---

## 14. TESTING INFRASTRUCTURE

**File**: `pubspec.yaml`
```yaml
dev_dependencies:
  flutter_test:
  mocktail: ^1.0.5  # Mocking library
  flutter_lints: ^3.0.0  # Lint rules
```

**Test Categories**:
- Unit tests: Services, engines, models
- Widget tests: UI components
- Integration tests: End-to-end flows

---

## 15. PERFORMANCE & OPTIMIZATION

### Lazy Loading
- Ponds fetched on-demand (not all at startup)
- Feed schedules generated per-pond
- Inventory stock cached with expiration

### Caching Strategies
- SharedPreferences: Farm settings (persistent across app restarts)
- Riverpod cache: Feed schedule (invalidated when pond changes)
- Supabase realtime subscriptions: Farm data (auto-sync if available)

### Build Optimization
- Feature flags prevent loading unused feature UI
- Code splitting: Each feature is self-contained

---

## 16. SECURITY MEASURES

### Authentication
- Supabase Auth (email/password + SMS OTP)
- JWT tokens (managed by Supabase)
- Session validation on app resume

### Authorization (RLS)
- Row-level security at database layer
- User can only see their own farms
- Farm members see farm data (if invited)

### Secrets Management
- API keys passed via `--dart-define` (not hardcoded)
- Environment-specific configs (dev, staging, prod)
- AdminSecurityService: Passcode gating for admin features

### Data Privacy
- Supabase handles GDPR compliance
- User can export/delete data
- Farm data isolated by user_id (RLS)

---

## 17. DEPLOYMENT & BUILD PROCESS

### Build Variants

**Debug Build** (development):
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://dev-supabase.co \
  --dart-define=SUPABASE_ANON_KEY=dev_key \
  --dart-define=RAZORPAY_KEY_ID=dev_key_id
```

**Release Build** (production):
```bash
flutter build apk \
  --dart-define=SUPABASE_URL=https://prod-supabase.co \
  --dart-define=SUPABASE_ANON_KEY=prod_key \
  --dart-define=RAZORPAY_KEY_ID=prod_key_id
```

### Platform-Specific Configs

**Android** ([android/app/build.gradle](android/app/build.gradle)):
- Minified with ProGuard
- Signed APK for Play Store
- Razorpay integration

**iOS** ([ios/Runner/...](ios/Runner/)):
- App Store build
- Code signing certificates
- Razorpay SDK integration

---

## 18. KEY FILES SUMMARY

### Critical Files to Know

| File | Importance | Purpose |
|------|-----------|---------|
| `lib/main.dart` | CRITICAL | App entry, Supabase init, Riverpod setup |
| `lib/routes/app_routes.dart` | CRITICAL | Navigation routing & feature gates |
| `lib/systems/feed/master_feed_engine.dart` | CRITICAL | Feed calculation orchestrator |
| `lib/core/services/feed_service.dart` | CRITICAL | Feed CRUD & inventory sync |
| `lib/core/services/inventory_service.dart` | CRITICAL | Stock tracking & auto-deduction |
| `lib/features/farm/farm_provider.dart` | HIGH | Farm/pond data provider |
| `lib/features/feed/feed_schedule_provider.dart` | HIGH | Daily feed plan state |
| `lib/core/models/growth_curve.dart` | HIGH | Growth modeling & ABW expectations |
| `lib/core/models/farm_profile.dart` | HIGH | Farm-specific growth adjustments |
| `lib/core/config/feature_flags.dart` | HIGH | Feature launch control |
| `lib/core/services/subscription_gate.dart` | HIGH | Pro tier enforcement |
| `migrations/` | HIGH | Database schema (45+ files) |

---

## 19. COMMON WORKFLOWS

### Workflow 1: Add a New Feature

1. **Create feature module** in `lib/features/my_feature/`
2. **Define data models** in `lib/core/models/` or feature models/
3. **Create service** in `lib/core/services/` for data access
4. **Create Riverpod provider** in feature for state management
5. **Build screens** with Riverpod consumption
6. **Add routes** in `lib/routes/app_routes.dart`
7. **Gate feature** in `FeatureFlags` + `isProProvider` if Pro-only
8. **Test** with MockTail

### Workflow 2: Add Database Migration

1. Create SQL migration file: `migrations/YYYYMMDD_description.sql`
2. Write migration (alter table, create function, etc.)
3. Test on dev Supabase instance
4. Deploy to production Supabase
5. Update `lib/core/models/` and services to match new schema

### Workflow 3: Implement Business Logic

1. Define algorithm in **systems/** (pure function)
2. Write service wrapper in **core/services/**
3. Create Riverpod provider for state if needed
4. Integrate in feature screens
5. Add logging via AppLogger
6. Test edge cases (validation, bounds checking)

---

## 20. KNOWN LIMITATIONS & TECH DEBT

### Current Limitations

1. **Admin Module Disabled**: Admin passcode & dashboard temporarily removed (in progress refactor)
2. **Smart Feed V2 Disabled**: Advanced algorithm disabled at V1 launch (behind PRO gate)
3. **FCR Engine Unused**: Feed Conversion Ratio engine built but not integrated yet
4. **Offline-First**: App requires online (no offline queue for feed logs yet)
5. **No Multi-Language Completeness**: Telugu partial (English primary)

### Technical Debt Items

1. Repository pattern for Feed/Pond (currently direct service access in some places)
2. Error handling standardization across services
3. Test coverage gaps (high criticality areas lacking tests)
4. Database migration ordering (some dependencies manual)
5. Computed fields in models vs database views (duplication)

---

## 21. INTEGRATION POINTS

### External Services

1. **Supabase**:
   - Auth: Email/Password + SMS OTP
   - Database: PostgreSQL
   - Realtime: Stream updates (not currently used)

2. **Razorpay**:
   - Payment processing for Pro subscription
   - Webhook handling (in backend, not shown)

3. **SMS Provider** (via Supabase):
   - SMS OTP delivery for login

### Upcoming Integrations

1. **Weather API**: Water parameter recommendations
2. **Market Price API**: Real-time shrimp prices
3. **Analytics**: Amplitude or Firebase
4. **Notifications**: FCM for daily reminders

---

## CONCLUSION

**AquaRythu** is a sophisticated aquaculture management platform with:
- ✅ Clean architecture with clear layer separation
- ✅ Robust feed calculation pipeline (multiple engines)
- ✅ Automatic inventory sync with feed logging
- ✅ Personalized growth modeling per farm
- ✅ Feature gating for phased rollout
- ✅ Multi-farm, multi-user support
- ✅ Comprehensive data validation & error handling
- ✅ Supabase backend with RLS security

The codebase is well-organized, uses industry-standard patterns (Riverpod, Clean Architecture), and demonstrates sophisticated domain knowledge in aquaculture operations.

---

**Document Version**: 1.0  
**Last Updated**: 11 May 2026  
**Project Status**: Active Development  
