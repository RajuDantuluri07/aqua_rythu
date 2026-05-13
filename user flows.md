# AquaRythu — Final User Flows (V1 Launch)

## Product Philosophy

AquaRythu is designed as a practical farm operating system for shrimp farmers.

Core principle:

> Simple onboarding → daily usage → smart feeding trust → measurable savings → paid conversion.

The app should feel:

* Fast
* Low-friction
* Farmer-first
* Data-driven
* Trustworthy

---

# 1. New User Onboarding Flow

## Goal

Get farmer from install → first pond setup → first feed recommendation as fast as possible.

## Flow

### Step 1 — Splash Screen

* AquaRythu logo
* Tagline:

  * “Smart Shrimp Farming Assistant”
  * OR
  * “Reduce Feed Waste. Increase Profit.”

---

### Step 2 — Language Selection

* Telugu
* English
* Tamil (future)

Save preference locally.

---

### Step 3 — Login / Authentication

Options:

* Phone OTP
* Google Sign In

Minimal friction.

---

### Step 4 — Farmer Profile Setup

Fields:

* Farmer name
* Mobile number
* Village
* State
* Farm type

Optional:

* Profile image

---

### Step 5 — Add Farm

Fields:

* Farm name
* Location
* Total acres
* Water type

Actions:

* Save farm
* Add first pond

---

# 2. Pond Creation Flow

## Goal

Create operational pond profile.

## Step-by-Step

### Pond Details

Fields:

* Pond name/number
* Pond size
* Culture type
* Liner / soil pond
* Aeration count

---

### Stocking Details

Fields:

* DOC start date
* Seed source
* Density
* PL count
* Nursery/Hatchery seed

---

### Feed Initialization

System auto-generates:

* Feed schedule
* Initial feeding amount
* DOC progression

Rule:

* DOC 1–30 = blind feeding mode
* DOC > 30 = smart feeding eligible
* Sampling immediately enables smart feed engine

---

### Confirmation

User sees:

* Pond summary
* Current DOC
* Today's feed recommendation

CTA:

* “Start Managing Pond”

---

# 3. Home Dashboard Flow

## Goal

Farmer opens app daily and instantly understands pond health.

## Dashboard Sections

### Top Summary Cards

* Total ponds
* Today's total feed
* Active alerts
* Estimated biomass

---

### Pond Cards

Each pond card shows:

* Pond name
* DOC
* Feed today
* ABW
* FCR
* Growth status
* Feed trend
* Risk indicator

Color indicators:

* Green = healthy
* Yellow = caution
* Red = risk

---

### Smart Insights Section

Examples:

* “Feed reduced by 8% due to low tray response.”
* “Growth below expected curve.”
* “FCR improving this week.”

---

### Daily Actions

Quick buttons:

* Feed
* Tray
* Sampling
* Expenses
* Water check

---

# 4. Daily Feeding Flow

## Core Product Flow

This is the most important user journey.

## Flow

### Step 1 — Open Pond

User selects pond.

---

### Step 2 — Feed Recommendation Screen

System shows:

* Recommended feed
* Previous feed
* Difference
* Feeding confidence
* Why recommendation changed

Engine Inputs:

* DOC
* Tray factor
* Growth factor
* Environmental factor
* Feed history
* Sampling data
* Manual overrides

---

### Step 3 — Farmer Action

Options:

* Accept recommendation
* Increase manually
* Decrease manually

If manual override:

* Ask reason

  * Strong tray
  * Weak tray
  * Weather
  * Farmer intuition
  * Other

---

### Step 4 — Feed Log

Save:

* Feed quantity
* Feed brand
* Feed type
* Feeding time

---

### Step 5 — Engine Update

System recalculates:

* Biomass
* FCR
* Feed trend
* Consumption pattern

---

# 5. Tray Observation Flow

## Goal

Capture feeding behavior.

## Flow

### Step 1 — Select Pond

---

### Step 2 — Enter Tray Response

Options:

* Full feed remaining
* 75% remaining
* 50% remaining
* 25% remaining
* Clean tray

---

### Step 3 — Add Context

Optional:

* Rain
* Low oxygen
* Molting
* Stress
* Disease suspicion

---

### Step 4 — Smart Adjustment

System computes:

* tray_factor
* smart_factor
* final_factor

Debug values hidden from normal users.

---

### Step 5 — Recommendation Update

System suggests:

* Reduce feed
* Maintain feed
* Increase feed

With explanation.

---

# 6. Sampling Flow

## Goal

Enable growth intelligence.

## Rules

* Nursery seed → DOC 30
* Hatchery seed → DOC 45–50
* Repeat every 7–10 days

---

## Flow

### Step 1 — Start Sampling

Select pond.

---

### Step 2 — Enter Sampling Data

Fields:

* Shrimp count
* Total sample weight
* Survival estimate
* Notes

---

### Step 3 — Auto Calculations

System computes:

