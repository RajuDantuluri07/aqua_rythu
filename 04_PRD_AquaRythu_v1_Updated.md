# PRD — AquaRythu (v1) - Updated Based on Codebase

**Product:** AquaRythu  
**Owner:** Founder / Product Lead  
**Version:** v1 — Feed Discipline & Execution Core  
**Status:** Updated to match current implementation  

## 1. Purpose of This PRD
This PRD defines exactly what is built in AquaRythu v1 based on current codebase analysis.

### v1 Goal (Non-Negotiable)

Create a daily feed-logging and execution habit that reduces feed waste through discipline — not automation.
If a feature does not:
- Improve daily feed execution
- Or strengthen feed discipline
- **It is NOT in v1**

## 2. Product Summary (v1) - CODEBASE REALITY
AquaRythu v1 is a mobile-first feeding command system for shrimp farms that:

✅ **IMPLEMENTED:**
- Auto-generates blind feeding schedule (DOC 1–30 days)
- Allows farmer/supervisor to set final feed quantity in feed schedule 
- Ensures workers execute exactly what is set
- Logs daily feed reliably per pond
- Tracks DOC accurately

- **Smart Feeding System with real-time calculations**
- **Tray-based monitoring system**
- **Water quality tracking**
- **Supplement management system**
- **Growth sampling and mortality tracking**

🚫 **NOT IN v1:**
- Worker login system (single user only)
- Basic vs Advanced modes
- Automated recommendations without farmer oversight

## 3. Target Users

### Primary User — Farmer / Owner (Economic Buyer)
- Owns 1–20 ponds
- Decides or approves daily feed quantity
- Highly cost-sensitive
- Wants control without complexity

### Secondary User — Worker / Technician 
- Physically feeds ponds
- Logs feed in the app
- Low tech comfort
- Needs zero ambiguity
- **CURRENTLY: Same user as farmer (no separate login)**

## 4. Core User Journey (End-to-End)

### 4.1 First-Time Experience (Day 0)
✅ **IMPLEMENTED:**
- Open app
- Enter phone number (OTP) & Email Login
- Create Farm (name, location)
- Add Pond with:
  - Pond name
  - Pond size (Area)
  - Stocking count
  - PL Size
  - No of Trays
  - Stocking date
- App auto-generates blind feeding schedule (DOC 1–30)

**Success Criteria:** The farmer sees a ready-to-use feeding plan within 2 minutes.

### 4.2 Daily Usage — Blind Feeding Phase (DOC 1–30)
✅ **IMPLEMENTED:**
Farmer/Supervisor:
- Reviews auto blind feed
- Edits if required via Feed Schedule Screen
- Sets final feed quantity

**Feed Execution:**
- Opens Pond Dashboard
- Sees today's feed rounds (4 rounds)
- Executes and logs feed via Smart Feed Round Cards
- **Tray logging optional before DOC 30**

**Success Criteria:** Feed logged in <10 seconds, no confusion.

### 4.3 Daily Usage — Smart Feeding Phase (DOC 30+)

✅ **IMPLEMENTED:**
- **Smart Feed Provider calculates real-time feed recommendations**
- **Tray monitoring becomes MANDATORY**
- **Water quality integration**
- **Adjustment reasons displayed**
- **Manual override capability**
- **After sampling at any doc above smart feeding calauctes on feed quantity & Logice**

- Planned feed (from blind schedule)
- Smart feed (real-time calculation)
- Actual feed (logged by user)
- Farmer decides final quantity

## 5. Functional Requirements (What's Built)

### 5.1 Farm Setup ✅ IMPLEMENTED
- Create farm with name and location
- Farm type selection (Semi-Intensive)
- Multi-farm support with switching

### 5.2 Pond Management ✅ IMPLEMENTED
- Add unlimited ponds
- Pond name, size, stocking date, count, PL size, tray count
- **Current ABW tracking**
- **Pond status management**
- **Edit capability**

### 5.3 Blind Feeding Schedule ✅ IMPLEMENTED
- Auto-generated on pond creation
- DOC 1–30 with 4-round split
- **Fully editable via Feed Schedule Screen**
- **Save functionality**
- **Real-time validation**

### 5.4 Smart Feeding System ✅ IMPLEMENTED
**CORE FEATURE - NOT IN ORIGINAL PRD:**
- **Smart Feed Provider with real-time calculations**
- **Integration with:**
  - Water quality (DO, ammonia, pH)
  - Tray status monitoring
  - Mortality logs
  - Growth sampling data
  - Historical feed data
- **Adjustment reasons display**
- **Manual override dialogs**
- **Stop-feeding alerts**

### 5.5 Feed Logging ✅ IMPLEMENTED
- **Smart Feed Round Cards** with:
  - Planned vs Smart vs Actual comparison
  - Editable feed input
  - Override capability
  - Tray logging CTA (after DOC 30)
- **Multiple entries per day**
- **Edit capability**
- **Supplement integration**

