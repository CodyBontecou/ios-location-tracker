# Plan: Intraday scheduled exports (multiple exports per day, consistent files)

Source request:

> "Would it be possible to have the possibility to configure more export of the data for the same day, e.g. every 3,6,9 hours, using the 'append' function to ensure to have consistency of the file."

## 1. Summary

Extend the existing once-per-day auto-export so users can fire the scheduled export **multiple times per day** (e.g. every 3, 6, 9, or 12 hours from a daily anchor time), while keeping the exported file for a given day **consistent** — no duplicate rows, no invalid files, always reflecting the latest state.

## 2. Current state (what exists today)

| Piece | Location | Behavior |
|---|---|---|
| Daily scheduler | `IsoMe/Services/DailyExportScheduler.swift` | One fire/day at `hour:minute`. De-dup via `lastRun >= fireDate`. Recovery layers: BGAppRefresh + APNs silent push + local fallback notification + app-open catch-up. |
| Schedule model | ExportKit `ExportAutomationKit/ExportAutomationScheduling.swift` | `AutomationScheduleFrequency` = `.daily` / `.weekly` only. No sub-daily concept. |
| Remote worker | `worker/scheduled-notifications` | D1 `schedules` table (`frequency CHECK IN ('daily','weekly')`, `hour`, `minute`, `weekday`, `next_fire_at`), cron tick every minute, silent push + `computeNextFire` advance. |
| File writing | ExportKit `ExportDestinationWriting.swift`, used by `ExportFolderManager.savePlannedFilesToDefaultFolder` | Writer **already supports** `.overwrite`, `.append` (naive concat), and `.update` (merge-strategy) modes, incl. `MarkdownMergeStrategy`. The app currently always writes `.overwrite`. |
| Scheduled export content | `DailyExportScheduler.runExport` | Fetches **all** data, default `ExportOptions()` (`.allTime`), single format, default filename pattern. |
| UI | `IsoMe/Views/ExportView.swift` "DAILY EXPORT" section | Enable toggle, time picker, format picker, data-kind picker, Run Now, last run/error. |

Constraints that shape the design:

- JSON visit export has **no stable record id** (`arrivedAt` is the closest key); CSV has none. Naive re-export + append ⇒ duplicates.
- CSV/JSON are header/array-shaped: naive `.append` produces a duplicated header row / invalid JSON. GPX/KML/GeoJSON are XML/JSON containers — plain append is impossible.
- Fallback notification + APNs payloads already carry an exact `fireDate`, and identifiers are derived from it (`DailyExportNotificationPayload.identifier(for:)`) — occurrence de-dup generalizes to N fires/day for free.
- Worker is privacy-constrained to routing/timing metadata only (install id, token, tz, hour/minute, next fire). Interval + anchor are timing metadata — allowed.

## 3. Product design

### 3.1 Repeat interval

New "REPEAT" setting on the auto-export card:

- **Once daily** (default, status quo)
- Every **3 h** / **6 h** / **9 h** / **12 h**

Semantics: the existing TIME picker becomes the **daily anchor**. Fires occur at `anchor + k × interval` while still within the same local day, then reset to the anchor next day.

- Example (anchor 09:00, every 3 h): 09:00, 12:00, 15:00, 18:00, 21:00 → next day 09:00.
- 9 h does not divide 24 — that's fine: 09:00, 18:00 (and 03:00 is skipped because it belongs to the next day's cycle); the day simply ends after the last in-day occurrence.
- DST-safe: each occurrence reconstructed in wall-clock in the schedule's timezone (same approach as existing daily math).

### 3.2 File consistency — two modes

The user's "append for consistency" can be satisfied two ways. We ship both, with **Rewrite as the default** because it is correct for every format:

| Mode | Mechanism | Formats | Notes |
|---|---|---|---|
| **Rewrite today** (default) | Each fire exports a fresh **full snapshot of today-so-far** and **overwrites** the day's file. | All 8 formats | One row per record, always current, always valid. Lossless because SwiftData remains the source of truth. Works with `{date}`-token filenames so each day gets its own file. |
| **Append (delta)** | Each fire exports only records **since the last successful fire** (cursor = high-water mark) and appends/merges. | v1: CSV, OwnTracks, Overland (row append, header skipped); JSON (array merge). Markdown via `MarkdownMergeStrategy`. GPX/KML/GeoJSON: rewrite-only. | Matches the user's literal "append" ask; cheaper for very large histories. Needs per-format merge handling and delta-cursor bookkeeping. |

