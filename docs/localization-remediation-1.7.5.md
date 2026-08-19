# iso.me 1.7.5 localization remediation checkpoint

Date: 2026-08-10  
Branch: `localization/isome-remediation`  
App Store Connect app: `6761960794` (`com.bontecou.isome`)  
Live iOS version: `1.7.5` (`90ac49bc-8741-4c43-adbc-6fdc8ccdfe83`, `READY_FOR_DISTRIBUTION`)

## Approval status

This document began as the mandatory pre-mutation checkpoint. The original IAP and screenshot plan was explicitly approved. App Store Connect rejected the first IAP update and screenshot upload because the approved IAP version and released app version are not modifiable; both requests failed before changing data. The revised 1.7.6/new-IAP-version plan was then explicitly approved and completed. Build upload and App Review submission were authorized separately afterward; 1.7.6 build 32 and IAP version 2 are now waiting for review. No release operation was run.

The originally approved scope was limited to replacing the 1.7.5 screenshot sets for the nine existing ASC locales and correcting the localized name and description of the approved lifetime IAP. No App Store metadata mutation, submission, or release was approved.

Post-attempt verification proved that all nine IAP localizations are byte-for-byte unchanged at the API attribute level and all 50 existing screenshot records retain their original IDs, filenames, checksums, display types, and counts. The rollback backup remains at `/tmp/isome-asc-1.7.5-before-localization`.

Final ASC resources:

- App version 1.7.6: `bce27f1c-93c2-4975-97b8-fe06d3906e92` (`WAITING_FOR_REVIEW`, manual release), attached to build 32 (`faca16cd-1755-4b19-b9ff-32f61917eef6`).
- IAP version 2: `e71fa922-7505-4b76-9cce-4fd998b673db` (`WAITING_FOR_REVIEW`).
- Review submission: `bc5b53a3-d00b-4cce-b9d6-052a07fc08a9` (`WAITING_FOR_REVIEW`), containing exactly the app version and IAP version above.
- App metadata: nine copied locales, all semantically equal to the repository metadata.
- Screenshots: nine locales × three sets, with 90/90 assets in `COMPLETE` state and all source checksums matching the approved local files.
- IAP: nine corrected localizations verified against the approved copy.
- Isolation: released app version 1.7.5 and approved IAP version 1 remain unchanged.

## Verified facts

- `asc auth status --validate` succeeded with the existing `asc-localization-audit` Keychain configuration.
- The implementation gates data export behind `com.bontecou.isome.lifetime`. Location tracking remains free and unlimited.
- The repository now uses `MARKETING_VERSION = 1.7.6` for all project configurations.
- The nine files under both `metadata/isome/version/1.7.5` and `metadata/isome/version/1.7.6` are semantically identical to their authenticated ASC version metadata. The only difference from the raw pull is pretty-print formatting.
- The localization audit covers 1,018 active keys in nine String Catalogs. Every key has an entry for `ar`, `bn`, `en`, `es`, `fr`, `hi`, `ja`, `pt-BR`, `ru`, and `zh-Hans`; no placeholder mismatch or missing translation remains.
- Permission text, the paywall/export entitlement, App Shortcuts, iOS widgets, the Watch app, and Watch widgets are included.
- Final tests: 101 executed, 101 passed, 0 failed.
- Final screenshots: 30 locale/device sets, 100 files, 100 ready, 0 errors, 0 warnings in `asc screenshots validate`.
- The worktree contains zero `.p8` files, zero tracked `.p8` files, and no credential-pattern match in the localization diff or untracked artifacts.

## Changed-file summary

The worktree contains 37 modified tracked files and 189 untracked files, including this report. The tracked diff is 52,061 insertions and 6,170 deletions; most of that volume is structured String Catalog data.

