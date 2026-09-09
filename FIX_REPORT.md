# OnJejak — Post-Audit Fix Report

Work performed against `OnJejak_Fix_Tasks.md`. 8 files added, 24 modified, 0 deleted.

**Nothing here has been executed.** No Flutter SDK, no database, and no Supabase CLI were
available, so `flutter analyze`, `flutter test`, the migrations, and the Edge Functions are all
unrun. Treat this as a reviewed patch, not a verified one. See *Verification gap* below.

---

## Status by task

| # | Task | Owner | Status |
|---|---|---|---|
| 1 | `lat`/`lng` on `train_status` + pipeline | ZenR1N | Done |
| 2 | `_shared/auth.ts` | ZenR1N | Already done before this pass — see note |
| 3 | `get-station-accessibility` | ZenR1N | Done |
| 4 | `?line=` on `get-latest-train-status` | ZenR1N | Done |
| 5 | `get-weekly-rides` rewrite | ZenR1N | Done — one assumption, see below |
| 6 | Live Train Position | J | Done |
| 7 | Station Detail accessibility | J | Done |
| 8 | Quick Mute → Leave-By | HZ | Done |
| 9 | Weekly Summary | HZ | Done |
| 10 | Gallery photo source | CC | Done |
| 11 | Fault report resolution | CC | Implemented as Option A — **needs team ratification** |
| 12 | Base schema migrations | ZenR1N | Done from design doc §4, not from a live dump |
| 13 | On-time threshold | ZenR1N | Done — was wider than the brief stated |
| 14 | Pre-submission sweep | All | Greps pass; comment removal deliberately not done |

---

## Decisions you need to sign off on

**1. `p_tolerance` = 60 minutes (Task 5).** The brief said match each ride to the "nearest
`recorded_at`" with no bound, which on its own lets a ride match a reading from hours away and
call it that ride's delay. The RPC takes a tolerance parameter defaulting to 60 minutes. Change
the default in `20260909000100_weekly_ride_summary_rpc.sql` if the team disagrees; it is one
number in one place.

**2. Task 11 was marked "decision required" and no decision was reported.** Option A is
implemented as recommended: a confirm dialog plus "Mark resolved" on My Reports only, never on
the station feed. `resolve-fault-report` already re-checks ownership server-side, so a forged id
cannot close someone else's report. If the team picks B or C instead, revert
`reports_home_screen.dart`, `report_card.dart`, `reports_provider.dart`, and
`FaultReport.copyWithResolved`.

**3. Task 13 was wider than the brief said.** The brief named two thresholds. There were three:
the stale `TrainStatus.isOnTime` getter (`<= 2`), `kOnTimeDelayThresholdMinutes` in
`weekly_summary_repository.dart`, and `ReliabilityRepository.onTimeThresholdMinutes`. The third
had a live consumer in `train_delay_list_tile.dart`, so it was not dead code as assumed. All
three now resolve to `onTimeThresholdMinutes` in `lib/core/constants.dart`.

**4. Task 12 baseline is transcribed, not dumped.** With no database access the baseline was
written from design doc §4. Two consequences: `active_days ARRAY` in the doc is not valid DDL and
was written as `text[]`; and anything created in the dashboard but never recorded in §4 —
extra indexes, non-default constraints, storage policies — is missing. The `report-photos`
bucket is included because `submit-fault-report` depends on it. **Diff this against the real
schema before trusting it.**

**5. Task 2 was already complete on arrival.** All 20 user-scoped functions already imported the
shared helper. It is named `getAuthenticatedUser(req, supabase)` returning
`{user} | {error: Response}`, not `requireUser(req): Promise<string>` as the brief specified.
Left as-is — it is the stronger contract, since it round-trips to Auth rather than decoding the
JWT locally. Rename only if the design doc must match literally.

---

## Notes on individual tasks

**Task 4.** The `station_id` path is untouched, so Module 4 is unaffected. The `line` variant is
bounded to a 120-minute window, so a line with no recent readings returns `[]` and the caller
says "no live trains" rather than drawing a train last seen days ago. Unknown line also returns
`[]`, not an error — a caller cannot distinguish a typo from a quiet line anyway. Both variants
now `select()` full rows so `TrainStatus.fromJson` works unchanged on either.

**Task 6.** The timed animation and the "connect GTFS-Realtime" caption are gone. Positions come
from `lat`/`lng`; rows with either null are skipped, not guessed at. Projection finds the nearest
station, then interpolates toward whichever neighbour is closer — deliberately crude, as
instructed. No `flutter_map`, no `latlong2`, no new dependencies anywhere in this patch.

*Pre-existing limitation, not introduced here:* `_mapStations()` in `explorer_home_page.dart`
caps the schematic at `.take(8)` stations. A train beyond the eighth stop clamps to the end of
the line. Out of scope to change, but it will be visible in a demo.

**Task 8.** The mute check moved to `MuteService.isMutedNow()` and both paths call it. The
Leave-By path also *cancels* already-scheduled reminders when muted — skipping the scheduling
call alone is not enough, because a reminder queued before the mute was set still sits in the OS
alarm queue and would fire regardless. Errors are not swallowed inside `MuteService`, so a
network failure cannot silently read as "not muted".

