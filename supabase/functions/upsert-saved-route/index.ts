// POST /upsert-saved-route
// Body: { id?, origin_station_id, destination_station_id, walking_minutes? }
// user_id is always forced to the caller server-side.
//
// Same reasoning as upsert-saved-station: an id is ownership-checked with
// an UPDATE, never blindly upserted, so a caller can't repoint someone
// else's saved route at themselves.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { getAuthenticatedUser } from "../_shared/auth.ts";

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
  const authResult = await getAuthenticatedUser(req, supabase);
  if ("error" in authResult) return authResult.error;
  const { user } = authResult;

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }

  if (!body.origin_station_id || !body.destination_station_id) {
    return errorResponse("origin_station_id and destination_station_id are required", 400);
  }

  const fields = {
    origin_station_id: body.origin_station_id,
    destination_station_id: body.destination_station_id,
    walking_minutes: body.walking_minutes ?? 10,
  };

  if (body.id) {
    const { data, error } = await supabase
      .from("saved_routes")
      .update(fields)
      .eq("id", body.id)
      .eq("user_id", user.id)
      .select()
      .maybeSingle();

    if (error) return errorResponse(error.message, 500);
    if (!data) return errorResponse("Saved route not found", 404);
    return jsonResponse(data);
  }

  const { data, error } = await supabase
    .from("saved_routes")
    .insert({ ...fields, user_id: user.id })
    .select()
    .single();

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data, 201);
});
