-- Script to remove incomplete HSE notice duplicates
-- These are duplicates identified by (regulator_id, agency_id) where one copy
-- is missing notice_body and url (incomplete scrape) and the other has full data
--
-- Usage:
-- PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -d ehs_enforcement_prod < remove_incomplete_hse_notice_duplicates.sql
--
-- Or run interactively in psql and review before executing DELETE

-- Step 1: Identify incomplete notices that have complete duplicates
-- (Preview query - shows what will be deleted)
SELECT
    n.id,
    n.regulator_id,
    n.agency_id,
    CASE WHEN n.notice_body IS NULL OR n.notice_body = '' THEN 'MISSING' ELSE 'HAS' END as notice_body_status,
    CASE WHEN n.url IS NULL OR n.url = '' THEN 'MISSING' ELSE 'HAS' END as url_status,
    n.inserted_at,
    COUNT(*) OVER (PARTITION BY n.regulator_id, n.agency_id) as duplicate_count
FROM notices n
WHERE n.agency_id IN (SELECT id FROM agencies WHERE code = 'hse')
  AND n.regulator_id IS NOT NULL
  AND n.regulator_id != ''
  -- Only show records that are part of a duplicate group
  AND EXISTS (
    SELECT 1 FROM notices n2
    WHERE n2.regulator_id = n.regulator_id
      AND n2.agency_id = n.agency_id
      AND n2.id != n.id
  )
ORDER BY n.regulator_id, n.inserted_at;

-- Step 2: Count how many incomplete duplicates exist
SELECT
    COUNT(*) as incomplete_duplicates_to_delete,
    COUNT(DISTINCT regulator_id) as affected_regulator_ids
FROM notices n
WHERE n.agency_id IN (SELECT id FROM agencies WHERE code = 'hse')
  AND n.regulator_id IS NOT NULL
  AND n.regulator_id != ''
  -- Missing notice_body OR url (incomplete)
  AND (n.notice_body IS NULL OR n.notice_body = '' OR n.url IS NULL OR n.url = '')
  -- Has a complete duplicate
  AND EXISTS (
    SELECT 1 FROM notices n2
    WHERE n2.regulator_id = n.regulator_id
      AND n2.agency_id = n.agency_id
      AND n2.id != n.id
      AND n2.notice_body IS NOT NULL
      AND n2.notice_body != ''
      AND n2.url IS NOT NULL
      AND n2.url != ''
  );

-- Step 3: DELETE incomplete duplicates
-- IMPORTANT: Review the preview queries above before running this!
-- Uncomment the following to execute:

/*
DELETE FROM notices
WHERE id IN (
  SELECT n.id
  FROM notices n
  WHERE n.agency_id IN (SELECT id FROM agencies WHERE code = 'hse')
    AND n.regulator_id IS NOT NULL
    AND n.regulator_id != ''
    -- Missing notice_body OR url (incomplete)
    AND (n.notice_body IS NULL OR n.notice_body = '' OR n.url IS NULL OR n.url = '')
    -- Has a complete duplicate
    AND EXISTS (
      SELECT 1 FROM notices n2
      WHERE n2.regulator_id = n.regulator_id
        AND n2.agency_id = n.agency_id
        AND n2.id != n.id
        AND n2.notice_body IS NOT NULL
        AND n2.notice_body != ''
        AND n2.url IS NOT NULL
        AND n2.url != ''
    )
);
*/

-- Step 4: Verify cleanup (run after DELETE)
-- Should return 0 incomplete duplicates remaining
/*
SELECT
    COUNT(*) as remaining_incomplete_duplicates
FROM notices n
WHERE n.agency_id IN (SELECT id FROM agencies WHERE code = 'hse')
  AND n.regulator_id IS NOT NULL
  AND n.regulator_id != ''
  AND (n.notice_body IS NULL OR n.notice_body = '' OR n.url IS NULL OR n.url = '')
  AND EXISTS (
    SELECT 1 FROM notices n2
    WHERE n2.regulator_id = n.regulator_id
      AND n2.agency_id = n.agency_id
      AND n2.id != n.id
  );
*/
