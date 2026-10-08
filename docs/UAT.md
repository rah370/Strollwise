# StrollWise User Acceptance Testing Plan

This is the UAT plan for the hosted Cebu crowd-map: traveler app, admin console, and the tag → moderation → zone loop between them.

Use this document to run sessions, log results, and decide go / no-go. It is not a developer test suite. Backend `pytest` and widget tests stay separate.

Fixes that make these cases pass are tracked in [`UAT-hardening.md`](UAT-hardening.md).

---

## 1. Purpose

Confirm that real testers (travelers and operators) can complete the product’s intended jobs on the **current hosted stack**:

- Register and sign in as a traveler.
- See Metro Cebu zones on Explore.
- Submit a location tag.
- Browse Feed and Trends.
- Manage a profile (including visit pins and logout).
- As an operator: review tags, inspect zones, export thesis data, without exposing another user’s GPS trail.

UAT passes when the cases in §8 succeed on the agreed environment, known limitations in §6 are not treated as defects, and the product owner signs §12.

---

## 2. Scope

### In scope

| Surface | What testers use |
| --- | --- |
| Traveler web | https://strollwise-app.onrender.com |
| Admin console | https://strollwise.onrender.com |
| API (health / legal only for testers) | https://strollwise-api.onrender.com |
| Native Android / iOS | Optional extra pass if the team has a **current** local build pointed at the same API. Hosted web is the primary UAT surface. |

Traveler tabs: **Explore**, **Add Tag**, **Feed**, **Trends**, **Profile**. Auth, privacy, and terms screens. Admin pages: Dashboard, Moderation, Zones, Users, Catalog, Analytics, Pipeline (read / cache-invalidate only unless a facilitator is present), Settings (read-only unless a dedicated settings case is scheduled), Audit Log.

### Out of scope

- Seeding or resetting production (`backend/seed.py` must not run against production).
- Migrating to Supabase Auth, relocating PostGIS, or silencing the `spatial_ref_sys` RLS advisor.
- App Store / Play Store listing, push notifications, billing.
- Layers screen (`/layers`) — routed but **not** in the bottom navigation; skip unless a facilitator opens it on purpose.
- Zone-detail **bookmark** icon — visual only; it does not save a zone. Do not fail UAT if tapping it does nothing.
- Load / soak / security penetration testing.
- Changing H3 resolution or live validation thresholds during a public demo.

---

## 3. Environment and accounts

### Hosted URLs

| Role | URL |
| --- | --- |
| Traveler app | https://strollwise-app.onrender.com |
| Admin | https://strollwise.onrender.com |
| API health | https://strollwise-api.onrender.com/health |
| Privacy / terms (API) | https://strollwise-api.onrender.com/privacy · `/terms` |

Wake the API **before** every session: open `/health` and wait until `"database": "ok"`. Render Free sleeps after ~15 minutes idle; the first hit can take 30–60 seconds. That delay is expected, not a fail.

### Builds under test

Record in the results sheet:

- Traveler: hosted Flutter web (hard-refresh; close leftover tabs).
- Admin: hosted Vite SPA.
- API: Render service, **one worker** (in-memory admin live-sync). Do not scale workers for UAT.
- Database: Supabase Postgres + PostGIS (session pooler). Do not enable a second API replica.

### Accounts

| Role | How to obtain | Rules |
| --- | --- | --- |
| Traveler | Each tester **registers a new account** in the app | Use a disposable email. Password ≥ 8 characters. Accept research consent. Pick a real origin country/city pair from the lists. |
| Operator | Team-shared admin (created via `create_admin.py` / `promote_admin.py`, not committed) | Do not paste passwords into this repo, tickets, or screenshots. |
| Non-admin control | A traveler account that is **not** promoted | Must be rejected by the admin console. |

Production traveler web has **demo login off** (`ENABLE_DEMO_LOGIN=false`). `demo@strollwise.local` must not sign in on the hosted app. That is a pass, not a fail.

### Devices

Minimum mix:

- 1× desktop Chrome (traveler web + admin).
- 1× phone Chrome or Safari (traveler web).
- Optional: 1× Android APK **rebuilt from the same commit** as hosted web.

If native and web disagree on a recently fixed bug (for example zone-card dismiss), treat **hosted web** as source of truth unless the APK SHA matches the live web deploy.

