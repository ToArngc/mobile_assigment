// POST /submit-fault-report
// Content-Type: multipart/form-data (chosen over base64-in-JSON: it's the
// natural fit for a real file upload and avoids ~33% base64 bloat for
// photo bytes over the wire).
//
// Fields: station_id, issue_type, description?, lat?, lng?, photo? (file)
//
// The client never gets direct write access to the report-photos bucket —
// this function uploads with the service-role client, gets the public URL,
// then inserts the fault_reports row. user_id is always forced to the caller.

import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { getAuthenticatedUser } from "../_shared/auth.ts";

const VALID_ISSUE_TYPES = [
  "lift_broken",
  "escalator_broken",
  "overcrowding",
  "cleanliness",
  "safety_hazard",
];

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const supabase = createAdminClient();
  const authResult = await getAuthenticatedUser(req, supabase);
  if ("error" in authResult) return authResult.error;
  const { user } = authResult;

  const contentType = req.headers.get("content-type") ?? "";
  if (!contentType.includes("multipart/form-data")) {
    return errorResponse("Content-Type must be multipart/form-data", 400);
  }

  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return errorResponse("Invalid multipart/form-data body", 400);
  }

  const stationId = form.get("station_id");
  const issueType = form.get("issue_type");
  const description = form.get("description");
  const latRaw = form.get("lat");
  const lngRaw = form.get("lng");
  const photo = form.get("photo");

  if (typeof stationId !== "string" || !stationId) {
    return errorResponse("station_id is required", 400);
  }
  if (typeof issueType !== "string" || !VALID_ISSUE_TYPES.includes(issueType)) {
    return errorResponse(
      `issue_type must be one of: ${VALID_ISSUE_TYPES.join(", ")}`,
      400,
    );
  }

  const lat = typeof latRaw === "string" && latRaw !== "" ? Number(latRaw) : null;
  const lng = typeof lngRaw === "string" && lngRaw !== "" ? Number(lngRaw) : null;
  if ((latRaw && Number.isNaN(lat)) || (lngRaw && Number.isNaN(lng))) {
    return errorResponse("lat/lng must be numbers", 400);
  }

  let photoUrl: string | null = null;
  if (photo instanceof File) {
    const path = `${stationId}/${Date.now()}_${photo.name}`;
    const bytes = new Uint8Array(await photo.arrayBuffer());

    const { error: uploadError } = await supabase.storage
      .from("report-photos")
      .upload(path, bytes, {
        contentType: photo.type || "application/octet-stream",
      });

    if (uploadError) return errorResponse(uploadError.message, 500);

    const { data: publicUrlData } = supabase.storage
      .from("report-photos")
      .getPublicUrl(path);
    photoUrl = publicUrlData.publicUrl;
  }

  const { data, error } = await supabase
    .from("fault_reports")
    .insert({
      user_id: user.id,
      station_id: stationId,
      issue_type: issueType,
      description: typeof description === "string" ? description : null,
      photo_url: photoUrl,
      lat,
      lng,
      status: "open",
    })
    .select()
    .single();

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data, 201);
});
