# Recruiting Application Security Model
### Greenville County Schools — APEX App 121
### Sierra-Cedar | June 18, 2026

---

## SLIDE 1: Agenda

1. **Architecture Overview** — How the pieces fit together
2. **Layer 1: Page Access** — Who can see recruiting pages?
3. **Layer 2: Row-Level Security** — Which schools can they see?
4. **School Grant Overrides** — Handling transfers and exceptions
5. **Admin Controls** — What can administrators manage?
6. **Summary**

---

## SLIDE 2: Architecture Overview

```
                         USER LOGS IN TO APEX
                               |
                     +---------+---------+
                     |                   |
               Page Access          Row-Level Security
               (can they see        (which school
                recruiting?)         locations?)
                     |                   |
             +-------+-------+   +-------+-------+
             |               |   |               |
         Fusion Roles   Fallback   Fusion       Fallback
         (REST API)    (BIP table) Assignments  (BICC table)
                                   (REST API)
                                         |
                               (whichever path succeeds)
                                         |
                                         v
                              +---------------------+
                              | + School Grant      |
                              |   Overrides         |
                              |   (rec_school_grant)|
                              +---------------------+
                                         |
                                         v
                              +---------------------+
                              | VPD Policy          |
                              | (automatic WHERE    |
                              |  clause on every    |
                              |  query)             |
                              +---------------------+
```

**Overrides are applied after both paths** — whether the user's locations came from the real-time REST API or the daily BICC fallback, school grant overrides are always injected before the session begins.

---

## SLIDE 3: Layer 1 — Page Access (Roles)

**Any user with one of these existing Fusion roles gets automatic access:**

| Fusion Role | Who Has It |
|---|---|
| ORA_IRC_RECRUITER_JOB | Recruiters |
| ORA_IRC_RECRUITING_MANAGER_JOB | Recruiting Managers |
| ORA_PER_RECRUITING_ADMINISTRATOR_JOB | Recruiting Administrators |

**How it works:**
- At login, the app calls the Fusion REST API using a service account with access to the roles and assignments endpoints — not the end user's credentials
- Roles are cached in a session-scoped APEX collection
- APEX Authorization Schemes check the collection on every page load

**No new roles to create. No manual APEX user setup required.**

Role granted in Fusion today --> access at next APEX login.
Role revoked in Fusion today --> access removed at next APEX login.

**Fallback:** If the Fusion REST API is unreachable at login, the app automatically falls back to the `fa_user_roles` table — a daily BIP snapshot of all user-role assignments. The user gets in with the same roles they had as of the last daily refresh.

---

## SLIDE 4: Layer 2 — Row-Level Security (Locations)

**Users only see recruiting data for schools where they have an active Fusion assignment.**

```
  Jane (Principal at Greenville High)
       |
       v
  Login --> REST fetches her assignments:
            - Position: Principal
            - Location: Greenville High (code 295)
       |
       v
  VPD Policy automatically appends:
     WHERE LOCATION_CODE IN ('295')
       |
       v
  Jane sees ONLY Greenville High job requisitions
```

**Virtual Private Database (VPD)** — Oracle applies a WHERE clause to every query against the recruiting report view. No application code can bypass it.

| User Type | What They See |
|---|---|
| Normal user | Only their assignment location(s) |
| ADMIN role | All locations (bypass) |
| No APEX session (SQL Developer, scheduler) | All locations (bypass) |

---

## SLIDE 5: School Grant Overrides (NEW)

**The scenario:** A secretary at School A transfers to School B but still needs temporary access to School A's job requisitions during the transition.

**The solution:** Administrators can grant manual location overrides via the `rec_school_grant` table.

```
  +-------------------+     +-------------------+     +------------------+
  |  Fusion REST API  |     |  BICC Fallback    |     | rec_school_grant |
  |  (assignments)    |     |  (if REST fails)  |     | (manual overrides|
  +--------+----------+     +--------+----------+     +--------+---------+
           |                         |                          |
           +-------  OR  -----------+                          |
                    |                                           |
                    +------------------+  +  +-----------------+
                                       |     |
                                       v     v
                             FUSION_USER_ASSIGNMENTS collection
                             (combined: real assignments + overrides)
                                       |
                                       v
                                 VPD Policy
                             (filters by location)
```

**How it works:**
1. Admin adds a row: user + location code + notes
2. At user's next login, override locations are injected into the same collection as real assignments
3. VPD policy picks them up automatically — no code changes needed downstream
4. When access is no longer needed, admin sets `is_active = 'N'`

**Key details:**
- **Overrides are additive — they never remove existing access**
- Duplicate locations are handled automatically (no double-counting)
- Works with both the REST path and the BICC fallback path

---

## SLIDE 6: Override Admin Page

| Field | Description |
|---|---|
| **User** | APEX username (matches Fusion username) |
| **Location Code** | School location code (LOV shows school name) |
| **Active** | Y = active, N = revoked |
| **Granted By** | Who approved the override |
| **Granted Date** | Automatic timestamp |
| **Notes** | Reason for the override (e.g., "Transfer transition — revoke after Aug 1") |

The admin report shows all grants with school names, filterable by user or location.

---

## SLIDE 7: Five Security Data Sources

| # | Source | Purpose | Updated |
|---|---|---|---|
| 1 | `app_user_roles` | Local ADMIN role grants | Manual |
| 2 | Fusion REST → APEX collection | Recruiting roles (page access) | Every login |
| 3 | Fusion REST → APEX collection | Assignments / locations (row security) | Every login |
| 4 | BICC / BIP tables | Fallback for #2 and #3 when REST is unavailable | Daily |
| 5 | `rec_school_grant` | Manual location overrides for transfers / exceptions | Manual |

All five are checked at login and combined into session-scoped collections that drive the entire security model for the session.

---

## SLIDE 8: Admin Controls Summary

| Action | How | Effect |
|---|---|---|
| Grant page access automatically | Assign a recruiting role in Fusion | Immediate at next login |
| Revoke page access automatically | Remove the role in Fusion | Immediate at next login |
| Grant ADMIN access | Insert into `app_user_roles` | Full access, bypasses all filters |
| Grant extra school location | Insert into `rec_school_grant` | User sees that school's data at next login |
| Revoke extra school location | Set `is_active = 'N'` in `rec_school_grant` | Access removed at next login |

---

## SLIDE 9: Summary

| Before | After |
|---|---|
| Manual user management | Automated via Fusion roles |
| All-or-nothing school access | Row-level filtering by assignment location |
| No way to handle transfers | School grant override table |
| Single point of failure (REST only) | Automatic fallback to daily snapshots |
| No audit trail | Grants tracked with timestamps and notes |

**Key takeaways:**
- Security is driven by Oracle Fusion — the source of truth for roles and assignments
- VPD enforces row-level security at the database level — no application code can bypass it
- School grant overrides handle exception cases without changing Fusion data
- Automatic failover ensures users are never locked out by a REST outage
- Zero ongoing maintenance for standard users — Fusion changes flow automatically
