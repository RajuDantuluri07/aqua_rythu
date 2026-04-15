# 🚀 AQUA RYTHU REFACTORING ACTION PLAN

**Status:** System Audit Complete | **Date:** April 15, 2026  
**Priority:** HIGH — Multiple intelligence gaps affecting farm profitability

---

## ⚡ QUICK WINS (This Week)

### 1. Reactivate FCR Feed Adjustment [~3 hours]
**File:** [lib/core/engines/smart_feed_engine.dart](lib/core/engines/smart_feed_engine.dart)  
**Issue:** FCR calculated but disabled (comment line 365)  
**Action:**
```dart
// BEFORE (line ~367)
// fcrFactor = 1.0; // TODO: re-enable with guards

// AFTER
final lastFcr = input.lastFcr;
final fcrFactor = lastFcr != null && (input.sampleAgeDays ?? 999) < 10
  ? FeedFactorEngine.calculateFcrFactor(lastFcr)
  : 1.0;
// Guard: Only apply if FCR data < 10 days old
```
**Test:** If FCR 1.2, feed should increase by 10%  
**Benefit:** Farms improve efficiency automatically

---

### 2. Wire Up Feed Cost Calculation [~2 hours]
**File:** [lib/services/dashboard_service.dart](lib/services/dashboard_service.dart)  
**Issue:** Farm sets feed price/kg but never used  
**Action:**
```dart
// In getPonds() response, add:
final feedPrice = pond['feed_price'] ?? 0.0; // from farm_settings
final dailyCost = totalFeedToDate * feedPrice;
pond['cumulative_feed_cost_rupees'] = dailyCost;
pond['feed_cost_rupees_per_day'] = lastDayFeed * feedPrice;
```
**Test:** In dashboard, show "₹X cumulative feed cost"  
**Benefit:** Farmer sees real expense immediately

---

### 3. Remove Dead Code [~1 hour]
**Files to delete/archive:**
- [lib/core/engines/feed_calculation_engine.dart](lib/core/engines/feed_calculation_engine.dart) ← DEPRECATED
- Move [lib/core/engines/master_feed_engine.dart](lib/core/engines/master_feed_engine.dart) → `_archive/`
- Remove duplicate FeedMode from [lib/core/engines/feed_state_engine.dart](lib/core/engines/feed_state_engine.dart)

**Benefit:** Code clarity, avoid confusion

---

## 📊 NEXT SPRINT (Week 2-3)

### 4. Profit Forecaster Widget [~8 hours]
**Location:** New file `lib/features/dashboard/profit_forecast_card.dart`

**What to show:**
```
Current ABW: 15g | Ideal at DOC 30: 20g | Behind: -25%
↓
At current growth: 50 days to 45g (target harvest)
↓
Projected Yield: (100k shrimp × 0.92 survival × 45g) / 1000 = 4.14 tons
↓
Projected Revenue: 4.14 tons × ₹250/kg = ₹10.35L
Total Feed Cost to date: ₹2.5L (with forecast to harvest: ₹3.1L)
↓
🟢 PROFIT FORECAST: ₹7.25L (70% margin)
```

**Inputs needed:**
- current_abw, doc (from pond)
- dailyFeed, feedPrice (from settings)
- seedCount, survival estimate (from pond)
- sellingPrice (from farm settings)

**Calculation:**
```
days_to_harvest = (targetAbw - currentAbw) / (growthRate per day)
projected_biomass = seedCount × survivalRate × targetAbw / 1000
projected_revenue = projected_biomass × sellingPrice
cumulative_cost = sumOfFeedToDate + (remainingDays × avgDailyFeedCost)
profit_forecast = projected_revenue - cumulative_cost
confidence = ±15% (due to growth variability)
```

---

### 5. Growth Alert System [~6 hours]
**File:** [lib/features/dashboard/growth_alert_card.dart](lib/features/dashboard/growth_alert_card.dart) (new)

