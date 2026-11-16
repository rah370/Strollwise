# StrollWise User Manual

Crowd-sourced zone intelligence for **Metro Cebu**.

This guide is for travelers using the app and researchers using the admin console. It is not a developer setup guide. For hosting, see [HOSTING.md](HOSTING.md). For acceptance testing, see [UAT.md](UAT.md).

---

## 1. What StrollWise is

StrollWise is a map of **how people actually use places in Metro Cebu** — not a GPS trail of individuals.

Travelers drop **tags** (short notes about food, safety, transport, and so on). StrollWise groups those tags into **named areas** (for example IT Park or Lahug) and colors them by **who uses the area**:

| Map meaning | What it means |
| --- | --- |
| Mostly locals | People who live in Cebu |
| Mostly visitors | People visiting from abroad |
| Locals and visitors | A mix of both |
| Not sure yet | Not enough tags yet |

The public map never shows another person’s exact GPS, email, or walking path. Tags are snapped to a small hex-shaped cell, then rolled into a place on the map.

There are two products:

1. **Traveler app** — Explore the map, add a tag, browse Feed and Trends, manage your profile.
2. **Researcher console** — Review tags, inspect places, export spreadsheets. Researchers only.

---

## 2. How to open it

| What | Address |
| --- | --- |
| Traveler app | https://strollwise-app.onrender.com |
| Researcher console | https://strollwise.onrender.com |
| Privacy policy | https://strollwise-api.onrender.com/privacy |
| Terms of use | https://strollwise-api.onrender.com/terms |

The first load can take **30–60 seconds** if the server was idle. Wait for the sign-in screen. That delay is normal.

Use Chrome or Safari. On a phone you can add the traveler URL to the home screen; it works in the browser. A native Android or iOS build may also be used when the team gives you one pointed at the same server.

---

## 3. Traveler guide

### 3.1 Create an account

1. Open the traveler app.
2. Switch to **Create your account**.
3. Fill in:
   - Display name
   - Email
   - Password (at least 8 characters)
   - How you travel: lives in Cebu / visiting from elsewhere in the Philippines / visiting from abroad
   - Country and city of origin (pick from the lists)
   - Check the **research consent** box
4. You can open **Privacy** and **Terms** from this screen before you accept.
5. Submit. You land on **Explore**.

**Sign in later:** Welcome back → email + password.

**Forgot password:** tap **Forgot password?**, enter your email, then enter the 6-digit code and a new password. If email sending is not configured, the app may show the code on screen so you can finish the reset.

Demo accounts such as `demo@strollwise.local` do not work on the hosted app.

### 3.2 The five tabs

| Tab | Job |
| --- | --- |
| **Explore** | Map of Cebu zones |
| **Add Tag** | Drop a pin and describe the place |
| **Feed** | Live stream of area tags and pulses |
| **Trends** | Suggestions and vibes |
| **Profile** | Your tags, visits, settings, logout |

### 3.3 Explore (the map)

1. After sign-in you should see Metro Cebu, colored zone fills, and the bottom tabs.
2. Allow location **or** set a Cebu place later in Profile. StrollWise only tags inside Metro Cebu.
3. **Tap a colored zone** to open the bottom card (name, mix, how busy it feels).
4. Close it with **X**. Tap empty map (water or unlabeled road) if the card should stay closed. Tap the same zone again to reopen it.
5. **Search** a known place (for example `Ayala Center Cebu` or `IT Park`). Pick a result to move the camera.
6. **Filters** — traveler mix and/or place type. Clear filters to restore the full map.
7. **+ / −** zoom. The location button recenters on GPS or on the Cebu pin you chose in Profile.
8. **Hiking / visit button** — saves a **private** visit pin for you. It does not become a public zone.
9. **View Details** — mix, activity, and more about that area. Save / bookmark (when signed in) can add the zone to Profile → Saved zones. Saving a zone also lets **Feed → Following** show it.
10. **Google Maps** — opens the external maps app toward that area.

The map is about **places**, not people. You will not see other travelers as dots.

### 3.4 Add a tag

Pick a **new street** each time. A second tag in the **same small cell** within about **24 hours** is usually refused (cooldown).

1. Open **Add Tag**.
2. Set location in one of these ways:
   - Place search (barangay, mall, street inside Cebu)
   - Use GPS (must be inside Metro Cebu)
   - Use the Explore map center while Explore is on Cebu
3. Choose a kind, then a detail chip. Common kinds:
   - **Food** — Street Food, Cafe, Restaurant, Late Night
   - **Attractions** — Photo Spot, Landmark, Visitor Friendly, Scenic
   - **Local Favorite** — Neighborhood Favorite, Budget Meal, Worth Detour, Calm
   - **Transport** — Near Transit, Pickup Point, Traffic, Easy Crossing
   - **Nature** — Shade, Green Space, Fresh Air, Quiet Walk
   - **Safety** — Well Lit, Avoid Late, Police Nearby, Crowded Exit
   - Residential, Commercial, and other types as shown on screen
