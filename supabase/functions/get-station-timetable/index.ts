


import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";

const KL_OFFSET_MINUTES = 8 * 60;
const MAX_ENTRIES = 8;

function nowInKualaLumpur(): Date {
  const utcNow = new Date();
  return new Date(utcNow.getTime() + KL_OFFSET_MINUTES * 60 * 1000);
}

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const url = new URL(req.url);
  const stationId = url.searchParams.get("station_id");
  if (!stationId) return errorResponse("station_id query param is required", 400);

  const klNow = nowInKualaLumpur();
  const hh = klNow.getUTCHours().toString().padStart(2, "0");
  const mm = klNow.getUTCMinutes().toString().padStart(2, "0");
  const nowTimeString = `${hh}:${mm}:00`;

  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("timetable_entries")
    .select()
    .eq("station_id", stationId)
    .gte("scheduled_time", nowTimeString)
    .order("scheduled_time")
    .limit(MAX_ENTRIES);

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});