**Rules:**
```
if (actualAbw / expectedAbw) < 0.85 for 2+ weeks:
  Alert 🔴: "Growth severely slow — check water quality, reduce density, increase feed"
  
if (actualAbw / expectedAbw) > 1.2:
  Alert 🔵: "Growth excellent — consider early harvest or density reduction"
  
if (latestSample.age > 7 days):
  Alert 🟡: "ABW data stale — update sampling for accurate recommendations"
```

---

### 6. Risk Dashboard [~10 hours]
**File:** New `lib/features/dashboard/risk_summary.dart`

**Monitors:**
| Risk | Trigger | Action |
|------|---------|--------|
| DO dropping | trend: DO -0.5/day for 3d | Check aerator, reduce density |
| Ammonia rising | NH3 >0.05 and rising | Increase water exchange |
| Appetite loss | feedingScore ≤ 2 for 3d | Check water quality, reduce feed |
| ABW stalled | growth < 0.1g/day for 1w | Investigate — possible disease |
| Overfeeding risk | intake < 70% for 2d | Reduce daily feed by 5% |

---

## 🏗️ TECHNICAL DEBT (Next Sprint+)

### 7. Consolidate Feed Engines [~4 hours]
**Current state:** 3 competing implementations
- SmartFeedEngine (ACTIVE) ← Use this
- MasterFeedEngine (ORPHAN) ← Move to archive
- FeedCalculationEngine (DEPRECATED) ← Remove

**Action:**
```
Archive folder structure:
lib/core/engines/_archive/
  ├── master_feed_engine_v0.dart  (historical, do not use)
  ├── feed_calculation_engine_v0.dart
  └── README.md ("These are legacy implementations")

lib/core/engines/ (active):
  ├── smart_feed_engine.dart  (CURRENT: use this)
  ├── feeding_engine_v1.dart  (CURRENT: base feed)
  ├── feed_factor_engine.dart (CURRENT: factors)
  └── ... (others active)
```

### 8. Biomass Validator [~6 hours]
**Goal:** Replace hardcoded survival with measured data

**Approach:**
1. Track stocking count at start
2. Sample for mortality/survival estimates (if possible with farm resources)
3. Store real survival % by DOC in new table: `survival_estimates`
4. Use real data in FCR = feed / (seedCount × realSurvival × ABW / 1000)

**If not feasible:** Add comment in code explaining survival uncertainty

---

## Implementation Sequence

### Week 1 (This Week)
```
Day 1-2: ✅ Reactivate FCR (code change + test)
Day 2-3: ✅ Wire up feed cost display
Day 3-4: ✅ Remove dead code
Day 5: Review with team, deploy to staging
```

Impact: **Immediate cost visibility + efficiency feedback**

### Week 2
```
Day 1-3: Build Profit Forecaster card
Day 3-4: Build Growth Alert system
Day 5: Integrate, test, staging
```

Impact: **Farmer can see profit trajectory before harvest**

### Week 3
```
Day 1-2: Build Risk Dashboard
Day 2-3: Wire water quality trends
Day 3-4: Test, staging
Day 5: Team review, plan Phase 2
```

Impact: **Proactive problem detection**

---

## Testing Checklist

### FCR Reactivation
- [ ] If FCR = 1.2, feed increases by 10% ✅
- [ ] If FCR = 1.5, feed decreases by 10% ✅
- [ ] If FCR data > 10 days old, no adjustment ✅
- [ ] Dashboard shows FCR value correctly ✅

### Feed Cost Integration
- [ ] Daily cost = feed (kg) × price/kg ✅
- [ ] Cumulative cost accumulates ✅
- [ ] Dashboard displays cost with farm currency ✅
- [ ] Works with other adjustments (tray, growth, etc) ✅

### Profit Forecaster
- [ ] Calculates days-to-harvest correctly ✅
- [ ] Projects biomass within ±15% ✅
- [ ] Shows profit/loss forecast ✅
- [ ] Updates daily as new samples added ✅

