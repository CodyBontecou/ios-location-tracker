# Site Docs Gap Analysis — isome.isolated.tech vs. Feature Baseline

> Cross-check of `marketing/public/` (index, privacy, terms, blog) against `docs/FEATURES.md` and shipped release metadata (app at **1.7.10**; site copy predates the 1.6.0 outings release).
> Priorities: **P0 = legal/accuracy risk, P1 = factually wrong claims, P2 = missing features to expand on, P3 = clarify/polish.**

---

## P0 — Privacy policy & terms contradict the code (fix first)

The privacy policy (effective Apr 8, 2026) and Terms §03 make four claims the current build contradicts:

| # | Site claim | Reality (FEATURES.md ref) |
|---|---|---|
| P0-1 | Privacy §Data Collection: *"does not collect, transmit, or store any personal data on external servers"* · §Analytics: *"no analytics SDKs… no tracking pixels"* | **ANL-1**: onboarding/purchase analytics are **default-on in release builds**, sending a persistent install UUID + funnel events (app version, permission status, paywall outcomes) to `iso-me-onboarding-analytics.costream.workers.dev`. Homegrown, not an SDK — but it is telemetry with a durable device identifier, and the App Store privacy label question follows from it. |
| P0-2 | Privacy §Location Data: *"never leaves your device… not sent to… any server of any kind"* | **WHK-1**: opt-in webhooks POST location points/visits to user-chosen endpoints (Dawarich, OwnTracks Recorder, Traccar). Opt-in + paid + warned, but the policy's absolute language is false when the feature exists. |
| P0-3 | Privacy §Network Requests discloses only *geocoding* + *App Store* | Three undisclosed Apple-network surfaces beyond geocoding: **road snapping** (route segment endpoints → MKDirections), **place search & nearby suggestions** (coordinates → MKLocalSearch, VIS-5), **Live Activity map snapshots** (MKMapSnapshotter). Also **SCH-2**: when Auto Export is on, the app sends an install ID, APNs token, timezone, and schedule time to the scheduling worker (routing-only, no location — but it *is* stored in D1 and belongs in the policy's network section). |
| P0-4 | Terms §03: *"never transmitted to external servers"* | Same as P0-1/P0-2. |

**Recommended fix:** rewrite Privacy §Network Requests into an honest table — *Apple system services (geocoding, Maps search/directions/snapshots; toggleable only for geocoding)*, *optional analytics (default-on, pseudonymous install ID, funnel events only; state the retention/deletion posture)*, *optional webhook delivery (off by default, user-configured destination)*, *optional export scheduling service (timing metadata only, no location)*. Either that, or ship a build flag flip (make ANL-1 opt-in) and keep the current copy — that's a product decision, but one of the two must happen.

Also note: the site itself runs a gated Cloudflare Web Analytics beacon (fine — it's the website, not the app) but the homepage readout row "Analytics SDKs: **None listed**" and hero "No analytics SDKs" lean on the outdated policy and should be reworded once P0-1 is settled.

---

## P1 — Factually outdated product claims

| # | Site element | Says | Should say |
|---|---|---|---|
| P1-1 | Hero ticker, Feature 05, Showcase 03, Pricing card, FAQ, schema.org `featureList` | Export = "JSON, CSV, and Markdown" | **8 formats**: + GeoJSON, GPX, KML, OwnTracks, Overland (EXP-1); per-day file splitting, filename templates, scheduled exports (EXP-3/4, SCH-1); feeds the Obsidian maps plugin |
| P1-2 | Pricing card | "Import from backup — **Pro**" | Import is **free** (EXP-6 has no gate). Also the paid tier is broader than "export": webhook delivery + scheduled exports are gated too (MON-1) |
| P1-3 | FAQ "What is free and what is Pro?" | "Export is the paid Pro feature" | Same correction: in-app export action, webhooks, and Auto Export are Pro; import, preview, tracking, watch, widgets free. (⚠︎ D-6: export **intents** currently bypass the gate — either fix the code or word copy as "in-app export" to stay honest) |
| P1-4 | FAQ "Does iso.me work with Apple Watch?" | "glanceable tracking controls and status" | The watch app now **records independently** — own GPS session, works without the phone, offline queue syncs routes back later, plus 4 complication families (WCH-1/2, WID-2). This is a headline differentiator being under-sold |
| P1-5 | FAQ "Does iso.me sync with iCloud?" | Hedged: "unless the app itself shows a sync feature" | Can now be definitive: no cloud sync; export/import is the transfer path; watch↔phone sync is direct (WatchConnectivity), not iCloud |
| P1-6 | Freshness markers ("Updated June 2026", trust ledger, hero eyebrow) | June 2026 | App ships through **1.7.10** with outings/replay/timeline/scheduled exports — update markers and screenshots |

---

## P2 — Shipped features with zero site presence (expansion opportunities)

Roughly ordered by marketing value:

1. **Timeline & outings (TIM-1, TRK-5/6)** — daily timeline merging visits + movement; inferred outings from old GPS data; stats, sorting, renaming, notes. *The "Google Timeline alternative" promise is now literally true in-app; show it.*
2. **Route replay + road-snapped paths (MAP-1/2)** — scrubber replay with moving playhead; Apple-Maps-matched route rendering. Highly visual; ideal showcase row.
3. **Visit correction & saved places (VIS-2/3/5)** — confirm/correct detected visits with nearby-business suggestions, undo, saved places auto-naming future visits. Answers the #1 skeptics' question ("what if it guesses wrong?").
4. **Photos on the map (PHT-1/2)** — opt-in photo moments correlated by GPS/route/visit; clusters, full-screen viewer. Entirely absent from the site.
5. **Scheduled/automatic exports (SCH-1)** — daily or every 1–23h, one consistent file per day, rewrite/append, background wake. Pairs with the Obsidian "daily note" workflow.
6. **Webhooks / self-hosting ecosystem (WHK-1)** — OwnTracks/Overland/Dawarich/Traccar integration. Pulls a whole self-hosting audience the site never addresses.
7. **Shortcuts & Siri depth (INT-1)** — 9 intents incl. start/stop, rename outing, today's stats, export today/yesterday. Site only says "Siri and Shortcuts support" in one line.
8. **Live Activity map snapshot (WID-1)** — lock-screen activity shows a live mini-map of the route, not just counters.
9. **Manual visit entry (VIS-4)** — add past visits/save current place from the map.
10. **Import is free** — worth stating explicitly as a data-portability promise (see P1-2).

Suggested additions: a "Showcase" row per headline feature (timeline, replay, photos, auto-export), 3–5 new FAQ entries (see P3-2), a blog post on the Obsidian/self-hosted pipeline.

---

## P3 — Clarify & polish

1. **schema.org `featureList`** — currently the oldest copy on the site (JSON/CSV/MD, "Apple Watch companion"); update alongside P1-1/P1-4 since it feeds rich results.
2. **New FAQ candidates:** "Can the Watch track without my phone?" · "Does it work with OwnTracks/Dawarich?" · "What can Shortcuts automate?" · "What's the difference between a visit and an outing?" · "Where do automatic exports save?"
3. **Blog export section** (`private-location-journal-iphone`) mentions JSON/CSV/MD only — refresh the format list and add the per-day/Obsidian workflow.
4. **Trust-ledger wording** — "a privacy policy that says no analytics" self-references the stale policy; reword after P0 lands.
5. **⚠︎ Open question (pre-docs):** release notes 1.7.5–1.7.7 advertise a *Settings → Show Location Indicator* toggle that does **not exist in the current code tree** (`showsBackgroundLocationIndicator`: 0 hits). Verify whether it shipped and was reverted, or lives on an unmerged branch — before documenting it anywhere.

---

## Suggested execution order

1. Decide the ANL-1 posture (opt-in flip vs. policy disclosure) → rewrite Privacy + Terms §03 (P0).
2. Sweep format/pricing/watch/iCloud copy + schema.org + freshness markers (P1) — one pass, mechanical.
3. Add the P2 showcase rows/FAQs in a second pass (needs screenshots for outings/replay/photos/auto-export).
4. Resolve the 1.7.5 indicator question and D-6 (intent gating) before finalizing pricing/privacy wording.