---

## 4. Roles

| Role | Who | Responsibility |
| --- | --- | --- |
| Facilitator | Engineer who knows the stack | Wake API, hand out accounts, stop testers from running seed / full pipeline / settings writes unless scheduled. |
| Traveler testers | 2–4 people (local resident, domestic traveler, international visitor if possible) | Run T- cases. One person should be **outside Cebu GPS** or with location denied, to cover the manual-location path. |
| Operator testers | 1–2 researchers / admins | Run A- cases. One person must **not** approve every tag blindly — reject or flag at least one. |
| Scribe | Anyone | Fill the results sheet; file defects with severity. |
| Product owner | Thesis / product lead | Sign off go / no-go. |

Suggested size: **one 90-minute traveler session** and **one 60-minute operator session**, plus a **30-minute paired E2E** (traveler + operator in the same room or call).

---

## 5. Entry criteria (do not start UAT until these are true)

Facilitator checklist, in order:

1. `GET https://strollwise-api.onrender.com/health` returns HTTP 200 with `"database": "ok"`. `"status": "degraded"` / `"database": "error"` means Postgres is paused — resume Supabase, then retry. `"redis": "unavailable"` is acceptable.
2. Traveler URL loads the auth screen (not a blank page or Render 502 after a 90s wait).
3. Admin URL loads the researcher sign-in form.
4. Operator can sign in and see Dashboard stats (pending / flagged / active zones / users).
5. Explore, once signed in, shows the Cebu basemap and at least the catalog / merged zones already in production (currently named areas such as Lahug, IT Park Business Zone, SRP Tourism Belt — lifecycle may be **unthreshold**; that is allowed).
6. Testers have unique emails. Operator password is shared out-of-band.
7. Testers agree: no real home addresses in tag notes; no attempts to recover another user’s GPS from public zone data.

If health stays down after two wake attempts, **stop**. Do not file traveler-app defects against a sleeping or crashed API.

---

## 6. Known limitations (not defects)

Log these as **N/A** or **expected** if a tester hits them:

| Item | What testers will see | Why it is allowed |
| --- | --- | --- |
| Cold start | 30–60s spinner / pending fetch after idle | Render Free sleep. |
| Redis | Health `"redis": "unavailable"`; admin “Polling fallback” if SSE is quiet | Optional cache. App is designed to run without it. |
| Demo login | Hosted web rejects `demo@strollwise.local` | Production flag is off. |
| Unthreshold zones | Zones visible with low contributor counts | Production has few approved tags; cells need `pending_min_reports_per_cell` (default 3) agreeing contributors. |
| Tag cooldown | Second tag in the **same H3 cell** may be rejected for hours | Default `report_cooldown_hours_per_cell` is 24. Testers must pick **different streets**. |
| Rate limit | Very fast repeat submits may 429 | `report_max_per_user_per_hour` (default 30). |
| Outside Cebu | GPS / Explore-center tagging refused | Service area is Metro Cebu. |
| Visit pins | Hiking-button pins are **private** to the user | By design; they must not appear as public zone GPS. |
| Bookmark on zone details | Tapping Save / the bookmark glyph adds the zone to Profile → Saved zones | Requires a signed-in account (not demo). |
| Layers route | Not in the tab bar | Skip. |
| PostGIS advisor | Supabase Security Advisor ERROR on `spatial_ref_sys` | Catalog table owned by `supabase_admin`; do not drop PostGIS. |
| Admin live-sync | “Live — mobile sync” may fall back to polling | Single worker + optional SSE. Polling still refreshes queues. |
| Google Maps | Opens an external maps tab/app | Expected. |
| Native APK lagging web | Old phone build may still have the “zone card won’t close” bug | Rebuild the APK from current `main`/hosting branch; until then, score web. |

---

## 7. Session scripts

Run in this order so later cases have data.

### Session 0 — Facilitator pre-flight (10 min)

Wake `/health`, open traveler + admin, confirm operator login, screenshot Dashboard counts (pending, zones, users) as the **baseline**. Do not rebuild Render during the session.

### Session 1 — Traveler happy path (45–60 min)

Each traveler tester, alone:

