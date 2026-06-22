-- =============================================================================
-- MIGRATION: rec_school_grant.school → location_code
-- =============================================================================
-- Converts existing school-name-based grants to location-code-based grants.
-- Run ONCE against the live database.
--
-- Prerequisites:
--   - dim_location_r must be populated (pkg_bicc_dimensions.load_locations)
--   - Verify the UPDATE matched all rows before running the ALTER
-- =============================================================================

-- Step 1: Backfill — convert location names to codes
UPDATE rec_school_grant g
   SET g.school = (
       SELECT dl.location_code
         FROM dim_location_r dl
        WHERE dl.location_name = g.school
   )
 WHERE EXISTS (
       SELECT 1 FROM dim_location_r dl
        WHERE dl.location_name = g.school
   );

COMMIT;

-- Step 2: Check for any rows that didn't match (names not in dim_location_r)
-- If this returns rows, fix them manually before proceeding to Step 3.
SELECT id, app_user, school AS unmatched_value
  FROM rec_school_grant
 WHERE school NOT IN (SELECT location_code FROM dim_location_r WHERE location_code IS NOT NULL);

-- Step 3: Rename the column
ALTER TABLE rec_school_grant RENAME COLUMN school TO location_code;

-- Step 4: Update comments
COMMENT ON COLUMN rec_school_grant.location_code IS 'Fusion location code (e.g. 188, 435) — must match RECRUITING_REPORT_V.LOCATION_CODE';
