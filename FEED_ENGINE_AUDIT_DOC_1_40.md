# Feed Engine Audit — Blind Feed (DOC 1–30), Smart Activation, and Late Onboarding (DOC 40+)

Date: 2026-05-05

## Scope
- Validate blind feeding behavior across DOC 1–30.
- Validate smart feed activation rules at DOC 31+.
- Validate edge cases for late onboarding (stock added after DOC 40).

## What was audited
- `lib/systems/feed/master_feed_engine.dart`
- `lib/systems/planning/feed_plan_generator.dart`
- `lib/systems/feed/blind_feeding_engine.dart`
- Existing internal audit docs:
  - `FEATURE_GATING_AUDIT.md`
  - `BLIND_FEEDING_ARCHITECTURE.md`

## Findings

### 1) Blind feed DOC 1–30 logic is correctly enforced
- `isBlindPhase = input.doc <= 30`.
- `shouldUseSmartFeeding` only when `input.doc > 30`.
- `useBlindFeeding = forceBlindFeeding || !shouldUseSmartFeeding` guarantees blind mode for DOC 1–30.
- Tray/environment factors are neutralized in blind mode (`trayFactor = 1.0`, env factor not applied).

Status: ✅ PASS

### 2) Smart feed activation gates are mostly correct
- Activation threshold is `DOC > 30` (starts at DOC 31).
- FREE users are forced blind by `!SubscriptionGate.isPro`.
- PRO users can use smart flow after DOC 30, if admin smart feed is enabled.

Status: ✅ PASS

### 3) Edge case found and fixed: DOC 31 instruction incorrectly showed “Smart Mode Active” for forced-blind users
Problem:
- At DOC 31, recommendation text used `if (input.doc == 31)` and always displayed smart activation guidance.
- This could mislead FREE users (or when admin disables smart feed), because their computation is still blind.

Fix applied:
- Condition changed to only show smart activation message when `input.doc == 31 && !useBlindFeeding`.

Status: ✅ FIXED

### 4) Late onboarding DOC 40+ behavior
- Feed plan pre-generation intentionally caps at DOC 30 in `ensureFutureFeedExists`.
- For DOC 31+, engine computes feed live via `orchestrate` and does not depend on pre-generated rows.
- This supports late onboarding at DOC 40+ as long as pond state is complete.

Status: ✅ PASS (by design)

## Recommended checks for QA (manual)
1. FREE user at DOC 31: verify recommendation does **not** show smart activation text.
2. PRO user at DOC 31 with smart feed enabled: verify recommendation shows smart activation text once and applies smart factors.
3. Onboard pond directly at DOC 40:
   - Verify orchestration returns non-zero feed (with valid density).
   - Verify no dependency on `feed_rounds` pre-generation beyond DOC 30.

## Final verdict
- Blind feed DOC 1–30: compliant.
- Smart activation DOC 31+: compliant after one messaging fix.
- Late onboarding DOC 40+: supported by live computation path.