1. Register (T-AUTH-01) → land on Explore.
2. Map: pan Cebu, select a zone, dismiss the card, select again (T-EXP-01…04).
3. Search a known Cebu place (T-EXP-05).
4. Add Tag at a **unique** street (T-TAG-01).
5. Feed → **View on map** for a listed zone (T-FEED-02).
6. Trends sections (T-TRD-01).
7. Profile: confirm the new tag in recent contributions; set or confirm location preference; logout / login (T-PRF-*).

### Session 2 — Edges (20–30 min)

Wrong password, empty register, consent skipped, tag with no location, tag outside Cebu, pull-to-refresh, hard refresh mid-session (T-NEG-\* and selected T-EXP / T-TAG negatives).

### Session 3 — Operator (45–60 min)

Login, reject non-admin, walk every nav item, moderate the tags from Session 1 (approve one, flag or reject one), inspect zone validation, export CSV/JSON, confirm audit row, **do not** click Full pipeline unless the facilitator is ready to wait for rebuild.

### Session 4 — Paired E2E (20–30 min)

Traveler submits a clearly labeled test tag (“UAT food note, discard”). Operator sees it in Pending without seeing raw GPS in the list. Approve. Traveler pull-to-refresh Feed / Profile. Facilitator notes whether the public map changed (it may **not** until the cell hits threshold — that is still a pass for E2E-01 if moderation and profile counts update).

### Session 5 — Wrap-up (15 min)

Scribe tallies P0/P1. Product owner signs §12.

---

## 8. Test cases

Score each case **Pass / Fail / Blocked / N/A**. Blocked means environment or missing account, not product disagreement.

Expected results are the **acceptance** bar. Anything in §6 is N/A.

### 8.1 Environment

| ID | Case | Steps | Expected |
| --- | --- | --- | --- |
| ENV-01 | API health | Open `/health` after idle | JSON with `"database": "ok"`. Redis unavailable is OK. |
| ENV-02 | Traveler loads | Open traveler URL, wait for cold start | Auth screen, StrollWise branding, no infinite blank page. |
| ENV-03 | Admin loads | Open admin URL | Researcher sign-in form. Optional API-unreachable banner only if health is actually down. |
| ENV-04 | Legal on API | Open `/privacy` and `/terms` on the API host | HTML policies load. |

### 8.2 Traveler — auth and legal

| ID | Case | Steps | Expected |
| --- | --- | --- | --- |
| T-AUTH-01 | Register | Switch to create account. Email, password ≥ 8, display name, traveler type, origin country **and** city, check research consent. Submit. | Lands on Explore. No demo banner. |
| T-AUTH-02 | Register validation | Omit consent; too-short password; empty display name; submit. | Inline / snackbar errors; stay on auth. |
| T-AUTH-03 | Login | Sign out if needed. Log in with T-AUTH-01 credentials. | Explore. Session survives a hard refresh. |
| T-AUTH-04 | Bad login | Wrong password. | Error snackbar; not logged in. |
| T-AUTH-05 | Demo login blocked | Try `demo@strollwise.local` / `demo12345` on **hosted** web. | Login fails (production). N/A on a local debug build where demo is on. |
| T-AUTH-06 | Privacy / terms from auth | Open Privacy and Terms links on the consent card. | Screens open; close returns to auth. |
| T-AUTH-07 | Guarded routes | While logged out, paste `/explore` in the address bar (web). | Redirect to `/auth`. |

### 8.3 Traveler — Explore

Use a signed-in account. Allow location **or** set a Cebu manual location on Profile first.

