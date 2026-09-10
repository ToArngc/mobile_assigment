# OnJejak

OnJejak is a Flutter app for KTM Komuter riders in the Klang Valley. It answers
four questions a rider actually has: which station is near me, how reliable is
this line lately, how do I report a broken lift, and when should I leave home.

Built for BMIT2073 Mobile Application Development.

## Modules

| Module | What it does |
| --- | --- |
| 1 — Explore / Station | Browse and search stations by line, see live train positions on a route map, open a station for its accessibility status and next scheduled departures. |
| 2 — Reliability | On-time percentage and delay trend per line or station, drawn from logged arrivals, plus route suggestions. |
| 3 — Reports | File a fault report (broken lift, escalator, overcrowding, cleanliness, safety hazard) with an optional photo and description; see recent reports for a station and your own history. |
| 4 — Alerts | Per-station delay alerts with a threshold, quiet hours and active days; a Leave-By planner that schedules a morning reminder; a weekly ride summary. |

## Architecture

- **Flutter** app (`lib/`), `provider` for state, `google_maps_flutter` for the
  live map, `flutter_local_notifications` for alerts.
- **Supabase** for auth, Postgres and storage. The app never queries Postgres
  directly — every read and write goes through an Edge Function
  (`supabase/functions/`) running on the service-role key.
- **Python pipeline** (`pipeline/`) run by GitHub Actions: `sync_static.py`
  loads GTFS static stations and timetables daily, `poll_realtime.py` polls the
  KTMB GTFS-Realtime feed and logs arrivals into `train_status`.

```
lib/
  core/            theme, constants, Malaysia timezone helpers
  models/          plain data classes
  services/        repositories, one per backend concern
  providers/       ChangeNotifier state per screen
  modules/         one folder per module, each with screens/ and widgets/
  shared_widgets/  app shell, empty/error states, shared app bar actions
```

## Getting started

Requires the Flutter SDK (stable) and a configured Android toolchain.

```bash
flutter pub get
flutter run
```

### Google Maps API key

The Android manifest reads its Maps key from `android/secrets.properties`,
which is gitignored and never committed. Create it from the example file:

```bash
cp android/secrets.properties android/secrets.properties
```

Then set the one key it expects:

```
MAPS_API_KEY=<your Android Maps SDK key>
```

Get a key from the Google Cloud console with the **Maps SDK for Android**
enabled, and restrict it to this app's package name and signing certificate.
Without this file the build still succeeds, but the map renders blank — the
manifest placeholder falls back to an empty string.

### Supabase

Set the project URL and anon key the app initialises with (see
`lib/services/supabase_service.dart`), then apply the schema and deploy the
functions:

```bash
supabase db push
supabase functions deploy
```

## Tests

```bash
flutter analyze
flutter test
```
