// ============================================================================
// newsletter-send  —  Hilltrek admin newsletter blaster
// ----------------------------------------------------------------------------
// Called by the admin SPA (hilltrek-admin/app.js:sendBlast) when an admin
// clicks "Send test" or "Send live" in the newsletter editor.
//
// Flow:
//   1. Verify the caller is signed in AND public.is_admin() → 403 otherwise.
//   2. Load site_newsletters[newsletter_id].
//   3. Resolve recipients:
//        mode='test'  → just the calling admin's auth email
//        mode='live'  → site_subscribers matching segment_filter (same
//                       rules as the newsletter_segment_count RPC):
//                         unsubscribed_at is null
//                         AND (not confirmed_only OR confirmed_at not null)
//                         AND (source IS NULL OR source = filter.source)
//                         AND (tags IS NULL OR tags && filter.tags)
//   4. For each recipient:
//        - Insert site_newsletter_sends row → get sid (bigint)
//        - Rewrite <a href> links in body_html through newsletter-track-click
//        - Append unsubscribe footer (uses each subscriber's
//          unsubscribe_token — for the test path we just point at the
//          generic /subscribe/unsubscribe/ form)
//        - SMTP send via the same denomailer client used by
//          subscriber-send-confirmation
//        - Stamp sent_at on success, or .error on failure
//   5. For mode='live', update site_newsletters: status='sent', sent_at,
//      sent_count, failed_count, recipient_count.
//
// Returns { ok, sent, failed, errors[] }. The admin SPA reads `sent` and
// `failed` to display "Done. Sent: X, failed: Y" in the editor.
//
// Required env vars (already set for subscriber-send-confirmation):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY
//   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS
// ============================================================================

// deno-lint-ignore-file no-explicit-any
import { createClient } from "jsr:@supabase/supabase-js@2";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

const SUPABASE_URL          = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_ANON         = Deno.env.get("SUPABASE_ANON_KEY")!;
const SMTP_HOST = Deno.env.get("SMTP_HOST")!;
const SMTP_PORT = parseInt(Deno.env.get("SMTP_PORT") || "465");
const SMTP_USER = Deno.env.get("SMTP_USER")!;
const SMTP_PASS = Deno.env.get("SMTP_PASS")!;
const FROM_NAME = "Hilltrek";
const FROM_EMAIL = SMTP_USER;
const SITE_URL = "https://hilltrek.co.za";

const ALLOWED_ORIGINS = [
  "https://hilltrek.co.za",
  "https://www.hilltrek.co.za",
  "https://admin.hilltrek.co.za",
];

function corsHeaders(origin: string | null): Record<string, string> {
  const allow = origin && ALLOWED_ORIGINS.includes(origin)
    ? origin
    : ALLOWED_ORIGINS[0];
  return {
    "Access-Control-Allow-Origin":  allow,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
    "Content-Type": "application/json",
  };
}

function jsonResp(cors: Record<string, string>, status: number, body: any): Response {
  return new Response(JSON.stringify(body), { status, headers: cors });
}

