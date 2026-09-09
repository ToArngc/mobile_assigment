


import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return errorResponse("Method not allowed", 405);

  const url = new URL(req.url);
  const q = url.searchParams.get("q");
  if (!q) return errorResponse("q query param is required", 400);






  const escaped = q.replace(/[\\%_]/g, (c) => `\\${c}`);

  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("stations")
    .select()
    .ilike("name", `%${escaped}%`)
    .order("name");

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data);
});
