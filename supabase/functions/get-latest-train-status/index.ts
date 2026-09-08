// GET /get-latest-train-status?station_id=<uuid>
//   Public. The most recent train_status row for one station, or null.
//   Module 4's delay alerts depend on this exact shape — unchanged.
//
// GET /get-latest-train-status?line=<line>
//   Public. The most recent train_status row per station on that line, as
//   an array. Backs Module 1's live schematic.
//
// Exactly one of the two params must be supplied.
//
// The line variant is bounded to the last LIVE_WINDOW_MINUTES so "latest"
// means "currently running" rather than "whatever was last seen days
// ago". A line with no recent readings must come back empty, so the
// caller can say so honestly instead of drawing a stale train. Deduping
// to one row per station happens here rather than in SQL because the
// window is small enough that the row count is trivial.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";

const LIVE_WINDOW_MINUTES = 120;

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const url = new URL(req.url);
  const stationId = url.searchParams.get("station_id");
  const line = url.searchParams.get("line");

  if (stationId && line) {
    return errorResponse("Supply either station_id or line, not both", 400);
  }
  if (!stationId && !line) {
    return errorResponse("station_id or line query param is required", 400);
  }

  const supabase = createAdminClient();

  if (stationId) {
    const { data, error } = await supabase
      .from("train_status")
      .select()
      .eq("station_id", stationId)
      .order("recorded_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) return errorResponse(error.message, 500);
    return jsonResponse(data);
  }

  const since = new Date(
    Date.now() - LIVE_WINDOW_MINUTES * 60 * 1000,
  ).toISOString();

  const { data, error } = await supabase
    .from("train_status")
    .select()
    .eq("line", line)
    .gte("recorded_at", since)
    .order("recorded_at", { ascending: false });

  if (error) return errorResponse(error.message, 500);

  const seen = new Set<string>();
  const latestPerStation = [];
  for (const row of data ?? []) {
    if (!row.station_id || seen.has(row.station_id)) continue;
    seen.add(row.station_id);
    latestPerStation.push(row);
  }

  // An unknown line is an empty array, not an error — the caller cannot
  // tell a typo from a quiet line and should render "no live trains"
  // either way.
  return jsonResponse(latestPerStation);
});
