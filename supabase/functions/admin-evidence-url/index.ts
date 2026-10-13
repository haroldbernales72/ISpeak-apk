
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createRemoteJWKSet, jwtVerify } from "npm:jose@5.9.6";

const PROJECT_ID = "ispeak-um";
const BUCKET = "incident-evidence";
const MAX_BYTES = 5 * 1024 * 1024;

const firebaseKeys = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return respond({ error: "Method not allowed" }, 405);
  }

  try {
    const authorization = req.headers.get("Authorization") ?? "";
    const match = authorization.match(/^Bearer\s+(.+)$/i);

    if (!match) {
      return respond({ error: "Missing Firebase ID token" }, 401);
    }

    const { payload } = await jwtVerify(match[1], firebaseKeys, {
      issuer: `https://securetoken.google.com/${PROJECT_ID}`,
      audience: PROJECT_ID,
      algorithms: ["RS256"],
    });

    const uid = payload.sub;
    if (!uid) {
      return respond({ error: "Invalid Firebase user" }, 401);
    }

    const body = await req.json();
    const { storagePath, fileBase64, contentType } = body;

    if (
      typeof storagePath !== "string" ||
      typeof fileBase64 !== "string" ||
      typeof contentType !== "string"
    ) {
      return respond({ error: "Missing upload information" }, 400);
    }

    // Only allow files inside this user's folder.
    if (
      !storagePath.startsWith(`${uid}/`) ||
      storagePath.includes("..") ||
      storagePath.startsWith("/") ||
      storagePath.length > 500
    ) {
      return respond({ error: "Invalid storage path" }, 403);
    }

    if (!["image/jpeg", "image/png", "application/pdf"].includes(contentType)) {
      return respond({ error: "Unsupported file type" }, 400);
    }

    const base64 = fileBase64.replace(/^data:[^;]+;base64,/, "");
    const binary = atob(base64);

    if (binary.length === 0 || binary.length > MAX_BYTES) {
      return respond({ error: "File must be between 1 byte and 5 MB" }, 413);
    }

    const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      console.error("Missing Supabase server configuration");
      return respond({ error: "Server upload configuration is missing" }, 500);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);

    const { error } = await admin.storage
      .from(BUCKET)
      .upload(storagePath, bytes, {
        contentType,
        upsert: false,
      });

    if (error) {
      console.error("Storage upload failed:", error.message);
      return respond({ error: "Could not save evidence file" }, 500);
    }

    return respond({ success: true, storagePath });
  } catch (error) {
    console.error("Upload request failed:", error);
    return respond({ error: "Authentication failed or upload request was invalid" }, 401);
  }
});
