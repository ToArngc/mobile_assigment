// GET /get-station-accessibility?station_id=<uuid>
//
// Public — the current accessibility picture for one station, read from
// the station_accessibility view (design doc §4.1), which keeps only the
// newest fault report per station + issue type.
//
// This closes a contract gap: §4.1 dropped stations.accessibility_features
// in favour of the view but never specified an endpoint to serve it, so
// Module 1 had nothing to read and accessibility rendered permanently
// blank. Reads the view rather than fault_reports directly so the
// "latest per issue" rule stays defined in exactly one place.
//
// No auth and no user_id scoping: a broken lift is public reference data,
// and the view exposes no reporter identity.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const url = new URL(req.url);
  const stationId = url.searchParams.get("station_id");

  if (!stationId) {
    return errorResponse("station_id query param is required", 400);
  }
  if (!UUID_PATTERN.test(stationId)) {
    return errorResponse("station_id must be a valid uuid", 400);
  }

  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("station_accessibility")
    .select("issue_type, status, created_at")
    .eq("station_id", stationId)
    .order("created_at", { ascending: false });

  if (error) return errorResponse(error.message, 500);

  // A station with no reports is a normal, good state — an empty array,
  // never a 404. The caller renders it as "no issues reported".
  return jsonResponse(data ?? []);
});