- Project configuration: references for four new InfoPlist/App Shortcuts catalogs and the 1.7.5 marketing version.
- Runtime source: localized dynamic user-facing strings across models, services, utilities, view models, iOS views, widgets, Watch, Watch widgets, and shared Watch data.
- Entitlement copy: paywall/settings wording now describes data export and says tracking remains free.
- Catalogs: nine complete catalogs, including new App Shortcuts and InfoPlist catalogs for the iOS widget, Watch app, and Watch widget.
- Metadata: nine canonical 1.7.5 locale JSON files reconciled from live ASC.
- Screenshot tooling: deterministic capture, copy localization, composition, validation, and contact-sheet generation scripts.
- Screenshot artifacts: 100 final store images, 50 raw captures, and 10 contact sheets (about 280 MB total).
- Test isolation: one export filename test now passes an empty route-point fixture so it tests the saved outing only; production export behavior was not changed.

`git diff --check` passes. No changes are staged or committed.

## Runtime locale coverage

| Catalog | Keys | ar | bn | en | es | fr | hi | ja | pt-BR | ru | zh-Hans |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| iOS app | 945 | 945 | 945 | 945 | 945 | 945 | 945 | 945 | 945 | 945 | 945 |
| iOS InfoPlist | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 |
| App Shortcuts | 9 | 9 | 9 | 9 | 9 | 9 | 9 | 9 | 9 | 9 | 9 |
| iOS widget | 6 | 6 | 6 | 6 | 6 | 6 | 6 | 6 | 6 | 6 | 6 |
| iOS widget InfoPlist | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 |
| Watch app | 32 | 32 | 32 | 32 | 32 | 32 | 32 | 32 | 32 | 32 | 32 |
| Watch InfoPlist | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 |
| Watch widget | 12 | 12 | 12 | 12 | 12 | 12 | 12 | 12 | 12 | 12 | 12 |
| Watch widget InfoPlist | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 |

The audit allowlist is intentionally narrow: `iso.me`; format/protocol names such as JSON, CSV, GPX, KML, GeoJSON, OwnTracks, Overland, Markdown, HTTP, API, URL, GPS, and YAML; platform names; placeholder-only values; compact units; and a small set of words naturally spelled the same in English and French, Spanish, or Portuguese. Stable export schema field names remain English for interoperability, and the import parser consumes those same field names.

Audit command and result:

```sh
python3 scripts/localization_catalog.py audit
# PASS: no missing translations or placeholder mismatches
```

The audit also reports zero non-allowlisted values identical to English in every non-English locale.

A final heuristic scan of literal `return` values and `Text(verbatim:)` sites was manually triaged. User-facing matches are typed as `LocalizedStringKey`/`LocalizedStringResource` or receive an already-localized dynamic value. The remaining matches are SF Symbol names, MIME/file-format identifiers, internal IDs, or stable export schema values.

## Build and test results

Discovered schemes: `IsoMe`, `IsoMeWidgetExtension`, `IsoMeWatch`, and `IsoMeWatchWidgetExtension`. `IsoMeTests` is attached to the `IsoMe` scheme.

| Validation | Destination | Result |
|---|---|---|
| `IsoMe` clean build | generic iOS Simulator | pass |
| `IsoMeWidgetExtension` clean build | generic iOS Simulator | pass |
| `IsoMeWatch` clean build | generic watchOS Simulator | pass |
| `IsoMeWatchWidgetExtension` clean build | generic watchOS Simulator | pass |
| `IsoMe` tests | booted iOS 26.5 simulator | 101/101 pass |

The final test command was:

```sh
xcodebuild test -project IsoMe.xcodeproj -scheme IsoMe \
  -destination 'platform=iOS Simulator,id=03AE614E-7BA2-4B5A-8CEA-D3A3BC2404B0' \
  -derivedDataPath /tmp/isome-final-test-derived
```

An earlier no-signing test invocation failed while bootstrapping the host and ran no tests. Retrying on a rebooted simulator with normal simulator signing ran the suite. It exposed a pre-existing fixture-isolation problem in one outing filename test; after isolating that fixture, the focused test and the full suite passed. The final 1.7.6 test command initially referenced a temporary simulator that no longer existed and therefore ran no tests; rerunning against the booted iPhone 17 Pro executed all 101 tests successfully.

Pre-existing warnings remain for unassigned app icon/mascot assets and missing widget `AccentColor`/`WidgetBackground` assets. They are unrelated to localization and were not changed.