### Growth Alerts
- [ ] Triggers at correct thresholds (0.85, 1.2, 7-day stale) ✅
- [ ] Provides actionable recommendations ✅
- [ ] Doesn't spam with false positives ✅

---

## Questions to Answer Before Starting

1. **Survival rates:** Can we measure real survival on this farm? Or stick with estimates?
   - **Decision:** _______________
   
2. **Target selling price:** Is this stored per farm? Or use global default?
   - **Location in code:** _______________

3. **Harvest target weight:** Is there a goal ABW? Or assume 45g always?
   - **Location in code:** _______________

4. **Growth rate baseline:** What growth/kg/day do we expect? (empirical data?)
   - **Current assumption:** 0.25 g/day (from sampling_screen.dart)
   - **Confidence:** LOW (should validate)

5. **Cost forecast horizon:** Forecast cost only to expected harvest, or full 120 days?
   - **Decision:** _______________

---

## Files to Create/Modify

### Create (new)
- [ ] `lib/features/dashboard/profit_forecast_card.dart`
- [ ] `lib/features/dashboard/growth_alert_card.dart`
- [ ] `lib/features/dashboard/risk_summary.dart`
- [ ] `lib/core/engines/models/fcr_input.dart` (if needed)

### Modify (existing)
- [ ] [smart_feed_engine.dart](lib/core/engines/smart_feed_engine.dart) ← FCR reactivation
- [ ] [dashboard_service.dart](lib/services/dashboard_service.dart) ← Add feed cost
- [ ] [pond_dashboard_provider.dart](lib/features/pond/pond_dashboard_provider.dart) ← Wire profit card

### Archive/Remove
- [ ] [feed_calculation_engine.dart](lib/core/engines/feed_calculation_engine.dart) → `_archive/`
- [ ] [master_feed_engine.dart](lib/core/engines/master_feed_engine.dart) → `_archive/`
- [ ] Remove duplicate FeedMode from [feed_state_engine.dart](lib/core/engines/feed_state_engine.dart)

---

## Estimated Effort

| Phase | Features | Dev Days | Risk |
|-------|----------|----------|------|
| **Week 1** | FCR + Cost + Cleanup | 1.5 | 🟢 LOW |
| **Week 2** | Profit Forecaster + Growth Alerts | 2.5 | 🟡 MEDIUM |
| **Week 3** | Risk Analyzer | 2 | 🟡 MEDIUM |
| **Total** | Complete intelligence system | ~6 days | 🟡 MEDIUM |

---

## Success Metrics

After implementation, farmer should be able to:

1. ✅ **See real-time feed cost** — "We've spent ₹2.5L on feed so far"
2. ✅ **Know profit trajectory** — "At current pace, we'll profit ₹7L at harvest (70% margin)"
3. ✅ **Get growth prescriptions** — "Your shrimp growth is 15% slow - suggest increasing water exchange"
4. ✅ **See efficiency rewards** — "Your FCR improved; you're feeding more efficiently. Feed adjusted +8%."
5. ✅ **Get early warnings** — "DO trending down; check aerator immediately"
6. ✅ **Plan harvest timing** — "At current growth, you'll reach 45g target in 45 days (June 30)"

**Current state:** 0/6 metrics achieved  
**Target:** 6/6 metrics achieved in 3 weeks

---

## Next Step

**Assign ownership:**
- Week 1 quick wins → __________ (Est: 6 hours)
- Profit Forecaster → __________ (Est: 8 hours)  
- Growth Alerts → __________ (Est: 6 hours)
- Risk Analyzer → __________ (Est: 10 hours)

**Schedule kickoff meeting:** ___________

**Deploy to production:** ___________

---

Generated from: [/Users/sunny/Documents/aqua_rythu/SYSTEM_AUDIT_APRIL_2026.md](SYSTEM_AUDIT_APRIL_2026.md)

