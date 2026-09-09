# OnJejak - Design Document

**Course:** BMIT2073 Mobile Application Development Group Assignment  
**Status:** Living document. Update through a team-reviewed pull request when a product decision changes.  
**Revision:** Map, Malaysia-time, and Ride History reconciliation

---

## 1. Project overview

**App:** OnJejak - a KTM Komuter and ETS reliability, accessibility, and personal-alerts tracker.

**Problem:** Existing Malaysian rail trackers can show current vehicle locations, but they do not present accumulated reliability history or a persistent public record of station-level accessibility and fault reports.

**Solution:** OnJejak adds two layers to KTMB open GTFS data:

1. line and station reliability history; and
2. community accessibility and fault reporting, with personal alerts and commute summaries.

**SDG 9 alignment:** Reliability tracking supports resilient public-transport infrastructure. Accessibility reporting supports inclusive infrastructure.

| Member | Ownership |
|---|---|
| J | Module 1 - Station and Route Explorer |
| You | Module 2 - Reliability Engine and shared GTFS pipeline |
| CC | Module 3 - Community Fault and Accessibility Reports |
| HZ | Module 4 - Personal Alerts |

The data pipeline is shared infrastructure. Each member owns their module's implementation and code walkthrough.

---

## 2. Technology stack

| Area | Choice | Purpose |
|---|---|---|
| Mobile app | Flutter and Dart (`^3.10.9`) | Android-focused client application |
| Backend | Supabase | Postgres, Auth, Storage, and Edge Functions |
| State | Provider | Feature-level application state |
| Data pipeline | Python and GitHub Actions | KTMB GTFS static and realtime ingestion |
| Android map | `google_maps_flutter` | Station markers, route polylines, and live train markers |
| Charts | `fl_chart` | Reliability trends |
| Device services | `location`, `permission_handler`, `image_picker`, `flutter_local_notifications` | GPS, permissions, photos, and local alerts |

Firebase and Supabase Realtime are not used. The app fetches data on demand through Edge Functions.

### Android Google Maps configuration

Google Maps is part of the Android Explore experience. The application key is supplied locally through `android/secrets.properties`:

```properties
MAPS_API_KEY=your-restricted-android-maps-api-key
```

This file is ignored by Git. The key must be restricted to the Android application and must never be committed, placed in Flutter source, or shown in project documentation. Maps SDK for Android must be enabled in the associated Google Cloud project.

---

## 3. Architecture

```
Flutter UI
  -> Provider
    -> Repository
      -> edge_function_client
        -> Supabase Edge Function
          -> Supabase Postgres or Storage

GitHub Actions pipeline
  -> KTMB GTFS static and realtime feeds
    -> Supabase Postgres
```

### Folder ownership

```
lib/
  core/                 # theme, constants, Malaysia time utility
  models/               # immutable data classes
  services/             # repositories, device services, Edge Function client
  providers/            # ChangeNotifier feature state
  modules/
    auth/
    module1_explorer/
    reliability/
    reports/
    alerts/
  shared_widgets/

supabase/
  functions/
  migrations/

pipeline/
  poll_realtime.py
  sync_static.py

.github/workflows/
```

### Layering rules

- Screens and widgets use Providers or repositories; they do not query Supabase tables directly.
- Flutter data reads and writes use Edge Functions through `edge_function_client.dart`.
- Flutter must never call `.from()` for application data. Direct Supabase client usage is allowed only for Auth.
- No service-role key may appear in Flutter code.

### State rules

- Local widget state: selected navigation tab, form values, scroll state, and selected map line.
- Provider state: sessions, saved stations, routes, reports, reliability data, and weekly summaries.

---

## 4. Data model

The version-controlled schema is under `supabase/migrations/`. The main data objects are:

| Object | Purpose |
|---|---|
| `stations` | Station name, line label, latitude, longitude |
| `timetable_entries` | Scheduled departure times and directions |
| `train_status` | Arrival-based train status, delay, `trip_id`, vehicle latitude, vehicle longitude, and timestamp |
| `ride_logs` | Automatically detected rider journeys, origin, destination, duration, and detection time |
| `saved_stations` | User alert rules |
| `saved_routes` | Leave-By route preferences and walking minutes |
| `mute_settings` | User notification mute dates |
| `fault_reports` | Community station reports and optional photo URL |
| `profiles` | Usernames |
| `station_accessibility` view | Latest report status by station and issue type |