4. Optional short note. Do **not** write home addresses, plate numbers, or other people’s names. Example: `Good sisig at lunch`.
5. Submit. You should see **Tag submitted** and return to Explore.

If it fails:

| Situation | What to do |
| --- | --- |
| Location required | Search a Cebu place or allow GPS |
| Outside the tagging area | Move the pin into Metro Cebu |
| Cooldown | Tag a different street, or wait until the next day |
| Sensitive building | Move the pin off hospitals, schools, military, and similar sites |
| Search miss (for example `Reykjavik`) | Expected — only Cebu places |

A new tag is **waiting for review**. It does **not** always change the public zone color immediately. Enough **different people** must agree on the same kind of place in that cell (default: **3 people**, about **60% agreement**), **or** a researcher publishes it.

### 3.5 Feed

Feed is a live stream of short community posts and **Live Zone Pulse** cards — not a list of place names only.

1. Open **Feed**. Pull down to refresh.
2. Filter chips: **Nearby**, **Following**, **Food**, **Crowd**, **Safety**.
3. **Following** shows areas you saved on Explore. If it is empty, save a zone from a zone card first.
4. The composer bar at the top jumps to **Add Tag**.
5. Posts use a privacy-safe handle such as `@local` or `@visitor`, not email.
6. **Like** is on-device feedback for the stream.
7. **View on map** opens Explore on that area.

Empty results are OK if the copy says nothing matches yet.

### 3.6 Trends

1. Open **Trends**.
2. **For You** is the starting view; you can jump to Explore from a card.
3. Switch **Browse / Routes** and try vibe chips (Food, Night, and others).
4. Pull down to refresh.

### 3.7 Profile

- Display name, traveler type, origin.
- **Contributions** — submitted / waiting / on the map. After you tag, submitted should be at least 1. Waiting vs on the map depends on review.
- **Badges** — earned by tagging (for example Food Finder, Safety Reporter).
- **Visit history** — private pins from Explore; open one to focus that spot.
- **Saved zones** — areas you saved from zone details (also powers Feed → Following).
- **Map location** — choose a Cebu place when you do not want Explore to follow live GPS.
- **Edit profile** — name or origin; save; it should survive a refresh.
- **Settings** — account, privacy links, logout. Confirm logout. You return to sign-in; Explore is blocked until you sign in again.

---

## 4. Researcher console guide

For operators and thesis researchers only. A normal traveler account is **rejected** (you return to sign-in).

### 4.1 Sign in

1. Open https://strollwise.onrender.com
2. Email + password for an **admin** account.
3. You land on the **Validation dashboard**.
4. **Forgot password** works the same way as the traveler app.
5. **Sign out** is at the bottom of the sidebar.

The green **LIVE — MOBILE SYNC** (or similar) means new traveler tags can refresh the console. If it falls back to polling, lists still update; wait a few seconds.

If the API is waking up, you may see “Cannot reach the StrollWise API.” Open `/health`, wait until `"database": "ok"`, then retry. Your session is kept.

### 4.2 Sidebar

| Item | What it is |
| --- | --- |
| **Dashboard** | Snapshot: waiting tags, map health, contributors |
| **Review tags** | Publish, hold, or mark tags wrong |
| **Places** | Named Cebu areas and validation |
| **Users** | Traveler accounts (type, activity) — not a public directory |
| **Place list** | Catalog of named footprints |
| **Export** | Spreadsheets for the thesis |
| **Settings** | Tag rules (thresholds). Read first; saving changes live rules for everyone |
| **Activity** | Audit of researcher decisions |

Hosted production may still show older names such as Moderation / Zones / Pipeline / Audit Log. Same jobs, different labels.

### 4.3 Dashboard

Read the stats (waiting tags, published tags, zones, users) and the 30-day chart. Zeros are valid on a quiet day.

Shortcuts:

- **Review waiting tags** → Review tags
- **Download spreadsheets** → Export

Do not treat a cold-start spinner as a broken dashboard. Refresh once after `/health` is OK.

### 4.4 Review tags (moderation)

This is the main researcher job.

**Lists**

| List | Meaning |
| --- | --- |
| **Waiting** | Need a yes or no |
| **Hold** | Needs a reason before it can go on the map |
| **Almost ready** | A few more matching tags would auto-publish |
| **Mixed** | People described this area differently |
| **Repeats** | Similar tags in the same area |
| **All** | Every tag, including published ones |

Search by place, tag, or note. Filter by kind. Open a row to see **Should this go on the map?** — how many people tagged the area, how much they agree, and whether it is ready.

**What you will not see:** raw GPS, email, or a public trail of the tagger. You may see a display label such as a first name or “Traveler.”

**Actions**

| Button | Effect |
| --- | --- |
| **Publish** | Tag becomes visible; the cell may rebuild into the map |
| **Hold** | Needs a reason (wrong location, wrong kind, spam, sensitive building, other) |
| **Wrong** | Removed from the map; needs a reason |