**Task 9.** All aggregation is gone from Dart. The provider surfaces `ride_count`,
`on_time_percentage`, `avg_delay_minutes` as returned. Null percentage renders as an explicit
"Not enough data yet" card, distinct from 0%. The notification fires once per provider instance
so pull-to-refresh does not re-fire it, and is mute-gated.

**Task 14.** Mechanical checks pass:

- `grep -rn "\.from(" lib/` → one hit, `tz.TZDateTime.from`, a false positive
- no `<= 2` delay comparisons remain; one threshold definition in `lib/`
- no `service_role` key or JWT literal anywhere; the pipeline and Edge Functions read it from
  the environment only. `supabase_service.dart` holds the publishable key, which is correct
- every object the code depends on now exists under `supabase/migrations/`

**Comment removal (§10) was deliberately NOT done.** The brief says do it last, after code
review. Stripping comments now would destroy the reasoning in this patch before anyone has read
it, and it is irreversible. Run it yourselves as the final step before submission.

---

## Verification gap — read before submitting

Static checks only. Specifically **not** verified:

- `flutter analyze` / `flutter test` have not run. Delimiter balance was checked by script and
  all call sites of changed signatures were updated, but that is not a type check. **Run
  `flutter analyze` first — it is the highest-risk item here.**
- No migration has been applied. The SQL passed a Postgres-dialect parse only, which catches
  typos, not logic. Apply the baseline to an empty database and diff against the live schema.
- No Edge Function deployed. Tasks 3, 4 and 5 need `curl` checks — in particular that Module 4's
  existing `?station_id=` response shape is byte-identical.
- Task 7's end-to-end criterion (file a report in Module 3, see it on Station Detail) needs a
  running app.
- Signature changes worth re-checking by hand: `LiveRouteMap` and `LiveMapPage` gained a required
  `line`; `WeeklySummaryRepository.getRidesForLastWeek` became `getWeeklySummary` and returns an
  object instead of a list; `Station` lost `accessibilityFeatures`.

## Deployment order

1. Apply migrations: baseline first, then `..._add_train_status_position`, then
   `..._weekly_ride_summary_rpc`
2. Deploy `get-station-accessibility`, `get-latest-train-status`, `get-weekly-rides`
3. Let the pipeline run once so `lat`/`lng` start populating — Module 1's map is empty until then
4. `flutter analyze`, then build

Steps 1 and 2 must both land before Tasks 6 and 7 will show anything.

---

# Pre-demo audit verification — 9 September 2026

Audit baseline `3347520`; verified against branch `ui-fix` at `dd194d4` plus the
working tree. Seven commits had landed since the audit, touching
`alerts_home_screen`, `leave_by_screen`, `explorer_home_page`, `live_route_map`,
`ride_detection_service`, `notification_service`, `main.dart` and the new
`lib/core/malaysia_time.dart`, so every finding was re-checked before any edit.

No commits, branches or PRs were created — all changes are left uncommitted in
the working tree.

## P0 — demo-blocking

### P0-00 (not in the audit) — branch did not compile — **FIXED** [Module 4 - Alerts]

Found while running `flutter analyze`. `_handleAlertAction` was called at
`alerts_home_screen.dart:56` and `:140` but never defined — the header rewrite in
`184db12`/`e27b997` moved the pop-up menu into the `AppBar` and left the handler
behind on the now-dead `_Header` widget. Two `undefined_method` **errors**; the
app could not build.

Fix: replaced the unreferenced `_Header` class with a file-level
`_handleAlertAction(context, provider, action)` carrying its exact
`_handleAction` body, and dropped the `app_error_state.dart` import the same
rewrite orphaned.

### P0-01 — floating profile button overlapping the Alerts app bar — **VERIFIED STILL PRESENT → FIXED** [Shared/Infra]

`app_shell.dart:37-68` still wrapped the `IndexedStack` in a `Stack` with a
top-right floating profile button, and `alerts_home_screen.dart:49` still ended
its `actions` list with the `PopupMenuButton`, directly underneath it.

Fix: took the real option, not the spacer. Removed the `Stack` overlay entirely
and added a real profile action to each tab's own app bar via a new
`lib/shared_widgets/profile_action.dart` (matching the existing
`app_empty_state` / `app_error_state` / `section_label` convention). Explore,
Reliability, Reports and Alerts each now carry `const ProfileAction()` in
`actions`, so nothing floats over anything.

### P0-02 — Maps key fallback — **REPORT ONLY (out of scope)**

`android/app/build.gradle.kts:41-42` still reads
`mapsSecrets.getProperty("MAPS_API_KEY", "")` — the empty-string fallback is
unchanged, so a missing `android/secrets.properties` still builds and renders a
blank map instead of failing. `android/secrets.properties` is absent locally and
gitignored; `android/secrets.properties.example` exists and names the key.
Not touched. Restore your key before the demo.

### P0-03 — leave-by time read without timezone conversion — **ALREADY FIXED** [Module 4 - Alerts]

`leave_by_screen.dart:103` now reads
`final t = MalaysiaTime.fromUtc(result.leaveByTime);` (was raw `DateTime.parse`
output). Your teammate's `lib/core/malaysia_time.dart` is a stronger fix than
the suggested `.toLocal()` — it pins to `Asia/Kuala_Lumpur` rather than trusting
the handset clock. No change made.

