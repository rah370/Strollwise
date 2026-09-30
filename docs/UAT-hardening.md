# UAT hardening plan

Work list to make hosted StrollWise pass [`UAT.md`](UAT.md) go/no-go cases and close loops testers hit. Do not seed production. Do not change H3 resolution.

Status: **implemented on this branch.** Re-run UAT after Render deploys.

## Blockers (must pass)

| ID | UAT cases | Change |
| --- | --- | --- |
| P0-1 | E2E-03 | Public `/reports/place-markers` returns H3 cell centroids of **visible** reports only (no raw GPS, no pending). |
| P1-1 | A-DASH-01 | Empty 30-day chart is outside Recharts `ResponsiveContainer`. |
| P1-2 | T-PRF-02, E2E-01 | Profile contributions keep last-good stats on refresh error. Safe H3 substring. |
| P1-3 | T-TAG-02, T-TAG-03 | Location-required warning reachable. GPS outside Cebu uses Cebu-area copy. API rejects tags outside the 120 km Cebu service area. |
| P1-4 | T-PRF-06, T-AUTH-03 | Logout awaits Secure Storage clear before dropping the in-memory token. |
| P1-5 | A-AUTH-01 | Admin clears session only on 401/403. Login validates `/me` before bounce. Health check requires JSON `status` + `database`. |
| P1-6 | T-EXP-03, T-EXP-04, T-EXP-06 | Empty-map taps do not snap to a nearby cell. Filter “Show on map” redraws and tracks chips. Mix **and** place-type keys. 800 ms dismiss ignore window. |

## Loops and operator safety

| ID | UAT cases | Change |
| --- | --- | --- |
| P2-1 | T-FEED-01, T-TRD-03 | Watch quantized lat/lng so GPS ticks do not refetch Feed/Trends. |
| P2-2 | Admin load | Poll only when SSE is down. |
| P2-3 | A-PIP-01, A-SET-01 | Confirm before pipeline rebuilds and settings save. Pipeline POSTs rate-limited. |
| P2-4 | A-CAT-01 | Catalog export downloads catalog rows, not merged analytics zones. |
| P2-5 | T-EXP-09 / related | Zone-detail “nearby” focus uses centroid **or** polygon, same as Feed. |

## Out of scope this pass

- `StatefulShellRoute` keep-alive (View on map already uses pending camera).
- Wiring the zone-detail bookmark (UAT currently allows empty saved list).
- PostGIS `spatial_ref_sys` advisor, Render sleep, Redis off, demo login off.