## Screenshot coverage and previews

Final layout: `screenshots/localized/appstore/<locale>/{iphone-67,ipad-129,watch-series-10}`.

| Locale | iPhone | iPad | Watch | ASC upload |
|---|---:|---:|---:|---|
| ar-SA | 5 | 4 | 1 | uploaded to 1.7.6 |
| bn | 5 | 4 | 1 | runtime QA only |
| en-US | 5 | 4 | 1 | uploaded to 1.7.6 |
| es-ES | 5 | 4 | 1 | uploaded to 1.7.6 |
| fr-FR | 5 | 4 | 1 | uploaded to 1.7.6 |
| hi | 5 | 4 | 1 | uploaded to 1.7.6 |
| ja | 5 | 4 | 1 | uploaded to 1.7.6 |
| pt-BR | 5 | 4 | 1 | uploaded to 1.7.6 |
| ru | 5 | 4 | 1 | uploaded to 1.7.6 |
| zh-Hans | 5 | 4 | 1 | uploaded to 1.7.6 |

Dimensions are 1290×2796 (`APP_IPHONE_67`), 2064×2752 (`APP_IPAD_PRO_3GEN_129`), and 416×496 (`APP_WATCH_SERIES_10`). Bengali is excluded from upload because no Bengali version localization exists.

Contact sheets:

- `screenshots/localized/contact-sheets/ar-SA.jpg`
- `screenshots/localized/contact-sheets/bn.jpg`
- `screenshots/localized/contact-sheets/en-US.jpg`
- `screenshots/localized/contact-sheets/es-ES.jpg`
- `screenshots/localized/contact-sheets/fr-FR.jpg`
- `screenshots/localized/contact-sheets/hi.jpg`
- `screenshots/localized/contact-sheets/ja.jpg`
- `screenshots/localized/contact-sheets/pt-BR.jpg`
- `screenshots/localized/contact-sheets/ru.jpg`
- `screenshots/localized/contact-sheets/zh-Hans.jpg`

The iPhone story remains: private map, control settings, open export formats, exact export filters, and the user's own endpoint. iPad uses four onboarding stages; Watch uses the tracking home screen. Captures force the requested language/locale, use deterministic seeded content, and contain no personal data or credentials. Duplicate and low-entropy checks found no English-copy duplicates or blank captures. Arabic was recomposed with RTL-aware shaping, and Simplified Chinese was recomposed with a font containing the required glyphs.

## Applied IAP copy

IAP: `com.bontecou.isome.lifetime` (`6761962715`)  
IAP version 2: `e71fa922-7505-4b76-9cce-4fd998b673db` (`WAITING_FOR_REVIEW`)

All names are at most 30 characters and descriptions at most 42 characters.

| Locale | Localization ID | Applied name | Applied description |
|---|---|---|---|
| ar-SA | `c250ecea-8d05-495f-8aa1-53c1846882bf` | تصدير iso.me مدى الحياة | افتح تصدير البيانات بعملية شراء واحدة. |
| en-US | `fd2248ba-5573-48fc-9906-ffc222e8af5a` | iso.me Lifetime Export | Unlock data export with one purchase. |
| es-ES | `96b1db5e-dadb-4cad-b747-e3f76f98bceb` | iso.me Exportación de por vida | Activa la exportación con una sola compra. |
| fr-FR | `e132d9b5-b9ff-4f05-a282-5891226a6931` | iso.me Export à vie | Débloquez l’export avec un achat unique. |
| hi | `7c8ae9f2-4deb-4faa-a67b-a188ae506305` | iso.me लाइफटाइम एक्सपोर्ट | एक खरीद से डेटा एक्सपोर्ट अनलॉक करें। |
| ja | `d879bf3f-36ac-4497-917d-a3a8f8424d74` | iso.me 永久データ書き出し | 一度の購入でデータ書き出しをアンロック。 |
| pt-BR | `56877ccb-95ab-41e4-8ff3-771b96959e59` | iso.me Exportação vitalícia | Libere a exportação com uma única compra. |
| ru | `5782f8a8-fb8c-4228-bb6a-cf0422514253` | iso.me Экспорт навсегда | Откройте экспорт данных одной покупкой. |
| zh-Hans | `623fd860-9202-4309-b992-28d0b1947ece` | iso.me 永久数据导出 | 一次购买即可解锁数据导出。 |