You can select several rows. **Bulk publish** only works when those areas already show strong agreement.

After you publish, the public map **may still look the same** until enough distinct people have agreed in that cell. That is expected. The tag should leave Waiting and show in Activity.

### 4.5 Places

Browse All / Established / Growing / Just starting. Search a known name (Lahug, IT Park). Select a row for validation context (counts, mix). Low contributor counts (“just starting”) are normal early in the project.

### 4.6 Users

Search by email, name, or hometown. You see traveler type and tag counts.

Do **not** promote a tester to admin unless the product owner asked for that. You can pause an account if needed; that is audited.

### 4.7 Place list and Export

Named Cebu footprints. Download **CSV** or **JSON**.

Exports are **aggregated** (place / hex cell / counts). They are **not** a GPS trail dump. Keep files with the research team; do not post them in a public chat.

Typical downloads: tags, places, activity log.

### 4.8 Settings

Shows live tag rules, including:

- Minimum distinct people per cell (default **3**)
- Agreement ratio (default about **60%**)
- Cooldown hours in the same cell (default **24**)

Do **not save** during a class demo unless a settings change was scheduled. Saving affects everyone.

Map refresh / cache controls may live under Settings → Map (older consoles: Pipeline). Prefer **Invalidate cache** only. Do not run a full rebuild during a live session unless someone is ready to wait.

### 4.9 Activity

After you publish, hold, or mark wrong, a row should appear (for example “Published a tag”). Allow a short delay. Filter by travelers vs researcher decisions and by date if those tabs exist.

Footer **Privacy**, **Terms**, and **API docs** — API docs require your researcher sign-in. Public `/docs` is off in production.

---

## 5. How a tag becomes a map zone

```text
You tag a street in Cebu
        ↓
Tag is stored as “waiting” (hex cell, not a public GPS trail)
        ↓
Either:
  • Enough different people agree on the same kind of place
  • Or a researcher publishes it
        ↓
The named place / zone on Explore can update
```

One tag is a **contribution**, not an instant new polygon. That protects privacy and reduces one-person noise.

---

## 6. Privacy and safety rules

For everyone:

- No home addresses, plate numbers, or other people’s names in notes.
- Do not try to reconstruct another user’s GPS from the map.
- Visit pins stay on **your** profile only.
- Researchers must not share export files outside the research team.

For researchers:

- Do not promote random testers to admin.
- Do not run production database seed scripts.
- Do not change live thresholds during a public demo.

---

## 7. Troubleshooting

| What you see | What it usually is | What to do |
| --- | --- | --- |
| Spinner for about a minute on first open | Server was asleep | Wait, then refresh |
| Blank traveler page after 90s | API still down | Open https://strollwise-api.onrender.com/health — need `"database": "ok"` |
| Cannot sign in as traveler on admin | Not an admin account | Use the traveler app, or ask an operator to promote you |
| Tag rejected immediately in the same spot | 24-hour cooldown | Move to another street |
| Tag submitted but map color unchanged | Not enough agreeing people yet | Normal; check Profile and Review tags |
| Search finds nothing | Place is outside Cebu or unknown | Try a well-known Cebu name |
| Feed → Following is empty | No saved zones yet | Save a zone from Explore details |
| Admin stuck on Loading | API timeout or old build | Wake `/health`, hard-refresh; operators can restart the API service |
| `demo@strollwise.local` fails | Demo login is off on hosted web | Register a real tester email |

---

## 8. Quick checklists

### Traveler (about 15 minutes)

- [ ] Create account with consent
- [ ] Land on Explore, tap a zone, close the card, open it again
- [ ] Search IT Park or Ayala
- [ ] Add one tag on a unique Cebu street
- [ ] Open Feed, try Nearby, tap View on map
- [ ] Open Trends
- [ ] Confirm the tag on Profile
- [ ] Sign out and sign in again

### Researcher (about 15 minutes)

- [ ] Sign in; traveler account must be rejected
- [ ] Dashboard numbers load
- [ ] Review tags: open Waiting, open a row (no GPS/email)
- [ ] Publish one tag; hold or mark wrong another (with a reason)
- [ ] Confirm a row in Activity
- [ ] Download one export

---

## 9. Glossary

| Term | Plain meaning |
| --- | --- |
| Tag | Your short report about a place |
| Zone / place | A named Cebu area on the map |
| Traveler mix | Mostly locals, mostly visitors, or both |
| Waiting | Tag not on the public map yet |
| Publish | Researcher puts a tag on the map |
| Hold | Researcher pauses a tag for a reason |
| Hex cell | Small private bucket for nearby tags (not shown as someone’s path) |
| Threshold | How many agreeing people are needed to auto-publish |
| Following | Feed filter for zones you saved on Explore |

---

## 10. Support

- Product / thesis owner: StrollWise team
- Health check: https://strollwise-api.onrender.com/health
- Legal: Privacy and Terms links in the app and at the API URLs in section 2
