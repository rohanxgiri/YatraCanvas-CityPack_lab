# YatraCanvas City Pack Manual QA & Release Certification Guide

This document defines the formal, human-centered protocol for auditing and certifying a DataFactory City Pack release before it can be merged or deployed into the main YatraCanvas travel mobile app.

---

## The Certification Protocol

The testing workflow guides an auditor through a 5-step evaluation protocol designed to take **15–20 minutes per city pack**:

```
┌────────────────────────────────────────────────────────────────────────┐
│                      CITY PACK AUDITOR PROTOCOL                        │
├──────────────────┬─────────────────┬──────────────────┬────────────────┤
│ 1. Executive     │ 2. Coverage     │ 3. Stratified    │ 4. Release     │
│    Overview      │    & Gap Audit  │    Manual QA     │    Gate & Cert │
│   (10-sec scan)  │   (Matrix/Gaps) │   (50 places)    │    (Export)    │
└──────────────────┴─────────────────┴──────────────────┴────────────────┘
```

---

### Step 1: Open Pack & 10-Second Executive Scan (Overview Screen)

1. Launch **City Pack Lab** and select your target city (e.g., **Jaipur**, **Manali**, **Rishikesh**, **Panaji**, or **Gulmarg**).
2. The **Overview Screen** opens with an immediate executive health scan:
   - **Release Status Badge**: Shows `READY`, `REVIEW_REQUIRED`, or `BLOCKED`.
   - **Primary KPI Cards**:
     - **Data Quality Score (0–100)**: Must be `>= 70.0` for release.
     - **Travel Readiness Score (0–100)**: Must be `>= 60.0` for release.
     - **Manual QA Health**: Initially displays `NOT STARTED (0/50)`.
     - **Critical Blockers**: Lists any condition currently barring release.
3. Check the **Dataset Scan Details**:
   - Total places count, Core destinations count, Local images count, and Database file size.
4. If the pack is `BLOCKED`, review the red **Critical Blockers Box** at the bottom of the overview. Note the specific blockers (e.g. "Manual QA sample not started (0/50 completed)", "Data Quality score below 70.0").

---

### Step 2: Coverage Matrix & Data Gap Analysis (Data Coverage Screen)

1. Switch to the **Data Coverage** tab.
2. Review the **Category Coverage Matrix**:
   - Verify that primary travel categories have adequate representation:
     - `Heritage / Attractions`: Minimum 5 Core places for anchor itineraries.
     - `Food & Cafes`: Ample dining options with hours coverage.
     - `Nature / Scenic`: Viewpoints, trails, and parks.
     - `Religious / Cultural`: Historical temples, mosques, churches, or cultural centers.
   - Observe the **Photos %** and **Hours %** columns for each category.
3. Scroll down to the **Data Gap Analyzer**:
   - **Missing Core Hero Photos**: Highlights anchor attractions lacking bundled photos.
   - **Missing Operating Hours**: Identifies attractions and food POIs where visitors could be sent during closed hours.
   - **Coordinate Outliers**: Flags places located outside the official city bounding box coordinates.
4. Tap **View Places** on any gap card to open a bottom sheet drill-down, listing every affected place name, ID, and category.

---

### Step 3: Complete Stratified 50-Item Manual QA (Review Screen)

The system automatically prepares a **50-place stratified review queue** representing a statistically balanced cross-section:
- **Bucket 1**: Top Core Attractions (15 places)
- **Bucket 2**: Recommended Highlights (15 places)
- **Bucket 3**: Food & Cafes (8 places)
- **Bucket 4**: High-Relevance Discovery (7 places)
- **Bucket 5**: Hidden Gems / Long-Tail (5 places)

#### Auditor Instructions for Each Place Card:
1. Examine the **Place Card**:
   - **Name & Alternate Name**: Is the English and Hindi name authentic and free from OCR garbage?
   - **Category & Subcategory**: Is a hardware store incorrectly classified as an attraction?
   - **Tier Badge**: Does a commercial shop or ordinary hotel hold an unearned `Core` tier?
   - **Image**: Does the image accurately portray this specific landmark, or is it irrelevant?
   - **Explainable Quality Tags**: Note whether the engine tagged the record with `Clean`, `In City Bounds`, `Multi-Source`, or `Missing Image`.
2. Record your evaluation:
   - If acceptable: Tap **LOOKS GOOD** (Green).
   - If defective: Tap **FLAG ISSUE** and select the appropriate defect code:
     - `WRONG_CATEGORY`: Misclassified category or subcategory.
     - `WRONG_LOCATION`: Bad coordinates, placed in wrong district/state.
     - `BAD_IMAGE`: Inaccurate photo, blurry, or showing wrong landmark.
     - `WRONG_NAME`: Malformed name, phone number in title, spam.
     - `DUPLICATE`: Same entity mapped under multiple IDs.
     - `NOT_TRAVEL_RELEVANT`: Industrial plant, toilet, utility depot.
     - `SHOULD_NOT_BE_CORE`: Low-importance place promoted to Core.
     - `STALE_CLOSED`: Permanently closed venue.
3. Track the **Progress Header**:
   - Monitor the counter advancing from `0/50` to `50/50`.
   - Once all 50 items are audited, the QA state automatically transitions from `PENDING` to `SUFFICIENT_SAMPLE`.

---

### Step 4: Release Gate Evaluation (Release Gate Screen)

1. Navigate to the **Release Gate** tab.
2. Review the automated **7-Gate Verification Checklist**:
   - [ ] **Valid Schema & Database**: SQLite opens cleanly without corruption.
   - [ ] **Core Coordinate Integrity**: 100% of Core places fall within city bounds.
   - [ ] **Core Media Sufficiency**: At least 60% of Core places have local hero photos.
   - [ ] **Minimum Core Depth**: At least 5 Core destination landmarks.
   - [ ] **Data Quality Score**: Score meets or exceeds 70.0 / 100.
   - [ ] **Travel Readiness Score**: Score meets or exceeds 60.0 / 100.
   - [ ] **Manual QA Verification**: At least 50 places audited with a defect rate <= 10.0%.
3. If any gate fails, inspect the **Release Blockers** section for specific remediation instructions.
4. If non-fatal warnings exist (e.g., secondary category opening hours below 50%), evaluate whether they impact travelers significantly.

---

### Step 5: Export Certified Production Artifacts

1. When the status displays `READY` (or `REVIEW_REQUIRED` with signed justification), tap **Export Certified Release**.
2. The export service generates three release artifacts in `ApplicationDocuments/qa_exports/`:
   - **`<city>_release.json`**: Machine-readable pass/fail release manifest with SHA256 checksums, gate results, and auditor timestamp.
   - **`<city>_quality_report.json`**: Complete 8-dimension data quality and 5-dimension travel readiness score breakdown.
   - **`<city>_release_report.md`**: Human-readable markdown audit summary suitable for pull request or release sign-off documentation.
3. Deliver the exported artifacts to the release engineering pipeline or commit them into the city pack release repository.
