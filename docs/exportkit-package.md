# ExportKit integration

iso.me uses the standalone `https://github.com/CodyBontecou/ExportKit` Swift package for reusable export infrastructure while keeping all location-domain logic in this app.

## Domain mapping

- Exportable app models: `Visit` and `LocationPoint` SwiftData records.
- App settings: `ExportOptions`, `ExportFormat`, and `FilenameTemplate` remain app-owned because they drive iso.me copy, UI labels, field toggles, filters, and persisted preferences.
- ExportKit payload: `IsoMeExportSnapshot` in `IsoMe/Utilities/IsoMeExportKitAdapter.swift` conforms to `ExportRecord` and wraps the filtered visits/points for either one condensed export or one split-by-day export record.

## ExportKit adapters

`IsoMeExportKitAdapter` owns the app-local bridge:

- `ExportFormatDescriptor` values are derived from iso.me `ExportFormat` cases (`json`, `csv`, `markdown`, `owntracks`, `overland`, `gpx`, `kml`, `geojson`).
- `AnyExportRenderer<IsoMeExportSnapshot>` renderers delegate to the existing iso.me format functions so exported files remain compatible.
- `IsoMeExportPathPlanner` expands iso.me path tokens, preserves `/` as relative folder separators, rejects traversal/absolute paths, and sanitizes each path component before writes.
- `PlannedExportFile` is the shared unit for render, preview, share-sheet temp files, and default-folder writes.
- `ExportFileWriter` writes planned files in `ExportFolderManager.savePlannedFilesToDefaultFolder` and for share-sheet temporary files.
- `IsoMeExportKitAdapter.preview(...)` uses `ExportPreviewBuilder` for no-write previews.
- `IsoMeExportKitAdapter.run(...)` wraps `ExportRunOrchestrator` for generic success/failure result reporting.

## Automation

iso.me has an automatic export scheduler with optional intraday repeats. `DailyExportScheduler` uses `ExportAutomationKit.AutomationSchedule` and `AutomationScheduleDateMath` for once-per-day schedules and mirrors them to `worker/scheduled-notifications`. Interval schedules (every 1–23 hours from a daily anchor) use app-side math in `IntervalExportScheduleDateMath` — the same anchor+24h-clock cycle the worker implements — because the pinned ExportKit `AutomationScheduleFrequency` does not yet express sub-daily repeats. Interval sync sends a wire-compatible upsert payload (`frequency: "interval"`, `intervalMinutes`) from `PushRegistrationManager`.

The scheduler layers several recovery triggers:

- a server-side silent APNs push at each occurrence's minute;
- a local visible fallback notification shortly after each occurrence;
- app-open catch-up when the scheduled occurrence is overdue.

All automatic schedules keep one aggregate file per local calendar day, independent of the manual Export tab's split toggle. `IsoMeScheduledExportPlan` applies an explicit local start-of-day-through-now window, uses the same captured run date for aggregate filename resolution, and normalizes filenames with `FilenameTemplate.dayStablePattern` (time tokens collapse to `{date}`; an explicit date token is injected when missing, even when coarser tokens such as `{year}` are present). Once-daily runs always use Rewrite. Interval runs offer two update modes:

- **Rewrite** (default): every run exports the full day so far and overwrites the dated daily file.
- **Append**: every run exports only records since the last successful run (cursor in UserDefaults, clamped to the start of the local day) and merges into the dated daily file. `IsoMeScheduledExportWritePolicy` picks per-format behavior: CSV appends without duplicating the header (`CSVAppendMergeStrategy`), JSON-family formats merge and dedupe arrays (`JSONArrayMergeStrategy`), Markdown merges by section (`ExportKit.MarkdownMergeStrategy`); GPX and KML are XML containers and always rewrite the full day.

The worker stores only routing and timing metadata (install id, APNs token, bundle id, timezone, hour/minute, interval minutes, and next fire time). It must not store location records, export files, destination folder paths, or filename templates. Tapping the fallback notification retries the exact scheduled fire date only when `lastRun` does not already cover it, preventing duplicate exports when a silent push or background task already completed. `lastRun` dedup works per exact fire date, so it generalizes to multiple fires per day unchanged.

## Preserved behavior

- Existing JSON/CSV/Markdown/OwnTracks/Overland/GPX/KML/GeoJSON renderers remain in `ExportService` and are reused by ExportKit renderers.
- Manual `ExportOptions` filters, field toggles, date ranges, time-of-day windows, and split-by-day behavior are unchanged; Auto Export uses its fixed daily aggregate plan.
- Existing filename tokens (`{date}`, `{datetime}`, `{time}`, `{day}`, `{type}`, `{format}`) and sanitizing are preserved, with additional date tokens (`{year}`, `{month}`, `{dayNumber}`, `{weekday}`, `{monthName}`, `{quarter}`) and `/` subfolders supported.
- Default folder bookmarks remain managed by `ExportFolderManager`.
- Export purchase gating, UI labels, webhook settings, app intents, and import logic remain app-specific.
