# Admin Guide: Environment Agency Case Scraping

**Route:** `/admin/cases/scrape`
**Access Level:** Admin Required
**Module:** `EhsEnforcementWeb.Admin.CaseLive.Scrape`
**Agency:** Environment Agency (EA)

## Overview

The Environment Agency (EA) case scraping interface allows administrators to collect enforcement action data from the EA public register. Unlike HSE scraping which uses page-based navigation, EA scraping uses **date-range filtering** and fetches all results in a single request per action type.

## Pre-Scraping Manual Verification

Before running the automated scraper, it's important to manually verify that data exists on the EA website for your target date range. This serves as a **sense check** for your scraping results.

### Step 1: Manual EA Website Check

**Purpose:** Verify that enforcement cases exist for your intended date range and understand what results to expect.

#### 1.1 Access the EA Public Register

Open your web browser and navigate to the EA enforcement action search page:

```
https://environment.data.gov.uk/public-register/enforcement-action/registration
```

#### 1.2 Configure Search Parameters

On the EA search form, set the following parameters:

**Name Search:** Leave blank (searches all offenders)

**Action Type:** Select one of:
- Court Case
- Caution
- Enforcement Notice

**After Date:** Enter your start date (e.g., 30 days ago)
- Format: DD/MM/YYYY
- Example: `01/01/2024`

**Before Date:** Leave blank or enter end date
- Leaving blank searches up to today
- Example: `31/12/2024`

**Other Fields:** Leave blank (Offence Type, Agency Function, etc.)

#### 1.3 Execute Manual Search

Click the **"Search"** button on the EA website.

#### 1.4 Interpret the Results

The EA website will display **ALL matching results on a single page** (no pagination). Review the following:

**✅ What to Look For:**

1. **Total Number of Results**
   - Look for text like "Showing X results" or count table rows
   - This tells you how many cases to expect from automated scraping

2. **Table Structure**
   - Should see columns: Name, Address, Date
   - Each row has a clickable offender name linking to details

3. **Sample Data Quality**
   - Offender names should be present and complete
   - Dates should be in DD/MM/YYYY format
   - Addresses may vary (some entries have no address)

4. **Date Range Coverage**
   - Check the earliest and latest dates in results
   - Verify they match your "After" date parameter

**📋 Example Manual Check:**

```
Search Parameters:
- Action Type: Court Case
- After: 01/09/2024
- Before: (blank)

Expected Results:
- Should see table with enforcement cases from Sept 2024 onwards
- Each row shows: Company name, Address, Action date
- Clicking name opens detail page with fine amount, offence details, etc.
```

#### 1.5 Record Your Findings

Before running the automated scraper, note:

- **Total cases expected:** _________ (from manual search)
- **Date range verified:** _________ to _________
- **Action type:** Court Case / Caution / Enforcement Notice
- **Sample offender names:** _________ (first 2-3 names)

This information will help you verify that the automated scraper is working correctly when you compare results.

### Understanding EA Data Structure

**Two-Stage Scraping Process:**

The EA scraper uses a two-stage approach:

1. **Stage 1: Summary Collection**
   - Fetches the search results table (all results on one page)
   - Extracts: Offender name, address, date, detail page URL
   - **This is what you see in the manual search**

2. **Stage 2: Detail Collection**
   - For each case, fetches the individual detail page
   - Extracts: Company registration number, fine amount, offence description, environmental impact, legislation details
   - **This requires clicking each offender name in the manual search**

**Rate Limiting:**
- 3-second delay between detail page requests
- Prevents overloading EA servers
- Ensures respectful data collection

### Common EA Data Patterns

Based on manual searches, you may notice:

**🏢 Company Information:**
- Some entries have company registration numbers, others don't
- Addresses vary in completeness (some only have postcode)
- Industry sector may be present or missing

**💷 Fine Amounts:**
- Displayed as "£5,000" format
- Some cases may have £0 (e.g., cautions, warnings)
- Court cases typically have fines

**🌍 Environmental Impact:**
- May include: Water impact, Land impact, Air impact
- Often blank for cautions
- More detailed for serious prosecutions

**⚖️ Legal References:**
- Act and Section information (e.g., "Environmental Protection Act 1990 - Section 33")
- May reference multiple pieces of legislation

---

## Next Steps

After completing the manual verification:

1. Proceed to the **automated scraping interface** at `/admin/cases/scrape`
2. Select **"EA (Environment Agency)"** from the agency dropdown
3. Enter the **same date range** you used for manual verification
4. Start scraping and **compare results** with your manual findings

**Expected Match:**
- Automated scraper should find the same number of cases (±1-2 due to timing)
- Offender names should match your manual sample
- Date range should align with your manual search

If results differ significantly, consult the **Troubleshooting** section below.

---

## Troubleshooting Manual Verification

### No Results Found

**Possible Causes:**
- Date range may be too narrow (try expanding to 90 days)
- EA website may be temporarily unavailable
- Selected action type may have no recent cases

**Solutions:**
- Try a broader date range (e.g., last 6 months)
- Try different action type (Court Case usually has more data)
- Check EA website status in browser

### Unexpected Results

**If you see very few results (<5 cases):**
- This may be normal depending on the time period
- EA enforcement actions are less frequent than HSE prosecutions
- Consider expanding date range

**If you see very many results (>100 cases):**
- This is normal for long date ranges
- EA returns ALL results on one page (no pagination)
- Automated scraper will process all of them

### Website Differences

**If the EA website looks different:**
- Website structure may have changed
- Contact development team to update scraper
- Note any structural changes for bug report

---

*Continue to the next section: **Automated Scraping Configuration** (to be added)*
