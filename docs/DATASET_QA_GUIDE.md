# YatraCanvas City Pack Manual QA Guide

This guide describes the standard, human-centered protocol for evaluating a DataFactory City Pack release. 

While automated tests in the pipeline verify schema, types, geometry validity, and search recall, **this Lab tests human trust and product realism:**
> *"If a real traveller used this City Pack inside YatraCanvas, would the places feel authentic, well-categorized, correctly located, and trustworthy?"*

---

## 25–30 Minute Standard Tester Protocol

Follow this structured 11-step checklist whenever auditing a new city pack release:

```
[1. Open Pack] ───► [2. Inspect Core] ───► [3. Inspect Recommended] ───► [4. Inspect Discovery]
       │
       ▼
[5. Category Inspection] ───► [6. Natural Searches] ───► [7. Geographic Map]
       │
       ▼
[8. Random 50 Sample] ───► [9. Expected Places] ───► [10. Test Trip] ───► [11. Export Report]
```

---

### Step 1: Open City & Verify Integrity (1 min)
1. Launch **City Pack Lab**.
2. Locate your target city (e.g., **Manali**, **Rishikesh**, **Panaji**, or **Gulmarg**).
3. Confirm that the card displays `Integrity: PASS`. If it says `FAIL`, the database checksum does not match the manifest; investigate before continuing.
4. Tap **Metadata** to review the total place count, local image count, bounding box, and generation timestamp.
5. Tap **Open Pack**.

---

### Step 2: Inspect Core Destinations (3 min)
1. On the **Discover Places** screen, observe the **Top Destinations (Core)** section.
2. Verify that the places in Core are genuine anchor landmarks for the city (e.g., Hadimba Temple in Manali, Triveni Ghat in Rishikesh, Basilica of Bom Jesus in Goa).
3. **What to look for**:
   - Are commercial businesses, ordinary hotels, or minor shops falsely marked as `Core`?
   - If a place should not be Core, tap the card → tap **Report** → select `Should Not Be Core` and add a brief note.

---

### Step 3: Inspect Recommended Places (3 min)
1. Scroll down to the **Recommended** section.
2. These should represent high-quality secondary attractions, prominent cafes, cultural sites, and popular activities.
3. Check image coverage:
   - Does each place with an image show an accurate, local depiction of the place?
   - When an image is missing, confirm it shows the clean **"No local image"** placeholder rather than generic mountain/coffee photos.

---

### Step 4: Inspect Discovery / Lesser-Known (3 min)
1. Filter the feed by tapping the **Discovery** chip.
2. Review 10–15 lesser-known places (e.g., hidden viewpoints, ancient trails, village shrines, artisan bakeries).
3. **What to look for**:
   - Hallucinated or malformed names (e.g. OCR artifacts, phone numbers in titles).
   - Upstream junk entries (e.g., "Public Toilet", "ATM", "Private Villa").
   - If found, flag with `Not Travel Relevant` or `Wrong Category`.

---

### Step 5: Test Category Browsing (3 min)
1. Switch to **Categories** via the bottom navigation bar.
2. Tap **FOOD & CAFE**:
   - Are the cafes actual dining spots or wholesale grain depots?
   - Toggle **"Show only travel-relevant"** on and off to see what records are suppressed by the pipeline.
3. Tap **RELIGIOUS**:
   - Check if prominent temples, mosques, churches, or gurudwaras are present.
4. Change sorting to **Travel Relevance** and verify the highest scored places make sense.

---

### Step 6: Natural Search Queries (4 min)
1. Open the **Search** screen.
2. Toggle on **Review Mode** in the top right corner.
3. Test natural traveller queries using the quick chips or typing:
   - `cafe`
   - `waterfall`
   - `viewpoint`
   - `local food`
   - `temple`
   - `yoga` / `rafting`
4. For each query, review the top 5 results and rate each as:
   - **Relevant**: Spot on (e.g. searching "cafe" returns a real cafe).
   - **Partial**: Tangentially related (e.g. searching "coffee" returns a supermarket).
   - **Irrelevant**: Totally wrong (e.g. searching "temple" returns a gas station).
   - **Unsure**: Needs physical or local verification.

---

### Step 7: Review Geographic Spread on Map (3 min)
1. Open the **Geographic Map** screen.
2. Inspect the scatter of markers across the city bounding box:
   - **Golden markers**: Core Destinations
   - **Blue markers**: Recommended
   - **Teal markers**: Discovery
   - **Grey markers**: Support
3. Look for anomalies:
   - Are any markers located 50km away in a different district or state?
   - Are markers clustering in the ocean, deep off-road cliffs, or uninhabited regions?
4. Toggle **Strict Offline Mode** in the top right:
   - Verify that marker inspection continues smoothly without internet tile requests.

---

### Step 8: Random Review 50 Places (5 min)
1. Go to **Random QA** in the bottom navigation.
2. Set **Sample Size**: 30 or 50 places.
3. Tap **Start Reviewing**.
4. For each card displayed:
   - If valid, tap **LOOKS GOOD** (Green).
   - If defective, tap the specific defect button:
     - `WRONG CATEGORY`
     - `WRONG LOCATION`
     - `BAD IMAGE`
     - `WRONG NAME`
     - `DUPLICATE`
     - `NOT TRAVEL RELEVANT`
     - `SHOULD NOT BE CORE`
     - `STALE / CLOSED`
5. Note the final summary breakdown (e.g. 44 Good, 6 Problems = 12% Defect Rate).

---

### Step 9: Expected Places Check (2 min)
1. Open the drawer and tap **Expected Places Check**.
2. Type 3–5 famous landmarks you know should exist in this destination:
   - For Manali: *Hadimba Temple*, *Solang Valley*, *Old Manali*, *Rohtang Pass*, *Jogini Waterfall*.
   - For Rishikesh: *Triveni Ghat*, *Ram Jhula*, *Laxman Jhula*, *Beatles Ashram*, *Parmarth Niketan*.
   - For Panaji: *Immaculate Conception Church*, *Fontainhas*, *Miramar Beach*, *Reis Magos Fort*.
   - For Gulmarg: *Gulmarg Gondola*, *Apharwat Peak*, *St. Mary's Church*, *Maharani Temple*.
3. Mark whether the place was **FOUND**, **DATA WRONG**, or **NOT FOUND**.

---

### Step 10: Create a Test Trip & Review Clustering (2 min)
1. In Discover or Search, add 8–12 places to your **Test Trip**.
2. Navigate to **Test Trip Basket**.
3. Set trip duration to **3 Days**.
4. Tap **Cluster by Coords** to distribute places geographically.
5. Tap **View Trip Map** in the top bar:
   - Do the places assigned to Day 1, Day 2, and Day 3 form sensible spatial clusters, or does a single day bounce back and forth across mountain ridges?

---

### Step 11: Export QA Report & Make Dataset Determination (1 min)
1. Navigate to **QA Stats** (Dashboard).
2. Review total reviewed count and problem breakdown.
3. Tap **Export Report**.
4. Verify the generated `qa_<city>_<date>.json` and `qa_<city>_<date>.md` files.
5. Make your final dataset determination:
   - **PASS**: Dataset is realistic, clean, and ready for production staging in YatraCanvas.
   - **WARN**: Usable, but pipeline needs minor tuning (e.g. category misclassifications or image matching confidence threshold adjustments).
   - **FAIL**: Unacceptable rate of false core landmarks, spurious businesses, or severe coordinate errors.
