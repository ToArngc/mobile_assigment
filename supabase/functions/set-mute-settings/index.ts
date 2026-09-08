// POST /set-mute-settings
// Body: { muted_until: string | null }  ("YYYY-MM-DD" date, or null to clear)
// Upserts mute_settings for the caller.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { requireUser } from "../_shared/auth.ts";

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

  let body: { muted_until?: string | null };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }

  const { data, error } = await supabase
    .from("mute_settings")
    .upsert({
    user_id: userId,
      muted_until: body.muted_until ?? null,
      updated_at: new Date().toISOString(),
    })
    .select()
    .single();

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});