### Canonical values

- A train is on time when `delay_minutes <= 5`.
- The Flutter constant is `onTimeThresholdMinutes`.
- Malaysia operational time is `Asia/Kuala_Lumpur` (MYT, UTC+8).
- Database and API timestamps are UTC ISO-8601 instants. UI times and notifications convert those instants to MYT.
- `ride_logs.delay_minutes` is retained for schema stability but is not written by ride detection. Weekly delay data is resolved server-side at read time.

---

## 5. Supabase access model

RLS is disabled for this assignment. Therefore, Supabase Edge Functions are the sole access-control layer for application data.

- Flutter uses only the publishable key for Supabase Auth.
- Edge Functions hold the secret key server-side.
- Every user-owned operation imports the shared authentication helper, verifies the JWT, obtains `user_id`, scopes reads and writes to that user, and rejects invalid or missing tokens.
- Public reference endpoints validate inputs but do not apply user scoping.

Core endpoint groups are:

| Area | Endpoints |
|---|---|
| Profile | `create-profile`, `get-profile`, `update-profile` |
| Stations and map | `get-stations`, `search-stations`, `get-station`, `get-stations-by-line`, `get-station-timetable`, `get-latest-train-status?line=` |
| Reliability | `get-reliability-stats`, `get-recent-train-delays`, `get-network-reliability-stats`, `get-reliability-trend`, `get-route-suggestions` |
| Reports | `get-station-reports`, `get-my-reports`, `submit-fault-report`, `resolve-fault-report`, `get-station-accessibility` |
| Alerts and routes | saved-station CRUD endpoints, mute endpoints, saved-route CRUD endpoints, `compute-leave-by-time` |
| Ride history | `get-recent-rides`, `log-ride`, `get-weekly-rides` |

`get-latest-train-status?line=<line>` returns the latest status per station for the selected line. The map ignores rows without latitude or longitude.

---

## 6. Navigation

```
Splash / Auth
  -> Explore
  -> Reliability
  -> Reports
  -> Alerts

Profile is opened from the top-right action.
```

The four primary destinations use bottom navigation. Profile is pushed from the current tab and returns to it with normal Back navigation.

---

## 7. Screens and feature contract

| Module | Screen | Feature contract | Data |
|---|---|---|---|
| Auth | Login and Sign Up | Email/password authentication and unique profile username | Auth, `profiles` |
| Shared | Profile | View/edit username and logout | `profiles` |
| Module 1 | Explore | Search stations and lines; list available lines | `stations` |
| Module 1 | Live Train Position | Android Google Map with an explicit line selector, station markers, a selected-line polyline, and markers based only on real `lat`/`lng` train data | `stations`, `get-latest-train-status?line=` |
| Module 1 | Station Detail | Timetable and current accessibility issues | timetable and accessibility endpoints |
| Module 2 | Reliability Dashboard | On-time percentage, seven-day trend, and recent delays | `train_status` |
| Module 2 | Route Suggestion | Suggest alternate route or time using reliability data | `train_status`, `saved_routes` |
| Module 3 | Report an Issue | Station picker, category, optional photo, and location support | `fault_reports` |
| Module 3 | My Reports | User's submitted reports and resolution status | `fault_reports` |
| Module 4 | My Alerts | Saved station rules, threshold, quiet hours, active days | `saved_stations` |
| Module 4 | Ride History | Past automatically detected rides; read-only details | `ride_logs` |
| Module 4 | Quick Mute | Mute all local reminder categories through a selected date | `mute_settings` |
| Module 4 | Leave-By | Saved routes, Malaysian local departure time, and local reminder | `saved_routes`, `compute-leave-by-time` |
| Module 4 | Weekly Summary | Ride count, on-time percentage, average delay, and local summary notification | `get-weekly-rides` |

### Live map behaviour

1. The Explore screen derives the available line list from `Station.lines`.
2. The map uses the first available line as its initial selection.
3. The user chooses another line through one compact dropdown.
4. Changing the line updates its station markers, route polyline, fitted camera, and live-train query.
5. A line without current position rows shows its station route and `No live trains right now`.
6. The map never animates or invents a train position.

### Ride History behaviour