// Build the per-recipient HTML/text body. Rewrites <a href> through the
// click-tracking endpoint (which 302-redirects after recording the click)
// and stamps an unsubscribe footer. Plain text gets a trailing footer
// only — no link rewriting (too much trouble for the small benefit).
function decorateBody(args: {
  newsletterId: string;
  sendId: number;
  html: string;
  text: string;
  unsubscribeToken: string | null;
}): { html: string; text: string } {
  const { newsletterId, sendId, html, text, unsubscribeToken } = args;
  const trackBase = `${SUPABASE_URL}/functions/v1/newsletter-track-click?nid=${newsletterId}&sid=${sendId}&url=`;

  // Rewrite href targets. Already-tracked URLs (admin authored a direct
  // newsletter-track-click link by mistake) are left alone.
  const rewrittenHtml = html.replace(
    /href=("|')(https?:\/\/[^"']+)\1/gi,
    (match, quote, href) => {
      if (href.startsWith(trackBase)) return match;
      return `href=${quote}${trackBase}${encodeURIComponent(href)}${quote}`;
    },
  );

  const unsubUrl = unsubscribeToken
    ? `${SITE_URL}/subscribe/unsubscribe/?token=${unsubscribeToken}`
    : `${SITE_URL}/subscribe/unsubscribe/`;

  const htmlFooter = `
    <hr style="border:none;border-top:1px solid #eee;margin:32px 0 18px;">
    <p style="margin:0;font-size:11px;color:#999;text-align:center;">
      Hilltrek (Pty) Ltd · Drakensberg, South Africa<br>
      <a href="${unsubUrl}" style="color:#999;text-decoration:underline;">Unsubscribe</a>
    </p>`;

  const textFooter = `\n\n—\nHilltrek (Pty) Ltd · Drakensberg, South Africa\nUnsubscribe: ${unsubUrl}\n`;

  return {
    html: rewrittenHtml + htmlFooter,
    text: text + textFooter,
  };
}

Deno.serve(async (req) => {
  const cors = corsHeaders(req.headers.get("origin"));
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST")    return jsonResp(cors, 405, { ok: false, error: "POST only" });

  // 1. Auth — JWT user + is_admin gate. The function is admin-only.
  const authHeader = req.headers.get("Authorization") || "";
  if (!authHeader.startsWith("Bearer ")) {
    return jsonResp(cors, 401, { ok: false, error: "missing_auth" });
  }
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) {
    return jsonResp(cors, 401, { ok: false, error: "invalid_session" });
  }
  const callerEmail = userData.user.email ?? "";
  // Cheap admin check — RLS already gates the read but is_admin() is
  // explicit and matches the pattern other admin RPCs use.
  const { data: isAdmin, error: adminErr } = await userClient.rpc("is_admin");
  if (adminErr || !isAdmin) {
    return jsonResp(cors, 403, { ok: false, error: "not_admin" });
  }

  // 2. Parse body.
  let body: any;
  try { body = await req.json(); }
  catch { return jsonResp(cors, 400, { ok: false, error: "invalid_json" }); }
  const newsletterId = String(body?.newsletter_id ?? "").trim();
  const mode = body?.mode === "live" ? "live" : "test";
  if (!newsletterId) {
    return jsonResp(cors, 400, { ok: false, error: "newsletter_id required" });
  }

  // 3. Load newsletter (service role — RLS would block anon reads here).
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);
  const { data: nl, error: nlErr } = await admin
    .from("site_newsletters")
    .select("id, subject, body_html, body_text, segment_filter, status")
    .eq("id", newsletterId)
    .maybeSingle();
  if (nlErr) return jsonResp(cors, 500, { ok: false, error: "load_failed", detail: nlErr.message });
  if (!nl)   return jsonResp(cors, 404, { ok: false, error: "newsletter_not_found" });

  // 4. Resolve recipients.
  type Recipient = {
    subscriber_id: string | null;
    email: string;
    unsubscribe_token: string | null;
  };
  const recipients: Recipient[] = [];

  if (mode === "test") {
    if (!callerEmail) {
      return jsonResp(cors, 400, { ok: false, error: "caller_email_missing" });
    }
    recipients.push({
      subscriber_id: null,
      email: callerEmail,
      unsubscribe_token: null,
    });
  } else {
    // live — match the newsletter_segment_count RPC's WHERE clause.
    const filter = (nl.segment_filter ?? {}) as Record<string, any>;
    const confirmedOnly = filter.confirmed_only === false ? false : true;
    const source = typeof filter.source === "string" && filter.source ? filter.source : null;
    const tags = Array.isArray(filter.tags) && filter.tags.length > 0
      ? filter.tags.map((t: any) => String(t))
      : null;

    let q = admin
      .from("site_subscribers")
      .select("id, email, unsubscribe_token")
      .is("unsubscribed_at", null);
    if (confirmedOnly) q = q.not("confirmed_at", "is", null);
    if (source)        q = q.eq("source", source);
    if (tags)          q = q.overlaps("tags", tags);

    const { data: subs, error: subErr } = await q;
    if (subErr) {
      return jsonResp(cors, 500, { ok: false, error: "recipient_query_failed", detail: subErr.message });
    }
    for (const s of (subs ?? [])) {
      recipients.push({
        subscriber_id: (s as any).id,
        email: (s as any).email,
        unsubscribe_token: (s as any).unsubscribe_token ?? null,
      });
    }
    if (recipients.length === 0) {
      return jsonResp(cors, 200, {
        ok: true, sent: 0, failed: 0, errors: ["segment matched zero subscribers"],
      });
    }
  }

  // 5. SMTP loop. One connection reused across all sends — the recipient
  //    list is small (hundreds at most for Hilltrek's current volume). If
  //    we ever blow up to thousands, swap to batching.
  const smtp = new SMTPClient({
    connection: {
      hostname: SMTP_HOST,
      port: SMTP_PORT,
      tls: true,
      auth: { username: SMTP_USER, password: SMTP_PASS },
    },
  });

  let sent = 0;
  let failed = 0;
  const errors: string[] = [];

  for (const r of recipients) {
    // 5a. Stamp the send row first so click-tracking has a sid even if
    //     the SMTP step throws partway. For test mode we skip the row —
    //     site_newsletter_sends is for tracking blast performance, and a
    //     test from the admin shouldn't show up in those metrics.
    let sendId: number | null = null;
    if (mode === "live") {
      const { data: row, error: insErr } = await admin
        .from("site_newsletter_sends")
        .insert({
          newsletter_id: nl.id,
          subscriber_id: r.subscriber_id,
          email: r.email,
        })
        .select("id")
        .single();
      if (insErr || !row) {
        failed++;
        errors.push(`${r.email}: send-row insert failed (${insErr?.message ?? "no row returned"})`);
        continue;
      }
      sendId = (row as any).id as number;
    }

    // 5b. Decorate body. For test mode we skip click tracking entirely
    //     (no sid → no /newsletter-track-click rewrite). Test recipients
    //     get plain links.
    const decorated = sendId == null
      ? {
          html: nl.body_html + `<hr><p style="font-size:11px;color:#999;">[TEST · ${nl.subject}] · This was a test send to ${r.email}.</p>`,
          text: (nl.body_text ?? "") + `\n\n[TEST · ${nl.subject}] · This was a test send to ${r.email}.`,
        }
      : decorateBody({
          newsletterId: nl.id,
          sendId,
          html: nl.body_html,
          text: nl.body_text ?? "",
          unsubscribeToken: r.unsubscribe_token,
        });

    // 5c. Send.
    try {
      await smtp.send({
        from: `${FROM_NAME} <${FROM_EMAIL}>`,
        to: r.email,
        subject: nl.subject,
        content: decorated.text,
        html: decorated.html,
      });
      sent++;
      if (sendId != null) {
        await admin
          .from("site_newsletter_sends")
          .update({ sent_at: new Date().toISOString() })
          .eq("id", sendId);
      }
    } catch (e: any) {
      failed++;
      const msg = String(e?.message ?? e).slice(0, 300);
      errors.push(`${r.email}: ${msg}`);
      if (sendId != null) {
        await admin
          .from("site_newsletter_sends")
          .update({ error: msg })
          .eq("id", sendId);
      }
    }
  }

  try { await smtp.close(); } catch (_) { /* best-effort */ }

  // 6. For live blasts, finalize the newsletter row so the admin sees
  //    sent_at + counts on the detail page.
  if (mode === "live") {
    await admin
      .from("site_newsletters")
      .update({
        status: "sent",
        sent_at: new Date().toISOString(),
        sent_count: sent,
        failed_count: failed,
        recipient_count: recipients.length,
      })
      .eq("id", nl.id);
  }

  return jsonResp(cors, 200, {
    ok: true,
    mode,
    sent,
    failed,
    errors: errors.slice(0, 20), // cap to keep payloads sane on big sends
  });
});