Why rewrite is the safe default: no duplicate-row edge cases (in-progress visits re-exported after they close, edits/confirmations to earlier visits, outlier flag flips), no invalid container formats, no cursor state to lose. Append mode is offered as an opt-in for row formats where it's clean.

### 3.3 UI changes (`ExportView.swift`)

- Section header "DAILY EXPORT" → "AUTO EXPORT".
- New rows (when enabled):
  - `REPEAT` — picker: Once daily / 3 h / 6 h / 9 h / 12 h.
  - `TIME` relabeled to `START` (anchor).
  - `FILE MODE` (only when repeat ≠ once): Rewrite / Append, with footer copy explaining each.
- Footer copy updated; all new strings localized (10 locales — `Localizable.xcstrings`).

## 4. Technical design

### 4.1 ExportKit (separate repo, currently pinned `branch = main`)

1. `AutomationScheduleFrequency`: add `case interval = "interval"`.
2. `AutomationSchedule`: add `intervalHours: Int` (default 1; clamped 1–23; ignored unless `.interval`). Codable back-compat via `decodeIfPresent`.
3. `AutomationScheduleDateMath`: interval-aware
   - `calculateNextRunDate` — next occurrence strictly after `now`;
   - `latestScheduledOccurrenceDate` — anchor + largest `k×interval` ≤ `now` within the anchor's local day.
4. `RemoteSchedulePayload`: add `intervalHours: Int?` (nil = daily; old workers ignore it).
5. Optional: hoist generic merge strategies here (`CSVAppendMergeStrategy`, `JSONArrayMergeStrategy`) so they're reusable; `MarkdownMergeStrategy` already lives here.
6. Tag a release; switch iso.me from `branch = main` to a pinned version before shipping.

### 4.2 Worker (`worker/scheduled-notifications`)

