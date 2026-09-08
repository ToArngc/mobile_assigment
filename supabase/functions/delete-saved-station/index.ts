// DELETE /delete-saved-station
// Body or query param: { id: string }
// Deletes one saved_stations row, only if owned by the caller.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { requireUser } from "../_shared/auth.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "DELETE") return errorResponse("Method not allowed", 405);

  const supabase = createAdminClient();
  let userId: string;
  try {
    userId = await requireUser(req, supabase);
  } catch (error) {
    if (error instanceof Response) return error;
    return errorResponse("Unable to verify session", 401);
  }

  const url = new URL(req.url);
  let id = url.searchParams.get("id");
  if (!id) {
    try {
      const body = await req.json();
      id = body?.id ?? null;
    } catch {
      // no body — fall through to the missing-id check below
    }
  }

  if (!id) return errorResponse("id is required", 400);

  const { data, error } = await supabase
    .from("saved_stations")
    .delete()
    .eq("id", id)
    .eq("user_id", userId)
    .select();

  if (error) return errorResponse(error.message, 500);
  if (!data || data.length === 0) return errorResponse("Saved station not found", 404);

  return jsonResponse({ success: true });
});
