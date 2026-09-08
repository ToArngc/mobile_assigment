// POST /set-mute-settings
// Body: { muted_until: string | null }  ("YYYY-MM-DD" date, or null to clear)
// Upserts mute_settings for the caller.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { getAuthenticatedUser } from "../_shared/auth.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const supabase = createAdminClient();
  const authResult = await getAuthenticatedUser(req, supabase);
  if ("error" in authResult) return authResult.error;
  const { user } = authResult;

  let body: { muted_until?: string | null };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }

  const { data, error } = await supabase
    .from("mute_settings")
    .upsert({
      user_id: user.id,
      muted_until: body.muted_until ?? null,
      updated_at: new Date().toISOString(),
    })
    .select()
    .single();

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});
