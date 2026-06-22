-- =============================================================================
-- Fusion Assignment Popup + Badge — APEX App 121
-- =============================================================================
-- Adds a "My Assignments" entry to the navigation bar that:
--   1. Shows a badge with the number of Fusion assignments the user holds
--   2. Opens a modal dialog listing assignments with location/department names
--
-- PREREQUISITE: pkg_app_security.login_role_check must be set as the
--   Post-Authentication Procedure (populates the FUSION_USER_ASSIGNMENTS
--   collection and sets G_ASSIGNMENT_COUNT).
--
-- PREREQUISITE: dim_location_r and dim_department_r tables must be populated
--   (via pkg_bicc_dimensions.refresh_all).
-- =============================================================================


-- =============================================================================
-- STEP 1: Application Item (if not already created)
-- =============================================================================
-- Shared Components > Application Items > Create
--
--   Name:            G_ASSIGNMENT_COUNT
--   Scope:           Application
--   Session State:   Per Session (Disk)


-- =============================================================================
-- STEP 2: Create Modal Dialog Page
-- =============================================================================
-- Create Page > Modal Dialog
--
--   Page Number:     9997  (or any available number)
--   Name:            My Assignments
--   Page Mode:       Modal Dialog
--   Dialog Template: Drawer (or Modal Dialog — your preference)
--
-- On the new page, create a Classic Report region:
--
--   Title:           Fusion Assignments
--   Type:            Classic Report
--   Source > SQL Query:

SELECT c002  AS position_name,
       c005  AS position_code,
       c003  AS location_name,
       c006  AS location_code,
       c004  AS department_name,
       c007  AS job_name
  FROM apex_collections
 WHERE collection_name = 'FUSION_USER_ASSIGNMENTS'
 ORDER BY c003, c004;

--   Template:        Standard  (or Cards if you want a nicer look)
--   Pagination:      No Pagination (Show All Rows)
--
-- Column attributes:
--   POSITION_NAME:   Heading = "Position",   Type = Plain Text
--   POSITION_CODE:   Hidden (or Plain Text)
--   LOCATION_NAME:   Heading = "Location",   Type = Plain Text
--   LOCATION_CODE:   Hidden
--   DEPARTMENT_NAME: Heading = "Department",  Type = Plain Text
--   JOB_NAME:        Heading = "Job",         Type = Plain Text


-- =============================================================================
-- STEP 3: Navigation Bar Entry
-- =============================================================================
-- Shared Components > Navigation Bar List > Edit List Entries > Create Entry
--
--   Sequence:         4  (before the My Roles and Sign Out entries)
--   Image/Class:      fa-sitemap
--   List Entry Label: My Assignments
--   Target > Page:    9997
--   Badge Value:      &G_ASSIGNMENT_COUNT.
--   Badge Style:      Subtle (or Inverse)
--
-- TIP: If G_ASSIGNMENT_COUNT is 0 or NULL (user has no assignments),
-- the badge won't render — the link still works but shows no number.


-- =============================================================================
-- STEP 4: (Optional) Hide entry when no assignments exist
-- =============================================================================
-- On the nav bar list entry:
--   Condition Type:   Value of Item / Column in Expression 1 Is NOT NULL
--   Expression 1:     G_ASSIGNMENT_COUNT
--
-- This hides the "My Assignments" link entirely for users who don't have
-- any Fusion assignments (e.g., ADMIN-only local users).


-- =============================================================================
-- VERIFICATION
-- =============================================================================
-- 1. Log in as a user with Fusion assignments (active worker in Fusion)
--    - Nav bar should show "My Assignments" with a badge (e.g., "2")
--    - Clicking it opens the modal with location and department names
--
-- 2. Log in as a local-only user (e.g., JOHNK with only ADMIN in app_user_roles)
--    - If Step 4 applied: "My Assignments" link is hidden
--    - If Step 4 skipped: "My Assignments" shows with no badge
--
-- 3. If Fusion REST was unreachable at login:
--    - Collection doesn't exist, G_ASSIGNMENT_COUNT is NULL
--    - "My Assignments" link hidden (Step 4) or shows empty modal