## Applied metadata changes

No released 1.7.5 or App Info metadata was changed. The local 1.7.5 files were added because the repository stopped at 1.7.4. Version 1.7.6 copied that metadata in ASC, and the repository now contains the matching 1.7.6 files for all nine locales.

## Original 1.7.5 mutation plan (rejected)

The first IAP update and first screenshot upload below were attempted after approval and rejected by ASC without changing data. The remaining 1.7.5 writes were not run.

### Resource map

```sh
declare -A VERSION_LOCALIZATION=(
  [ar-SA]=13c9c44c-4c84-4a48-827b-cac3b0ed5e29
  [en-US]=a399b790-f013-454b-b24b-fa0cbccf338d
  [es-ES]=1f2db890-43f0-41eb-8ba1-ba37666cf0d9
  [fr-FR]=c3230731-b1ec-4f4b-9dc2-c50fc7ac7bcd
  [hi]=02b4e3b3-1a24-4c09-b39f-cc891b74d263
  [ja]=c8aeeed4-fb49-40b0-8d0d-77df4d5fd37d
  [pt-BR]=bd078303-f82b-4e19-960f-3627853e9876
  [ru]=10392f62-3e3d-4171-8538-6ce2ff212580
  [zh-Hans]=27c816a6-0393-4415-a8a6-d695172cd275
)
ASC_LOCALES=(ar-SA en-US es-ES fr-FR hi ja pt-BR ru zh-Hans)
```

Existing screenshot set IDs:

- ar-SA iPhone `99d4c9e7-c7ba-4dad-a15e-e3d6e0263bdc`
- en-US iPhone `143564a1-fae7-46a9-9ef9-753934ea8c98`; iPad `88d9e983-0a93-4d57-9c61-1f195ade9643`; Watch `fdf5b9ca-28f9-44c0-9370-cc4a6086acc5`
- es-ES iPhone `7540051b-d74f-42e9-844b-2cc288d37a77`
- fr-FR iPhone `c8fc81c2-e93a-4b01-b18c-c10162e267af`
- hi iPhone `bb0765e6-b027-44c8-97ed-ffc185a5fcf2`
- ja iPhone `15b7730e-414c-4c99-a495-e5a860721d3c`
- pt-BR iPhone `3dd3f7c7-19a2-4197-b825-5acd408944c4`
- ru iPhone `98c7e08b-4e93-4350-be4c-b909279ad57e`
- zh-Hans iPhone `d7b35345-1cab-4336-b2d1-34e9406af631`

### 1. Fresh backup and dry run

```sh
backup_dir="/tmp/isome-asc-1.7.5-before-localization"
mkdir -p "$backup_dir"
for locale in "${ASC_LOCALES[@]}"; do
  asc screenshots download \
    --version-localization "${VERSION_LOCALIZATION[$locale]}" \
    --output-dir "$backup_dir/$locale" --overwrite

  asc screenshots upload --version-localization "${VERSION_LOCALIZATION[$locale]}" --path "screenshots/localized/appstore/$locale/iphone-67" --device-type IPHONE_67 --replace --dry-run
  asc screenshots upload --version-localization "${VERSION_LOCALIZATION[$locale]}" --path "screenshots/localized/appstore/$locale/ipad-129" --device-type IPAD_PRO_3GEN_129 --replace --dry-run
  asc screenshots upload --version-localization "${VERSION_LOCALIZATION[$locale]}" --path "screenshots/localized/appstore/$locale/watch-series-10" --device-type WATCH_SERIES_10 --replace --dry-run
done
```

Stop if the backup or any dry run fails.

### 2. Correct the IAP copy

