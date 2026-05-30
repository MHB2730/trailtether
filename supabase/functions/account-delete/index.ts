// ============================================================================
// account-delete — POPIA "right to erasure" for a Trailtether user.
// The caller's JWT (verify_jwt:true) identifies them; they must echo their own
// email as confirmation. We then service-role-delete every row of THEIR personal
// data + their storage objects + the auth user. Site/CMS content (site_hikes,
// site_products, trails, site_newsletters) is deliberately NOT touched — an admin
// deleting their account must not wipe the catalogue.
// Deployed to prod 2026-05-30 (verify_jwt:true).
// ============================================================================
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(o: unknown, s = 200) {
  return new Response(JSON.stringify(o), { status: s, headers: { ...cors, "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const authHeader = req.headers.get("Authorization") || "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "missing_token" }, 401);

  // Resolve the caller from their JWT.
  const userClient = createClient(url, anon, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: uErr } = await userClient.auth.getUser();
  if (uErr || !user) return json({ error: "invalid_token" }, 401);
  const uid = user.id;
  const email = (user.email || "").toLowerCase();

  // Confirmation: the body must echo the caller's own email.
  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch { /* empty */ }
  const confirm = String(body.confirm_email || "").trim().toLowerCase();
  if (!email || confirm !== email) return json({ error: "confirm_email_mismatch" }, 400);

  const admin = createClient(url, service, { auth: { persistSession: false } });
  const errors: string[] = [];
  const del = async (table: string, col: string, val: string) => {
    const { error } = await admin.from(table).delete().eq(col, val);
    if (error) errors.push(`${table}.${col}: ${error.message}`);
  };

  // --- Personal-data rows keyed by the user's id ---
  // Dependents first where an FK might otherwise block.
  await del("incident_events", "created_by", uid).catch(() => {}); // best-effort if column exists
  for (const [table, col] of [
    ["app_logs", "uid"], ["community_activities", "user_id"], ["emergency_contacts", "user_id"],
    ["gpx_uploads", "user_id"], ["hike_history", "user_id"], ["hike_plans", "created_by"],
    ["incidents", "created_by"], ["notification_settings", "user_id"], ["notifications", "user_id"],
    ["post_likes", "user_id"], ["post_comments", "author_id"], ["posts", "author_id"],
    ["recorded_trails", "user_id"], ["reviews", "user_id"], ["route_plans", "user_id"],
    ["safety_plans", "user_id"], ["team_member_locations", "uid"], ["team_member_track_points", "uid"],
    ["user_gpx_tracks", "user_id"], ["watch_devices", "user_id"], ["weather_locations", "user_id"],
    ["admin_users", "user_id"],
  ] as [string, string][]) {
    await del(table, col, uid);
  }

  // tether_pairings: either side.
  for (const col of ["hiker_uid", "watcher_uid"]) await del("tether_pairings", col, uid);

  // Teams: delete teams they OWN; remove them from member_uids of others.
  try {
    const { data: teams } = await admin.from("teams")
      .select("id, member_uids, created_by")
      .or(`created_by.eq.${uid},member_uids.cs.{${uid}}`);
    for (const t of teams || []) {
      if (t.created_by === uid) {
        await admin.from("teams").delete().eq("id", t.id);
      } else {
        await admin.from("teams")
          .update({ member_uids: (t.member_uids || []).filter((m: string) => m !== uid) })
          .eq("id", t.id);
      }
    }
  } catch (e) { errors.push(`teams: ${String(e)}`); }

  // Newsletter row keyed by email.
  if (email) {
    const { error } = await admin.from("site_subscribers").delete().ilike("email", email);
    if (error) errors.push(`site_subscribers: ${error.message}`);
  }

  // --- Storage objects under <uid>/ in every user bucket ---
  for (const bucket of ["recorded-trails", "gpx_uploads", "incident-photos", "profile-photos", "avatars", "gpx-files"]) {
    try {
      const { data: files } = await admin.storage.from(bucket).list(uid, { limit: 1000 });
      if (files && files.length) {
        const paths = files.map((f) => `${uid}/${f.name}`);
        const { error } = await admin.storage.from(bucket).remove(paths);
        if (error) errors.push(`storage ${bucket}: ${error.message}`);
      }
    } catch (e) { errors.push(`storage ${bucket}: ${String(e)}`); }
  }

  // --- Finally, the auth user itself ---
  const { error: authErr } = await admin.auth.admin.deleteUser(uid);
  if (authErr) {
    errors.push(`auth.deleteUser: ${authErr.message}`);
    // Auth user still exists — surface failure so the client doesn't claim success.
    return json({ ok: false, errors }, 500);
  }

  return json({ ok: true, deleted_user: uid, errors });
});
