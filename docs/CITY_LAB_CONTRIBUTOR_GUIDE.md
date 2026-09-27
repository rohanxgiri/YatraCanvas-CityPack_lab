# YatraCanvas City Pack Curation Studio — Contributor Guide

Welcome to the **YatraCanvas City Pack Curation Studio**! 

Whether you are a local scout, travel enthusiast, or developer, this guide will help you verify places, correct inaccurate data, add missing sights, and prepare a city for the YatraCanvas mobile app.

---

## 1. Safety Rules (Non-Negotiables)

To keep our data reliable and conflict-free across dozens of contributors, please observe these essential rules:

1. **NEVER manually edit generated database files**: Do not touch `yatracanvas.db` directly. All changes must be made through the Curation Studio interface.
2. **NEVER invent or fabricate data**: If opening hours or contact numbers are uncertain, leave them blank or flag the place for later verification.
3. **DO cite sources for overrides**: When correcting opening hours, coordinates, or categories, provide a valid source (official tourism board, ticket photo, official website, or personal visit).
4. **DO work in a dedicated Git branch**: Keep your work isolated so we can review and merge your curation pull requests smoothly.

---

## 2. Quick Start (5 Minutes)

### Prerequisites
- [Git](https://git-scm.com/) installed
- [Flutter SDK](https://flutter.dev/docs/get-started/install) installed (version 3.19+)
- A Windows PC or Mac/Linux with Google Chrome

### Step 1: Clone Repository & Create Branch
```bash
git clone https://github.com/rohanxgiri/YatraCanvas-CityPack-Lab.git
cd YatraCanvas-CityPack-Lab

# Create your personal curation branch
git checkout -b curate/jaipur-updates
```

### Step 2: Run One-Command Setup
On Windows PowerShell:
```powershell
.\citylab.ps1 setup
```
*(This automatically checks your Flutter install, downloads dependencies, and verifies that city packs exist in `assets/city_packs/`.)*

### Step 3: Launch Curation Studio
```powershell
# Launch on Windows Desktop (default)
.\citylab.ps1 start

# Or launch in Google Chrome
.\citylab.ps1 start -Target chrome
```

---

## 3. How to Curate a City

When City Lab opens:
1. **Choose your city**: Click **Select City Pack** and pick your city (e.g. *Jaipur*).
2. **Review the Home Dashboard**: Within 10 seconds, you'll see:
   - **City Health Score** (0–100)
   - **Fix Center tasks** (Missing photos, missing hours, location issues)
   - **Manual Verification progress** (e.g., 12/50 completed)
   - **Current Release status** (Ready, Review Required, or Blocked)

### Task A: The Fix Center (Fastest way to contribute)
Click **Start Fixing** from the Home screen or go to the **Fix** tab in the top navigation:
- Select an issue category (e.g. *Missing Opening Hours* or *Missing Photos*).
- Click **Fix** next to any place.
- In the popup dialog:
  - **Hours**: Choose standard presets (e.g. 09:00–17:00, 24 Hours, or Day-by-Day schedule) and cite your evidence.
  - **Photos**: Review existing images or assign a verified photo path.
  - **Coordinates**: Enter exact latitude/longitude or nudge the pin if plotted off-center.
- Click **Save Correction**. The task will clear immediately and the City Health score will recalculate!

### Task B: Manual QA Verification
Go to the **Review** tab in the navigation:
- You will be presented with randomly sampled places across categories and tiers.
- For each place, inspect the name, photo, category, and coordinates:
  - If everything looks good: Click **Yes, Looks Good**.
  - If something is wrong: Click **Something is Wrong**, pick the defect (e.g. *Wrong Photo*, *Wrong Category*), and either **Fix Now** or **Flag for Later**.
- Complete at least **50 reviews** to satisfy the release gate requirement.

### Task C: Adding a Missing Sight (+ Add Place)
Notice an important local temple, museum, or landmark missing from the city pack?
1. Go to the **Places** tab.
2. Click **+ Add Place** in the top right.
3. Follow the 5-step wizard:
   - **Step 1**: Name, Hindi Name, Category, Tier (Core Destination vs. Standard).
   - **Step 2**: Coordinates & Address.
   - **Step 3**: Opening hours, description, website, and evidence source.
   - **Step 4**: Primary image path.
   - **Step 5**: Review & Submit.
4. The new place is saved to `assets/city_packs/<city>/curation/additions/` and immediately integrated into the city dataset.

### Task D: Excluding Inappropriate Places
If a place in the pack is permanently closed, private corporate property, or irrelevant for travelers:
1. Open the place in the **Places** tab.
2. Click **Exclude Place** in the toolbar.
3. Select an exclusion reason (e.g. *Permanently Closed*, *Restricted Facility*, *Duplicate Entry*).
4. Click **Confirm Exclusion**.
*(Note: Original source data is never destroyed; the place is safely hidden from tourist itineraries and can be restored at any time.)*

---

## 4. Submitting Your Work via Git

When you are done curating:

### Step 1: Generate Curation Summary
Run the summary command to see everything you touched:
```powershell
.\citylab.ps1 summary -City jaipur
```
This prints a clean summary table of:
- Number of field overrides (hours, photos, coordinates, categories)
- Newly added places
- Excluded places
- Manual reviews completed

### Step 2: Inspect Git Status
```bash
git status
```
You will notice clean JSON files added inside `assets/city_packs/jaipur/curation/`:
```text
assets/city_packs/jaipur/curation/overrides/osm_12345.json
assets/city_packs/jaipur/curation/additions/manual_001.json
assets/city_packs/jaipur/curation/reviews/rev_osm_12345.json
```

### Step 3: Run the Test Suite
Ensure all automated quality gates and regression tests pass:
```powershell
.\citylab.ps1 test
```

### Step 4: Export to Mobile App & DataFactory (Optional Local Testing)
To immediately test your fixes in the local YatraCanvas mobile app and sync with DataFactory:
```powershell
.\citylab.ps1 export -City jaipur
```
This automatically bakes your fixes into `yatracanvas.db`, copies it into `YatraCanvas/assets/city_packs/jaipur/`, and saves your JSON curation into `YatraCanvas-DataFactory/data/curated/jaipur/`.

### Step 5: Commit & Push
```bash
git add assets/city_packs/jaipur/curation/
git commit -m "Curate Jaipur: Add 14 opening hours, 8 photo updates, 1 missing stepwell"
git push origin curate/jaipur-updates
```

### Step 6: Open a Pull Request
1. Open a Pull Request on GitHub against `main`.
2. Paste the output from `.\citylab.ps1 summary -City jaipur` into the PR description.
3. An admin will review your changes and certify the pack for YatraCanvas production release!

---

## 5. Getting Help
- Found a software bug in City Lab? File an issue on GitHub.
- Need help with coordinates or city boundaries? Check `city.json` inside your city's folder.
