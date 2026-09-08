



import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { requireUser } from "../_shared/auth.ts";

interface Body {
  station_id?: string;
  delay_minutes?: number | null;
  destination_station_id?: string | null;
  duration_minutes?: number | null;
}

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const supabase = createAdminClient();
  let userId: string;
  try {
    userId = await requireUser(req, supabase);
  } catch (error) {
    if (error instanceof Response) return error;
    return errorResponse("Unable to verify session", 401);
  }

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }

  if (!body.station_id) return errorResponse("station_id is required", 400);

  const { data, error } = await supabase
    .from("ride_logs")
    .insert({
      user_id: userId,
      station_id: body.station_id,
      detected_at: new Date().toISOString(),
      delay_minutes: body.delay_minutes ?? null,
      destination_station_id: body.destination_station_id ?? null,
      duration_minutes: body.duration_minutes ?? null,
    })
    .select()
    .single();

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data, 201);
});