Ride History contains only automatically detected journeys. There is no manual ride-entry interface.

When a signed-in user grants location permission, the app listens for nearby stations while it is active. Reaching a first station opens a possible trip; reaching a different station records origin, destination, duration, and current detection time through `log-ride`.

Each card may open a read-only detail view showing the available origin, destination, MYT detection date and time, duration, line, and `Automatically detected` source label. Missing fields must be shown as unavailable rather than fabricated.

Prepared test `ride_logs` records may be used in the demonstration database, but they are not a product feature and must not be presented as user-entered rides.

---

## 8. Malaysia time and notifications

### Time rule

All KTM operational decisions use `Asia/Kuala_Lumpur`.

- Supabase and Edge Functions exchange timestamps as UTC ISO-8601 values.
- Flutter converts those values to MYT when displaying Leave-By times, Ride History times, and scheduled notifications.
- The app must not use the device's arbitrary local timezone for KTM commute windows.

### Ride-detection commute windows

Ride detection processes location updates only during these MYT ranges:

| Start inclusive | End exclusive |
|---|---|
| 07:00 | 10:00 |
| 17:00 | 20:00 |

It remains foreground-oriented. No background location service, background location permission, or persistent tracker is in scope.

### Local notifications

Notifications are local only. No FCM, push server, or device-token table is used.

Before any delay alert, Leave-By reminder, or weekly summary notification is scheduled or shown, the app checks `mute_settings`. When muted, any already scheduled Leave-By reminder is cancelled.

The notification timezone is explicitly `Asia/Kuala_Lumpur`.

---

## 9. GTFS pipeline

| Feed | Source | Use |
|---|---|---|
| Static GTFS | `https://api.data.gov.my/gtfs-static/ktmb` | Refreshes stations and timetable entries daily |
| GTFS Realtime vehicle positions | `https://api.data.gov.my/gtfs-realtime/vehicle-position/ktmb` | Produces train-status arrival events and position data |

The pipeline writes `trip_id`, delay information, and real vehicle `lat`/`lng` when a vehicle is near a station. It prevents duplicate trip/station arrival records. Pipeline credentials remain server-side in GitHub Actions secrets.

The Flutter client reads processed Supabase data rather than decoding the protobuf realtime feed itself. This is an intentional architecture decision and should be explained in the final presentation.

---

## 10. Quality and verification

Before final submission:

1. Run `flutter analyze` with no new warnings.
2. Run `flutter test`.
3. Verify `grep -rn "\\.from(" lib/` has no application-data table access.
4. Verify every schema object used by the app exists in `supabase/migrations/`.
5. Verify no secret, service-role key, or Android Maps key is committed.
6. Verify Leave-By displays a UTC response as the correct MYT time.
7. Verify the eight commute-window boundaries in MYT.
8. On an Android device or emulator with a locally configured Maps key, verify map loading, line switching, route fitting, and the honest no-live-trains state.
9. Verify a report submitted in Module 3 appears in Module 1 Station Detail.
10. Remove code comments only after the final code review, as required by the course submission instructions.

---

## 11. Decisions log

- Supabase replaces Firebase completely.
- The Google Maps widget is retained for the Android Explore route experience.
- Android map secrets remain local in `android/secrets.properties`; the repository includes only an example file.
- The map uses a single line dropdown rather than multiple map pages or tabs.
- Live train positions always come from GTFS-derived `train_status` rows. There is no mock animation.
- Malaysia time is explicit for Leave-By, notifications, and commute-window decisions.
- Ride History is automatic GPS detection, not a manually editable journal.
- Weekly ride-delay aggregation happens server-side when data is read, avoiding a timing race at detection time.
- Edge Functions remain the exclusive Flutter data-access path because RLS is disabled for the assignment.

---

## 12. Changelog for this revision

- Replaced the prior core schematic-map decision with an Android Google Maps implementation.
- Added an explicit selected-line dropdown requirement for the Explore map.
- Added secure Android Maps API-key setup through an ignored local secrets file.
- Made `Asia/Kuala_Lumpur` the canonical operational timezone.
- Documented UTC storage/API timestamps and MYT display/notification conversion.
- Documented the foreground-only MYT ride-detection windows.
- Clarified that Ride History is automatic, read-only, and may expose a lightweight details view.
