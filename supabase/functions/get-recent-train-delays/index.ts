




import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const url = new URL(req.url);
  const stationId = url.searchParams.get("station_id");
  const line = url.searchParams.get("line");
  const limitParam = url.searchParams.get("limit");
  const limit = limitParam ? parseInt(limitParam, 10) : 20;

  if (Number.isNaN(limit) || limit <= 0) {
    return errorResponse("limit must be a positive integer", 400);
  }

  const supabase = createAdminClient();
  let query = supabase.from("train_status").select();
  if (stationId) query = query.eq("station_id", stationId);
  if (line) query = query.eq("line", line);

  const { data, error } = await query.order("recorded_at", { ascending: false }).limit(limit);

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});
