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