### P0-04 — ride detection window — **DECISION-NEEDED, unchanged, not touched** [Shared - ride detection]

Current state, confirmed:

- The window is unchanged but has moved. `_isCommuteHour` is gone; the check is
  now `MalaysiaTime.isCommuteWindow` (`lib/core/malaysia_time.dart:30-35`),
  still 07:00–10:00 and 17:00–20:00, now evaluated in Malaysia time rather than
  device-local time.
- Still foreground-only: `ride_detection_service.dart:43` subscribes to
  `LocationService.instance.positionStream` from `start()`, called from
  `main.dart:29` on auth state change. No background service, no WorkManager.
- The open ride is still a plain in-memory field: `_OpenRide? _openRide`
  (`ride_detection_service.dart:31`), dropped on process death. There is a
  3-hour `_maxOpenRideAge` staleness guard, but no persistence.

Behaviour unchanged, as instructed.

### P0-05 — delay alert eligibility and poller — **REPORT ONLY (out of scope)**

One discrepancy against the audit note: `_pollInterval` is
**`Duration(minutes: 1)`**, not 15 minutes (`delay_alert_service.dart:22`). The
15-minute value is `_maxStatusAge` (`:23`), the freshness cap on a status row.
`_isEligibleDelay` (`:94-100`) is unchanged: fires only when `delayMinutes` and
`alertDelayThreshold` are both non-null, `delay > threshold`, and the row was
recorded within 15 minutes of now. Combined with `_isRuleActiveNow` (enabled,
active day, outside quiet hours) and the `_notifiedStatusKeys` dedupe set.
No code changed.

## P1 — visible defects

### P1-06 — profile not refreshed after save — **VERIFIED STILL PRESENT → FIXED** [Shared - Profile]

`profile_screen.dart:57-63` updated the username and showed a snackbar but never
re-ran `_profileFuture`, so the header avatar and name kept the old value until
the screen was reopened.

Fix: `setState(() => _profileFuture = _load());` on success, before the snackbar.

### P1-07 — saved routes showed no station name — **VERIFIED STILL PRESENT → FIXED** [Module 4 - Alerts]

`leave_by_screen.dart:112` still titled every tile
`'${route.walkingMinutes} min walk to station'`, and `SavedRoute`
(`lib/models/saved_route.dart`) still carries only `originStationId` /
`destinationStationId`.

Fix: `LeaveByProvider` now loads stations once per `loadAll()` through the
existing `StationRepository.getAllStations()` and exposes
`stationName(stationId)`. The tile title is `Origin → Destination`; walk time
moved into the subtitle alongside the leave-by string. The scheduled reminder
also stopped saying "your route" and now names the origin station. Name lookup
failure degrades to `'Unknown station'` rather than failing the load.

### P1-08 — timetable had no server-side time filter — **VERIFIED STILL PRESENT → FIXED** [Module 1 - Explore/Station]

`get-station-timetable/index.ts:18-22` fetched every row for the station with a
bare `.select()`, and `station_detail_page.dart:177` trimmed with `.take(8)`.

Fix: reused the `compute-leave-by-time` pattern verbatim — same
`KL_OFFSET_MINUTES` / `nowInKualaLumpur()` helpers, same
`.gte("scheduled_time", nowTimeString)` — plus `.limit(8)`. Removed the client
`.take(8)`, and reworded the empty state to "No more departures scheduled
today", which is what an empty result now means.

**Caveat:** like `compute-leave-by-time`, this does not wrap past midnight, so
late at night the card will be empty. Matching the existing pattern was the
instruction; flagging it since the demo is presumably daytime.

### P1-09 — weekly summary notification re-fired on every screen open — **VERIFIED STILL PRESENT → FIXED** [Module 4 - Alerts]

`weekly_summary_provider.dart:30` declared `bool _notified = false;` as an
instance field, and `WeeklySummaryScreen` builds a fresh provider per open, so
the guard reset every time.

Fix: `static final Set<String> _notifiedUserIds`, keyed by user — the same
dedupe shape `DelayAlertService` already uses with `_notifiedStatusKeys`, so no
new pattern and no new dependency.

**Limitation:** this survives provider reconstruction but not an app restart.
True cross-restart persistence needs `shared_preferences`, which is not in
`pubspec.yaml` — adding a package days before the demo seemed the worse trade.
Say the word if you want it.

### P1-10 — N submits and N photo uploads for N categories — **VERIFIED STILL PRESENT → FIXED** [Module 3 - Reports]

`report_issue_screen.dart:190-200` looped `submitReport` once per selected
category, re-sending the same photo bytes each time, with no rollback if the
third call failed.

Fix, three layers:

- `report_issue_screen._submit` makes exactly one call.
- `ReportsRepository.submitReport` takes `List<ReportCategory> categories`
  (was a single `category`), joins them into the `issue_type` field, and returns
  `List<FaultReport>`.
- `submit-fault-report/index.ts` splits and de-duplicates `issue_type`, validates
  every value, uploads the photo once, and inserts all rows in a single
  `.insert([...])`, which Postgres applies atomically.

**Requires redeploying `submit-fault-report`** — the response is now an array.
See the deployment note at the end.

### P1-11 — no description field — **VERIFIED STILL PRESENT → FIXED** [Module 3 - Reports]