| ID | Case | Steps | Expected |
| --- | --- | --- | --- |
| T-EXP-01 | Basemap and zones | Open Explore. Wait for style + zones. | Cebu-centered map, colored zone fills, bottom nav visible. |
| T-EXP-02 | Select zone | Tap inside a colored zone (e.g. Lahug). | Bottom **zone card** with name, mix, activity; not a blank sheet. |
| T-EXP-03 | Dismiss zone card | Tap the **X** (close). Wait 1s. Tap empty map (water / unlabeled road) if needed. | Card **stays closed**. It must not immediately pop back. Repeat twice. |
| T-EXP-04 | Re-select after dismiss | After T-EXP-03, tap the same zone again. | Card opens again for that zone. |
| T-EXP-05 | Place search | Search `Ayala Center Cebu` or `IT Park`. Pick a result. | Camera moves; search/insight UI updates. |
| T-EXP-06 | Filters | Open Filters. Apply a traveler mix and/or place type (e.g. Food). Clear filters. | Map / chips reflect the filter; clearing restores the previous set. Empty filter result is OK if copy says nothing matches. |
| T-EXP-07 | Zoom and my-location | Use + / −. Tap the location FAB. | Zoom changes. Location FAB recenters on GPS or the Profile manual pin inside Cebu. |
| T-EXP-08 | Visit pin | Tap the hiking FAB while signed in. | “Visit saved” (or equivalent) notification. Pin is **not** required to show as a public zone. |
| T-EXP-09 | View Details | From the zone card, tap View Details. | Detail sheet with traveler mix and close control. Bookmark may no-op (§6). |
| T-EXP-10 | Google Maps | From the zone card, tap Google Maps. | External maps opens toward that area. If the device has no maps handler, note N/A rather than fail. |
| T-EXP-11 | Notifications bell | Tap the bell if a tag was just submitted. | Notification sheet can open; unread dot acceptable. |

### 8.4 Traveler — Add Tag

Pick a **new** Cebu street each submit so cooldown does not fail the case.

| ID | Case | Steps | Expected |
| --- | --- | --- | --- |
| T-TAG-01 | Happy path | Add Tag. Set location via place search (e.g. a specific barangay street) **or** GPS inside Cebu **or** “use Explore map center” while Explore is on Cebu. Choose type (Food / Safety / …), a detail chip, optional note `UAT <tester> <time>`. Submit. | Success notification with H3 / threshold copy. App returns to Explore. |
| T-TAG-02 | No location | Clear location if possible and submit. | Warning: location required. No silent success. |
| T-TAG-03 | Outside Cebu | If tester GPS is outside Cebu, tap Use GPS. Or move Explore far away and use map center. | Refusal copy about Cebu tagging area. |
| T-TAG-04 | Place search miss | Search a non-Cebu query (`Reykjavik`). | Empty / no-match message. |
| T-TAG-05 | Categories | Spot-check Food, School, Transport, Safety. | Each selects; detail chips change. |
| T-TAG-06 | Cooldown (optional) | Immediately submit a **second** tag at the **same** pin. | May reject with cooldown hours. Pass if either a clear error **or** (unlikely) accept because settings were lowered. Do not file cooldown as a product bug. |

### 8.5 Traveler — Feed

| ID | Case | Steps | Expected |
| --- | --- | --- | --- |
| T-FEED-01 | List loads | Open Feed. | Ranked zone cards and/or empty state + pull to refresh. Not a raw exception. |
| T-FEED-02 | View on map | Tap **View on map** on a zone card (not only the card body). | Explore opens, camera on that zone, zone card for that area. |
| T-FEED-03 | Filters | Tap Following / Nearby / Trending / Food / Crowd / Safety. | List updates or shows the empty-state copy. Pull to refresh works. |
| T-FEED-04 | Activity strip | If recent activity exists, it is readable. If empty, no crash. | Pass either way. |

### 8.6 Traveler — Trends

| ID | Case | Steps | Expected |
| --- | --- | --- | --- |
| T-TRD-01 | For You | Open Trends. | Hero + For You content; can jump to Explore. |
| T-TRD-02 | Browse / Routes | Switch section tabs. Try a vibe chip (Food, Night, …). | Content changes without breaking the tab bar. |
| T-TRD-03 | Pull to refresh | Pull down. | Completes; no stuck spinner. |

### 8.7 Traveler — Profile

| ID | Case | Steps | Expected |
| --- | --- | --- | --- |
| T-PRF-01 | Identity | Open Profile after T-TAG-01. | Display name, traveler type, origin. Not the demo-session callout. |
| T-PRF-02 | Contributions | Check submitted / pending / approved counts and recent tags. | Submitted ≥ 1 after T-TAG-01. Pending vs approved depends on moderation (see E2E). |
| T-PRF-03 | Visit history | After T-EXP-08, history lists the pin. Open it. | Explore focuses that spot. |
| T-PRF-04 | Manual location | Set a Cebu map location from Profile. Return to Explore. | Location banner / my-location uses that pin when GPS is off or outside Cebu. |
| T-PRF-05 | Edit profile | Change display name or origin; save. | Values persist after refresh. |
| T-PRF-06 | Logout | Logout confirm. | Auth screen. Explore is blocked (T-AUTH-07). |
| T-PRF-07 | Saved zones | Note the saved list. | Empty list is **Pass** (bookmark not wired). Fail only if the page crashes. |