```sh
asc iap versions localizations update --localization-id e3eb061f-7819-4b72-816e-6aaafe628c6e --name 'تصدير iso.me مدى الحياة' --description 'افتح تصدير البيانات بعملية شراء واحدة.'
asc iap versions localizations update --localization-id 6d5d84a6-8f62-48b5-a8ae-d6d8528cfb76 --name 'iso.me Lifetime Export' --description 'Unlock data export with one purchase.'
asc iap versions localizations update --localization-id d821d5f5-bcec-41a8-99ff-9305144b7fad --name 'iso.me Exportación de por vida' --description 'Activa la exportación con una sola compra.'
asc iap versions localizations update --localization-id b4e65e10-6395-4f5f-97f9-15007f65eaa5 --name 'iso.me Export à vie' --description 'Débloquez l’export avec un achat unique.'
asc iap versions localizations update --localization-id 84625f32-2188-4d4d-8ad2-5a491a0d5f87 --name 'iso.me लाइफटाइम एक्सपोर्ट' --description 'एक खरीद से डेटा एक्सपोर्ट अनलॉक करें।'
asc iap versions localizations update --localization-id 983e716b-a4b8-412c-ae8e-d433db8a549c --name 'iso.me 永久データ書き出し' --description '一度の購入でデータ書き出しをアンロック。'
asc iap versions localizations update --localization-id e3af02d6-cd46-4db6-834e-98623c4c8a56 --name 'iso.me Exportação vitalícia' --description 'Libere a exportação com uma única compra.'
asc iap versions localizations update --localization-id 08a76504-eb55-41ab-86c1-88ce8eefe825 --name 'iso.me Экспорт навсегда' --description 'Откройте экспорт данных одной покупкой.'
asc iap versions localizations update --localization-id ebc58a3e-6fe3-4569-8b20-e37b205b3573 --name 'iso.me 永久数据导出' --description '一次购买即可解锁数据导出。'
```

### 3. Replace screenshots

```sh
for locale in "${ASC_LOCALES[@]}"; do
  asc screenshots upload --version-localization "${VERSION_LOCALIZATION[$locale]}" --path "screenshots/localized/appstore/$locale/iphone-67" --device-type IPHONE_67 --replace
  asc screenshots upload --version-localization "${VERSION_LOCALIZATION[$locale]}" --path "screenshots/localized/appstore/$locale/ipad-129" --device-type IPAD_PRO_3GEN_129 --replace
  asc screenshots upload --version-localization "${VERSION_LOCALIZATION[$locale]}" --path "screenshots/localized/appstore/$locale/watch-series-10" --device-type WATCH_SERIES_10 --replace
done
```

`--replace` deletes the existing files in the target display-type set before uploading. For the eight locales without iPad or Watch sets, the upload is expected to create the missing set.

### 4. Authenticated post-change audit

```sh
asc auth status --validate --output table
asc localizations list --version 90ac49bc-8741-4c43-adbc-6fdc8ccdfe83 --paginate --output json
asc iap versions localizations list --version-id cd793545-8a37-418c-8b80-758c97cd4a43 --paginate --output json
for locale in "${ASC_LOCALES[@]}"; do
  asc screenshots list --version-localization "${VERSION_LOCALIZATION[$locale]}" --output json
done
```

The audit must prove nine metadata locales, nine corrected IAP localizations, and for every ASC locale exactly five `APP_IPHONE_67`, four `APP_IPAD_PRO_3GEN_129`, and one `APP_WATCH_SERIES_10` screenshot.

## Risks and rollback

- The live version is `READY_FOR_DISTRIBUTION`. Local validation cannot prove ASC will permit replacement on that version. If ASC rejects the first approved write because it is not editable, stop immediately; do not invent or create a new version. A new version number requires a separate proposal and approval.
- Replacement is not atomic across 27 sets. A failure can leave a partial matrix. The fresh pre-write download is mandatory. Audit changed sets and restore affected display types from `$backup_dir/<locale>` with the same upload command, backup path, device type, and `--replace`.
- The current IAP text is preserved in the authenticated baseline and below. Rollback uses the same nine update resources with these former values.
- No metadata rollback is needed because no live metadata write is proposed.
- No submit or release command is in this plan. Submission/release remains separately unauthorized.

