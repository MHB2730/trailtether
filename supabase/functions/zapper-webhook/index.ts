// ============================================================================
// zapper-webhook — Hilltrek Edge Function
// ----------------------------------------------------------------------------
// Receives Zapper's payment notifications (Webhook Notification Model 1.3.0)
// and authoritatively updates the order status.
//
// The webhook URL must be registered with Zapper by emailing support@zapper.com
// (per their docs — there's no self-service portal for this yet).
//
// IMPORTANT: verify_jwt MUST be false. Zapper doesn't send a Supabase JWT;
// the HMAC signature on the request IS the auth.
//
// Required env vars:
//   ZAPPER_WEBHOOK_SECRET — signing secret from Merchant Portal
//
// SIGNATURE SCHEME — UNCONFIRMED. Defensive multi-format verification:
//   - Header:    X-Zapper-Signature (also tries Zapper-Signature, X-Signature)
//   - Algorithm: HMAC-SHA256 of raw request body
//   - Encoding:  hex or base64 (optional sha256= prefix)
// Once verified against a real delivery, narrow to the single correct form.
// ============================================================================

// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ZAPPER_WEBHOOK_SECRET = Deno.env.get("ZAPPER_WEBHOOK_SECRET") ?? "";

const STATUS_SUCCESS = 1;
const STATUS_FAILED  = 2;

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });

  const rawBody  = await req.text();
  const sourceIp = req.headers.get("cf-connecting-ip") ??
                   req.headers.get("x-forwarded-for") ?? "";

  let payload: any;
  try { payload = JSON.parse(rawBody); }
  catch { payload = { raw: rawBody, _parseError: true }; }

  const externalRef    = String(payload?.invoiceExternalReference ?? "");
  const invoiceRef     = String(payload?.invoiceReference ?? "");
  const invoicedAmount = Number(payload?.invoicedAmount ?? 0);
  const status         = Number(payload?.status ?? 0);
  const paymentRef     = String(payload?.paymentReference ?? "");
  const paymentDate    = String(payload?.paymentUTCDate ?? "");

  console.log(`[zapper-webhook] received ext=${externalRef} inv=${invoiceRef} status=${status}`);

  const signatureValid = await verifyZapperSignature(req.headers, rawBody);
  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  await admin.from("site_payment_events").insert({
    order_id:        externalRef || null,
    provider:        "zapper",
    payload:         payload,
    signature_valid: signatureValid,
    validate_ok:     true,
    ip_address:      sourceIp || null,
  });

  if (!signatureValid) {
    console.warn(`[zapper-webhook] REJECT — bad/missing signature for ext=${externalRef}`);
    return new Response("invalid signature", { status: 400 });
  }

  if (!externalRef) {
    console.warn(`[zapper-webhook] REJECT — missing invoiceExternalReference`);
    return new Response("missing externalReference", { status: 400 });
  }

  const { data: order, error: oErr } = await admin
    .from("site_orders")
    .select("*")
    .eq("id", externalRef)
    .maybeSingle();
  if (oErr)   return new Response("db error", { status: 500 });
  if (!order) return new Response("order not found", { status: 404 });

  if (invoicedAmount !== Number(order.total_cents)) {
    console.warn(`[zapper-webhook] REJECT — amount mismatch ${order.order_number}: expected ${order.total_cents}, got ${invoicedAmount}`);
    return new Response("amount mismatch", { status: 400 });
  }

  if (order.status === "paid" && order.payment_provider_ref === invoiceRef && paymentRef) {
    console.log(`[zapper-webhook] already paid (idempotent) — ${order.order_number}`);
    return new Response("ok (already finalised)", { status: 200 });
  }

  let newStatus    = order.status;
  let setCompleted = false;
  if (status === STATUS_SUCCESS) {
    newStatus    = "paid";
    setCompleted = true;
  } else if (status === STATUS_FAILED) {
    if (order.status === "pending") newStatus = "cancelled";
  } else {
    console.log(`[zapper-webhook] unknown status code: ${status}`);
  }

  const updates: any = {
    status:               newStatus,
    payment_provider:     "zapper",
    payment_provider_ref: invoiceRef || order.payment_provider_ref,
  };
  if (setCompleted) {
    updates.payment_completed_at =
      paymentDate ? new Date(paymentDate).toISOString() : new Date().toISOString();
  }

  const { error: uErr } = await admin
    .from("site_orders")
    .update(updates)
    .eq("id", externalRef);
  if (uErr) {
    console.error(`[zapper-webhook] order update failed:`, uErr);
    return new Response("db update error", { status: 500 });
  }

  console.log(`[zapper-webhook] OK — ${order.order_number} → ${newStatus}`);
  return new Response("ok", { status: 200 });
});

async function verifyZapperSignature(headers: Headers, body: string): Promise<boolean> {
  if (!ZAPPER_WEBHOOK_SECRET) {
    console.error("[zapper-webhook] ZAPPER_WEBHOOK_SECRET not set — failing closed");
    return false;
  }
  const candidateHeaders = ["x-zapper-signature", "zapper-signature", "x-signature", "signature"];
  let providedSig = "";
  for (const h of candidateHeaders) {
    const v = headers.get(h);
    if (v) { providedSig = v.trim(); break; }
  }
  if (!providedSig) return false;
  const cleanedSig = providedSig.replace(/^sha256=/i, "");
  const expectedHex    = await hmacSha256(ZAPPER_WEBHOOK_SECRET, body, "hex");
  const expectedBase64 = await hmacSha256(ZAPPER_WEBHOOK_SECRET, body, "base64");
  return (
    timingSafeEqual(cleanedSig, expectedHex) ||
    timingSafeEqual(cleanedSig, expectedBase64)
  );
}

async function hmacSha256(secret: string, data: string, encoding: "hex" | "base64"): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(data));
  const bytes = new Uint8Array(sig);
  if (encoding === "hex") {
    let out = "";
    for (let i = 0; i < bytes.length; i++) {
      out += bytes[i].toString(16).padStart(2, "0");
    }
    return out;
  }
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}
