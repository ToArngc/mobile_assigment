import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { requireUser } from "../_shared/auth.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "PATCH") return errorResponse("Method not allowed", 405);

  const supabase = createAdminClient();
  let userId: string;
  try {
    userId = await requireUser(req, supabase);
  } catch (error) {
    if (error instanceof Response) return error;
    return errorResponse("Unable to verify session", 401);
  }

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
      .eq("user_id", userId)
    .select()
    .maybeSingle();

  if (error) return errorResponse(error.message, 500);
  if (!data) return errorResponse("Saved station not found", 404);

  return jsonResponse(data);
});