### 8.8 Admin

Use the operator account. Browser desktop.

| ID | Case | Steps | Expected |
| --- | --- | --- | --- |
| A-AUTH-01 | Operator login | Sign in at `/login`. | Dashboard. Sidebar nav. |
| A-AUTH-02 | Non-admin rejected | Log in with a traveler account. | Returned to login with admin-required behavior; no dashboard data. |
| A-AUTH-03 | Sign out | Sign out. | Login page; refresh stays logged out. |
| A-DASH-01 | Dashboard | Read the four stats and 30-day chart. | Numbers load (zeros are OK). Review queue and Export shortcuts work. |
| A-MOD-01 | Queues | Open Moderation. Click Pending, Flagged, Duplicates, Near threshold. | Each queue loads a table or empty state. Search filters rows. |
| A-MOD-02 | Privacy | Open a report detail. | Category, H3, tags, note. **No raw lat/lng, email, or name of the traveler** in the list/detail the UI advertises as privacy-safe. |
| A-MOD-03 | Approve | Approve one UAT tag from Session 1. | Item leaves Pending; Dashboard pending count drops. |
| A-MOD-04 | Flag or reject | Flag **or** reject a different UAT tag (not the only remaining good tag if you still need E2E). | Queue and dashboard update; error banner only on real API failure. |
| A-ZON-01 | Zone list | Zones page: All / defined / emerging / unthreshold. Search a known name. | Rows load. Unthreshold count may be > 0. Select a zone → validation panel. |
| A-USR-01 | Users search | Search the traveler tester email. | Row with type and report count. **Do not** toggle admin on a tester unless the product owner scheduled that case. |
| A-CAT-01 | Catalog | Catalog page loads named Cebu zones. Export CSV or JSON. | File downloads. |
| A-ANL-01 | Analytics + export | Analytics overview. Download reports CSV and/or zones JSON and audit CSV. | Files download; exports are aggregated (H3 / zone), not a GPS trail dump. |
| A-AUD-01 | Audit | After A-MOD-03, open Audit Log. | A row for the moderation action appears (allow a short poll delay). |
| A-PIP-01 | Cache invalidate | Pipeline → **Invalidate cache** only. | Success result. Do **not** run Full pipeline / rebuild-all during UAT unless the facilitator announces a rebuild window. |
| A-SET-01 | Settings read | Open Settings. Record current thresholds. | Fields load. **Do not save** unless a scheduled settings case exists. Saving changes live tag rules for everyone. |
| A-NAV-01 | Legal / API docs | Footer Privacy and Terms. API docs link. | Privacy/terms open. API docs may be **disabled in production** — N/A if `/docs` is 404. |

### 8.9 End-to-end and privacy

| ID | Case | Steps | Expected |
| --- | --- | --- | --- |
| E2E-01 | Tag → queue → profile | Traveler T-TAG-01. Operator sees the report in Pending (A-MOD-01/02). Approve (A-MOD-03). Traveler refreshes Profile. | Pending/approved counts move in the right direction. Public **zone geometry may not change** until enough distinct contributors hit the cell — still Pass. |
| E2E-02 | Feed → Explore | T-FEED-02 after zones exist. | Same as T-FEED-02; camera not stuck on a previous city. |
| E2E-03 | No trajectory leak | Operator and a second traveler browse Explore / Feed / zone detail / admin list. | No other user’s exact GPS or identity on public surfaces. Visit pins stay on the owner’s profile/map only. |

---

## 9. Pass / fail rules

### Case-level

- **Pass:** Expected result observed on the first or second try (retry once after a cold start).
- **Fail:** Wrong behavior **after** API health is OK, and the behavior is not in §6.
- **Blocked:** Cannot run (API down, no admin password, GPS hardware missing for a GPS-only step). Re-run when unblocked; do not count as product fail.
- **N/A:** Case does not apply (demo login on debug builds, Google Maps missing, settings write skipped).

### Product-level (go / no-go)

**Go** if:

