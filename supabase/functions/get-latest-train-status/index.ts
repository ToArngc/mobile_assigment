// GET /get-latest-train-status?station_id=<uuid>
// Public — returns the most recent train_status row for a station, or null.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const url = new URL(req.url);
  const stationId = url.searchParams.get("station_id");
  if (!stationId) return errorResponse("station_id query param is required", 400);

  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("train_status")
    .select()
    .eq("station_id", stationId)
    .order("recorded_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});
