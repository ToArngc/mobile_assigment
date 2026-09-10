import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { requireUser } from "../_shared/auth.ts";

interface Body {
  id?: string;
  origin_station_id?: string;
  destination_station_id?: string;
  walking_minutes?: number;
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

  if (!body.origin_station_id) {
    return errorResponse("origin_station_id is required", 400);
  }

  const walkingMinutes = body.walking_minutes;
  if (walkingMinutes !== null && walkingMinutes !== undefined) {
    if (!Number.isInteger(walkingMinutes) || walkingMinutes < 1 || walkingMinutes > 120) {
      return errorResponse(
        "walking_minutes must be a whole number between 1 and 120",
        400,
      );
    }
  }

  const fields = {
    origin_station_id: body.origin_station_id,
    destination_station_id: body.destination_station_id ?? null,
    walking_minutes: body.walking_minutes ?? 10,
  };

  if (body.id) {
    const { data, error } = await supabase
      .from("saved_routes")
      .update(fields)
      .eq("id", body.id)
      .eq("user_id", userId)
      .select()
      .maybeSingle();

    if (error) return errorResponse(error.message, 500);
    if (!data) return errorResponse("Saved route not found", 404);
    return jsonResponse(data);
  }

  const { data, error } = await supabase
    .from("saved_routes")
    .insert({ ...fields, user_id: userId })
    .select()
    .single();

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data, 201);
});