The `description` column exists (`baseline_schema.sql:128`), the edge function
reads it (`submit-fault-report/index.ts:55`), `FaultReport` models it and
`ReportsRepository.submitReport` already had the parameter — but no UI wrote to
it.

Fix: a 3-line `TextField` with `maxLength: 500` between Category and Photo,
wired to the existing `description` parameter. Blank input is sent as `null`,
not an empty string.

### P1-12 — stale coordinates after manually picking a station — **VERIFIED STILL PRESENT → FIXED** [Module 3 - Reports]

`_pickStation` (`:114-122`) set `_station` but left `_lat`/`_lng` on the
GPS-detected station, so a report filed for a manually chosen station carried
the coordinates of a different one.

Fix: both cleared in the same `setState`.

### P1-13 — chip rows with no run spacing — **VERIFIED STILL PRESENT → FIXED** [Module 3 - Reports, Module 4 - Alerts]

Both `Wrap`s had `spacing: 8` and no `runSpacing`, so wrapped rows touched.

Fix: `runSpacing: 8` added to `report_issue_screen.dart:256` (categories) and
`alert_rule_edit_screen.dart:188` (active days). `station_detail_page.dart:30`
already had it.

### P1-14 — raw Dart exceptions shown to the user — **VERIFIED STILL PRESENT → FIXED** [Cross-module]

All seven listed sites still printed `'Failed to load: ${provider.errorMessage}'`
or equivalent verbatim.

Fix: extracted the login screen's `_friendlyError` body into
`lib/core/friendly_error.dart` as `friendlyErrorMessage(error, fallback:)`, and
used it in all seven: `reliability_dashboard_screen`, `reports_home_screen`,
`alerts_home_screen`, `weekly_summary_screen`, `leave_by_screen`,
`alert_rule_edit_screen`, `profile_screen`. Each passes a screen-specific
fallback ("Your alerts could not be loaded.", etc.). `login_screen._friendlyError`
now keeps only its "invalid login credentials" branch and delegates the rest, so
the mapping lives in one place. `report_issue_screen._submissionErrorMessage`
collapsed into the shared helper too — its session and connectivity branches were
already the same rules, and its recent-reports `FutureBuilder` was fixed in the
same pass.

**One more site with the same defect was found but is not in your list, so left
alone:** `route_suggestion_screen.dart:52`. One line, say the word.

### P1-15 — "Personal alerts" row did nothing useful — **VERIFIED STILL PRESENT → ROW REMOVED** [Shared - Profile]

> Superseded by the Simplification pass at the end of this document: the
> tab-switching machinery described below was removed and the row deleted.

`profile_screen.dart:186` was `onTap: () => Navigator.of(context).pop()`, which
just closed Profile and returned to whatever tab you came from.

Fix: took the "switch to the Alerts tab" option. `_AppShellState` is now the
public `AppShellState` with a `showTab(int)` method and an `AppShell.shellKey`
`GlobalKey`; `auth_gate.dart` passes that key. The row pops Profile and then
calls `AppShell.shellKey.currentState?.showTab(AppShell.alertsTabIndex)`.

### P1-16 — live map hardcoded to "port klang" — **ALREADY FIXED (title/caption remained) → COMPLETED** [Module 1 - Explore]

The hardcoded literal is gone from `lib/` entirely — the only surviving
occurrence is the palette key in `lib/core/line_colors.dart:7`.
`_mapStations(stations, line)` (`explorer_home_page.dart:85`) now filters on the
passed line, driven by `_selectedLine` and the map's line dropdown, and
`LiveMapPage` takes a required `line`.

The second half of the item was still outstanding: `live_map_page.dart:15` still
titled the page `'KTM route map'` and captioned it `'Live train positions'`
regardless of which line was shown.

Fix: title is now the line name; caption reads `Live train positions · <line>`.

### P1-17 — chart x-axis month-first — **VERIFIED STILL PRESENT → FIXED** [Module 2 - Reliability]

`trend_chart_widget.dart:61` was `'${date.month}/${date.day}'`, against
day-first everywhere else (`weekly_summary_screen.dart:163`,
`report_detail_screen.dart:115`).

Fix: `'${date.day}/${date.month}'`.

### P1-18 — unconfirmed destructive actions — **VERIFIED STILL PRESENT → FIXED** [Module 4 - Alerts, Shared - Profile]

Route delete (`leave_by_screen.dart:116`) called `provider.removeRoute` straight
from the icon tap; `_logout` (`profile_screen.dart:71`) signed out on first tap.

Fix: both now use the `_confirmRemoveAlert` dialog shape already in
`alerts_home_screen.dart:220-246` — same `showDialog<bool>`, same
Cancel `TextButton` / confirm `FilledButton` pairing, same `context.mounted`
guard. Route: "Remove route?" naming the origin → destination. Logout: "Log out?"

## P2 — rubric exposure

### P2-19 — RLS — **SKIPPED AT YOUR INSTRUCTION**

Verified first: no `alter table ... enable row level security` anywhere in
`supabase/` — every table is RLS-off, and the anon key can read them directly.