- All of ENV-01–03, T-AUTH-01, T-AUTH-03, T-EXP-01–04, T-TAG-01, T-FEED-02, T-PRF-01, A-AUTH-01, A-AUTH-02, A-MOD-02, A-MOD-03, E2E-01, E2E-03 are **Pass**.
- No open **P0**.
- At most two **P1**, each with an owner and workaround.

**No-go** if any of those core IDs Fail, or a P0 remains (data leak, cannot log in, map never loads after health OK, cannot submit a tag inside Cebu, admin moderation broken, zone card cannot be dismissed on the **build under test**).

---

## 10. Defects

File in the team tracker (GitHub issue is fine). One defect per problem.

| Field | What to capture |
| --- | --- |
| ID | `UAT-YYMMDD-##` |
| Case ID | e.g. T-EXP-03 |
| Surface | traveler web / admin / API / native |
| Device / browser | e.g. Pixel Chrome 131, Mac Safari |
| Steps | Numbered, including the tag location if relevant |
| Expected / actual | Short |
| Screenshot / clip | Required for UI bugs |
| Health JSON | Paste `/health` if the API was involved |
| Severity | See below |

| Severity | Meaning | Example |
| --- | --- | --- |
| **P0** | Stop UAT / stop demo | Auth broken; Explore blank after health OK; GPS of user B visible to user A; cannot dismiss zone card on the build under test |
| **P1** | Core path broken with workaround | View on map goes to Explore but wrong camera; tag submit succeeds but no profile row |
| **P2** | Secondary path | Trends vibe chip empty; export filename ugly |
| **P3** | Polish | Copy, spacing, chart empty state |

Do **not** file: Render sleep, Redis unavailable, unthreshold zones, bookmark no-op, demo login off, PostGIS advisor, cooldown on the same cell.

---

## 11. Data and safety rules for testers

- Notes like `UAT-Ada 14:32 Food` only. No home addresses, plate numbers, or other people’s names.
- Do not promote testers to admin “to see what happens.”
- Do not run `rebuild-all` or change H3 resolution during a live class demo.
- Do not run `seed.py` on production.
- Prefer different map pins so one tester’s cooldown does not block another if they share a cell.
- Operator exports stay with the research team; they are still aggregated, not a reason to email CSV dumps to a public chat.

---

## 12. Sign-off

Copy this block into the results sheet when Session 5 ends.

| Field | Value |
| --- | --- |
| Date | |
| Build (traveler / admin / API) | URLs + approximate time of test |
| Facilitator | |
| Testers | |
| Core cases (list in §9) | __ / __ Pass |
| P0 open | |
| P1 open | |
| Decision | Go / No-go / Go with waivers |
| Waivers | IDs + owner |
| Product owner signature | |

---

## 13. Results sheet (copy per tester)

Duplicate this table in a spreadsheet or below in a session note.

| Case ID | Tester | Platform | Result | Notes / defect ID |
| --- | --- | --- | --- | --- |
| ENV-01 | | | | |
| ENV-02 | | | | |
| ENV-03 | | | | |
| T-AUTH-01 | | | | |
| T-AUTH-03 | | | | |
| T-AUTH-05 | | | | |
| T-EXP-01 | | | | |
| T-EXP-02 | | | | |
| T-EXP-03 | | | | |
| T-EXP-04 | | | | |
| T-EXP-05 | | | | |
| T-TAG-01 | | | | |
| T-FEED-02 | | | | |
| T-TRD-01 | | | | |
| T-PRF-01 | | | | |
| T-PRF-06 | | | | |
| A-AUTH-01 | | | | |
| A-AUTH-02 | | | | |
| A-MOD-02 | | | | |
| A-MOD-03 | | | | |
| E2E-01 | | | | |
| E2E-03 | | | | |

Add remaining IDs from §8 as extra rows. Core rows above are the minimum the product owner should see filled.

---

## 14. Facilitator one-pager

**Before:** wake health → traveler auth page → admin login → screenshot dashboard.

**During:** one unique Cebu pin per tag; no seed; no full pipeline; no settings save; no extra admins.

**After:** tally P0/P1; confirm E2E-03 (privacy); owner signs §12.

**If the map card keeps reopening on a phone:** confirm whether the tester is on **hosted web** (fixed) or an **old APK**. Score the host that matches the build under test; rebuild native before a second UAT pass on Android.

Related ops notes: [`HOSTING.md`](HOSTING.md).
