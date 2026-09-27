# City Pack Size & Capacity Report

## Executive Summary

Before bundling datasets into the Flutter application, all production releases in `YatraCanvas-DataFactory/releases/india` were audited for disk consumption, place count, and media footprint.

A crucial distinction is made between:
1. **Total Release Directory**: Includes large pipeline development dumps (`places.parquet`, `places.json`, `places.jsonl`, `quality_report.html`) intended for batch analytics and CI.
2. **App Deployment Bundle**: Contains strictly the operational assets needed by the app: `yatracanvas.db`, `images/`, `manifest.json`, `city.json`, `checksums.json`, `image_manifest.json`, and `license_manifest.json`.

Excluding non-operational artifacts keeps the deployment footprint lean and within optimal APK/binary budgets.

## Audited Release Statistics

| City | State | Places | SQLite DB | Images (Count & MB) | Full Release | App Deployment | Tier Distribution |
|------|-------|--------|-----------|---------------------|--------------|----------------|-------------------|
| **Gulmarg** | Jammu & Kashmir | 84 | 0.18 MB | 20 files (2.47 MB) | 3.23 MB | **~2.66 MB** | Core: 10, Rec: 11, Disc: 20, Supp: 43 |
| **McLeod Ganj** | Himachal Pradesh | 1,012 | 1.47 MB | 54 files (7.51 MB) | 15.13 MB | **~9.00 MB** | Core: 31, Rec: 216, Disc: 228, Supp: 537 |
| **Rishikesh** | Uttarakhand | 1,409 | 2.00 MB | 30 files (2.99 MB) | 13.14 MB | **~5.02 MB** | Core: 15, Rec: 180, Disc: 710, Supp: 504 |
| **Manali** | Himachal Pradesh | 1,702 | 2.13 MB | 24 files (2.77 MB) | 14.73 MB | **~4.93 MB** | Core: 13, Rec: 147, Disc: 264, Supp: 1,278 |
| **Udaipur** | Rajasthan | 2,861 | 3.89 MB | 88 files (7.76 MB) | 28.40 MB | **~11.68 MB** | Core: 63, Rec: 508, Disc: 1,173, Supp: 1,117 |
| **Varanasi** | Uttar Pradesh | 2,937 | 4.16 MB | 192 files (18.51 MB) | 40.29 MB | **~22.71 MB** | Core: 131, Rec: 572, Disc: 1,342, Supp: 892 |
| **Panjim** | Goa | 3,753 | 4.98 MB | 106 files (9.17 MB) | 36.39 MB | **~14.19 MB** | Core: 60, Rec: 952, Disc: 989, Supp: 1,752 |
| **Jaipur** | Rajasthan | 10,060 | 13.39 MB | 106 files (11.83 MB) | 82.81 MB | **~25.26 MB** | Core: 80, Rec: 1,780, Disc: 6,122, Supp: 2,078 |

## Bundling Strategy & Profiles

1. **Default Initial Testing Profile (Recommended by Prompt)**:
   - Cities: **Manali, Rishikesh, Panaji, Gulmarg**
   - Total Places: **6,948 places**
   - Total Deployment Footprint: **~26.8 MB** (Extremely safe for rapid debugging and responsive APKs).

2. **Stress Test Profile**:
   - Cities: **Default + Jaipur** (Large 10k-record dataset)
   - Total Places: **17,008 places**
   - Total Deployment Footprint: **~52.1 MB**
   - Purpose: Verifies pagination, sub-100ms FTS/LIKE performance, and memory stability under high volume.

3. **Complete Profile (`--all`)**:
   - All 8 cities: **24,818 places**, **~95.5 MB** deployment footprint.