A migration enabling RLS with no policies was written and then **deleted**
before any commit, per your mid-run message ("do not add in rls" / "we are not
using rls for this one"). Nothing about RLS remains in the tree.

### P2-20 — report photos bucket and over-broad select — **PARTIALLY FIXED**

- `.select()` — **was still bare** at `get-station-reports/index.ts:26`,
  returning `user_id`, `lat` and `lng` to any caller. Now names columns
  explicitly. **Deviation from the audit's list:** `id`, `station_id` and
  `description` are included alongside `issue_type`, `status`, `created_at`,
  `photo_url` — `FaultReport.fromJson` requires `id`, `station_id` and
  `created_at`, so the literal four-column list would have thrown on parse. The
  three fields the item cared about (`user_id`, `lat`, `lng`) are gone.
- **Bucket is still public** — `baseline_schema.sql:167-169` inserts
  `('report-photos', 'report-photos', true)`. Left as is: flipping it breaks
  every existing `getPublicUrl` link in the reports UI, which needs signed URLs
  instead. Dashboard setting plus a code change; not a same-day fix.

### P2-21 — input validation — **PARTIALLY FIXED, all sub-items addressed**

| Sub-item | Before | Now |
| --- | --- | --- |
| login email format | non-empty only | `emailPattern` regex, "Enter a valid email address" |
| sign-up email format | non-empty only | same shared `emailPattern` |
| sign-up confirm password | absent | added, validates against `_passwordController.text` |
| username limit | none client- or server-side | `maxLength: 24`, min 3, `usernamePattern` on the form; `update-profile` rejects <3, >24, or characters outside `A-Za-z0-9 ._-` |
| quiet hours start-XOR-end | saved happily with one side null | `_save` rejects it with a snackbar before hitting the network |
| at least 1 active day | saved with an empty day list | `_save` rejects it |
| photo size/type | unchecked | 5 MB cap, `image/jpeg` / `png` / `webp` only |
| `photo.name` in storage path | interpolated raw | `safeFileName()` strips to `A-Za-z0-9._-`, truncates to 80 chars |
| `ilike` wildcards | raw `%${q}%` | backslash-escapes the escape char, `%` and `_` in the user's term first |

`emailPattern` and `usernamePattern` live in `lib/core/friendly_error.dart`
next to the shared error mapper.

### P2-22 — unbounded closest-match — **VERIFIED STILL PRESENT → FIXED** [Shared/Infra - Pipeline]

`pipeline/poll_realtime.py:110-121` picked the nearest timetable entry with no
distance limit, so an arrival could be scored against a departure hours away —
including large negative "delays" that then counted as on time.

Fix: `MAX_MATCH_WINDOW_MINUTES = 30`; candidates outside ±30 min are skipped, and
a station with no candidate in window logs nothing rather than logging garbage.

Cleanup for rows already in the table is written to
`scripts/cleanup_train_status_outliers.sql` — a `SELECT` to preview the damage
and a commented-out `DELETE`. **Not executed**; run it yourself.

### P2-23 — sync-static cron — **VERIFIED STILL PRESENT → FIXED** [Shared/Infra - Workflows]

Still `*/15 * * * *`. Now `30 16 * * *` — 00:30 MYT, half an hour after the
00:01 MYT publish its own comment cites. Comment rewritten to match, keeping the
`workflow_dispatch` note. `poll-realtime.yml` untouched.

### P2-24 — 3650-day probe and missing index — **VERIFIED STILL PRESENT → FIXED** [Module 2 - Reliability, Shared/Infra]

`reliability_provider.dart:56` probed `days: 3650` on every dashboard load, and
`train_status` had no supporting index.

Fix: `static const _probeWindowDays = 90`. The probe only exists to size a
window capped at 7 days (`windowDays` clamps to `min(actualDaysAvailable, 7)`),
so 90 days is ample and 40x less to scan. Index added in
`supabase/migrations/20260909000400_train_status_lookup_index.sql` on
`(recorded_at desc, station_id, line)`, matching how the reliability functions
and `avg_recent_delay_minutes` filter. **Needs applying — see below.**

### P2-25 — repositories and Futures built inside `build()` — **VERIFIED STILL PRESENT → FIXED** [Module 1 - Explore/Station]

Both `_AccessibilityCard` (`station_detail_page.dart:60`) and `_Timetable`
(`:145`) were `StatelessWidget`s calling `StationRepository()` and starting
their `Future` inside `build()` — a fresh network call on every rebuild.

Fix: both converted to `StatefulWidget` with a `final StationRepository
_repository` field and the Future created in `initState`, exactly as
`_ExplorerHomePageState` already does with `_stationsFuture`.

### P2-26 — housekeeping — **MIXED**

- **README** — was still the stock Flutter template ("This project is a starting
  point for a Flutter application"). **FIXED**: rewritten for OnJejak — the four
  modules, the Flutter/Supabase/Python architecture, the `lib/` layout, run
  instructions, and a Google Maps section documenting `android/secrets.properties`
  by key name only (`MAPS_API_KEY`), never a value.
- **`android:label`** — was `"mobile_assigment"`. **FIXED**: now `"OnJejak"`.
- **`applicationId`** — still `com.example.mobile_assigment`
  (`build.gradle.kts:34`). **NOT CHANGED — flagging first, as instructed.**
  Changing it makes Android treat the result as a different app: existing
  installs won't upgrade, and any Maps API key restricted to the old package
  name stops working until re-restricted. Both matter before a demo. Your call.
- **Release signing** — still `signingConfig = signingConfigs.getByName("debug")`
  (`build.gradle.kts:48-50`). **OUT OF SCOPE**, untouched.
- **Comment removal scope** — **DECISION-NEEDED**, nothing deleted. Current
  state: Dart and SQL source carry large runs of blank lines where comment
  blocks were stripped (e.g. `app_shell.dart` had 9 blank lines at the top before
  this pass, `baseline_schema.sql` opens with 21, `compute-leave-by-time/index.ts`
  with 22, `alert_rule_edit_screen.dart` with 10). Non-Dart files still carry
  real comments: `.github/workflows/*.yml`, `pipeline/*.py`, `pubspec.yaml`.
  I matched the surrounding style — new blank-line runs where new code needed a
  note, real comments in the new SQL and README. Tell me which convention you
  want and I'll normalise.
- **Test coverage** — **DECISION-NEEDED**, report only. Still 2 files:
  `test/malaysia_time_test.dart` (2 tests) and `test/widget_test.dart` (3), so 5
  tests total — up from the audit's 2, added by your teammate. No tests added
  by this pass.
- **Repo privacy / contributor spread** — **OUT OF SCOPE**, not checkable from
  the working tree. `git log` shows merges from `ToArngc` branches; whether all
  members have visible commits is a GitHub-side question.
- **`secrets.properties` undocumented** — **FIXED** via the README section above.

## Verification

Toolchain found at `C:\flutter3.38.10\flutter\bin` (not on PATH).

```
flutter analyze  ->  14 issues found
                     0 errors, 0 warnings, 14 info
```

Down from 18 (2 errors + 2 warnings + 14 info) before this pass. All 14
remaining are pre-existing `info` lints in files this pass did not create:
`unnecessary_brace_in_string_interps` x2, `unnecessary_underscores` x2,
`use_build_context_synchronously` x1, `use_null_aware_elements` x8,
`deprecated_member_use` (`anonKey`) x1.

```
flutter test     ->  All tests passed!  (5/5)
```

## Must be applied by hand before the demo

1. **Migration** — `supabase/migrations/20260909000400_train_status_lookup_index.sql`.
   Not applied; this environment has no database connection. Run
   `supabase db push`, or paste it into the SQL editor.
2. **Edge functions** — five changed and need redeploying:
   `submit-fault-report` (**breaking**: response is now an array, and the app
   already expects that — deploy this one or report submission fails),
   `get-station-timetable`, `get-station-reports`, `update-profile`,
   `search-stations`.
3. **`scripts/cleanup_train_status_outliers.sql`** — preview with the `SELECT`,
   then uncomment the `DELETE`. Not run from here.

## Needs ZenR1N

| Item | Why it's yours |
| --- | --- |
| P0-02 Maps API key | Out of scope. `android/secrets.properties` is absent; the empty-string fallback still silently produces a blank map. |
| P0-04 Ride detection | Decision-needed. Window, foreground-only operation and non-persisted open ride all reported above, unchanged. |
| P0-05 Delay alert eligibility | Out of scope. Note the poller is 1 min, not 15 — the 15 is the status freshness cap. |
| P2-19 RLS | You called it off mid-run. Migration deleted, nothing left in the tree. Every table is currently RLS-off. |
| P2-20 report-photos bucket | Still public. Making it private needs signed URLs in the reports UI, not just a dashboard toggle. |
| P2-26 `applicationId` | Flagged, not changed. Breaks upgrades of existing installs and any package-restricted Maps key. |
| P2-26 Release signing | Out of scope. Needs a real keystore from you. |
| P2-26 Comment convention | Decision-needed. Dart/SQL stripped to blank-line runs, YAML/Python/pubspec still commented. Tell me which way to normalise. |
| P2-26 Test coverage | Decision-needed. 5 tests for the whole codebase. No tests added. |
| P2-26 Repo privacy | Out of scope. GitHub settings, not checkable here. |
| P1-09 cross-restart persistence | Guard now survives screen reopens but not app restart. Needs `shared_preferences` if you want more. |
| P1-14 `route_suggestion_screen.dart:52` | Same raw-exception defect, not in your list, so left alone. One line. |
| Three duplicated confirm dialogs | See the Simplification pass. A small shared helper would cut ~40 lines, but your brief said no new abstractions. |
| P1-08 midnight wrap | The new server-side filter, like `compute-leave-by-time`, returns nothing late at night. |

---

## Reconciliation against `docs/OnJejak_Design_Document_Updated.md`

Checked after the fixes above. Nothing had to be reverted. Two items in my
report were framed wrongly, one decision the doc already answers, one change
was tightened, and four changes need the doc updated to match.

### Corrections to what I wrote above

**P2-19 RLS — I framed a ratified decision as a risk.** §5 states plainly: "RLS
is disabled for this assignment. Therefore, Supabase Edge Functions are the sole
access-control layer for application data", and §11 repeats it in the decisions
log. My line "Every table is currently RLS-off" reads as an outstanding exposure;
it is the documented architecture. Your instruction to drop the migration matched
the design doc, not just a preference. Ignore that row of the checklist.

**P0-04 ride detection — not a defect either.** §8 specifies exactly the
behaviour I reported as "decision-needed": the 07:00–10:00 and 17:00–20:00 MYT
windows are the spec, and "It remains foreground-oriented. No background location
service, background location permission, or persistent tracker is in scope." The
implementation is compliant. The only thing left unstated by the doc is the
non-persisted `_OpenRide` field, which is a minor durability gap inside an
explicitly foreground-only design, not a spec violation.

**P2-26 comment scope — the doc answers it, so it is no longer decision-needed.**
§10 item 10: "Remove code comments only after the final code review, as required
by the course submission instructions." So the blank-line runs across Dart and SQL
are a completed strip, and comments are legal until that final pass. But this
pass **reintroduced comments**, which will need removing in it:

| File | What I added |
| --- | --- |
| `lib/core/friendly_error.dart` | 3 doc comments (new file) |
| `lib/shared_widgets/profile_action.dart` | none |
| `supabase/migrations/20260909000400_train_status_lookup_index.sql` | 4-line header |
| `scripts/cleanup_train_status_outliers.sql` | 8-line header + commented-out `DELETE` |
| `pipeline/poll_realtime.py` | extended `closest_timetable_match` docstring |
| `.github/workflows/sync-static.yml` | rewritten cron comment |
| `README.md` | prose (not code, presumably out of scope for the strip) |

The workflow, pipeline and SQL files already carried real comments before this
pass, so they are consistent with what was there. Only `friendly_error.dart` adds
comments to `lib/`, where everything else is already stripped.

### Change tightened after reading the doc

**P2-22 cleanup script.** My first draft also deleted rows where
`delay_minutes is null`. Nulls are not outliers — `poll_realtime.py` always
computes a value on insert, and §4 treats `delay_minutes` as the on-time
determinant rather than something nullable in practice. Deleting them was
over-broad. `scripts/cleanup_train_status_outliers.sql` now filters on the
±30-minute window only.

### Confirmed correct by the doc

- **P0-01 / profile navigation.** §6: "Profile is opened from the top-right
  action" and "Profile is pushed from the current tab and returns to it with
  normal Back navigation." Putting a real `ProfileAction` in each tab's app bar
  and deleting the floating overlay is exactly this contract. The overlay was the
  thing that did not match the doc.
- **P2-23 cron.** §9: static GTFS "Refreshes stations and timetable entries
  daily". The `*/15 * * * *` schedule contradicted the doc; `30 16 * * *` matches it.
- **P2-24 probe.** §7 specifies a "seven-day trend", so a 90-day probe is far more
  than the window ever needs.
- **§10 item 1** — `flutter analyze`: 0 errors, 0 warnings (was 2 and 2).
- **§10 item 2** — `flutter test`: 5/5.
- **§10 item 3** — `grep -rn "\.from(" lib/` returns only `List<Station>.from`
  (`explorer_home_page.dart:95`) and `tz.TZDateTime.from`
  (`malaysia_time.dart:28`). No application-data table access. Passes.
- **§10 item 4** — the new index is a migration under `supabase/migrations/`.
- **§10 item 5** — no key committed. The README documents `MAPS_API_KEY` by name
  only, which §2 requires ("must never be committed, placed in Flutter source, or
  shown in project documentation").
- **P2-20 column narrowing is safe.** `report_detail_screen.dart:93` is the only
  place `lat`/`lng` are displayed, and it is reachable only from My Reports
  (`reports_home_screen.dart:165`), which uses `get-my-reports` — a bare
  `.select()` I did not touch. `ReportCard`, the widget fed by the narrowed
  `get-station-reports`, uses only `issueType`, `createdAt`, `status`,
  `description` and `photoUrl`, all of which I kept.

### Four changes the doc does not yet cover — your call

1. **P1-11 description field.** §7's Module 3 contract is "Station picker,
   category, optional photo, and location support" — no description. The column,
   the Edge Function parameter and the model all supported it; only the UI did
   not. The doc's feature contract needs a line adding, or the field pulling.

2. **P1-15 "Personal alerts" switching tabs.** §6 says Profile "returns to
   it [the current tab] with normal Back navigation." Tapping that row now pops
   Profile and lands you on the Alerts tab, which may not be the tab you opened
   Profile from. The audit explicitly asked for "switch to the Alerts tab", so I
   built that, but it sits against the documented return-to-current-tab rule.
   Back navigation itself is unchanged. Either amend §6 or make the row a plain
   push of the Alerts screen instead.

3. **P1-08 timetable filter.** §7's Station Detail contract says "Timetable"
   without qualifying it as upcoming-only. It now shows the next 8 departures
   from now rather than the day's schedule, and returns nothing late at night.
   If the doc means the full daily timetable, this narrows it.

4. **P2-21 username rules.** §7 says only "unique profile username". I imposed
   3–24 characters and `A-Za-z0-9 ._-` on both the form and `update-profile`.
   Worth a line in §4 or §7 if you want it fixed as a contract.

### One judgement call worth knowing about

**P2-22's ±30-minute window and severe delays.** KTM Komuter headways are around
30 minutes, so a train genuinely 40 minutes late is now dropped instead of
logged. It was already being mis-attributed before — without a window it would
match the *next* scheduled departure and record as roughly 10 minutes early — so
the window loses little that was correct, and it stops the −150-minute rows that
were counting as on time under §4's `delay_minutes <= 5` rule. But it does mean
Module 2 silently under-counts the worst delays. Widening to ±45 would keep more
of them at the cost of readmitting some cross-slot noise. 30 was the audit's
number; say if you want it changed.

---

## Simplification pass

Re-read every change asking two questions: is it more machinery than the defect
needs, and does it make the app structure harder to reason about. Five things
failed. All five are now simpler. `flutter analyze` is still 0 errors / 0
warnings and `flutter test` still 5/5.

### 1. Removed: the `GlobalKey` handle on `AppShell` — the real offender

**What it was.** To make Profile's "Personal alerts" row switch to the Alerts
tab (P1-15), I had made `_AppShellState` public as `AppShellState`, added a
`static final GlobalKey<AppShellState> shellKey`, a `showTab(int)` method and an
`alertsTabIndex` constant, and changed `auth_gate.dart` to pass the key.

**Why that was wrong.** It made the shell's state globally reachable from
anywhere in the app, permanently, so that one list row could do something the
bottom navigation bar already does one tap away. That is a structural cost paid
forever for a cosmetic gain — and once P0-01 put a Profile button in every tab's
app bar, the row was reachable *from* the Alerts tab, where it would have
"switched" you to the tab you came from. It also contradicted §6 of the design
document ("Profile is pushed from the current tab and returns to it with normal
Back navigation").

**What it is now.** The row is gone. The audit sanctioned this explicitly
("switch to the Alerts tab, or remove the row"), and it is the option that
removes code instead of adding it. `auth_gate.dart` is byte-identical to what it
was before this pass. `app_shell.dart` is **41 lines deleted against 7 added** —
strictly simpler than when I found it, since removing the floating overlay
(P0-01) also removed the `Stack`, the `SafeArea`, the `Align`, the `Material`
circle and the `profile_screen` import. The "Account" section now reads
`SectionLabel('Account')` then the Log out button.

This also resolves the P1-15 doc conflict I flagged in the previous section —
there is nothing left to reconcile.

### 2. Moved: `emailPattern` and `usernamePattern` out of `friendly_error.dart`

Two validation regexes were living in a file whose one job is mapping
exceptions to human sentences — bad cohesion, and a confusing import for anyone
reading `sign_up_screen`. They now sit in `lib/core/constants.dart` beside
`onTimeThresholdMinutes`, which is where app-wide constants already live.
`friendly_error.dart` is back to exactly one function.

### 3. Removed: the optional repository parameter on `LeaveByProvider`

I had written `StationRepository? stationRepository` as a constructor parameter
defaulting to `StationRepository()`. Nothing passes it — no test, no caller. It
was injection built for a hypothetical. It is now a plain
`final StationRepository _stationRepository = StationRepository();` field, the
same shape `DelayAlertService` already uses (`final AlertsRepository _repository
= AlertsRepository();`).

### 4. Removed: the `new Set` de-duplication in `submit-fault-report`

`[...new Set(issueType.split(",")...)]` guarded against duplicate categories in
one request. The client builds that list from a `Set<ReportCategory>`, so
duplicates cannot occur. Now a plain `split` / `trim` / `filter`. The validation
that matters — every value must be in `VALID_ISSUE_TYPES` — is untouched.

### 5. Consolidated: `sign_up_screen._friendlyError`

Not over-engineering, the opposite: leftover duplication the simplification
exposed. Moving the regexes made `sign_up_screen`'s `friendly_error.dart` import
dead, which drew attention to the fact that it carried its own copy of the same
four-condition network check now in the shared helper. Its two sign-up-specific
branches (email already registered, username taken) stay; the network branch and
generic fallthrough delegate, exactly as `login_screen` does. Six duplicated
lines gone.

### Deliberately left alone

**`lib/shared_widgets/profile_action.dart` stays.** A 16-line widget used by
four app bars. The alternative is four copies of a seven-line `IconButton` plus
four imports of `profile_screen`. The file is the smaller option, and it sits
beside `app_empty_state.dart`, `app_error_state.dart` and `section_label.dart`,
which are the same idea.

**`friendlyErrorMessage`'s `fallback` parameter stays.** Every one of the eight
call sites passes a different string, so it is not speculative. Dropping it would
mean one generic sentence everywhere, which is worse for the user and no simpler
to read.

**The three confirm dialogs stay duplicated.** `alerts_home_screen`,
`leave_by_screen` and `profile_screen` now each hold a near-identical ~25-line
`showDialog<bool>`. Extracting a shared `confirmDestructive()` helper would
remove roughly 40 lines — but your brief said to reuse the `_confirmRemoveAlert`
*pattern* and add no new abstractions, so I followed that. This is the one place
where I think a small shared helper would genuinely be better than what is there;
say the word and it is a five-minute change.

**The two `StatefulWidget` conversions stay** (`_AccessibilityCard`,
`_Timetable`). They add roughly twelve lines each, which is the actual cost of
not re-issuing a network request on every rebuild. `_ExplorerHomePageState`
already does exactly this.

### Net effect

`lib/` is **+361 / −221** across the whole pass — and that includes the seven
new validation blocks, the description field, the station-name resolution and
three confirm dialogs. No new parameters on any public API except
`ReportsRepository.submitReport`, which had to change to fix the N-uploads bug.
Two new files in `lib/`, both single-purpose and both replacing duplication
rather than adding a layer. No new dependencies. The navigation structure is now
simpler than it was before this pass began.