| Locale | Former name | Former description |
|---|---|---|
| ar-SA | iso.me فتح مدى الحياة | افتح التتبع غير المحدود إلى الأبد. |
| en-US | iso.me Lifetime Unlock | Unlock unlimited tracking forever. |
| es-ES | iso.me Desbloqueo de por vida | Desbloquee el seguimiento ilimitado para siempre. |
| fr-FR | iso.me Déblocage à vie | Débloquez un suivi illimité pour toujours. |
| hi | iso.me लाइफटाइम अनलॉक | असीमित ट्रैकिंग को हमेशा के लिए अनलॉक करें। |
| ja | iso.me 永久解除 | 無制限のトラッキングを永久に解除します。 |
| pt-BR | iso.me Desbloqueio Vitalício | Desbloqueie rastreamento ilimitado para sempre. |
| ru | iso.me Пожизненный доступ | Откройте безлимитное отслеживание навсегда. |
| zh-Hans | iso.me 永久解锁 | 永久解锁无限跟踪功能。 |

## Manual review and remaining uncertainty

- Critical privacy, permission, paywall, export-entitlement, screenshot headline, and App Shortcut terminology received contextual manual review. The remaining long-tail strings were machine-assisted and passed structural audits, but have not been certified by native speakers. Native review is recommended for all nine non-English languages before release, especially inferred-outing terminology, concise settings labels, and Siri phrase naturalness.
- Contact sheets were visually inspected for language visibility, clipping, Arabic directionality, missing Chinese glyphs, blank captures, and accidental personal data. Native readers should still review marketing tone.
- The screenshot pipeline uses Debug-only deterministic launch arguments and a Debug-only purchased state. These hooks do not change Release behavior.
- App version 1.7.6 and IAP version 2 are both `WAITING_FOR_REVIEW`. Their screenshots and corrected IAP copy are not customer-visible unless review succeeds and the app is released manually.

## Execution outcome and revised path

After the original plan was approved:

1. The first IAP localization update (`ar-SA`) returned `Version is not in modifiable state.`
2. A safer first screenshot test attempted to create the missing Arabic iPad set, without deleting any existing set. It returned `An attribute value is not acceptable for the current resource state.`
3. Authenticated re-queries confirmed zero ASC changes: all nine original IAP localizations and all 50 original screenshot records are unchanged.

The released 1.7.5 version and approved IAP version could not accept the requested edits. The smallest viable path was a new editable app version and a new editable IAP version. This revised mutation plan was explicitly approved and executed.

App version `1.7.6` was created in manual-release mode with the 1.7.5 metadata copied and received the approved 90 screenshots. It initially remained unsubmitted while the revised localization plan was audited:

```sh
asc versions create --app 6761960794 --version 1.7.6 --platform IOS \
  --copy-metadata-from 1.7.5 --release-type MANUAL \
  --output json > /tmp/isome-1.7.6-created.json

NEW_APP_VERSION_ID=$(jq -r '.data.id' /tmp/isome-1.7.6-created.json)
asc localizations list --version "$NEW_APP_VERSION_ID" --paginate --output json \
  > /tmp/isome-1.7.6-localizations.json

for locale in ar-SA en-US es-ES fr-FR hi ja pt-BR ru zh-Hans; do
  localization_id=$(jq -r --arg locale "$locale" \
    '.data[] | select(.attributes.locale == $locale) | .id' \
    /tmp/isome-1.7.6-localizations.json)
  test -n "$localization_id"

  asc screenshots upload --version-localization "$localization_id" --path "screenshots/localized/appstore/$locale/iphone-67" --device-type IPHONE_67 --replace
  asc screenshots upload --version-localization "$localization_id" --path "screenshots/localized/appstore/$locale/ipad-129" --device-type IPAD_PRO_3GEN_129 --replace
  asc screenshots upload --version-localization "$localization_id" --path "screenshots/localized/appstore/$locale/watch-series-10" --device-type WATCH_SERIES_10 --replace
done
```

The approved IAP initially had one version, `cd793545-8a37-418c-8b80-758c97cd4a43`, in `APPROVED` state. The new editable IAP version inherited those localizations automatically, and the nine inherited records were updated to the previously reviewed copy:

