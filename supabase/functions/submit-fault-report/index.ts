import { handleOptions, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-admin.ts";
import { requireUser } from "../_shared/auth.ts";

const VALID_ISSUE_TYPES = [
  "lift_broken",
  "escalator_broken",
  "overcrowding",
  "cleanliness",
  "safety_hazard",
];

const MAX_PHOTO_BYTES = 5 * 1024 * 1024;
const ALLOWED_PHOTO_TYPES = ["image/jpeg", "image/png", "image/webp"];
const MAX_DESCRIPTION_LENGTH = 500;

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function safeFileName(name: string): string {
  const cleaned = name.replace(/[^A-Za-z0-9._-]/g, "_");
  return cleaned.slice(-80) || "photo";
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

  const contentType = req.headers.get("content-type") ?? "";
  let stationId: unknown;
  let issueType: unknown;
  let description: unknown;
  let latRaw: unknown;
  let lngRaw: unknown;
  let photo: unknown = null;

  if (contentType.includes("multipart/form-data")) {
    let form: FormData;
    try {
      form = await req.formData();
    } catch {
      return errorResponse("Invalid multipart/form-data body", 400);
    }
    stationId = form.get("station_id");
    issueType = form.get("issue_type");
    description = form.get("description");
    latRaw = form.get("lat");
    lngRaw = form.get("lng");
    photo = form.get("photo");
  } else if (contentType.includes("application/json")) {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return errorResponse("Invalid JSON body", 400);
    }
    stationId = body.station_id;
    issueType = body.issue_type;
    description = body.description;
    latRaw = body.lat;
    lngRaw = body.lng;
  } else {
    return errorResponse("Content-Type must be application/json or multipart/form-data", 400);
  }

  if (typeof stationId !== "string" || !stationId) {
    return errorResponse("station_id is required", 400);
  }
  if (!UUID_PATTERN.test(stationId)) {
    return errorResponse("station_id must be a valid uuid", 400);
  }

  if (description !== null && description !== undefined && description !== "") {
    if (typeof description !== "string") {
      return errorResponse("description must be a string", 400);
    }
    if (description.length > MAX_DESCRIPTION_LENGTH) {
      return errorResponse(
        `description must be ${MAX_DESCRIPTION_LENGTH} characters or fewer`,
        400,
      );
    }
  }

  const issueTypes = typeof issueType === "string"
    ? issueType.split(",").map((t) => t.trim()).filter(Boolean)
    : [];
  if (issueTypes.length === 0) {
    return errorResponse("issue_type is required", 400);
  }
  if (issueTypes.some((t) => !VALID_ISSUE_TYPES.includes(t))) {
    return errorResponse(
      `issue_type must be one of: ${VALID_ISSUE_TYPES.join(", ")}`,
      400,
    );
  }

  const lat = latRaw !== null && latRaw !== undefined && latRaw !== "" ? Number(latRaw) : null;
  const lng = lngRaw !== null && lngRaw !== undefined && lngRaw !== "" ? Number(lngRaw) : null;
  if ((lat !== null && !Number.isFinite(lat)) || (lng !== null && !Number.isFinite(lng))) {
    return errorResponse("lat/lng must be numbers", 400);
  }

  let photoUrl: string | null = null;
  if (photo instanceof File) {
    if (photo.size > MAX_PHOTO_BYTES) {
      return errorResponse("Photo must be 5 MB or smaller", 400);
    }
    if (!ALLOWED_PHOTO_TYPES.includes(photo.type)) {
      return errorResponse(
        `Photo must be one of: ${ALLOWED_PHOTO_TYPES.join(", ")}`,
        400,
      );
    }

    const path = `${stationId}/${Date.now()}_${safeFileName(photo.name)}`;
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
    .insert(issueTypes.map((type) => ({
      user_id: userId,
      station_id: stationId,
      issue_type: type,
      description: typeof description === "string" ? description : null,
      photo_url: photoUrl,
      lat,
      lng,
      status: "open",
    })))
    .select();

  if (error) return errorResponse(error.message, 500);
  return jsonResponse(data, 201);
});
