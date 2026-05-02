# End-to-End Farmer Workflow Test Report

## Simulated Workflow Steps
1. **Create farm**: Implemented via `AddFarmScreen`
2. **Add pond**: Implemented via `AddPondScreen`
3. **Start crop**: Set up within pond/farm creation workflow (`NewCycleSetupScreen`)
4. **View feed plan**: Handled in `FeedScheduleScreen` / `FeedHistoryScreen`
5. **Log tray**: Implemented via `TrayLogScreen`
6. **Do sampling**: Handled via `SamplingScreen`
7. **Check dashboard**: Centralized via `DashboardScreen` (and fixed versions)
8. **View profit (if PRO)**: Implemented via `ProfitSummaryScreen` using `AccessControlHooks`

## Identified Issues

### 1. Missing Steps
- There is not always a direct path from Feed Schedule directly to Tray Logging; users may have to back out to the pond dashboard or home to access it directly.

### 2. Broken Navigation
- Admin routes (`/admin/passcode` and `/admin/dashboard`) are currently commented out in `lib/routes/app_routes.dart`, which breaks access to administrative functions.
- Missing dependencies or unhandled compile-time errors due to enum refactoring (`TrayStatus`) exist across multiple screens, causing build failures instead of just navigation failures.

### 3. Dead Screens
- When `FeatureFlags.isInventoryVisible` or `FeatureFlags.isExpenseVisible` are false, the app routes users to `_FeatureDisabledScreen` ("Coming Soon" screens). These act as dead ends by design but hinder a full workflow simulation for features like logging expenses for profit calculation.

### 4. Confusing UX
- **Inconsistent Tray Statuses**: The application exhibits conflicting naming for tray states. The canonical enum (`TrayStatus`) defines `empty`, `light`, `medium`, and `heavy`, but multiple areas of the codebase (e.g., `home_builder.dart`, `master_feed_engine.dart`) attempt to reference `full`, `partial`, and `completed`. This creates a confusing developer UX and runtime failures.
- **N+1 Queries**: Known memory notes indicate that some query structures currently risk high latency by not properly leveraging batched `.in_()` filtering consistently, slowing down dashboard loads.
