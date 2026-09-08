// PATCH /toggle-saved-station
// Body: { id: string, enabled: boolean }
// Ownership check + update happen atomically in one filtered UPDATE, so
// there's no separate select-then-update race window. 404 if the row
// doesn't exist or isn't owned by the caller.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { getAuthenticatedUser } from "../_shared/auth.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "PATCH") return errorResponse("Method not allowed", 405);

  const supabase = createAdminClient();
  const authResult = await getAuthenticatedUser(req, supabase);
  if ("error" in authResult) return authResult.error;
  const { user } = authResult;

  let body: { id?: string; enabled?: boolean };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }

  if (!body.id || typeof body.enabled !== "boolean") {
    return errorResponse("id and enabled are required", 400);
  }

  const { data, error } = await supabase
    .from("saved_stations")
    .update({ enabled: body.enabled })
    .eq("id", body.id)
    .eq("user_id", user.id)
    .select()
    .maybeSingle();

  if (error) return errorResponse(error.message, 500);
  if (!data) return errorResponse("Saved station not found", 404);

  return jsonResponse(data);
});
