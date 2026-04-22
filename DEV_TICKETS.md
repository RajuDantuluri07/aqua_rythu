# AquaRythu Development Tickets

## 🔴 Ticket 1 — Fix Feed Update Atomicity
**Priority**: Critical  
**Estimated**: 2-3 days  
**Assigned**: TBD

### Problem
- `feed_schedule_provider.dart:updateFeed()` modifies state without atomic database transaction
- Risk of data inconsistency if app crashes during update
- Double updates possible due to missing loading lock

### Tasks
- [ ] Add loading lock to prevent concurrent updates
- [ ] Wrap feed operations in database transaction
- [ ] Ensure state and database are always in sync
- [ ] Add rollback mechanism for failed updates
- [ ] Test crash scenarios

### Files to Modify
- `lib/features/feed/feed_schedule_provider.dart`
- `lib/core/services/feed_service.dart`
- `lib/systems/feed/master_feed_engine.dart`

### Acceptance Criteria
- No double updates possible
- State always reflects database state
- App crash during update doesn't corrupt data
- All feed operations are atomic

---

## 🔴 Ticket 2 — Expense + Feed + Inventory Sync
**Priority**: Critical  
**Estimated**: 3-4 days  
**Assigned**: TBD

### Problem
- No defined calculation flow between expense, feed, and inventory
- Potential mismatch cases causing data inconsistency
- Missing validation between related systems

### Tasks
- [ ] Define calculation flow: feed → cost → expense → inventory validation
- [ ] Implement cross-system validation
- [ ] Fix mismatch cases (feed amount vs inventory deduction)
- [ ] Add audit trail for all operations
- [ ] Create reconciliation reports

### Files to Modify
- `lib/core/services/expense_service.dart`
- `lib/core/services/feed_service.dart`
- `lib/core/services/inventory_service.dart`
- `lib/features/expense/expense_provider.dart`

### Acceptance Criteria
- Clear calculation flow defined and implemented
- All cross-system data validated
- No mismatch cases between systems
- Complete audit trail available

---

## 🔴 Ticket 3 — Remove Dangerous Null Defaults
**Priority**: Critical  
**Estimated**: 2-3 days  
**Assigned**: TBD

### Problem
- Excessive use of `?? 0.0` masking database integrity issues
- Silent data corruption possible
- Missing validation for critical numeric fields

### Tasks
- [ ] Audit all `?? 0.0` usage across codebase (84+ files)
- [ ] Replace with proper validation
- [ ] Log missing/invalid data instead of silent defaults
- [ ] Add database constraints where possible
- [ ] Implement data quality checks

### Files to Modify
- `lib/core/services/expense_service.dart` (line 103, etc.)
- `lib/features/pond/pond_dashboard_provider.dart`
- `lib/features/farm/farm_provider.dart`
- `lib/systems/planning/feed_plan_generator.dart`
- All other files with `?? 0.0` patterns

### Acceptance Criteria
- No silent null defaults for critical data
- All missing data logged and handled appropriately
- Database constraints prevent invalid data
- Data quality monitoring in place

---

## 🟠 Ticket 4 — Move Business Logic Out of UI
**Priority**: High  
**Estimated**: 4-5 days  
**Assigned**: TBD

### Problem
- Business logic scattered across UI layers
- Feed calculations in `pond_dashboard_screen.dart`
- Expense logic mixed with UI components

### Tasks
- [ ] Extract feed logic from UI to service layer
- [ ] Move expense calculations to dedicated service
- [ ] Create business logic layer separation
- [ ] Update UI to only handle presentation
- [ ] Add unit tests for business logic

### Files to Modify
- `lib/features/pond/pond_dashboard_screen.dart`
- `lib/features/expense/add_expense_screen.dart`
- `lib/features/expense/expense_summary_screen.dart`
- Create new: `lib/core/business/feed_calculation_service.dart`
- Create new: `lib/core/business/expense_calculation_service.dart`

### Acceptance Criteria
- UI components only handle presentation
- All business logic in dedicated services
- Clear separation of concerns
- Business logic fully testable

---

## 🟠 Ticket 5 — Optimize Providers
**Priority**: High  
**Estimated**: 2-3 days  
**Assigned**: TBD

### Problem
- Multiple providers watching same data source
- Duplicate network calls in expense provider
- Missing caching layer causing performance issues

### Tasks
- [ ] Remove duplicate fetch operations
- [ ] Implement caching strategy for frequently accessed data
- [ ] Optimize provider dependencies
- [ ] Add cache invalidation logic
- [ ] Performance testing with large datasets

### Files to Modify
- `lib/features/expense/expense_provider.dart`
- `lib/features/pond/pond_dashboard_provider.dart`
- `lib/features/feed/feed_history_provider.dart`
- Create new: `lib/core/cache/cache_manager.dart`

### Acceptance Criteria
- No duplicate network calls
- Efficient caching in place
- Fast loading with large datasets
- Cache properly invalidated when data changes

---

## Implementation Notes

### Dependencies
- Ticket 1 should be completed before Ticket 2
- Ticket 3 should be completed early to prevent data issues
- Ticket 4 and 5 can be done in parallel

### Testing Requirements
- All tickets require comprehensive unit tests
- Integration tests for critical flows
- Performance testing for Ticket 5
- Crash scenario testing for Ticket 1

### Code Review Checklist
- [ ] No hardcoded business logic in UI
- [ ] Proper error handling throughout
- [ ] No silent null defaults
- [ ] Atomic operations where required
- [ ] Efficient data access patterns

### Deployment Strategy
1. Deploy Ticket 3 fixes first (data integrity)
2. Deploy Ticket 1 fixes (atomicity)
3. Deploy Ticket 2 fixes (system sync)
4. Deploy Tickets 4 & 5 (architecture & performance)
