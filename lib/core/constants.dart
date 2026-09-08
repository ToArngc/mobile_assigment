/// Project-wide canonical values (design doc §4.2).
///
/// A train is "on time" if it arrived within this many minutes of its
/// scheduled time. This is the single source of truth for the Flutter
/// side — no module may hardcode its own value. The server-side
/// equivalent is ON_TIME_THRESHOLD_MINUTES in
/// supabase/functions/_shared/reliability.ts; change both together.
const int onTimeThresholdMinutes = 5;
