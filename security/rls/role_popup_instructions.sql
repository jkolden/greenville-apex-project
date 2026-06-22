-- =============================================================================
-- Fusion Role Popup + Badge — APEX App 121
-- =============================================================================
-- Adds a "My Fusion Roles" entry to the navigation bar that:
--   1. Shows a badge with the number of Fusion roles the user holds
--   2. Opens a modal dialog listing all role codes
--
-- PREREQUISITE: pkg_app_security.login_role_check must be set as the
--   Post-Authentication Procedure (populates the FUSION_USER_ROLES
--   collection and sets G_ROLE_COUNT).
-- =============================================================================


-- =============================================================================
-- STEP 1: Application Item (if not already created)
-- =============================================================================
-- Shared Components > Application Items > Create
--
--   Name:            G_ROLE_COUNT
--   Scope:           Application
--   Session State:   Per Session (Disk)


-- =============================================================================
-- STEP 2: Create Modal Dialog Page
-- =============================================================================
-- Create Page > Modal Dialog
--
--   Page Number:     9998  (or any available number)
--   Name:            My Fusion Roles
--   Page Mode:       Modal Dialog
--   Dialog Template: Drawer (or Modal Dialog — your preference)
--
-- On the new page, create a Classic Report region:
--
--   Title:           Fusion Roles
--   Type:            Classic Report
--   Source > SQL Query:
--
--     SELECT c001 AS role_code
--       FROM apex_collections
--      WHERE collection_name = 'FUSION_USER_ROLES'
--      ORDER BY c001
--
--   Template:        Standard  (or Cards if you want a nicer look)
--   Pagination:      No Pagination (Show All Rows)
--
-- Column attributes for ROLE_CODE:
--   Heading:         Role
--   Type:            Plain Text


-- =============================================================================
-- STEP 3: Navigation Bar Entry
-- =============================================================================
-- Shared Components > Navigation Bar List > Edit List Entries > Create Entry
--
--   Sequence:         5  (before the Sign Out entry)
--   Image/Class:      fa-key
--   List Entry Label: My Roles
--   Target > Page:    9998
--   Badge Value:      &G_ROLE_COUNT.
--   Badge Style:      Subtle (or Inverse)
--
-- TIP: If G_ROLE_COUNT is 0 or NULL (user has no Fusion roles), the badge
-- won't render — the link still works but shows no number. This is fine.


-- =============================================================================
-- STEP 4: (Optional) Hide entry when no roles exist
-- =============================================================================
-- On the nav bar list entry:
--   Condition Type:   Value of Item / Column in Expression 1 Is NOT NULL
--   Expression 1:     G_ROLE_COUNT
--
-- This hides the "My Roles" link entirely for users who don't have
-- any Fusion roles (e.g., ADMIN-only local users).


-- =============================================================================
-- VERIFICATION
-- =============================================================================
-- 1. Log in as a user with Fusion roles (e.g., sara.solomon@sierra-cedar.com)
--    - Nav bar should show "My Roles" with a badge (e.g., "25")
--    - Clicking it opens the modal with all role codes listed
--
-- 2. Log in as a local-only user (e.g., JOHNK with only ADMIN in app_user_roles)
--    - If Step 4 applied: "My Roles" link is hidden
--    - If Step 4 skipped: "My Roles" shows with badge "0" or no badge
--
-- 3. If Fusion REST was unreachable at login:
--    - Collection doesn't exist, G_ROLE_COUNT is NULL
--    - "My Roles" link hidden (Step 4) or shows empty modal