### 5.6 Tray Monitoring ✅ IMPLEMENTED
**CORE FEATURE - NOT IN ORIGINAL PRD:**
- **Tray logging screen**
- **Tray status tracking**
- **Integration with Smart Feed Engine**
- **Mandatory after DOC 30**
- **Status options: Clean, Partial, Full, Empty**

### 5.7 Water Quality ✅ IMPLEMENTED
**CORE FEATURE - NOT IN ORIGINAL PRD:**
- **Water test logging**
- **Parameters: DO, ammonia, pH, temperature**
- **Integration with Smart Feed calculations**
- **Historical tracking**

### 5.8 Growth & Mortality ✅ IMPLEMENTED
**CORE FEATURE - NOT IN ORIGINAL PRD:**
- **Sampling screen with ABW measurement**
- **Mortality logging**
- **Growth tracking**
- **Integration with Smart Feed Engine**

### 5.9 Supplement Management ✅ IMPLEMENTED
**CORE FEATURE - NOT IN ORIGINAL PRD:**
- **Supplement planning**
- **Feed mix supplements**
- **Water application supplements**
- **Automated dosage calculations**
- **Application logging**

### 5.10 Dashboard (Home) ✅ IMPLEMENTED
**Today Overview:**
- Active ponds count
- **Total Biomass calculation**
- **Feed Consumed tracking**
- **EST FCR calculation**
- **Avg Growth calculation**
- **Health indicators**

**Pond Cards:**
- Pond name, DOC, size, status
- **ABW, Feed, FCR, Survival metrics**
- **Real-time data**
- **Edit capability**

### 5.11 Pond Dashboard ✅ IMPLEMENTED
**Pond Summary:**
- DOC, Area, ABW, FCR
- **Feed phase indicator**
- **Smart feeding status**

**Daily Feed Progress:**
- **Consumed / Planned tracking**
- **Progress bar**
- **Real-time updates**

**Feed Rounds List:**
- **4 rounds with time schedules**
- **Status: READY, NEXT, UPCOMING, DONE**
- **Smart Feed integration**
- **Editable feed amounts**

**Quick Actions:**
- Sampling ✅
- Water ✅
- **Supplements** ✅
- Harvest ✅
- History ✅

## 6. Technical Implementation Details

### 6.1 Feed Logic ✅ IMPLEMENTED
**Case 1: DOC ≤ 30 (Starter Phase)**
- Shows planned feed
- Smart feed calculated but optional
- Tray logging optional

**Case 2: DOC > 30 & NO Sampling**
- Smart feed active
- Tray logging recommended

**Case 3: Sampling Done (ANY DOC)**
- Smart feed ENABLED with ABW data
- Tray logging mandatory after DOC 30

### 6.2 Round Status Logic ✅ IMPLEMENTED
- **READY:** Current time ≥ round time & not completed
- **NEXT:** Next upcoming round
- **UPCOMING:** Future rounds
- **DONE:** Actual > 0

### 6.3 User Actions ✅ IMPLEMENTED
**Feed Logging:**
- Tap round
- Edit "Actual Feed" via override dialog
- Save with confirmation
- **Editable again**

**Tray Logging:**
- Mandatory after DOC 30
- Status selection
- Photo support

## 7. What's NOT in v1 (Based on Codebase)

🚫 **Worker Login System** - Single user only
🚫 **Multi-user pond assignment** - Farmer manages all
🚫 **Basic vs Advanced modes** - Single unified interface
🚫 **Automated feeding** - Manual execution only
🚫 **IoT integration** - Manual data entry
🚫 **Weather integration** - Basic weather card only
🚫 **Predictive analytics** - Reactive calculations only

## 8. Production Readiness

### 8.1 ✅ IMPLEMENTED Features
- All core feed functionality
- Smart feeding system
- Tray monitoring
- Water quality tracking
- Growth sampling
- Supplement management
- Dashboard metrics
- Data persistence
- Error handling

### 8.2 🔧 TECHNICAL DEBT
- TODO items resolved
- Null safety implemented
- Error handling added
- Production optimizations complete

## 9. Success Metrics (v1)

### 9.1 User Engagement
- Daily feed logging consistency
- Tray logging compliance after DOC 30
- Feed schedule editing frequency

### 9.2 Business Impact
- Feed waste reduction
- FCR improvement
- Farmer retention

### 9.3 Technical Performance
- App load time < 3 seconds
- Feed logging < 10 seconds
- 99.9% uptime

## 10. v2 Considerations (Based on Codebase Gaps)

### 10.1 Worker Management
- Multi-user support
- Role-based access
- Worker assignment to ponds

### 10.2 Advanced Analytics
- Predictive feeding
- Trend analysis
- Benchmarking

### 10.3 Automation
- IoT sensor integration
- Automated recommendations
- Alert systems

---

**Note:** This PRD reflects the ACTUAL current implementation as analyzed from the codebase, not the originally planned features. The app is more advanced than originally planned with smart feeding, tray monitoring, and supplement management fully implemented.
