# SECTION 2 — SYSTEM ARCHITECTURE
**Production-Grade Startup Documentation for Aqua Rythu**

---

## TABLE OF CONTENTS

1. [High-Level System Architecture](#1-high-level-system-architecture)
2. [Frontend Architecture](#2-frontend-architecture)
3. [Backend Architecture](#3-backend-architecture)
4. [Riverpod State Management Architecture](#4-riverpod-state-management-architecture)
5. [Supabase Integration Architecture](#5-supabase-integration-architecture)
6. [Database Communication Flows](#6-database-communication-flows)
7. [Feature-Module Architecture](#7-feature-module-architecture)
8. [Service Layer Architecture](#8-service-layer-architecture)
9. [Dependency Graph](#9-dependency-graph)
10. [Synchronization Architecture](#10-synchronization-architecture)
11. [Authentication Architecture](#11-authentication-architecture)
12. [Offline/Cache Strategy](#12-offline-and-cache-strategy)
13. [Folder Structure Explanation](#13-folder-structure-explanation)
14. [Data Lifecycle Flows](#14-data-lifecycle-flows)

---

## 1. HIGH-LEVEL SYSTEM ARCHITECTURE

### System Overview Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                      AQUA RYTHU PLATFORM                          │
│                    (Clean Architecture)                            │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │          PRESENTATION LAYER (Flutter UI)                     │  │
│  │                                                               │  │
│  │  • Feature Screens (Home, Feed, Growth, Pond, Dashboard)    │  │
│  │  • Navigation (Routes, Deep linking)                        │  │
│  │  • Theme & Localization                                     │  │
│  └─────────────────────────────────┬──────────────────────────┘  │
│                                     │                              │
│  ┌──────────────────────────────────▼──────────────────────────┐  │
│  │     STATE MANAGEMENT LAYER (Riverpod)                       │  │
│  │                                                               │  │
│  │  • ProviderScope (root)                                     │  │
│  │  • StateNotifiers (FarmProvider, FeedProvider)              │  │
│  │  • FutureProviders (async operations)                       │  │
│  │  • Watch/Consume pattern (reactive updates)                 │  │
│  └─────────────────────────────────┬──────────────────────────┘  │
│                                     │                              │
│  ┌──────────────────────────────────▼──────────────────────────┐  │
│  │      BUSINESS LOGIC LAYER (Services + Engines)              │  │
│  │                                                               │  │
│  │  • Feed Engines (Blind, Smart, Master Orchestrator)         │  │
│  │  • Growth Models (FCR, ABW, Curves)                         │  │
│  │  • Decision Engines (Profit, Harvest Timing)                │  │
│  │  • Sync Service (offline→online reconciliation)             │  │
│  │  • Validation & Safety Services                             │  │
│  └─────────────────────────────────┬──────────────────────────┘  │
│                                     │                              │
│  ┌──────────────────────────────────▼──────────────────────────┐  │
│  │      DATA ACCESS LAYER (Repositories + Services)            │  │
│  │                                                               │  │
│  │  • Supabase Client (REST + Realtime)                        │  │
│  │  • Service Classes (FeedService, PondService, etc.)         │  │
│  │  • Repository Pattern (abstract data access)                │  │
│  │  • Local Cache (SharedPreferences)                          │  │
│  └─────────────────────────────────┬──────────────────────────┘  │
│                                     │                              │
│  ┌──────────────────────────────────▼──────────────────────────┐  │
│  │         DATA LAYER (Supabase PostgreSQL)                    │  │
│  │                                                               │  │
│  │  • Core Tables: ponds, feed_logs, inventory, expenses       │  │
│  │  • Auth: Supabase Auth (Email, SMS OTP)                     │  │
│  │  • Policies: Row-Level Security (RLS)                       │  │
│  │  • Triggers: Auto-deductions, validations                   │  │
│  │  • Functions: Complex business logic (RPCs)                 │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘

                         Data Flow Direction
                               ▲  ▼
                    (request) ▼  ▲ (response)
```

---

### Architectural Decision Rationale

| Decision | Why | Trade-offs |
|----------|-----|-----------|
| **Clean Architecture** (Layers) | Clear separation of concerns; easy to test; team scaling | More files, slightly more boilerplate |
| **Riverpod for State** | Declarative, testable, built for async; no rebuild issues | Learning curve; different from Provider |
| **Supabase (not Firebase)** | PostgreSQL (relational integrity); RLS (fine-grained security); transparent pricing | Smaller ecosystem than Firebase |
| **Service Layer** | Business logic decoupled from DB; testable; reusable | Extra indirection; might feel heavyweight for small features |
| **Offline-First** | Works on 2G, rural areas; no network dependency | Sync complexity; conflict resolution needed |
| **Riverpod Notifiers** | Pure state management; no BuildContext pollution | Boilerplate per feature; more files |

---

## 2. FRONTEND ARCHITECTURE

### Flutter App Entry Point

```
main.dart
  │
  ├─► WidgetsFlutterBinding.ensureInitialized()
  │   (Initialize Flutter engine)
  │
  ├─► Supabase.initialize(url, anonKey)
  │   (Connect to backend)
  │
  ├─► SharedPreferences.getInstance()
  │   (Initialize local cache)
  │
  ├─► SubscriptionGate.hydrateDebugOverride()
  │   (Restore debug subscription state)
  │
  ├─► runApp(ProviderScope(child: MyApp()))
  │   (Wrap app with Riverpod; start UI tree)
  │
  └─► MyApp (ConsumerWidget)
       │
       ├─► locale = ref.watch(languageProvider)
       │   (Get current language)
       │
       ├─► Material App with:
       │   ├─ Theme: AppTheme.lightTheme
       │   ├─ Localization: English + Telugu
       │   ├─ Home: AuthGate (splash screen)
       │   └─ Routes: AppRoutes.routes
       │
       └─► AuthGate (ConsumerStatefulWidget)
            │
            ├─► Splash Screen (while checking session)
            │
            ├─► Session Check:
            │   ├─ Is user logged in? (Supabase.auth.currentUser)
            │   ├─ Has user selected farm? (SharedPreferences)
            │   └─ Is subscription data loaded? (SubscriptionNotifier)
            │
            ├─► Route Decision:
            │   ├─ Not logged in → LoginScreen
            │   ├─ Logged in, no farm → AddFarmScreen
            │   └─ Logged in, farm exists → HomeScreen
            │
            └─► Periodic Hydration (on resume):
                 └─ Re-sync subscription, user, farm data
```

### Frontend Folder Structure

```
lib/
├── main.dart                           # App entry point
├── routes/
│   └── app_routes.dart                # Route definitions + navigation
│
├── features/                           # Feature modules (user-facing)
│   ├── auth/                          # Authentication screens
│   │   ├── login_screen.dart
│   │   ├── splash_screen.dart
│   │   ├── auth_provider.dart         # Riverpod notifier
│   │   └── enums/
│   │
│   ├── home/                          # Dashboard/home screen
│   │   ├── home_screen.dart
│   │   ├── home_provider.dart
│   │   └── widgets/
│   │
│   ├── feed/                          # Feed logging & tracking
│   │   ├── feed_schedule_screen.dart
│   │   ├── feed_timeline_card.dart    # ← You're working here!
│   │   ├── feed_history_provider.dart
│   │   ├── models/
│   │   │   ├── feed_input.dart
│   │   │   ├── orchestrator_result.dart
│   │   │   └── correction_result.dart
│   │   └── widgets/
│   │
│   ├── pond/                          # Pond management
│   │   ├── add_pond_screen.dart
│   │   ├── edit_pond_screen.dart
│   │   ├── pond_dashboard_screen.dart
│   │   ├── farm_provider.dart         # Riverpod notifier
│   │   └── enums/
│   │       ├── seed_type.dart
│   │       └── stocking_type.dart
│   │
│   ├── growth/                        # Growth tracking
│   │   ├── growth_dashboard.dart
│   │   ├── abw_sampling_screen.dart
│   │   └── growth_provider.dart
│   │
│   ├── inventory/                     # Stock tracking
│   │   ├── inventory_dashboard_screen.dart
│   │   ├── inventory_setup_screen.dart
│   │   └── inventory_provider.dart
│   │
│   ├── expense/                       # Cost tracking
│   │   ├── expense_summary_screen.dart
│   │   ├── add_expense_screen.dart
│   │   └── expense_provider.dart
│   │
│   ├── dashboard/                     # Analytics dashboard
│   │   ├── dashboard_screen_fixed.dart
│   │   └── dashboard_provider.dart
│   │
│   ├── farm/                          # Farm management
│   │   ├── add_farm_screen.dart
│   │   ├── farm_provider.dart
│   │   └── models/
│   │
│   ├── profile/                       # User profile
│   │   ├── profile_screen.dart
│   │   ├── user_provider.dart
│   │   ├── farm_settings_provider.dart
│   │   └── models/
│   │
│   ├── upgrade/                       # Subscription management
│   │   ├── upgrade_screen.dart
│   │   ├── subscription_provider.dart
│   │   └── payment_ui.dart
│   │
│   ├── harvest/                       # Harvest tracking
│   │   ├── harvest_screen.dart
│   │   └── harvest_provider.dart
│   │
│   ├── tray/                          # Seed tray phase
│   │   ├── tray_screen.dart
│   │   ├── tray_provider.dart
│   │   └── enums/
│   │
│   ├── water/                         # Water quality
│   │   ├── water_quality_screen.dart
│   │   └── water_provider.dart
│   │
│   ├── supplements/                   # Supplements
│   │   ├── supplement_screen.dart
│   │   └── supplement_provider.dart
│   │
│   ├── profit/                        # Profit analytics
│   │   ├── profit_screen.dart
│   │   └── profit_provider.dart
│   │
│   ├── admin/                         # Admin features (gated)
│   │   ├── admin_dashboard.dart
│   │   └── admin_provider.dart
│   │
│   └── common/                        # Shared screens/widgets
│       ├── error_screen.dart
│       └── feature_disabled_screen.dart
│
├── core/                              # Core services & utilities
│   ├── config/
│   │   ├── app_config.dart            # Environment config
│   │   ├── feature_flags.dart         # Feature gating
│   │   └── constants.dart
│   │
│   ├── services/                      # Business logic + data access
│   │   ├── feed_service.dart          # Feed logging/retrieval
│   │   ├── pond_service.dart          # Pond CRUD + lifecycle
│   │   ├── inventory_service.dart     # Stock tracking
│   │   ├── expense_service.dart       # Cost tracking
│   │   ├── farm_service.dart          # Farm management
│   │   ├── profit_service.dart        # Profit calculation
│   │   ├── growth_service.dart        # Growth tracking (if needed)
│   │   ├── subscription_service.dart  # Subscription management
│   │   ├── subscription_gate.dart     # Sync access to subscription state
│   │   ├── payment_service.dart       # Razorpay integration
│   │   └── [20+ other services]
│   │
│   ├── engines/                       # Specialized business logic
│   │   (Note: actual engines are in /systems/, not /core/)
│   │
│   ├── models/                        # Data models
│   │   ├── farm_profile.dart          # Farm personalization
│   │   ├── growth_curve.dart          # Scientific growth model
│   │   ├── subscription_model.dart    # Subscription state
│   │   ├── harvest_model.dart
│   │   ├── expense_model.dart
│   │   ├── inventory_item.dart
│   │   ├── profit_decision_engine.dart
│   │   ├── real_world_anchors.dart    # Test data
│   │   └── [other models]
│   │
│   ├── providers/                     # Global Riverpod providers
│   │   ├── app_config_provider.dart
│   │   └── server_time_provider.dart
│   │
│   ├── theme/
│   │   └── app_theme.dart             # Material theme
│   │
│   ├── language/
│   │   ├── language_provider.dart     # Locale selection (Riverpod)
│   │   ├── app_localizations.dart     # i18n delegate
│   │   └── translations/
│   │       ├── en.dart
│   │       └── te.dart
│   │
│   ├── utils/
│   │   ├── logger.dart                # Logging utility
│   │   ├── doc_utils.dart             # DOC calculations
│   │   ├── date_utils.dart
│   │   └── validators.dart
│   │
│   ├── repositories/                  # Data access abstraction
│   │   ├── feed_repository.dart
│   │   ├── pond_repository.dart
│   │   └── [other repositories]
│   │
│   ├── widgets/                       # Reusable UI components
│   │   ├── custom_app_bar.dart
│   │   ├── custom_button.dart
│   │   ├── custom_text_field.dart
│   │   ├── loading_indicator.dart
│   │   ├── error_snackbar.dart
│   │   └── [other widgets]
│   │
│   ├── validators/
│   │   └── feed_input_validator.dart  # Critical input validation
│   │
│   └── business/
│       └── [specialized business logic]
│
├── systems/                           # Advanced business systems
│   ├── feed/                          # Feed calculation engines
│   │   ├── master_feed_engine.dart    # Main orchestrator
│   │   ├── blind_feeding_engine.dart  # DOC ≤ 30 logic
│   │   ├── feed_engine_v2.dart        # Smart adjustments
│   │   ├── feed_intelligence_layer.dart
│   │   ├── feed_base_service.dart
│   │   ├── feed_base_resolver.dart
│   │   ├── feed_orchestrator.dart
│   │   ├── feed_models.dart
│   │   ├── feed_calculations.dart
│   │   ├── feed_timing_helper.dart
│   │   ├── tray_factor_service.dart
│   │   ├── env_factor_service.dart
│   │   ├── engine_constants.dart
│   │   ├── seed_feed_engine.dart
│   │   ├── config/
│   │   └── [other feed utilities]
│   │
│   ├── growth/                        # Growth modeling
│   │   └── fcr_engine.dart            # FCR calculations
│   │
│   ├── planning/                      # Planning & decision
│   │   ├── feed_plan_generator.dart   # Generate feed schedule
│   │   └── feed_plan_constants.dart   # Configuration
│   │
│   ├── pond/                          # Pond-specific logic
│   │   └── [pond lifecycle logic]
│   │
│   ├── water/                         # Water quality models
│   │   └── [water quality logic]
│   │
│   ├── supplements/                   # Supplement models
│   │   └── [supplement logic]
│   │
│   ├── tray/                          # Tray logic
│   │   └── [tray lifecycle logic]
│   │
│   └── config/                        # System config
│       └── [system constants]
│
├── migrations/                        # Database migrations (SQL)
│   ├── 001_create_base_tables.sql
│   ├── 002_add_rls_policies.sql
│   └── [45+ migration files]
│
└── assets/
    └── images/
        ├── logo.png
        ├── appicon.png
        └── splash.png
```

### Frontend Component Hierarchy

```
MyApp (MaterialApp with Riverpod)
  │
  └─► AuthGate (Splash + Auth Router)
       │
       ├─► (Not Logged In) → LoginScreen
       │
       ├─► (Logged In, No Farm) → AddFarmScreen
       │
       └─► (Logged In) → HomeScreen
            │
            ├─► AppBar
            │   ├─ Title: Farm Name
            │   ├─ User Menu
            │   └─ Notifications (alerts)
            │
            ├─► BottomNavigationBar
            │   ├─ Home (Dashboard)
            │   ├─ Feed (Schedule & History)
            │   ├─ Growth (Monitoring)
            │   ├─ Pond (Management)
            │   └─ More (Inventory, Expense, Profile)
            │
            ├─► Home Screen / Feed Screen / Growth Screen / etc.
            │   │
            │   ├─► KPI Cards
            │   │   ├─ Current DOC
            │   │   ├─ Today's Feed Recommendation
            │   │   ├─ Current ABW
            │   │   └─ Days to Harvest
            │   │
            │   ├─► Charts/Graphs
            │   │   ├─ Growth Curve (Expected vs Actual)
            │   │   ├─ Feed Consumption Trend
            │   │   └─ Profit Projection
            │   │
            │   ├─► Action Buttons
            │   │   ├─ Log Feed Round
            │   │   ├─ Record ABW Sample
            │   │   ├─ Add Expense
            │   │   └─ Schedule Harvest
            │   │
            │   └─► Data Tables
            │       ├─ Feed History
            │       ├─ Expense Log
            │       └─ Harvest Records
            │
            └─► Dialogs & Bottom Sheets
                ├─ Feed Logging Modal
                ├─ Expense Entry Modal
                └─ Confirmation Dialogs
```

---

## 3. BACKEND ARCHITECTURE

### Backend Services Overview

The backend is **pure Dart/Flutter** — no separate backend server. All business logic runs on-device or via Supabase functions.

```
┌─────────────────────────────────────────────────────────┐
│        BACKEND LOGIC (Dart Services Layer)              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Feed Engines (Pure Dart)                              │
│  ├─ MasterFeedEngine (orchestrator)                    │
│  ├─ BlindFeedingEngine (DOC ≤ 30)                      │
│  ├─ SmartFeedEngineV2 (DOC > 30)                       │
│  ├─ FeedIntelligenceLayer (monitoring)                 │
│  ├─ FeedInputBuilder (data assembly)                   │
│  ├─ FeedBaseService (calculations)                     │
│  └─ [6+ supporting engines]                            │
│                                                         │
│  Growth Models (Pure Dart)                             │
│  ├─ GrowthCurve (scientific model)                     │
│  ├─ FarmProfile (personalization)                      │
│  ├─ FCREngine (feed conversion ratio)                  │
│  └─ SamplingService (confidence scoring)               │
│                                                         │
│  Decision Engines (Pure Dart)                          │
│  ├─ ProfitDecisionEngine (harvest timing)              │
│  ├─ FeedDecisionEngine (feed adjustments)              │
│  ├─ DailyActionEngine (recommendations)                │
│  └─ AdaptiveInsights (personalization)                 │
│                                                         │
│  Services (Data Access + Business Logic)               │
│  ├─ FeedService (feed CRUD + calculations)             │
│  ├─ PondService (pond lifecycle)                       │
│  ├─ InventoryService (stock tracking)                  │
│  ├─ ExpenseService (cost tracking)                     │
│  ├─ ProfitService (ROI calculation)                    │
│  ├─ HarvestService (harvest tracking)                  │
│  ├─ FarmService (farm management)                      │
│  ├─ SubscriptionService (billing)                      │
│  ├─ PaymentService (Razorpay integration)              │
│  ├─ AuthService (authentication)                       │
│  └─ [20+ other services]                               │
│                                                         │
│  Sync & Offline Service                                │
│  ├─ SystemSyncService (local↔cloud reconciliation)     │
│  ├─ NetworkService (connectivity detection)            │
│  ├─ ConflictResolver (merge local/cloud)               │
│  └─ BackgroundSyncQueue (async persistence)            │
│                                                         │
│  Utility Services                                      │
│  ├─ AdminSecurityService (access control)              │
│  ├─ FeedSafetyService (validation)                     │
│  ├─ FarmPriceSettingsService (localization)            │
│  ├─ AppConfigService (runtime config)                  │
│  └─ [other utilities]                                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
                      │
                      │ (REST + Realtime)
                      ▼
         ┌──────────────────────────┐
         │   Supabase Backend       │
         │  (Managed PostgreSQL)    │
         ├──────────────────────────┤
         │ • Auth (Email, OTP)      │
         │ • Database (PostgreSQL)  │
         │ • RLS Policies           │
         │ • Functions (PL/pgSQL)   │
         │ • Realtime (WebSocket)   │
         │ • Storage (Files)        │
         │ • Edge Functions (JS)    │
         └──────────────────────────┘
```

### Service Architecture Pattern

Each service follows a consistent pattern:

```dart
// Example: FeedService

class FeedService {
  final supabase = Supabase.instance.client;  // Dependency injection
  
  // Method 1: Save (CREATE)
  Future<void> saveFeed({
    required String pondId,
    required double feedGiven,
    // ... other params
  }) async {
    // Validation
    // Business logic
    // Supabase RPC call
    // Local cache update (offline-safe)
    // Error handling + retry
  }
  
  // Method 2: Fetch (READ)
  Future<List<Map>> fetchFeedLogs(String pondId) async {
    // Load from cache first (offline support)
    // If online, fetch from Supabase
    // Merge results
    // Return
  }
  
  // Method 3: Update (UPDATE)
  Future<void> updateFeed(String feedId, Map updates) async {
    // Validation
    // Optimistic update (local cache)
    // Cloud update (background)
    // Conflict resolution if needed
  }
  
  // Method 4: Delete (DELETE)
  Future<void> deleteFeed(String feedId) async {
    // Check permission (RLS enforced server-side)
    // Optimistic delete (local cache)
    // Cloud delete (background)
  }
  
  // Helper methods
  Future<void> _withRetry(String operation, Function fn) async {
    // Auto-retry logic for transient failures
    // Exponential backoff
    // Log all retries
  }
}
```

---

## 4. RIVERPOD STATE MANAGEMENT ARCHITECTURE

### Riverpod Pattern Overview

Aqua Rythu uses **Riverpod** for state management because:
- **Declarative:** State defined as providers, not scattered across BuildContext
- **Testable:** No BuildContext required; easy to mock/test
- **Efficient:** Only rebuilds widgets that depend on changed providers
- **Async-first:** Built-in support for FutureProvider, AsyncValue
- **Simple dependency injection:** No service locators; providers are providers

### Provider Types Used

| Provider Type | Use Case | Example |
|---------------|----------|---------|
| **StateProvider** | Simple state (string, bool, enum) | `selectedPondProvider` |
| **StateNotifierProvider** | Complex state + logic | `farmProvider` (FarmNotifier) |
| **FutureProvider** | Async operations (fetch data) | `feedLogsProvider(pondId)` |
| **StreamProvider** | Real-time subscriptions | `realtimeUpdatesProvider` |
| **Family Modifier** | Parameterized providers | `feedLogsProvider('pond123')` |
| **Select** | Derived state | `ref.watch(farmProvider.select((f) => f.name))` |

### Feature-Level Provider Examples

```dart
// ==================== FEED FEATURE ====================

// FutureProvider: Fetch feed logs for a pond
final feedLogsProvider = FutureProvider.family<List<FeedLog>, String>((ref, pondId) async {
  final feedService = FeedService();
  return feedService.fetchFeedLogs(pondId);
});

// StateNotifierProvider: Feed history with filtering
final feedHistoryProvider = StateNotifierProvider<FeedHistoryNotifier, FeedHistoryState>((ref) {
  return FeedHistoryNotifier(ref);
});

// StateProvider: UI state (selected round)
final selectedFeedRoundProvider = StateProvider<int>((ref) => 0);

// ==================== FARM FEATURE ====================

// StateNotifierProvider: Current farm + all farms
final farmProvider = StateNotifierProvider<FarmNotifier, Farm?>((ref) {
  return FarmNotifier(ref);
});

// FutureProvider: Fetch all farms for user
final allFarmsProvider = FutureProvider<List<Farm>>((ref) async {
  final farmService = FarmService();
  return farmService.fetchFarmsForUser();
});

// Derived provider: Get selected farm's ponds
final selectedFarmPondsProvider = FutureProvider<List<Pond>>((ref) async {
  final farm = ref.watch(farmProvider);
  if (farm == null) return [];
  final pondService = PondService();
  return pondService.fetchPondsForFarm(farm.id);
});

// ==================== AUTHENTICATION ====================

// StateNotifierProvider: Auth state
final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  return AuthNotifier(ref);
});

// Derived provider: Check if user is logged in
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

// ==================== SUBSCRIPTION ====================

// StateNotifierProvider: Subscription tier
final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier(ref);
});

// Derived provider: Is user PRO?
final isProProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).isPro;
});
```

### Riverpod Widget Consumption Pattern

```dart
// ==================== CONSUMER WIDGET ====================

class FeedScheduleScreen extends ConsumerWidget {
  final String pondId;
  
  const FeedScheduleScreen({required this.pondId});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch providers
    final feedLogs = ref.watch(feedLogsProvider(pondId));
    final selectedRound = ref.watch(selectedFeedRoundProvider);
    
    // Consume data
    return feedLogs.when(
      loading: () => const LoadingIndicator(),
      error: (err, stack) => ErrorScreen(error: err),
      data: (logs) => _buildContent(context, ref, logs, selectedRound),
    );
  }
  
  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<FeedLog> logs,
    int selectedRound,
  ) {
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, idx) {
        final log = logs[idx];
        return FeedLogTile(
          log: log,
          onTap: () {
            // Mutate state
            ref.read(selectedFeedRoundProvider.notifier).state = idx;
          },
        );
      },
    );
  }
}

// ==================== CONSUMER STATEFUL WIDGET ====================

class GrowthDashboard extends ConsumerStatefulWidget {
  final String pondId;
  
  const GrowthDashboard({required this.pondId});
  
  @override
  ConsumerState<GrowthDashboard> createState() => _GrowthDashboardState();
}

class _GrowthDashboardState extends ConsumerState<GrowthDashboard> {
  @override
  void initState() {
    super.initState();
    // Setup listeners when widget loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(growthServiceProvider).startMonitoring(widget.pondId);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Watch providers
    final growth = ref.watch(growthProvider(widget.pondId));
    final isPro = ref.watch(isProProvider);
    
    return growth.when(
      loading: () => const LoadingIndicator(),
      error: (err, stack) => ErrorScreen(error: err),
      data: (growth) => _buildContent(growth, isPro),
    );
  }
  
  Widget _buildContent(GrowthData growth, bool isPro) {
    return Column(
      children: [
        // PRO-only feature gating
        if (isPro) PredictedHarvestCard(growth: growth),
        GrowthCurveChart(growth: growth),
        SamplingHistoryTable(growth: growth),
      ],
    );
  }
}
```

### Dependency Injection with Riverpod

```dart
// Global service providers (injected into features)

final feedServiceProvider = Provider<FeedService>((ref) {
  return FeedService();  // Singleton
});

final pondServiceProvider = Provider<PondService>((ref) {
  return PondService();
});

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService();
});

final farmProfileProvider = FutureProvider<FarmProfile?>((ref) async {
  final farm = ref.watch(farmProvider);
  if (farm == null) return null;
  
  final feedService = ref.watch(feedServiceProvider);
  return feedService.getFarmProfile(farm.id);
});

// Usage in a notifier
class FeedHistoryNotifier extends StateNotifier<FeedHistoryState> {
  final Ref ref;
  
  FeedHistoryNotifier(this.ref) : super(FeedHistoryState.initial());
  
  Future<void> loadHistory(String pondId) async {
    state = state.copyWith(isLoading: true);
    
    try {
      // Inject service via ref
      final feedService = ref.read(feedServiceProvider);
      final logs = await feedService.fetchFeedLogs(pondId);
      
      state = state.copyWith(
        logs: logs,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}
```

---

## 5. SUPABASE INTEGRATION ARCHITECTURE

### Supabase as Backend-as-a-Service

```
┌──────────────────────────────────────────────────┐
│           SUPABASE (Managed Backend)             │
├──────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Auth (Email + SMS OTP)                  │   │
│  ├──────────────────────────────────────────┤   │
│  │ • Supabase Auth API                      │   │
│  │ • Custom SMS provider (local number)     │   │
│  │ • Session management (JWT)               │   │
│  │ • Password reset, email verification     │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Database (PostgreSQL 15+)                │   │
│  ├──────────────────────────────────────────┤   │
│  │ • 45+ tables (ponds, feed_logs, etc.)    │   │
│  │ • Relational integrity (FK constraints)  │   │
│  │ • Auto-generated timestamps (server_now) │   │
│  │ • Triggers (feed deduction, validation)  │   │
│  │ • Functions (RPC operations)             │   │
│  │ • Views (calculated stock, summaries)    │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Row-Level Security (RLS)                │   │
│  ├──────────────────────────────────────────┤   │
│  │ • User can only see their own data       │   │
│  │ • Farm-level isolation (multi-tenant)    │   │
│  │ • Enforced at DB layer (zero-trust)      │   │
│  │ • Admin override policies (manual)       │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Realtime Subscriptions (WebSocket)      │   │
│  ├──────────────────────────────────────────┤   │
│  │ • Listen to table changes (INSERT/UPDATE)│   │
│  │ • Broadcast events across devices        │   │
│  │ • Low-latency updates (<100ms)           │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Storage (File uploads)                  │   │
│  ├──────────────────────────────────────────┤   │
│  │ • Store user-uploaded files              │   │
│  │ • PDF reports, CSV exports               │   │
│  │ • Profile pictures, farm photos          │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Edge Functions (Serverless)             │   │
│  ├──────────────────────────────────────────┤   │
│  │ • Custom API endpoints (if needed)       │   │
│  │ • Webhook handlers (notifications)       │   │
│  │ • Data processing tasks (async)          │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Supabase Client Setup

```dart
// lib/core/config/app_config.dart

class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  
  static void validate() {
    assert(supabaseUrl.isNotEmpty);
    assert(supabaseAnonKey.isNotEmpty);
  }
}

// lib/main.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase with environment variables
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  runApp(const MyApp());
}

// Usage throughout app

final supabase = Supabase.instance.client;

// Auth access
final user = supabase.auth.currentUser;

// Database access
final response = await supabase
    .from('ponds')
    .select('*')
    .eq('farm_id', farmId);

// Function calls (RPC)
final result = await supabase.rpc('safe_insert_feed_log', params: {
  'p_pond_id': pondId,
  'p_feed_given': feedQty,
});
```

### Supabase Database Schema Overview

```sql
-- Core Tables

ponds
├─ id (PK)
├─ farm_id (FK → farms)
├─ name
├─ area (hectares)
├─ stocking_date
├─ seed_count
├─ pl_size
├─ status (active/harvested)
└─ created_at, updated_at

feed_logs
├─ id (PK)
├─ pond_id (FK → ponds)
├─ doc (Day of Culture)
├─ round (1-4)
├─ feed_given (kg)
├─ base_feed (recommendation)
├─ created_at
└─ [indexed by pond_id, doc, created_at]

inventory_items
├─ id (PK)
├─ farm_id (FK → farms)
├─ name
├─ category (feed/supplement/other)
├─ unit (kg)
├─ is_auto_tracked (bool)
└─ created_at

inventory_adjustments
├─ id (PK)
├─ item_id (FK → inventory_items)
├─ adjustment_type (addition/deduction)
├─ quantity
├─ reason
├─ created_at
└─ [triggers feed log deduction]

expenses
├─ id (PK)
├─ pond_id (FK → ponds)
├─ category (labour/electricity/diesel/sampling/other)
├─ amount (₹)
├─ created_at
└─ [sum by pond for cost analysis]

harvests
├─ id (PK)
├─ pond_id (FK → ponds)
├─ harvest_date
├─ weight_kg
├─ survival_rate
├─ price_per_kg
├─ revenue
└─ created_at

-- Supporting Tables

farms
├─ id (PK)
├─ user_id (FK → auth.users)
├─ name
├─ location
└─ created_at

profiles
├─ id (PK) [FK → auth.users]
├─ first_name
├─ phone
└─ avatar_url

-- Views (Calculated Data)

inventory_stock_view
├─ item_id
├─ farm_id
├─ name
├─ category
├─ initial_stock
├─ total_added
├─ total_deducted
└─ expected_stock (initial + added - deducted)
```

### RLS (Row-Level Security) Policies

```sql
-- Users can only see their own farms
CREATE POLICY "Users can see own farms" ON farms
  USING (auth.uid() = user_id);

-- Users can only see ponds from their farms
CREATE POLICY "Users can see own ponds" ON ponds
  USING (
    farm_id IN (
      SELECT id FROM farms WHERE user_id = auth.uid()
    )
  );

-- All data is scoped to user's farms
CREATE POLICY "Users can see own feed logs" ON feed_logs
  USING (
    pond_id IN (
      SELECT id FROM ponds
      WHERE farm_id IN (
        SELECT id FROM farms WHERE user_id = auth.uid()
      )
    )
  );

-- Admin bypass (if admin user_id in special list)
CREATE POLICY "Admin can see all" ON farms
  USING (auth.uid() IN (SELECT user_id FROM admin_users));
```

### Supabase Functions (RPC)

```dart
// Example: safe_insert_feed_log (prevents duplicates)

await supabase.rpc('safe_insert_feed_log', params: {
  'p_pond_id': pondId,
  'p_doc': doc,
  'p_round': 1,
  'p_feed_given': actualFeedGiven,
  'p_base_feed': baseFeed,
  'p_created_at': date.toIso8601String(),
  'p_tray_leftover': leftoverPercent,
  'p_stocking_type': stockingType,
  'p_density': density,
});

// PL/pgSQL Implementation:
-- INSERT IGNORE logic (returns bool: inserted? true/false)
-- Prevents duplicate feed logs for same (pond, doc, round)
-- Automatically triggers inventory deduction if successful
```

---

## 6. DATABASE COMMUNICATION FLOWS

### Feed Logging Flow (Happy Path)

```
┌──────────────────────────────────────────────────────────────┐
│                  FEED LOGGING FLOW                           │
└──────────────────────────────────────────────────────────────┘

START: Farmer logs "5 kg feed given at 11:00 AM"
  │
  ├─ FeedTimelineCard (UI)
  │   ├─ Validates input
  │   │   └─ FeedInputValidator.validate(pondId, feedQty, doc)
  │   │       └─ Check: density valid? area valid? doc range valid?
  │   │
  │   └─ Calls FeedService.saveFeed()
  │
  ├─► FeedService.saveFeed()
  │   │
  │   ├─ Calculate actualFeedGiven = sum(all rounds today)
  │   │   └─ 5 kg + previous rounds = 5 kg (if first round)
  │   │
  │   ├─ Check inventory stock (warning only, don't block)
  │   │   ├─ Fetch farm_id from pond
  │   │   ├─ Get feed item for farm
  │   │   ├─ Calculate remaining stock
  │   │   └─ Log if stock <0 or <20kg
  │   │
  │   └─ Call Supabase RPC: safe_insert_feed_log()
  │       └─ Write to local cache IMMEDIATELY (offline-safe)
  │
  ├─► Supabase: safe_insert_feed_log() [PL/pgSQL Function]
  │   │
  │   ├─ BEGIN TRANSACTION
  │   │   └─ Check if (pond_id, doc, round) already exists
  │   │       └─ If yes: RETURN false (don't insert duplicate)
  │   │       └─ If no: INSERT and RETURN true
  │   │
  │   ├─ INSERT INTO feed_logs (pond_id, doc, round, feed_given, base_feed, ...)
  │   │   └─ Trigger: feed_logs_after_insert FIRES
  │   │
  │   ├─ Trigger: feed_logs_after_insert
  │   │   ├─ INSERT INTO inventory_adjustments
  │   │   │   (item_id, adjustment_type='deduction', quantity=feed_given, reason='Feed log DOC 15')
  │   │   │
  │   │   └─ Trigger: inventory_adjustments_after_insert FIRES
  │   │       └─ UPDATE inventory_items SET expected_stock = expected_stock - feed_given
  │   │
  │   └─ COMMIT
  │
  ├─ Supabase returns: {success: true, inserted: true}
  │
  ├─► FeedService._withRetry()
  │   ├─ If network error: queue for retry
  │   ├─ Backoff: 1s, 2s, 4s, 8s (max 4 retries)
  │   └─ Mark for sync when online
  │
  ├─► UI Updates (Riverpod)
  │   ├─ feedHistoryProvider invalidated
  │   ├─ All widgets watching feedHistoryProvider rebuild
  │   ├─ Show toast: "Feed logged: 5 kg ✓"
  │   └─ Update Today's Feed Summary card
  │
  ├─► Background Sync (if offline)
  │   ├─ Feed logged to local cache first
  │   ├─ When online: SystemSyncService.sync() runs
  │   ├─ Upload local logs to Supabase
  │   ├─ Inventory auto-deduction fires on server
  │   └─ All synced ✓
  │
  └─ END: Feed logged, inventory updated, UI refreshed

TIMELINE:
  T+0ms    | UI → FeedService
  T+50ms   | FeedService → Local Cache (offline-safe)
  T+100ms  | Local Cache writes ✓
  T+150ms  | FeedService → Supabase RPC (if online)
  T+250ms  | Supabase function executes (300ms avg)
  T+300ms  | Trigger fires (inventory deduction)
  T+350ms  | Response to client
  T+400ms  | UI refreshes (feedHistoryProvider updates)
  T+500ms  | Toast shows "Logged ✓"
```

### Growth Monitoring Data Flow

```
┌──────────────────────────────────────────────────────────────┐
│              GROWTH MONITORING FLOW                          │
└──────────────────────────────────────────────────────────────┘

START: Farmer measures shrimp ABW (Average Body Weight)
  │
  ├─ GrowthDashboard (UI)
  │   ├─ Click "Record Sample"
  │   └─ Opens ABWSamplingScreen (modal)
  │
  ├─► ABWSamplingScreen
  │   ├─ Input: {abw: 12.5g, sample_count: 50, doc: 45}
  │   ├─ Validate: ABW in range for DOC? Sample count >0?
  │   └─ Call SamplingService.recordSample()
  │
  ├─► SamplingService.recordSample()
  │   ├─ Save to feed_logs table (with metadata)
  │   └─ Trigger: growth_calculation_job (async)
  │
  ├─► Background: MasterFeedEngine.computeWithIntelligence()
  │   │
  │   ├─ Fetch: GrowthCurve.getExpectedAbw(doc=45)
  │   │   └─ Returns: 12g (expected for DOC 45)
  │   │
  │   ├─ Compare: actual (12.5g) vs expected (12g)
  │   │   ├─ Deviation: +4% (ahead of curve!)
  │   │   └─ Status: "EXCELLENT" growth
  │   │
  │   ├─ Fetch: FarmProfile.growthFactors
  │   │   └─ Apply farm-specific adjustment (if learned from history)
  │   │
  │   ├─ Confidence scoring
  │   │   ├─ Days since last sample: 3 days
  │   │   ├─ Confidence: 95% (fresh data)
  │   │   └─ Score = 1.0 * 0.95 = 95%
  │   │
  │   ├─ Predict harvest date
  │   │   ├─ Current ABW: 12.5g
  │   │   ├─ Target harvest ABW: 20g
  │   │   ├─ Growth rate: (12.5-10) / 3days = 0.83g/day
  │   │   ├─ Days remaining: (20-12.5) / 0.83 = 9 days
  │   │   └─ Predicted harvest: DOC 54 ± 3 days (confidence 85%)
  │   │
  │   ├─ Feed adjustment recommendations
  │   │   ├─ Growth ahead of curve → can reduce feed 5%
  │   │   └─ New recommendation: 6.2 kg/day → 5.9 kg/day
  │   │
  │   └─ Save results to:
  │       ├─ growth_monitoring table
  │       ├─ farm_profile table (update growth factors)
  │       └─ dashboard cache (aggregates)
  │
  ├─► Riverpod invalidation
  │   ├─ growthProvider(pondId).invalidate()
  │   ├─ feedRecommendationProvider(pondId).invalidate()
  │   └─ harvestPredictionProvider(pondId).invalidate()
  │
  ├─► UI Updates (GrowthDashboard rebuilds)
  │   ├─ Show growth curve with new point
  │   ├─ Update "Estimated Harvest: DOC 54"
  │   ├─ Update "Confidence: 85%"
  │   ├─ Show "Feed can reduce by 5%"
  │   └─ Show confidence interval graph
  │
  ├─► Alert if anomaly detected
  │   ├─ If growth >20% ahead/behind: send notification
  │   ├─ If sampling data stale (>21 days): alert user
  │   └─ If survival < expected: investigate disease risk
  │
  └─ END: Sample recorded, harvest date updated, feed adjusted

TIMELINE:
  T+0ms    | UI → SamplingService
  T+50ms   | Database: save sample
  T+100ms  | Background job triggered
  T+150ms  | GrowthCurve.getExpectedAbw()
  T+200ms  | FarmProfile lookup
  T+250ms  | Confidence scoring
  T+300ms  | Harvest prediction
  T+400ms  | Feed adjustment calculation
  T+500ms  | Results saved to DB
  T+600ms  | Riverpod invalidation
  T+650ms  | UI rebuilds
  T+700ms  | Toast: "Sample recorded! Harvest in 9 days ±3"
```

### Profit Calculation Data Flow

```
┌──────────────────────────────────────────────────────────────┐
│              PROFIT CALCULATION FLOW                         │
└──────────────────────────────────────────────────────────────┘

START: Farmer wants to see profitability of pond
  │
  ├─ ProfitScreen (UI)
  │   ├─ Select pond
  │   └─ Call ProfitService.calculateProfit(pondId)
  │
  ├─► ProfitService.calculateProfit()
  │   │
  │   ├─ Part 1: REVENUE CALCULATION
  │   │   ├─ Fetch harvest data: weight_kg, price_per_kg
  │   │   ├─ Revenue = weight_kg × price_per_kg
  │   │   └─ Example: 1200 kg × ₹250 = ₹3,00,000
  │   │
  │   ├─ Part 2: COST CALCULATION
  │   │   │
  │   │   ├─ Feed Cost (from inventory deductions)
  │   │   │   ├─ Fetch: SUM(inventory_adjustments.quantity) for pond
  │   │   │   │   └─ = 250 kg feed used
  │   │   │   ├─ Fetch: feed item price per kg
  │   │   │   │   └─ = ₹500/kg
  │   │   │   └─ Feed Cost = 250 × 500 = ₹1,25,000
  │   │   │
  │   │   ├─ Labour Cost (manual expenses)
  │   │   │   ├─ Fetch: SUM(expenses.amount) where category='labour'
  │   │   │   └─ = ₹60,000
  │   │   │
  │   │   ├─ Electricity Cost
  │   │   │   ├─ Fetch: SUM(expenses.amount) where category='electricity'
  │   │   │   └─ = ₹24,000
  │   │   │
  │   │   ├─ Diesel Cost
  │   │   │   ├─ Fetch: SUM(expenses.amount) where category='diesel'
  │   │   │   └─ = ₹12,000
  │   │   │
  │   │   ├─ Sampling Cost
  │   │   │   ├─ Fetch: SUM(expenses.amount) where category='sampling'
  │   │   │   └─ = ₹5,000
  │   │   │
  │   │   ├─ Other Costs
  │   │   │   ├─ Fetch: SUM(expenses.amount) where category='other'
  │   │   │   └─ = ₹8,000
  │   │   │
  │   │   └─ Total Cost = 125K + 60K + 24K + 12K + 5K + 8K = ₹2,34,000
  │   │
  │   ├─ Part 3: PROFIT CALCULATION
  │   │   ├─ Profit = Revenue - Total Cost
  │   │   ├─ Profit = 3,00,000 - 2,34,000 = ₹66,000
  │   │   ├─ ROI = (Profit / Total Cost) × 100
  │   │   ├─ ROI = (66,000 / 2,34,000) × 100 = 28.2%
  │   │   └─ Cost per kg = Total Cost / Harvest Weight
  │   │       └─ = 2,34,000 / 1200 = ₹195/kg produced
  │   │
  │   ├─ Part 4: COMPARATIVE ANALYSIS (if PRO)
  │   │   ├─ Compare vs. previous pond (same farm)
  │   │   │   ├─ Fetch: all ponds harvested in last 12 months
  │   │   │   ├─ Calculate profit/ROI for each
  │   │   │   └─ Show: "Profit 8% lower than avg (₹72K avg)"
  │   │   │
  │   │   ├─ Identify cost drivers
  │   │   │   ├─ Feed cost = 53% of total (highest)
  │   │   │   ├─ Labour cost = 26% of total
  │   │   │   └─ Others = 21% of total
  │   │   │
  │   │   └─ Recommendations
  │   │       ├─ "Feed waste detected: reduce feed 10% for ROI +3%"
  │   │       ├─ "Labour cost 5% above farm average"
  │   │       └─ "Harvest timing optimal (good price)"
  │   │
  │   └─ Return: ProfitCalculation object
  │
  ├─► UI: ProfitScreen displays
  │   ├─ Revenue: ₹3,00,000
  │   ├─ Cost Breakdown (pie chart)
  │   │   ├─ Feed (53%)
  │   │   ├─ Labour (26%)
  │   │   └─ Other (21%)
  │   ├─ Profit: ₹66,000
  │   ├─ ROI: 28.2%
  │   ├─ Comparison: "8% below farm average"
  │   ├─ Actionable insights
  │   └─ Export to PDF button
  │
  └─ END: Farmer understands profitability drivers

DATA SOURCES:
  - harvest table           → Revenue
  - inventory_adjustments   → Feed cost (automatic)
  - expenses table          → All other costs (manual)
  - farm average cache      → Benchmarking
  - previous_harvests       → Comparative data
```

---

## 7. FEATURE-MODULE ARCHITECTURE

### Module Organization Pattern

Each feature module follows this structure:

```
features/
└── feed/                              # Feature name
    ├── feed_schedule_screen.dart      # Main screens
    ├── feed_timeline_card.dart
    ├── feed_history_provider.dart     # State management
    ├── feed_detail_provider.dart
    │
    ├── widgets/                       # Feature-specific widgets
    │   ├── feed_round_card.dart
    │   ├── feed_deviation_alert.dart
    │   ├── feed_chart.dart
    │   └── feed_input_form.dart
    │
    ├── models/                        # Feature-specific models
    │   ├── feed_input.dart            # Input DTO
    │   ├── feed_display_model.dart    # Display model
    │   ├── orchestrator_result.dart   # Feed engine output
    │   └── correction_result.dart
    │
    ├── enums/                         # Feature enums
    │   └── feed_stage.dart            # (blind/transitional/smart)
    │
    └── [no services or business logic] # ← All in /core/services/
```

### Why This Structure?

| Decision | Rationale |
|----------|-----------|
| **Screens in feature** | Easy to find UI code; screens are feature-specific |
| **Providers in feature** | State is feature-specific; easy to test in isolation |
| **Models in feature** | DTOs and display models belong with their screens |
| **Services in /core** | Shared across multiple features (DRY) |
| **Engines in /systems** | Complex algorithms, reusable, non-feature-specific |

### Feature Module: Feed Example

```dart
// features/feed/feed_history_provider.dart

class FeedHistoryState {
  final List<FeedLog> logs;
  final bool isLoading;
  final String? error;
  final int? selectedIndex;
  
  const FeedHistoryState({
    required this.logs,
    this.isLoading = false,
    this.error,
    this.selectedIndex,
  });
  
  FeedHistoryState copyWith({
    List<FeedLog>? logs,
    bool? isLoading,
    String? error,
    int? selectedIndex,
  }) {
    return FeedHistoryState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }
}

class FeedHistoryNotifier extends StateNotifier<FeedHistoryState> {
  final Ref ref;
  final String pondId;
  
  FeedHistoryNotifier(this.ref, this.pondId)
      : super(FeedHistoryState(logs: []));
  
  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true);
    try {
      final feedService = ref.read(feedServiceProvider);
      final logs = await feedService.fetchFeedLogs(pondId);
      state = state.copyWith(logs: logs, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
  
  void selectLog(int index) {
    state = state.copyWith(selectedIndex: index);
  }
  
  Future<void> deleteLog(String logId) async {
    try {
      final feedService = ref.read(feedServiceProvider);
      await feedService.deleteLog(logId);
      await loadHistory(); // Refresh
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final feedHistoryProvider = StateNotifierProvider.family<
  FeedHistoryNotifier,
  FeedHistoryState,
  String // pondId parameter
>((ref, pondId) {
  return FeedHistoryNotifier(ref, pondId);
});

// Usage in UI
class FeedTimelineCard extends ConsumerWidget {
  final String pondId;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(feedHistoryProvider(pondId));
    
    return history.when(
      loading: () => LoadingIndicator(),
      error: (err, stack) => ErrorText(error: err),
      data: (state) => _buildContent(context, ref, state),
    );
  }
  
  Widget _buildContent(BuildContext context, WidgetRef ref, FeedHistoryState state) {
    return ListView.builder(
      itemCount: state.logs.length,
      itemBuilder: (context, index) {
        final log = state.logs[index];
        return FeedLogTile(
          log: log,
          isSelected: state.selectedIndex == index,
          onTap: () {
            ref.read(feedHistoryProvider(pondId).notifier).selectLog(index);
          },
          onDelete: () {
            ref.read(feedHistoryProvider(pondId).notifier).deleteLog(log.id);
          },
        );
      },
    );
  }
}
```

---

## 8. SERVICE LAYER ARCHITECTURE

### Service Class Pattern

All services follow a consistent pattern for testability and maintainability:

```dart
// Example: InventoryService

class InventoryService {
  // Dependency injection (optionally injected Supabase client for testing)
  final SupabaseClient supabase;
  
  InventoryService({SupabaseClient? client})
      : supabase = client ?? Supabase.instance.client;
  
  // Method 1: CRUD Create
  Future<void> createInventoryItems(List<Map<String, dynamic>> items) async {
    try {
      // Validation
      // Database call
      // Error handling
      // Logging
    } catch (e) {
      AppLogger.error('Failed to create items: $e');
      rethrow;
    }
  }
  
  // Method 2: CRUD Read
  Future<List<Map<String, dynamic>>> getInventoryStock(String farmId) async {
    try {
      final result = await supabase
          .from('inventory_stock_view')
          .select('*')
          .eq('farm_id', farmId);
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      AppLogger.error('Failed to get stock: $e');
      rethrow;
    }
  }
  
  // Method 3: CRUD Update
  Future<void> updateStock(String itemId, double newQuantity) async {
    try {
      await supabase
          .from('inventory_items')
          .update({'expected_stock': newQuantity})
          .eq('id', itemId);
    } catch (e) {
      AppLogger.error('Failed to update stock: $e');
      rethrow;
    }
  }
  
  // Method 4: CRUD Delete
  Future<void> deleteItem(String itemId) async {
    try {
      await supabase
          .from('inventory_items')
          .delete()
          .eq('id', itemId);
    } catch (e) {
      AppLogger.error('Failed to delete item: $e');
      rethrow;
    }
  }
  
  // Method 5: Complex business logic
  Future<void> verifyInventory(String itemId, double actualQuantity) async {
    try {
      await supabase.rpc('verify_inventory', params: {
        'p_item_id': itemId,
        'p_actual': actualQuantity,
      });
    } catch (e) {
      AppLogger.error('Verification failed: $e');
      rethrow;
    }
  }
  
  // Helper: Retry logic with exponential backoff
  Future<T> _withRetry<T>(
    String operation,
    Future<T> Function() fn,
  ) async {
    int retries = 0;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        retries++;
        if (retries >= 4) rethrow;
        
        final backoff = Duration(milliseconds: 1000 * (1 << (retries - 1)));
        await Future.delayed(backoff);
      }
    }
  }
}
```

### Service Dependency Graph

```
┌─────────────────────────────────────────────────────────────┐
│                SERVICE DEPENDENCY GRAPH                     │
└─────────────────────────────────────────────────────────────┘

                   AppConfig (top-level)
                         │
                         │ (provides Supabase credentials)
                         ▼
                 Supabase.initialize()
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    FeedService   InventoryService  ExpenseService
         │               │               │
         │               └───────────────┤
         │                               │
         ▼                               ▼
    ProfitService ◄─────────────────────┘
         │
         ├─► PondService (for pond lookups)
         ├─► HarvestService (for revenue)
         ├─► FarmService (for farm data)
         └─► SubscriptionGate (for tier checks)

    AuthService (independent)
         │
         └─► Supabase.auth

    FarmPriceSettingsService (independent)
         │
         └─► SharedPreferences (local cache)

    SystemSyncService (sync orchestrator)
         │
         ├─► FeedService
         ├─► InventoryService
         ├─► ExpenseService
         ├─► PondService
         └─► All other services (triggers sync)

    MasterFeedEngine (pure business logic)
         │
         ├─► FeedInputBuilder (assemble data)
         ├─► FeedBaseService (calculate base feed)
         ├─► BlindFeedingEngine (DOC ≤ 30)
         ├─► SmartFeedEngineV2 (DOC > 30)
         ├─► FeedIntelligenceLayer (monitoring)
         ├─► FarmProfile (personalization)
         ├─► GrowthCurve (scientific model)
         └─► SubscriptionGate (feature gating)
```

### Service Composition Example

```dart
// lib/core/services/profit_service.dart

class ProfitService {
  final supabase = Supabase.instance.client;
  
  // Dependency injection of other services
  final ExpenseService _expenseService = ExpenseService();
  final InventoryService _inventoryService = InventoryService();
  final HarvestService _harvestService = HarvestService();
  
  // Public method: Calculate profit for a pond
  Future<ProfitCalculation> calculateProfit(String pondId) async {
    // Step 1: Get revenue (from harvest)
    final revenue = await _harvestService.getHarvestRevenue(pondId);
    
    // Step 2: Get feed cost (from inventory)
    final feedCost = await _inventoryService.getFeedCostForPond(pondId);
    
    // Step 3: Get other costs (from expenses)
    final otherCosts = await _expenseService.getTotalExpenses(pondId);
    
    // Step 4: Calculate profit
    final totalCost = feedCost + otherCosts;
    final profit = revenue - totalCost;
    final roi = (profit / totalCost) * 100;
    
    // Step 5: Return structured result
    return ProfitCalculation(
      revenue: revenue,
      feedCost: feedCost,
      otherCosts: otherCosts,
      totalCost: totalCost,
      profit: profit,
      roi: roi,
    );
  }
}
```

---

## 9. DEPENDENCY GRAPH

### Complete System Dependency Graph

```
┌─────────────────────────────────────────────────────────────────────┐
│              AQUA RYTHU DEPENDENCY RESOLUTION                       │
└─────────────────────────────────────────────────────────────────────┘

LAYER 1: Infrastructure (Initialization)
  │
  ├─ AppConfig.supabaseUrl
  ├─ AppConfig.supabaseAnonKey
  ├─ SharedPreferences.getInstance()
  └─ SubscriptionGate.hydrateDebugOverride()
                  │
                  ▼
LAYER 2: Platform Services
  │
  ├─ Supabase.initialize() ──────────────┐
  │   (Auth + Database + Realtime)       │
  │                                      │
  ├─ SupabaseClient dependency           │
  │   (injected into services)           │
  │                                      │
  └─ Riverpod ProviderScope ─────────────┤
                  │                      │
                  ▼                      │
LAYER 3: Service Layer                   │
  │                                      │
  ├─ FeedService ◄──────────────────────┘
  ├─ PondService
  ├─ InventoryService
  ├─ ExpenseService
  ├─ HarvestService
  ├─ FarmService
  ├─ SubscriptionService
  ├─ PaymentService
  ├─ AuthService
  └─ [20+ other services]
                  │
                  ▼
LAYER 4: Business Logic Engines
  │
  ├─ MasterFeedEngine
  │   ├─ BlindFeedingEngine
  │   ├─ SmartFeedEngineV2
  │   ├─ FeedIntelligenceLayer
  │   ├─ FeedBaseService
  │   ├─ TrayFactorService
  │   └─ EnvFactorService
  │
  ├─ GrowthCurve
  ├─ FarmProfile
  ├─ FCREngine
  │
  ├─ ProfitDecisionEngine
  ├─ FeedDecisionEngine
  └─ DailyActionEngine
                  │
                  ▼
LAYER 5: Riverpod State Management
  │
  ├─ authProvider (StateNotifierProvider)
  ├─ farmProvider (StateNotifierProvider)
  ├─ feedHistoryProvider (StateNotifierProvider.family)
  ├─ growthProvider (FutureProvider.family)
  ├─ inventoryProvider (FutureProvider)
  ├─ expenseProvider (FutureProvider.family)
  ├─ subscriptionProvider (StateNotifierProvider)
  └─ [20+ other providers]
                  │
                  ▼
LAYER 6: Feature Screens
  │
  ├─ HomeScreen (ConsumerWidget)
  ├─ FeedScheduleScreen (ConsumerWidget)
  ├─ GrowthDashboard (ConsumerStatefulWidget)
  ├─ InventoryDashboard (ConsumerWidget)
  ├─ ExpenseScreen (ConsumerWidget)
  ├─ DashboardScreen (ConsumerWidget)
  └─ [other screens]
                  │
                  ▼
LAYER 7: Presentation (MaterialApp)
  │
  └─ MyApp (ConsumerWidget)
      └─ AuthGate (Router)
          ├─ LoginScreen
          ├─ AddFarmScreen
          └─ HomeScreen + Sub-screens
```

### Dependency Injection Pattern

```dart
// Riverpod providers act as DI container

// Global service providers
final feedServiceProvider = Provider<FeedService>((ref) {
  return FeedService(); // Singleton created once
});

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService();
});

final profitServiceProvider = Provider<ProfitService>((ref) {
  // Access other services via ref
  final feedService = ref.watch(feedServiceProvider);
  final inventoryService = ref.watch(inventoryServiceProvider);
  return ProfitService(feedService, inventoryService);
});

// Feature-level providers
final feedHistoryProvider = StateNotifierProvider.family<FeedHistoryNotifier, FeedHistoryState, String>(
  (ref, pondId) {
    // Inject services into notifier
    return FeedHistoryNotifier(
      ref,
      feedService: ref.watch(feedServiceProvider),
      pondId: pondId,
    );
  },
);

// Usage in widgets
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Services are injected automatically
    final feedService = ref.watch(feedServiceProvider);
    final feedHistory = ref.watch(feedHistoryProvider('pond123'));
    
    // All dependencies resolved by Riverpod
    return Container();
  }
}
```

---

## 10. SYNCHRONIZATION ARCHITECTURE

### Offline-First Sync Strategy

```
┌──────────────────────────────────────────────────────────────┐
│           OFFLINE-FIRST SYNCHRONIZATION PATTERN              │
└──────────────────────────────────────────────────────────────┘

LOCAL STATE (SharedPreferences + In-Memory Cache)
  │
  ├─ Feed logs (today's)
  ├─ Pond data (cached)
  ├─ Inventory stock (snapshot)
  ├─ Expenses (uncommitted)
  └─ User session (JWT token)

         │
         │ User performs action offline
         │ (e.g., logs feed, records expense)
         │
         ▼

WRITE OPERATIONS (Always succeed locally)
  │
  ├─ Write to SharedPreferences immediately
  ├─ Update in-memory cache
  ├─ Update Riverpod provider state
  ├─ Show success toast to user
  └─ Mark for sync (sync queue)

         │
         │ User can see their changes immediately
         │ No waiting for network
         │
         ▼

SYNC QUEUE (Background Job)
  │
  ├─ If online: sync immediately
  ├─ If offline: queue grows
  └─ Retry with backoff (1s, 2s, 4s, 8s)

         │
         │ When device comes online
         │ (SystemSyncService detects connectivity)
         │
         ▼

CLOUD SYNC (Upload local to server)
  │
  ├─ Fetch pending sync items
  ├─ Upload to Supabase one by one
  ├─ Transaction for each item (all-or-nothing)
  ├─ Mark as synced in local cache
  └─ Retry failed items (exponential backoff)

         │
         │ If conflict detected
         │ (server has newer version)
         │
         ▼

CONFLICT RESOLUTION
  │
  ├─ Last-write-wins: Use timestamp comparison
  ├─ Client timestamp vs server timestamp
  ├─ If local is newer: override server
  ├─ If server is newer: discard local
  └─ Log all conflicts for debugging

         │
         │ Sync completes
         │
         ▼

CLOUD DOWNLOAD (Fetch latest from server)
  │
  ├─ Fetch data modified since last sync
  ├─ Apply to local cache
  ├─ Invalidate Riverpod providers
  ├─ UI refreshes automatically
  └─ User sees merged state

TIMELINE:
  Offline action: T+0ms  ✓ (immediate, local)
  Sync when online: T+2s  ✓ (background, automatic)
  UI refresh: T+2.5s ✓ (Riverpod watches sync completion)
```

### Sync Service Implementation

```dart
// lib/core/services/system_sync_service.dart

class SystemSyncService {
  final supabase = Supabase.instance.client;
  final feedService = FeedService();
  final inventoryService = InventoryService();
  final expenseService = ExpenseService();
  
  // Start monitoring connectivity
  Future<void> startSyncMonitoring() async {
    networkService.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        sync(); // Sync when online
      }
    });
  }
  
  // Main sync method
  Future<void> sync() async {
    try {
      // Step 1: Get all pending sync items from local cache
      final pendingFeedLogs = await _getPendingFeedLogs();
      final pendingExpenses = await _getPendingExpenses();
      final pendingInventory = await _getPendingInventoryUpdates();
      
      // Step 2: Upload each item with retry
      for (final log in pendingFeedLogs) {
        await _withRetry(() => feedService.saveFeed(
          pondId: log.pondId,
          feedGiven: log.feedGiven,
          // ... other fields
        ));
      }
      
      for (final expense in pendingExpenses) {
        await _withRetry(() => expenseService.saveExpense(
          pondId: expense.pondId,
          amount: expense.amount,
          // ... other fields
        ));
      }
      
      // Step 3: Download latest data from server
      await _downloadLatestData();
      
      // Step 4: Invalidate providers (UI refreshes)
      Riverpod.invalidateAllProviders();
      
      AppLogger.info('Sync completed successfully');
    } catch (e) {
      AppLogger.error('Sync failed: $e');
      // User can retry manually or wait for auto-retry
    }
  }
  
  // Conflict resolution
  Future<bool> _resolveConflict(LocalItem local, RemoteItem remote) async {
    final localTime = local.updatedAt;
    final remoteTime = remote.updatedAt;
    
    if (localTime.isAfter(remoteTime)) {
      // Local is newer: override server
      return await _uploadToServer(local);
    } else {
      // Server is newer: use server version
      await _updateLocal(remote);
      return true;
    }
  }
  
  // Retry with exponential backoff
  Future<T> _withRetry<T>(Future<T> Function() fn) async {
    int retries = 0;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        retries++;
        if (retries >= 4) rethrow;
        
        final backoff = Duration(milliseconds: 1000 * (1 << (retries - 1)));
        await Future.delayed(backoff);
      }
    }
  }
}
```

---

## 11. AUTHENTICATION ARCHITECTURE

### Authentication Flow

```
┌──────────────────────────────────────────────────────────────┐
│             AUTHENTICATION FLOW (Email + SMS OTP)            │
└──────────────────────────────────────────────────────────────┘

SCENARIO 1: User Signs Up (Email)
  │
  ├─ LoginScreen
  │   └─ User enters email address
  │
  ├─► AuthService.signUpWithEmail(email)
  │   │
  │   ├─ Call Supabase.auth.signUp(email)
  │   │   └─ Supabase sends confirmation email to user inbox
  │   │
  │   ├─ Show: "Check your email for confirmation link"
  │   └─ UI: Switch to email verification screen
  │
  ├─ User clicks confirmation link in email
  │   └─ Supabase redirects back to app with session token
  │
  ├─► AuthService.completeEmailVerification()
  │   │
  │   ├─ Supabase creates user account
  │   ├─ Generate JWT session token
  │   └─ Store token in app (secure storage)
  │
  ├─ App detects authenticated user
  │   └─ Route to AddFarmScreen (no farm yet)
  │
  └─ END: User ready to add farm


SCENARIO 2: User Signs Up (SMS OTP)
  │
  ├─ LoginScreen (Phone Tab)
  │   └─ User enters phone number (10 digits, India)
  │
  ├─► AuthService.signUpWithPhone(phone)
  │   │
  │   ├─ Validate: Is 10-digit Indian phone number?
  │   ├─ Call Supabase.auth.signUpWithPhone(phone)
  │   │   └─ Supabase sends OTP SMS to phone
  │   │
  │   ├─ Show: "OTP sent to +91-XXXXXX-{last4}"
  │   └─ Show: OTP input field + 60-second countdown
  │
  ├─ User enters OTP (auto-filled via SMS Autofill plugin)
  │   └─ AuthService.verifyOtp(phone, otp)
  │
  ├─► Supabase.auth.verifyOtp(phone, otp)
  │   │
  │   ├─ Verify OTP against sent value
  │   ├─ If correct: create/update user account
  │   ├─ Generate JWT session token
  │   └─ Store in app (secure)
  │
  ├─ App detects authenticated user
  │   └─ Route to AddFarmScreen or HomeScreen
  │
  └─ END: User signed up via SMS


SCENARIO 3: User Logs In (Existing Account)
  │
  ├─ LoginScreen
  │   ├─ User enters email/phone (depending on signup method)
  │   └─ User enters password (if email) or requests OTP (if phone)
  │
  ├─► AuthService.login(email, password) or AuthService.loginWithOtp(phone)
  │   │
  │   ├─ Supabase verifies credentials
  │   ├─ If valid: return JWT token
  │   └─ Store token in app
  │
  ├─ App detects authenticated user
  │   └─ Load farms (if exist) → HomeScreen
  │       └─ or AddFarmScreen (first time)
  │
  └─ END: User logged in


SESSION MANAGEMENT:
  │
  ├─ JWT token stored in secure storage (Supabase native)
  ├─ Token auto-refreshed by Supabase before expiry
  ├─ Logout: Delete token + clear user data
  ├─ App resume: Check if token still valid
  │   └─ If not: logout + show login screen
  └─ If network offline: Use cached auth state (until token expires)


RLS (Row-Level Security) Enforcement:
  │
  ├─ Supabase enforces user's JWT in all database queries
  ├─ User can ONLY see their own farms/ponds/data
  ├─ Even if user tries to hack API: RLS prevents access
  └─ All access logged for security audit
```

### AuthProvider State Machine

```dart
// lib/features/auth/auth_provider.dart

class AppAuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isCheckingSession; // ← Key for splash screen
  final String? errorMessage;
  final String? email;
  
  const AppAuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isCheckingSession = true, // Initially checking
    this.errorMessage,
    this.email,
  });
}

class AuthNotifier extends StateNotifier<AppAuthState> {
  AuthNotifier(this.ref, {SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client,
        super(AppAuthState()) {
    _initializeAuth();
  }
  
  Future<void> _initializeAuth() async {
    // Called on app startup
    try {
      // Step 1: Check if user has valid session
      final user = _supabase.auth.currentUser;
      
      if (user != null) {
        // Step 2: If yes, user is authenticated
        state = state.copyWith(
          isAuthenticated: true,
          email: user.email,
          isCheckingSession: false,
        );
      } else {
        // Step 3: If no, user needs to login
        state = state.copyWith(
          isAuthenticated: false,
          isCheckingSession: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: _friendlyAuthError(e),
        isCheckingSession: false,
      );
    }
  }
  
  Future<void> signUpWithEmail(String email) async {
    state = state.copyWith(isLoading: true);
    try {
      await _supabase.auth.signUp(email: email, password: '...');
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(e),
      );
    }
  }
  
  Future<void> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true);
    try {
      await _supabase.auth.verifyOtp(phone: phone, token: otp, type: OtpType.sms);
      
      // OTP verified, user authenticated
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(e),
      );
    }
  }
  
  Future<void> logout() async {
    await _supabase.auth.signOut();
    state = AppAuthState(); // Reset to initial state
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  return AuthNotifier(ref);
});
```

---

## 12. OFFLINE AND CACHE STRATEGY

### Local Cache Architecture

```
┌──────────────────────────────────────────────────────────────┐
│            OFFLINE + CACHE STRATEGY                          │
└──────────────────────────────────────────────────────────────┘

Cache Hierarchy:
  │
  ├─ LAYER 1: In-Memory Cache (Riverpod + StateNotifiers)
  │   ├─ Purpose: Instant UI updates (zero latency)
  │   ├─ Lifetime: App session (cleared on restart)
  │   ├─ Data: Feed history, selected pond, growth data
  │   └─ Examples: feedLogsProvider, selectedPondProvider
  │
  ├─ LAYER 2: Local Persistence (SharedPreferences)
  │   ├─ Purpose: Survive app restarts + offline access
  │   ├─ Lifetime: Until manually deleted
  │   ├─ Data: User preferences, farm settings, last-known ponds
  │   ├─ Max size: ~100KB per app
  │   └─ Use: farmSettings, userProfile, languagePreference
  │
  ├─ LAYER 3: Supabase Cache (Server-Side)
  │   ├─ Purpose: Source of truth + validation
  │   ├─ Lifetime: Permanent (until deleted)
  │   ├─ Data: All app data (ponds, feed logs, expenses, etc.)
  │   └─ RLS enforces user isolation
  │
  └─ LAYER 4: Sync Queue (Pending Operations)
      ├─ Purpose: Queue operations for later sync
      ├─ Lifetime: Until synced to server
      ├─ Data: {operation: 'create_feed', data: {...}, timestamp: ...}
      └─ Stored in: SharedPreferences (key: 'sync_queue')


Offline Workflow:
  │
  ├─ User on 2G network (very slow) or no connection
  │   │
  │   ├─ Read operation: Use local cache (no network call)
  │   ├─ Write operation: Write locally, queue for sync
  │   ├─ UI remains responsive (no loading spinners)
  │   └─ User sees: "Not synced yet (will sync when online)"
  │
  └─ When online again:
      ├─ SystemSyncService.sync() runs automatically
      ├─ Upload all queued operations
      ├─ Resolve conflicts (local vs server)
      ├─ Download latest server state
      ├─ Invalidate Riverpod providers (UI updates)
      └─ Show toast: "Synced ✓"


Cache Invalidation Strategy:
  │
  ├─ Time-based: Refresh after 1 hour
  ├─ Event-based: Refresh after user action (feed logged, expense added)
  ├─ Manual: "Pull to refresh" gesture
  ├─ Server: Real-time via Supabase subscriptions
  └─ On error: Refetch data on next access


Data Freshness Guidelines:
  │
  ├─ Feed logs: Refresh immediately (user just added)
  ├─ Growth data: Refresh when new sample added
  ├─ Inventory: Refresh every 5 minutes (auto-deductions)
  ├─ Expenses: Refresh on manual entry
  ├─ Dashboard summaries: Refresh every 30 minutes
  └─ Farm settings: Refresh on startup
```

### SharedPreferences Usage

```dart
// Example: Cache farm settings locally

class FarmSettingsProvider {
  static const String _prefsKey = 'farm_settings';
  
  static Future<void> saveFarmSettings(FarmSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(settings.toJson());
    await prefs.setString(_prefsKey, json);
  }
  
  static Future<FarmSettings?> getFarmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json == null) return null;
    
    return FarmSettings.fromJson(jsonDecode(json));
  }
  
  static Future<void> clearFarmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

// Usage
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<FarmSettings?>(
      future: FarmSettingsProvider.getFarmSettings(),
      builder: (context, snapshot) {
        if (snapshot.data == null) {
          return const Text('No farm data');
        }
        return Text('Farm: ${snapshot.data!.farmName}');
      },
    );
  }
}
```

---

## 13. FOLDER STRUCTURE EXPLANATION

### Complete Folder Tree with Purposes

```
aqua_rythu/
├── lib/
│   ├── main.dart                      # App entry point; initializes Supabase, Riverpod
│   │
│   ├── routes/
│   │   └── app_routes.dart            # Route definitions; feature-gated navigation
│   │
│   ├── features/                      # User-facing feature modules
│   │   └── [15 feature folders]       # Each with screens, providers, widgets, models
│   │
│   ├── core/                          # Shared services, models, utilities
│   │   ├── services/                  # [30+ services; business logic + data access]
│   │   ├── models/                    # Domain models; DTOs; data classes
│   │   ├── providers/                 # Global Riverpod providers
│   │   ├── config/                    # App configuration; environment vars
│   │   ├── theme/                     # Material theme
│   │   ├── language/                  # Localization (i18n)
│   │   ├── widgets/                   # Reusable UI components
│   │   ├── utils/                     # Utility functions (loggers, validators)
│   │   ├── validators/                # Input validation (critical)
│   │   └── repositories/              # Data access abstraction layer
│   │
│   ├── systems/                       # Advanced business logic systems
│   │   ├── feed/                      # Feed calculation engines [16 files]
│   │   ├── growth/                    # Growth modeling (FCR, curves)
│   │   ├── planning/                  # Feed plan generation
│   │   ├── pond/                      # Pond lifecycle logic
│   │   ├── water/                     # Water quality models
│   │   ├── supplements/               # Supplement logic
│   │   ├── tray/                      # Seed tray logic
│   │   └── config/                    # System constants
│   │
│   ├── migrations/                    # Database migrations (SQL) [45+ files]
│   │   ├── 001_create_base_tables.sql
│   │   ├── 002_add_rls_policies.sql
│   │   └── [43+ other migrations]
│   │
│   └── assets/
│       └── images/                    # App branding, icons
│
├── android/                           # Android app configuration
│   ├── app/
│   │   └── build.gradle               # Android build config
│   └── local.properties               # Local build overrides
│
├── ios/                               # iOS app configuration
│   ├── Runner.xcproject
│   └── Runner.xcworkspace
│
├── windows/                           # Windows desktop (if supported)
├── macos/                             # macOS desktop (if supported)
├── linux/                             # Linux desktop (if supported)
│
├── pubspec.yaml                       # Dart/Flutter dependencies
├── analysis_options.yaml              # Lint rules
├── README.md                          # Project overview
│
└── [Documentation Files]
    ├── STARTUP_DOCUMENTATION_SECTION_1.md
    ├── STARTUP_DOCUMENTATION_SECTION_2.md
    └── [other docs]


KEY PRINCIPLES:

1. Features are ISOLATED
   ✓ Each feature has its own screens, providers, models
   ✓ No direct dependencies between features
   ✓ Features communicate only via providers

2. Core is SHARED
   ✓ Services (FeedService, PondService) used by multiple features
   ✓ Models (Farm, Pond, Expense) are shared data structures
   ✓ Providers are global dependency injection

3. Systems are SPECIALIZED
   ✓ Complex algorithms (feed engines, growth models) live here
   ✓ Reusable across features
   ✓ Pure Dart (no UI)
   ✓ Testable independently

4. Services are STATELESS
   ✓ No internal state (Riverpod handles state)
   ✓ All methods are pure functions (same input → same output)
   ✓ Dependency injected (for testability)

5. Migrations are VERSIONED
   ✓ Each migration numbered sequentially
   ✓ All run in order on first app launch
   ✓ Immutable (never modified after deployed)
```

---

## 14. DATA LIFECYCLE FLOWS

### Complete Feed Logging Lifecycle

```
┌──────────────────────────────────────────────────────────────────┐
│            FEED LOGGING: DATA LIFECYCLE                          │
└──────────────────────────────────────────────────────────────────┘

PHASE 1: USER INPUT (Farmer logs feed)
  │
  ├─ FeedTimelineCard (UI)
  │   ├─ User taps "Log Feed" button
  │   └─ Opens FeedInputForm dialog
  │
  └─► FeedInputForm Modal
      ├─ Input field: Feed quantity (kg)
      │   └─ Validator: Must be 0.1-50 kg (safety bounds)
      │
      ├─ Input field: Round (1-4)
      │   └─ Validator: Must be active round
      │
      ├─ Optional: Notes
      │
      └─ Submit button: "Log Feed"

PHASE 2: VALIDATION
  │
  └─► FeedInputValidator.validate()
      ├─ Check: Quantity in valid range (0.1-50kg)?
      ├─ Check: Pond exists? (DB lookup)
      ├─ Check: DOC calculated correctly?
      ├─ Check: Stocking density valid?
      ├─ Check: Area valid?
      └─ Return: ValidationResult {isValid, reason}

PHASE 3: LOCAL STORAGE (Offline-safe)
  │
  ├─► SharedPreferences.setString(
  │   key: 'pending_feed_log_{timestamp}',
  │   value: jsonEncode({
  │     pond_id: 'pond123',
  │     feed_given: 5.0,
  │     doc: 45,
  │     round: 2,
  │     timestamp: 2026-05-11T11:00:00Z,
  │     synced: false,
  │   })
  │ )
  │
  └─ Local cache updated immediately (user sees their action)

PHASE 4: SUPABASE UPLOAD (If online)
  │
  └─► FeedService.saveFeed()
      ├─ Call Supabase RPC: safe_insert_feed_log()
      │   └─ Params: {pond_id, doc, round, feed_given, timestamp, ...}
      │
      └─► Supabase Backend (PostgreSQL)
          ├─ Check: Does this (pond, doc, round) already exist?
          │   ├─ If yes: RETURN false (duplicate prevention)
          │   └─ If no: INSERT and trigger cascade
          │
          ├─ INSERT INTO feed_logs (...)
          │   └─ Trigger: feed_logs_after_insert FIRES
          │
          ├─► Trigger: feed_logs_after_insert
          │   │
          │   ├─ INSERT INTO inventory_adjustments
          │   │   ├─ item_id: (feed item for farm)
          │   │   ├─ adjustment_type: 'deduction'
          │   │   ├─ quantity: 5.0 (feed_given)
          │   │   └─ reason: 'Feed log DOC 45 Round 2'
          │   │
          │   └─ Trigger: inventory_adjustments_after_insert FIRES
          │       └─ UPDATE inventory_items
          │           SET expected_stock = expected_stock - 5.0
          │           WHERE id = (farm's feed item)
          │
          └─ COMMIT transaction (all or nothing)

PHASE 5: RESPONSE & VALIDATION
  │
  └─ Supabase returns: {success: true, inserted: true}
     OR {success: true, inserted: false} (duplicate)

PHASE 6: RIVERPOD INVALIDATION
  │
  ├─ feedLogsProvider(pondId).invalidate()
  ├─ feedHistoryProvider(pondId).invalidate()
  ├─ inventoryProvider(farmId).invalidate()
  ├─ dashboardProvider(farmId).invalidate()
  └─ MasterFeedEngine.recalculate() (for tomorrow's recommendation)

PHASE 7: UI REFRESH
  │
  ├─► FeedTimelineCard (ConsumerWidget)
  │   ├─ Watches: feedLogsProvider(pondId)
  │   ├─ Detects: Provider was invalidated
  │   ├─ Rebuilds: With new feed log in list
  │   └─ Displays: Updated list (new entry at top)
  │
  ├─► DashboardScreen (ConsumerWidget)
  │   ├─ Watches: dashboardProvider
  │   ├─ Detects: Invalidation
  │   ├─ Recalculates: Today's feed summary
  │   └─ Updates: "Today: 5kg logged, 2kg remaining"
  │
  └─► InventoryDashboard (ConsumerWidget)
      ├─ Watches: inventoryProvider
      ├─ Detects: Invalidation
      ├─ Recalculates: Expected stock
      └─ Updates: "Feed stock: 245kg (was 250kg)"

PHASE 8: USER FEEDBACK
  │
  ├─ Toast: "Feed logged: 5kg ✓"
  ├─ Haptic feedback (vibration)
  └─ Dismiss dialog; return to feed timeline

DATA AT REST:
  │
  ├─ Supabase PostgreSQL:
  │   ├─ feed_logs: {id, pond_id, doc, round, feed_given, created_at}
  │   └─ inventory_adjustments: {id, item_id, adjustment_type, quantity, reason, created_at}
  │
  ├─ Local cache (SharedPreferences):
  │   └─ pending_feed_logs: {...} (if offline)
  │
  └─ Riverpod in-memory:
      ├─ feedLogsProvider: [latest logs...]
      ├─ inventoryProvider: {stock: 245kg, ...}
      └─ dashboardProvider: {today_fed: 5kg, ...}

TIMELINE:
  T+0ms    | User taps "Log Feed"
  T+50ms   | FeedInputForm opens (instant)
  T+100ms  | User enters 5kg, taps submit
  T+150ms  | Validation runs (150ms)
  T+200ms  | SharedPreferences write (offline-safe)
  T+250ms  | Riverpod state updated
  T+300ms  | FeedTimelineCard rebuilds (UI visible change)
  T+350ms  | Toast appears: "Syncing..."
  T+400ms  | Supabase RPC call (if online; 400ms avg latency)
  T+800ms  | Trigger fires (inventory deduction)
  T+850ms  | Response returns
  T+900ms  | Riverpod invalidation
  T+950ms  | UI refresh with new data
  T+1000ms | Toast: "Feed logged ✓"

OFFLINE SCENARIO:
  T+0-350ms | Same as above (locally cached)
  T+350ms   | Toast: "Syncing..." (but no internet)
  T+2000ms  | Toast: "Saved offline, will sync when online"
  ...
  [When user comes online]
  T+N       | SystemSyncService detects online
  T+N+100ms | Begins uploading pending logs
  T+N+500ms | Log synced to server
  T+N+600ms | Toast: "Synced ✓"
```

---

## Summary: Architecture Principles

1. **Layered Isolation:** Each layer has clear responsibilities; UI ≠ Business Logic ≠ Data Access
2. **Dependency Injection:** Riverpod providers = DI container; services are stateless
3. **Offline-First:** Local write first, sync to cloud async; user never waits
4. **Reactive Updates:** Riverpod watches handle all UI refresh; no manual setState calls
5. **Type Safety:** Dart's strong typing prevents runtime errors
6. **Testability:** Services are decoupled; engines are pure functions
7. **Scalability:** Add new features without modifying existing code; clean boundaries

---

**End of Section 2**

*Prepared for: Technical team, architects, new developers*

*Last Updated: May 11, 2026*

