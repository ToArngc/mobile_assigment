# OnJejak - Map, Malaysia Time, and Ride History Fix Prompt

## Objective

Implement the agreed quality fixes in the existing Flutter/Supabase project. Keep the current Android Google Maps implementation. Do not replace it with a schematic map, add new packages, add database objects, add Edge Functions, or change the existing Leave-By server calculation.

The implementation must be small, production-like for this assignment, and match the updated design document in `docs/OnJejak_Design_Document_Updated.md`.

## Existing facts to preserve

- `compute-leave-by-time` correctly returns ISO-8601 UTC instants. UTC is the storage and API format.
- Malaysia time is `Asia/Kuala_Lumpur` (MYT, UTC+8).
- Ride detection is intentionally foreground-oriented and is only active during the Malaysian commute windows: 07:00 to 09:59 and 17:00 to 19:59.
- Google Maps is retained for Android. Its real station markers, route polyline, and real train markers must remain.
- A live train marker comes only from a recent `train_status` row with both `lat` and `lng`. Never create fake markers or timed animations.
- Ride History is for automatically detected rides. There is no manual `Add ride` feature.

## Scope and ownership

Modify only the files needed for these fixes. Expected Flutter areas are:

- `lib/core/`
- `lib/services/notification_service.dart`
- `lib/services/ride_detection_service.dart`
- `lib/modules/alerts/screens/leave_by_screen.dart`
- `lib/modules/alerts/screens/alerts_home_screen.dart`
- `lib/modules/alerts/screens/ride_detail_screen.dart` if needed
- `lib/modules/module1_explorer/screens/explorer_home_page.dart`
- `lib/modules/module1_explorer/screens/live_route_map.dart` only if required for selected-line reload or visible state
- `test/`
- `.gitignore`
- `android/secrets.properties.example`

Do not modify Supabase migrations, Edge Functions, pipeline code, `pubspec.yaml`, or the Google Maps package version for this task.

## 1. Establish one Malaysia-time rule

Create a small shared utility in `lib/core/` for Malaysia time. It must:

1. Use the existing `timezone` package and the IANA identifier `Asia/Kuala_Lumpur`.
2. Expose the Malaysia timezone location after timezone data has been initialized.
3. Convert a UTC `DateTime` to a Malaysia `TZDateTime` for display and scheduling.
4. Provide a testable commute-window check that returns true only for:
   - 07:00 inclusive to 10:00 exclusive MYT
   - 17:00 inclusive to 20:00 exclusive MYT

Keep this utility focused. Do not introduce a generic date framework, locale system, or clock abstraction.

Initialize timezone data before `runApp` so all later screens and services can safely use the Malaysia-time utility.

## 2. Fix Leave-By time display and reminder scheduling

### Flutter display

`LeaveByResult` must continue parsing the Edge Function timestamps normally. Do not change the server response or remove its `Z`/UTC meaning.

In `leave_by_screen.dart`, convert `result.leaveByTime` to Malaysia time before formatting its hour and minute. The visible value must represent the actual Malaysian departure time, not the UTC hour.

Example acceptance case:

- API value: `2026-09-08T23:00:00.000Z`
- Screen value: `07:00` on 09 Sep 2026 in Kuala Lumpur

### Notifications

After `tz_data.initializeTimeZones()`, explicitly set the notification library's local timezone to `Asia/Kuala_Lumpur`. When scheduling a Leave-By reminder, construct the `TZDateTime` with that same location.

Do not change Quick Mute behaviour. The current mute check and cancellation of already scheduled reminders must remain.

## 3. Keep ride detection accurate to MYT

Replace the device-local `DateTime.now()` commute-window check in `RideDetectionService` with the Malaysia-time utility.

Keep all existing behaviour unchanged:

- require a signed-in user and granted location permission;
- load stations through `StationRepository`;
- use the existing 150 m proximity threshold;
- treat the first station as the trip origin;
- log a trip only after arrival near a different station;
- discard an open trip older than three hours;
- remain foreground-oriented; do not add background location permissions, services, or persistent tracking.

This ensures a test device configured to another timezone does not change KTM commute hours.

## 4. Add Google Maps line selection

The Explore map currently forces Port Klang Line. Replace that hard-coded selection with a selected-line state value in `ExplorerHomePage`.

Requirements:

1. Build the available lines from the existing station data using `Station.lines`.
2. Select the first available line only as the initial default.
3. Show a compact, accessible Flutter dropdown immediately above the live map. It must display the active line and allow the user to choose every available line.
4. Filter map stations with an exact match against `station.lines.contains(selectedLine)`. Do not use the current text-contains Port Klang fallback.
5. Pass the selected line and its filtered stations to `LiveRouteMap` and the full-map page.
6. Selecting a line must update the station markers, route polyline, camera fit, and the request to `get-latest-train-status?line=<selectedLine>`.
7. Preserve the existing map loading, error, and no-live-trains states. A line with no train positions must still show stations and the route, with the honest no-live-trains label.
8. If no stations are available, preserve the existing unavailable state and do not show a broken dropdown.

Use standard Material widgets only. A `DropdownButtonFormField` or equivalent single-selection widget is sufficient. Do not add tabs, separate map screens per line, a map-provider abstraction, or extra network calls.

## 5. Configure Android Google Maps without committing a secret

The current Gradle configuration reads `MAPS_API_KEY` from `android/secrets.properties`; that local file is absent.

1. Add `android/secrets.properties` to `.gitignore` if it is not already ignored.
2. Add a tracked `android/secrets.properties.example` containing exactly this placeholder:

```properties
MAPS_API_KEY=replace-with-your-android-maps-api-key
```

3. Do not create or commit a real API key.
4. Document in the final report that the developer must copy the example to `android/secrets.properties`, insert a restricted key, and enable Maps SDK for Android in the matching Google Cloud project.

The Android build must continue to use the existing manifest placeholder. Do not put a key in `AndroidManifest.xml`, Dart code, Gradle source, screenshots, or documentation.

## 6. Add lightweight Ride History details

Make an existing Ride History card tappable. Open a simple details screen or bottom sheet using the already loaded `RideLog`; do not add a backend endpoint.

Display only data that is already available:

- origin station;
- destination station when present;
- detected date and time in MYT;
- duration when present;
- line when present;
- a clear `Automatically detected` label.

If a field is unavailable, show a clear unavailable label rather than inventing a value. Do not add a manual ride form, edit action, delete action, or per-ride delay lookup in this task.

## 7. Verification

Run and report only meaningful checks:

1. `flutter analyze`
2. `flutter test`
3. Unit tests for Malaysia-time conversion and the four commute-window boundaries:
   - 06:59 MYT: false
   - 07:00 MYT: true
   - 09:59 MYT: true
   - 10:00 MYT: false
   - 16:59 MYT: false
   - 17:00 MYT: true
   - 19:59 MYT: true
   - 20:00 MYT: false
4. Widget test that changing the selected line sends the selected line and its matching stations to the map widget.
5. Android emulator or device check after the developer configures a valid Maps key:
   - map tiles load;
   - selecting a different line changes the route and markers;
   - a line with no live positions has no fake train marker;
   - Leave-By displays Malaysia time correctly.

## Definition of done

- Leave-By never displays UTC as Malaysian local time.
- Leave-By scheduling uses `Asia/Kuala_Lumpur`.
- Ride detection evaluates its existing commute windows in MYT.
- The user can select any available line in the Explore map.
- Android Google Maps can be configured securely without committing a key.
- Ride History has a read-only details view and remains GPS-detected only.
- No new dependencies, schema, Edge Functions, manual rides, fake live data, or background tracking are introduced.