* ABW
* Biomass
* Survival
* FCR
* Growth rate

---

### Step 4 — Growth Intelligence

Compare actual vs ideal curve.

Statuses:

* Slow
* Medium
* Good
* Fast

---

### Step 5 — Feed Engine Sync

Sampling immediately activates smart feeding.

---

# 7. Growth Intelligence Flow

## Goal

Make growth tracking addictive and useful.

## Components

### Growth Curve

Graph:

* Expected growth
* Actual growth

---

### Growth Status Engine

Shows:

* Growth performance
* Weekly trend
* Projected harvest size

---

### Prediction Layer

Forecast:

* Harvest biomass
* Feed requirement
* Profit estimate

---

# 8. Expense & Profit Flow

## Goal

Show farmer real financial impact.

## Expense Categories

* Feed
* Seed
* Electricity
* Labor
* Medicine
* Probiotics
* Diesel
* Misc

---

## Profit Dashboard

Metrics:

* Total investment
* Feed cost percentage
* Expected revenue
* Profit estimate
* Cost per kg

---

## Smart Insights

Examples:

* “Feed cost higher than normal.”
* “FCR improvement may save ₹25,000.”

---

# 9. Alerts & Risk Engine Flow

## Goal

Increase daily engagement.

## Alert Types

* Missed feed
* Missing tray entry
* Slow growth
* High FCR
* Sudden feed drop
* Sampling due
* Harvest approaching

---

## Risk Dashboard

Risk levels:

* Low
* Medium
* High

Potential reasons:

* Poor growth
* Overfeeding
* Inconsistent tray
* Survival drop

---

# 10. Feed Requirement Overview Flow

## Goal

Help planning and inventory management.

## Views

### Tomorrow Feed

Total feed needed tomorrow.

---

### 7-Day Forecast

Projected weekly requirement.

---

### 25-Day Forecast

Long-term planning.

Useful for:

* Dealers
* Bulk purchase
* Inventory prediction

---

# 11. Multi-Pond Management Flow

## Goal

Manage multiple ponds easily.

## Features

* Compare ponds
* Sort by DOC
* Sort by risk
* Sort by FCR
* Sort by growth

---

## Comparison Metrics

* Feed efficiency
* Growth speed
* Biomass
* Feed cost
* Profitability

---

# 12. Role-Based Access Flow

## Roles

### Owner

Full access.

### Supervisor

Operational access.

### Worker

Restricted access.

---

## Worker Permissions

Allowed:

* Feed logs
* Tray logs

Restricted:

* Profit data
* Settings
* Reports

---

# 13. Reports Flow

## Goal

Generate trust and professionalism.

## Report Types

* Crop summary
* Feed history
* Growth report
* Expense report
* Harvest projection

---

## Export Options

* PDF
* Share
* WhatsApp

---

# 14. Paywall & Monetization Flow

## FREE PLAN

Limits:

* 1 farm
* 3 ponds
* Basic feed engine
* DOC 1–30 schedule
* Basic dashboard
* Manual tray logging

---

## PRO PLAN

Pricing:

* ₹999 per crop
* ₹2999 yearly

Features:

* Full smart feed engine
* Growth intelligence
* Profit intelligence
* Multi-pond analytics
* Reports
* Comparison systems
* Role-based access

---

## Upgrade Trigger Moments

Show paywall when:

* Farmer sees savings
* Wants advanced analytics
* Wants reports
* Wants multiple ponds
* Wants comparison features

---

# 15. Daily Retention Loop

## Daily User Habit Loop

Morning:

* Open app
* Check feed
* Feed shrimp

Afternoon:

* Enter tray response
* Review recommendation

Weekly:

* Sampling
* Growth tracking
* Profit review

Monthly:

* Compare performance
* Optimize feeding

---

# 16. Core App Architecture Thinking

## Core Engine Layers

### Layer 1 — Farm Data

* Farms
* Ponds
* DOC
* Stocking

### Layer 2 — Operational Logs

* Feed
* Tray
* Sampling
* Expenses

### Layer 3 — Intelligence Engine

* Smart feeding
* Growth engine
* Risk engine
* Profit engine

### Layer 4 — Monetization Layer

* Paywall
* Reports
* Premium analytics

---

# 17. Final V1 User Experience Goal

Farmer should feel:

* “This app understands my pond.”
* “This app saves feed.”
* “This app helps me make decisions.”
* “I cannot manage ponds without this.”

That emotional dependency is the real product moat.

---

# 18. V1 Success Metrics

## Engagement

* Daily active usage
* Tray entries per day
* Feed logs per pond

---

## Intelligence Trust

* Recommendation acceptance rate
* Override frequency
* Sampling consistency

---

## Business Metrics

* Free → paid conversion
* Retention
* Feed savings reported
* Referral rate

---

# 19. Final North Star

AquaRythu should evolve from:

Feed Calculator → Smart Farm Operating System → Aquaculture Intelligence Platform.