1. **D1 migration `0002_interval.sql`**: SQLite can't alter CHECK constraints → rebuild `schedules` with `frequency CHECK IN ('daily','weekly','interval')` + new `interval_minutes INTEGER` column (nullable). Additive-safe: existing rows unaffected.
2. `scheduling.ts`: `Frequency` gains `"interval"`; `Schedule` gains `intervalMinutes?`; `computeNextFire` interval branch (anchor + k×interval in local tz, roll to tomorrow's anchor when exhausted; DST via existing `zonedTimeToUtcMs` per candidate).
3. `scheduled.ts` / `index.ts` upsert handler: accept + persist `intervalMinutes`; silent-push payload unchanged (`fireAt` already exact).
4. Deploy worker **before** the app ships (old clients are unaffected by new columns/values).

### 4.3 iOS scheduler (`DailyExportScheduler.swift`)

- New persisted keys: `dailyExport.intervalHours` (Int; 0 = once daily), `dailyExport.fileMode` (`"rewrite"` | `"append"`; default `rewrite`).
- `automationSchedule` becomes `.interval` with `intervalHours` when set — everything downstream (`PushRegistrationManager.syncSchedule`, next-run math, BGAppRefresh earliest date) picks it up unchanged.
- Occurrence de-dup already keys on exact `fireDate` (`hasCompletedScheduledOccurrence`) — works for N fires/day.
- `runExport` window (updated by the one-file-per-day adaptation):
  - Once daily: local start-of-day through now, overwrite the dated daily file.
  - Interval + rewrite: the same full local-day-through-now window, write mode `.overwrite`.
  - Interval + append: delta window `(lastSuccessfulFire, now]` clamped to local start-of-day, write mode `.append`/`.update` with per-format merge strategy; container formats rewrite the full local day.
- Appends also update `lastRun` per fire so catch-up, notification retry, and silent-push dedup stay consistent.

### 4.4 Write path (`ExportFolderManager` / `IsoMeExportKitAdapter`)

- `savePlannedFilesToDefaultFolder(_:mode:mergeStrategies:)` — thread write mode into the existing `ExportFileWriter.write` call (the API already exists; today it's hardcoded `.overwrite`).
- Per-format merge strategy registry in `IsoMeExportKitAdapter`:
  - CSV: skip header when appending to an existing file.
  - JSON: merge arrays (decode existing + new, concatenate, dedupe by `arrivedAt`+coords as v1 key — or first add a stable `id` to export payloads, which also benefits the Obsidian plugin).
  - Markdown: `MarkdownMergeStrategy` (section-aware, already in ExportKit).
  - OwnTracks/Overland (JSONL): line append.
  - GPX/KML/GeoJSON: rewrite only (force overwrite regardless of mode).
- Consider adding a stable record `id` to `ExportableVisit` / `ExportableLocationPoint` / `ExportableOuting` as part of this work — it makes any merge/dedup exact and is useful downstream.

### 4.5 Docs & privacy

- `docs/exportkit-package.md` Automation section + README "Export & Import" bullet updated (mention repeat interval + file modes).
- Worker README: new field in schema docs.
- Privacy posture unchanged: worker still stores only routing/timing metadata (an interval and anchor are timing). No location records, file paths, or templates leave the device.

## 5. Testing

| Layer | Tests |
|---|---|
| ExportKit | Interval date math: next/latest occurrence, day-boundary reset, 9 h partial cycles, DST spring/fall; merge strategies (CSV header skip, JSON array dedupe, markdown re-merge). |
| Worker | `scheduling.test.ts`: interval `computeNextFire` cases incl. DST + migration round-trip on D1. |
| App | `DailyExportScheduler`: multiple fires/day dedup, fallback notification per occurrence, delta cursor, mode fallback; `IsoMeTests` integration for today-window + append/rewrite writes; Run Now unaffected. |
| Manual | TestFlight: silent pushes at multiple hours in one day; airplane-mode catch-up; file inspection for CSV/JSON/MD consistency. |

## 6. Rollout order

1. ExportKit changes → tagged release → pin dependency in iso.me.
2. Worker migration + interval support → deploy (backward compatible).
3. iOS scheduler + write path + UI + localization.
4. Docs, release notes ("What's New"), TestFlight validation, App Store release (export is the paid feature — this lands behind the existing unlock; no pricing change).

## 7. Decisions (resolved at implementation)

1. **Interval choices** — Custom: any interval from **1 to 23 hours** (picker: Once daily + EVERY 1–23 H).
2. **Append in v1?** — Yes. Rewrite (default) + Append shipped together; GPX/KML always rewrite the full day.
3. **Stable export ids** — Deferred. JSON merge dedupes by the first present identity field (`id`, `arrivedAt`, `timestamp`, `tst`, `startedAt`, `started_at`).
4. **Anchor semantics** — **Anchor-day reset on a 24h clock**: occurrences fire at `anchor + k × interval` for every `k` with `k × interval < 24h`; cycles reset at the next daily anchor and tails can spill past local midnight.
5. **All automatic exports are daily files** — Superseded by the one-file-per-day adaptation: once-daily and interval Rewrite runs use the local today window; interval Append uses the since-last-run window clamped to today.

Implementation notes: interval logic lives app-side (`IntervalExportScheduleDateMath`, `IsoMeScheduledExportWritePolicy`, interval upsert mirror in `PushRegistrationManager`) because the pinned ExportKit release cannot yet express sub-daily frequencies; the worker gained `frequency: "interval"` + `interval_minutes` (migration `0002`).

## 8. Rough effort

| Phase | Scope | Estimate |
|---|---|---|
| 1 | ExportKit: interval model + date math + payload (+ merge strategies) | 0.5–1 d |
| 2 | Worker: migration + `computeNextFire` + tests + deploy | 0.5 d |
| 3 | iOS scheduler generalization + UI + 10-locale strings | 1–2 d |
| 4 | Write-path modes + per-format merge + tests | 1–2 d (can be phase-gated with Phase 3 shipping rewrite-only) |
| 5 | Docs, release notes, TestFlight validation | 0.5 d |
