# AquaRythu Architecture Contract

## Layer Responsibilities

| Layer | Path | Responsibility |
|-------|------|----------------|
| **systems/** | `lib/systems/` | Business logic — pure functions, engines, calculations |
| **core/services/** | `lib/core/services/` | Orchestration, API calls, persistence, cross-cutting concerns |
| **features/** | `lib/features/` | UI screens, widgets, and Riverpod providers |
| **core/models/** | `lib/core/models/` | Pure data classes and enums — no logic |

## Rules

- No business logic in UI (`features/`)
- No heavy calculations in services (`core/services/`) — delegate to `systems/`
- All feed/growth/decision calculations go through `systems/`
- Models hold data only; engines live in `systems/`

## Feed Pipeline (single entry point)

```
UI → provider → FeedService → MasterFeedEngine → FeedPipeline → result
```

- `MasterFeedEngine` (`systems/feed/master_feed_engine.dart`) is the **single entry point** for all feed calculations
- No direct pipeline calls from UI or providers
- `FeedService` (`core/services/feed/feed_service.dart`) orchestrates persistence; delegates calculations to the engine

## Service Domains

```
core/services/
  feed/         → feed_service, feed_config_service, feed_safety_service, feed_savings_service
  farm/         → farm_service, farm_member_service, farm_price_settings_service
  subscription/ → subscription_service, subscription_gate
  decision/     → decision_integration_service, decision_priority_service
  profit/       → profit_service
```

## Systems Domains

```
systems/
  feed/         → master_feed_engine (entry point), pipeline, smart_feed_service, seed_feed_engine, ...
  decision/     → profit_decision_engine, safe_decision_engine
  action/       → daily_action_engine
  growth/       → growth calculations
  planning/     → feed plan generators
  pond/         → pond-level calculations
  tray/         → tray decision engine
  water/        → water quality logic
  supplements/  → supplement calculations
```
