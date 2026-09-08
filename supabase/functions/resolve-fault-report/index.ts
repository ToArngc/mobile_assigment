// PATCH /resolve-fault-report
// Body: { id: string }
// Marks one fault_reports row 'resolved'.
//
// Ownership: reports_repository.dart's markResolved (lines 112-116)
// already filters `.eq('id', reportId).eq('user_id', currentUserId)` —
// i.e. only the reporter can resolve their own report. That is NOT
// ambiguous (contrary to the task brief's caveat) and is reproduced here
// exactly: 404 if the report doesn't exist or isn't owned by the caller.

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

  let body: { id?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }

  if (!body.id) return errorResponse("id is required", 400);

  const { data, error } = await supabase
    .from("fault_reports")
    .update({ status: "resolved" })
    .eq("id", body.id)
    .eq("user_id", user.id)
    .select()
    .maybeSingle();

  if (error) return errorResponse(error.message, 500);
  if (!data) return errorResponse("Fault report not found", 404);

  return jsonResponse(data);
});
