// POST /upsert-saved-station
// Body: { id?, station_id, alert_delay_threshold?, quiet_hours_start?,
//         quiet_hours_end?, active_days?, enabled? }
// user_id is always forced to the caller server-side, regardless of body.
//
// Deliberately NOT a blind `.upsert()`: if the body includes an id, we
// verify it belongs to the caller before updating it. Since RLS is
// disabled, a raw upsert keyed on a client-supplied id would let any
// authenticated caller hijack another user's row by re-pointing its
// user_id at themselves. If id is supplied but not owned, this returns 404
// instead of silently taking over someone else's alert rule.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { requireUser } from "../_shared/auth.ts";

interface Body {
  id?: string;
  station_id?: string;
  alert_delay_threshold?: number | null;
  quiet_hours_start?: string | null;
  quiet_hours_end?: string | null;
  active_days?: string[] | null;
  enabled?: boolean;
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

  const fields = {
    station_id: body.station_id,
    alert_delay_threshold: body.alert_delay_threshold ?? null,
    quiet_hours_start: body.quiet_hours_start ?? null,
    quiet_hours_end: body.quiet_hours_end ?? null,
    active_days: body.active_days ?? null,
    enabled: body.enabled ?? true,
  };

  if (body.id) {
    const { data, error } = await supabase
      .from("saved_stations")
      .update(fields)
      .eq("id", body.id)
      .eq("user_id", userId)
      .select()
      .maybeSingle();

    if (error) return errorResponse(error.message, 500);
    if (!data) return errorResponse("Saved station not found", 404);
    return jsonResponse(data);
  }

  const { data, error } = await supabase
    .from("saved_stations")
    .insert({ ...fields, user_id: userId })
    .select()
    .single();

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data, 201);
});