```sh
asc iap versions create --iap-id 6761962715 --output json \
  > /tmp/isome-new-iap-version.json
NEW_IAP_VERSION_ID=$(jq -r '.data.id' /tmp/isome-new-iap-version.json)

asc iap versions localizations update --localization-id c250ecea-8d05-495f-8aa1-53c1846882bf --name 'تصدير iso.me مدى الحياة' --description 'افتح تصدير البيانات بعملية شراء واحدة.'
asc iap versions localizations update --localization-id fd2248ba-5573-48fc-9906-ffc222e8af5a --name 'iso.me Lifetime Export' --description 'Unlock data export with one purchase.'
asc iap versions localizations update --localization-id 96b1db5e-dadb-4cad-b747-e3f76f98bceb --name 'iso.me Exportación de por vida' --description 'Activa la exportación con una sola compra.'
asc iap versions localizations update --localization-id e132d9b5-b9ff-4f05-a282-5891226a6931 --name 'iso.me Export à vie' --description 'Débloquez l’export avec un achat unique.'
asc iap versions localizations update --localization-id 7c8ae9f2-4deb-4faa-a67b-a188ae506305 --name 'iso.me लाइफटाइम एक्सपोर्ट' --description 'एक खरीद से डेटा एक्सपोर्ट अनलॉक करें।'
asc iap versions localizations update --localization-id d879bf3f-36ac-4497-917d-a3a8f8424d74 --name 'iso.me 永久データ書き出し' --description '一度の購入でデータ書き出しをアンロック。'
asc iap versions localizations update --localization-id 56877ccb-95ab-41e4-8ff3-771b96959e59 --name 'iso.me Exportação vitalícia' --description 'Libere a exportação com uma única compra.'
asc iap versions localizations update --localization-id 5782f8a8-fb8c-4228-bb6a-cf0422514253 --name 'iso.me Экспорт навсегда' --description 'Откройте экспорт данных одной покупкой.'
asc iap versions localizations update --localization-id 623fd860-9202-4309-b992-28d0b1947ece --name 'iso.me 永久数据导出' --description '一次购买即可解锁数据导出。'
```

No build attachment, submission, review-submission mutation, or release was included in that revised localization mutation. The repository now uses `MARKETING_VERSION = 1.7.6` and contains the canonical 1.7.6 metadata directory. Local build/test and authenticated ASC audits were rerun afterward. Build upload and review submission were authorized and executed later, as recorded below.

The rollback asymmetry was explicitly accepted while the resources were editable. Now that both items are `WAITING_FOR_REVIEW`, cancellation or rejection handling must use the review-submission lifecycle; the earlier pre-submission deletion path is no longer applicable. The current CLI and public API schema expose no IAP-version deletion endpoint.

## Build and App Review submission outcome

After separate user authorization to submit the latest source, App Store Connect had no eligible 1.7.6 binary; the newest prior upload was 1.7.5 build 31. The current workspace was therefore archived and uploaded as 1.7.6 build 32. The Release archive and App Store export succeeded, Apple processed the upload as `VALID` and `APP_STORE_ELIGIBLE`, and the build was attached to app version 1.7.6.

Pre-submission checks reported zero errors and zero warnings:

- Strict app validation: 0 blocking issues; manual release confirmed.
- Strict IAP validation: 0 blocking issues.
- Review Doctor: review details configured and no submission blockers detected.
- The App Privacy publish state remains unverifiable through the public API, but it was informational rather than a submission blocker.

A single review submission was created with exactly two items:

- App Store version `bce27f1c-93c2-4975-97b8-fe06d3906e92`, using build `faca16cd-1755-4b19-b9ff-32f61917eef6` (1.7.6 build 32).
- IAP version `e71fa922-7505-4b76-9cce-4fd998b673db` (version 2 with the nine corrected localizations).

Submission `bc5b53a3-d00b-4cce-b9d6-052a07fc08a9` was accepted at `2026-08-11T01:18:58.458Z`. Authenticated read-back confirmed the submission, app version, and IAP version are all `WAITING_FOR_REVIEW`. Release type remains `MANUAL`; no release was performed.
