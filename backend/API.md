# StrollWise API

Human reference for the traveler app, the admin console, and research write-ups.
Machine-readable Swagger is **not** public on Render.

| Where | What you get |
| --- | --- |
| Local (`ENV=development`) | `http://localhost:8000/docs` (Swagger) and this file |
| Production | `/docs`, `/redoc`, `/openapi.json` stay **404** on purpose |
| Signed-in admin | `GET /api/v1/admin/docs` and `GET /api/v1/admin/openapi.json` (JWT required) |

Base path for all product routes: **`/api/v1`**.

Send `Authorization: Bearer <access_token>` after login. JSON bodies unless noted.

## Privacy (always)

- Public map responses use **H3 cell centroids**, not raw GPS.
- A traveler’s pending tag is visible only to them until it is published.
- Place markers (`GET /reports/place-markers`) only include **visible** reports.
- `GET /reports/sensitive-sites` is authenticated and returns `{kind, lat, lng, radius_m}` — no facility names.
- Admin Review tags lists a display name, never email.

## Traveler app

### Sign in

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/auth/register` | Creates account; returns JWT |
| POST | `/auth/login` | Email + password; returns JWT |
| POST | `/auth/forgot-password` | Sends a reset code |
| POST | `/auth/reset-password` | Email + code + new password |
| GET | `/auth/me` | Current user (JWT) |

### Profile

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/users/me` | Profile |
| PATCH | `/users/me` | Update profile |
| GET | `/users/me/contributions` | Own tags (cell centroid, not raw GPS) |
| GET | `/users/me/saved-zones` | Saved places |
| POST | `/users/me/saved-zones/{zone_id}` | Save |
| DELETE | `/users/me/saved-zones/{zone_id}` | Unsave |

### Explore (map)

Viewport queries take `min_lat`, `max_lat`, `min_lng`, `max_lng`.

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/zones` | Zones in the viewport |
| GET | `/zones/feed` | Recent / ranked zones |
| GET | `/zones/current` | Zone around a lat/lng |
| GET | `/zones/{zone_id}` | Zone detail |
| GET | `/zones/{zone_id}/nearby` | Neighbors |
| GET | `/places` | Catalog places in the viewport |
| GET | `/places/recommendations` | Suggestions |
| GET | `/places/resolve` | Place at a point |
| GET | `/places/{place_id}` | Place detail |
| GET | `/cells` | H3 cells in the viewport |
| GET | `/geocode/forward` | Place-name search |

### Add Tag

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/reports` | Submit a tag (`latitude`, `longitude`, `category`, `tags`, optional note/image) |
| GET | `/reports/sensitive-sites` | Muted building footprints (~40 m). Pin on a building is refused |
| POST | `/uploads/image` | Image for a tag |
| GET | `/reports/my-pending-pins` | Your unpublished pins in the viewport |
| POST | `/reports/my-visit-pins` | Private visit pin |
| GET | `/reports/my-visit-pins` | Private pins in the viewport |
| GET | `/reports/my-visit-history` | Recent visits |

Crowd publish rule: **3 different people** in the same H3 cell and **≥ 60%** the same category. Split agreement stays in review. Campus/USPF tags use that same rule.

Sensitive buildings (hospital, city hall, police station): tag the **street or cafe next to it**, not the building. Identity words such as “police station” must not become a public place title.

### Feed and trends

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/reports/feed` | Recent **published** tags |
| GET | `/reports/by-zone/{zone_id}` | Published tags in a zone |
| GET | `/reports/place-markers` | Validated pins for a tag token (H3 centroid) |
| GET | `/analytics/city-pulse` | City summary |
| GET | `/analytics/trends` | Trend series |
| GET | `/analytics/zone/{zone_id}/history` | Zone history |
| GET | `/analytics/zone/{zone_id}/category-trends` | Category mix over time |

## Admin console

Researchers sign in at `/login` with the same `POST /auth/login` as travelers. **Forgot password?** on that screen uses `POST /auth/forgot-password` and `POST /auth/reset-password`; the account keeps `is_admin`.

All under `/api/v1/admin/...`. Requires JWT **and** `is_admin`.

### Review tags

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/admin/moderation/reports` | Queues: `flagged` (Hold), `near_threshold`, `mixed_agreement`, `pending`, `duplicates`, `all` |
| GET | `/admin/moderation/reports/{id}` | Detail + cell agreement |
| POST | `/admin/moderation/reports/{id}/approve` | Publish |
| POST | `/admin/moderation/reports/{id}/reject` | Wrong — body `{ "reason": "wrong_location" \| "wrong_kind" \| "spam" \| "sensitive" \| "other" }` |
| POST | `/admin/moderation/reports/{id}/flag` | Hold — same `reason` required |
| POST | `/admin/moderation/reports/bulk` | Bulk; Publish only when agreement is high |

### Users, Activity, Settings

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/admin/users` | Roster |
| PATCH | `/admin/users/{user_id}` | `is_admin`, `is_active` (pause) |
| GET | `/admin/users/{user_id}/contributions` | Counts |
| GET | `/admin/audit` | Activity diary. `scope=admin` or `travelers`; `since` / `until` (Asia/Manila dates) |
| GET | `/admin/config` | Tag rules (crowd size, agreement, cooldown) |
| PATCH | `/admin/config` | Save tag rules (audited) |
| POST | `/admin/pipeline/rebuild-*` | Map refresh (audited) |
| GET | `/admin/dashboard/stats` | Home numbers |
| GET | `/admin/zones` | Place list on the admin map |
| GET | `/admin/analytics/overview` | Export overview |
| GET | `/admin/analytics/export/{reports\|zones\|audit}` | CSV/JSON |
| GET | `/admin/catalog/zones` | Catalog CRUD |
| GET | `/admin/events` | Live SSE (`?token=` because EventSource cannot send headers) |
| GET | `/admin/docs` | Swagger UI (admin JWT via header or `?token=`) |
| GET | `/admin/openapi.json` | OpenAPI schema (same auth) |

## Public (no JWT)

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/` | This is the API, not the website |
| GET | `/health` | Process + database (+ Redis) |
| GET | `/privacy` | Privacy policy HTML |
| GET | `/terms` | Terms HTML |

## Errors you will see on tags

| Status | Meaning |
| --- | --- |
| 401 | Missing or dead session |
| 403 | Signed in but not an admin |
| 422 | Validation: outside Cebu, pin on a sensitive building, duplicate pending cell, cooldown, hourly cap, missing Wrong/Hold reason |
