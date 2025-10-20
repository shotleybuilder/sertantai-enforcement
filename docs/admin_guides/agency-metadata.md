# Admin Guide: Agency Metadata Setup

**Route:** `/admin/agencies`
**Access Level:** Admin Required
**Purpose:** Configure enforcement agencies for data collection and case management

## Overview

The EHS Enforcement application requires agencies to be configured in the database before scraping or creating cases. Each agency has specific metadata that enables the scraping system to correctly route and process enforcement data.

## Required Agencies

The application currently supports two UK regulatory agencies:

### 1. Health and Safety Executive (HSE)

**Agency Configuration:**

| Field | Value |
|-------|-------|
| **Code** | `hse` |
| **Name** | Health and Safety Executive |
| **Base URL** | `https://www.hse.gov.uk` |
| **Enabled** | ✓ Yes (Agency is active) |

**Description:**
HSE is responsible for workplace health and safety regulation in Great Britain. The scraper collects prosecution cases, enforcement notices, and appeal decisions.

**Data Sources:**
- **Prosecutions:** `https://resources.hse.gov.uk/convictions/`
- **Enforcement Notices:** `https://resources.hse.gov.uk/notices/`
- **Appeals:** `https://resources.hse.gov.uk/appeals/`

**Scraping Method:** Page-based pagination (start_page, end_page parameters)

---

### 2. Environment Agency (EA)

**Agency Configuration:**

| Field | Value |
|-------|-------|
| **Code** | `ea` |
| **Name** | Environment Agency |
| **Base URL** | `https://environment.data.gov.uk` |
| **Enabled** | ✓ Yes (Agency is active) |

**Description:**
The Environment Agency is responsible for protecting and improving the environment in England. The scraper collects court cases, cautions, and enforcement notices related to environmental violations.

**Data Source:**
- **Public Register:** `https://environment.data.gov.uk/public-register/enforcement-action/registration`

**Scraping Method:** Date-range based filtering (date_from, date_to parameters)

**Action Types Supported:**
- Court Cases
- Cautions
- Enforcement Notices

---

## Adding Agencies via Admin Interface

### Step 1: Access Agency Management

Navigate to: **`/admin/agencies`**

You should see a table of existing agencies with columns:
- ID
- CODE
- NAME
- BASE URL
- ENABLED
- INSERTED AT
- UPDATED AT

### Step 2: Click "New Agency"

Click the blue **"+ New Agency"** button in the top right.

### Step 3: Fill Agency Form

**For Environment Agency:**

| Field | Value to Enter |
|-------|----------------|
| **Code** | Select **"EA - Environment Agency"** from dropdown |
| **Name** | `Environment Agency` |
| **Base URL** | `https://environment.data.gov.uk` |
| **Enabled** | ✓ Check "Agency is active" |

**Important Notes:**
- **Code** must be exactly `ea` (lowercase) - the dropdown should provide this option
- **Name** can be the full display name
- **Base URL** should be the root domain only (no paths)
- **Enabled** must be checked for scraping to work

### Step 4: Save Agency

Click **"Save"** or **"Create Agency"** button.

### Step 5: Verify Agency Created

You should see the Environment Agency appear in the agencies table with:
- Code: `ea`
- Name: Environment Agency
- Base URL: https://environment.data.gov.uk
- Enabled: Yes (green badge)

---

## Verifying Agency Setup via Database

If you need to verify agencies exist at the database level:

```sql
-- Check all agencies
SELECT id, code, name, base_url, enabled
FROM agencies
ORDER BY code;

-- Expected results:
--   code | name                            | base_url                            | enabled
--   -----+---------------------------------+-------------------------------------+---------
--   ea   | Environment Agency              | https://environment.data.gov.uk     | true
--   hse  | Health and Safety Executive     | https://www.hse.gov.uk              | true
```

---

## Agency Code Usage in Application

The **agency code** is used throughout the application for:

### 1. **Scraping**
When scraping cases, the system uses `agency_code` to:
- Route to the correct scraper module (`Hse.CaseScraper` vs `Ea.CaseScraper`)
- Determine scraping parameters (pages vs date ranges)
- Apply agency-specific parsing logic

### 2. **Case Creation**
When creating cases, the code maps to the agency relationship:
```elixir
# Example from EA scraping
%{
  agency_code: :ea,
  regulator_id: "EA-20240111-CC-10000368",
  offender_attrs: %{name: "Example Ltd"},
  # ... other fields
}
```

### 3. **Data Display**
Cases are filtered and displayed by agency:
- Dashboard metrics by agency
- Case listings with agency badges
- Reports grouped by regulatory body

---

## Troubleshooting Agency Issues

### Error: "Failed to lookup agency: ea"

**Cause:** Environment Agency not in database, or code mismatch

**Solution:**
1. Check agencies table: Navigate to `/admin/agencies`
2. Verify EA exists with code exactly `ea` (lowercase)
3. Verify "Enabled" is checked (green "Yes" badge)
4. If missing, follow "Adding Agencies via Admin Interface" above

### Error: "Agency not found: ea"

**Cause:** Agency code is `nil` or doesn't match database code

**Solution:**
1. Check that scraping is using `agency_code: :ea` (as atom) or `"ea"` (as string)
2. Verify database has exact match (case-sensitive)
3. Check agency is enabled in database

### Cases Not Appearing Under Correct Agency

**Cause:** Agency relationship not set correctly during case creation

**Solution:**
1. Verify agency lookup is succeeding in logs
2. Check `agency_id` foreign key is set on cases table
3. Run database query to verify:
   ```sql
   SELECT c.regulator_id, a.code, a.name
   FROM cases c
   JOIN agencies a ON a.id = c.agency_id
   WHERE c.regulator_id LIKE 'EA-%'
   LIMIT 10;
   ```

---

## Agency Expansion (Future)

Additional UK regulatory agencies can be added following the same pattern:

### Office for Nuclear Regulation (ONR)
- **Code:** `onr`
- **Name:** Office for Nuclear Regulation
- **Base URL:** `https://www.onr.org.uk`

### Scottish Environment Protection Agency (SEPA)
- **Code:** `sepa`
- **Name:** Scottish Environment Protection Agency
- **Base URL:** `https://www.sepa.org.uk`

### Natural Resources Wales (NRW)
- **Code:** `nrw`
- **Name:** Natural Resources Wales
- **Base URL:** `https://naturalresources.wales`

**Note:** Each new agency requires:
1. Database entry via admin interface
2. Scraper module implementation in `lib/ehs_enforcement/scraping/[agency]/`
3. Data transformer in `lib/ehs_enforcement/agencies/[agency]/`
4. AgencyBehavior implementation

---

## Quick Reference: Agency Codes

| Code | Name | Primary Data Type | Scraping Style |
|------|------|-------------------|----------------|
| `hse` | Health and Safety Executive | Workplace safety cases | Page-based |
| `ea` | Environment Agency | Environmental violations | Date-range |

**All codes must be lowercase and match database exactly.**

---

*For scraping-specific instructions, see:*
- **[case_scraping.md](case_scraping.md)** - HSE case scraping
- **[case-scraping-environment-agency.md](case-scraping-environment-agency.md)** - EA case scraping
