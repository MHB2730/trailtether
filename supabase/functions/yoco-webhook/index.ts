// ============================================================================
// yoco-webhook — Hilltrek Edge Function
// ----------------------------------------------------------------------------
// Receives Yoco's Standard-Webhooks-format payment events server-to-server.
//
// AUTHORITATIVE source of payment status. The shopper-facing successUrl /
// cancelUrl can't be trusted (anyone can hit them). Yoco posts directly
// to this endpoint with an HMAC-SHA256 signature. We verify the signature,
// verify the timestamp window, verify the amount, and only then update
// the order.
//
// Standard Webhooks spec: https://www.standardwebhooks.com/
//
// Required env vars (Supabase Dashboard → Edge Functions → Secrets):
//   YOCO_WEBHOOK_SECRET  — set in Yoco dashboard when you create the
//                          webhook endpoint. Looks like "whsec_xxxxxxx".
//
// IMPORTANT: this function MUST have verify_jwt: false. Yoco doesn't send
// a Supabase JWT — the HMAC signature inside the payload IS the auth.
// ============================================================================

// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const YOCO_WEBHOOK_SECRET = Deno.env.get("YOCO_WEBHOOK_SECRET") ?? "";

const TIMESTAMP_TOLERANCE_MS = 5 * 60 * 1000;  // 5 minutes — replay protection

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });

  // Capture the raw body — Standard Webhooks signs the bytes-as-sent, not
  // a JSON.stringify'd re-encoding. Re-encoding could differ in whitespace
  // or key order and break verification.
  const rawBody    = await req.text();
  const webhookId  = req.headers.get("webhook-id")        ?? "";
  const webhookTs  = req.headers.get("webhook-timestamp") ?? "";
  const webhookSig = req.headers.get("webhook-signature") ?? "";
  const sourceIp   = req.headers.get("x-forwarded-for") ??
                     req.headers.get("cf-connecting-ip") ?? "";

  console.log(`[yoco-webhook] id=${webhookId} ts=${webhookTs}`);

  let payload: any;
  try { payload = JSON.parse(rawBody); }
  catch { payload = { raw: rawBody, _parseError: true }; }

  const eventType      = String(payload?.type ?? "");
  const yocoData       = payload?.payload ?? {};
  const orderId        = String(yocoData?.metadata?.order_id ?? "");
  const orderNumber    = String(yocoData?.metadata?.order_number ?? "");
  const yocoCheckoutId = String(yocoData?.id ?? "");
  const yocoAmount     = Number(yocoData?.amount ?? 0);

  // 1. Verify the signature. Bail (but log) if anything's off.
  const signatureValid = await verifyStandardWebhookSignature(
    YOCO_WEBHOOK_SECRET,
    webhookId,
    webhookTs,
    rawBody,
    webhookSig,
  );

  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  // 2. Log EVERY webhook (valid or not). Audit trail is gold when
  //    something goes wrong months later.
  await admin.from("site_payment_events").insert({
    order_id:        orderId || null,
    provider:        "yoco",
    payload:         payload,
    signature_valid: signatureValid,
    validate_ok:     true,  // Yoco doesn't have a separate validate endpoint
    ip_address:      sourceIp || null,
  });

  if (!signatureValid) {
    console.warn(`[yoco-webhook] REJECT — bad/missing signature for ${orderNumber}`);
    return new Response("invalid signature", { status: 400 });
  }

  if (!orderId) {
    console.warn(`[yoco-webhook] REJECT — missing metadata.order_id`);
    return new Response("missing order id", { status: 400 });
  }

  // 3. Look up the order, verify amount matches.
  const { data: order, error: oErr } = await admin
    .from("site_orders")
    .select("*")
    .eq("id", orderId)
    .maybeSingle();
  if (oErr)   return new Response("db error", { status: 500 });
  if (!order) return new Response("order not found", { status: 404 });

  if (yocoAmount !== Number(order.total_cents)) {
    console.warn(`[yoco-webhook] REJECT — amount mismatch for ${orderNumber}: expected ${order.total_cents}, got ${yocoAmount}`);
    return new Response("amount mismatch", { status: 400 });
  }

  // 4. Idempotency — if we've already finalised this with the same
  //    payment ref, ack the webhook but skip the update.
  if (order.status === "paid" && order.payment_provider_ref === yocoCheckoutId) {
    console.log(`[yoco-webhook] already paid (idempotent) — ${orderNumber}`);
    return new Response("ok (already finalised)", { status: 200 });
  }

  // 5. Map Yoco event → our status.
  let newStatus    = order.status;
  let setCompleted = false;
  switch (eventType) {
    case "payment.succeeded":
    case "payment.completed":
      newStatus    = "paid";
      setCompleted = true;
      break;
    case "payment.failed":
    case "payment.cancelled":
    case "payment.canceled":  // belt + suspenders for spelling variants
      if (order.status === "pending") newStatus = "cancelled";
      break;
    default:
      console.log(`[yoco-webhook] no-op event type: ${eventType}`);
  }

  const updates: any = {
    status:               newStatus,
    payment_provider:     "yoco",
    payment_provider_ref: yocoCheckoutId || order.payment_provider_ref,
  };
  if (setCompleted) updates.payment_completed_at = new Date().toISOString();

  const { error: uErr } = await admin
    .from("site_orders")
    .update(updates)
    .eq("id", orderId);
  if (uErr) {
    console.error(`[yoco-webhook] order update failed:`, uErr);
    return new Response("db update error", { status: 500 });
  }

  console.log(`[yoco-webhook] OK — ${orderNumber} → ${newStatus}`);
  return new Response("ok", { status: 200 });
});

// ----------------------------------------------------------------------------
// Standard Webhooks signature verification
// ----------------------------------------------------------------------------
// Algorithm (per https://www.standardwebhooks.com/verifying):
//   signedContent = webhookId + "." + webhookTimestamp + "." + rawBody
//   signature     = base64( hmacSha256(secret, signedContent) )
//
// The signature header is `webhook-signature` and may contain MULTIPLE
// signatures separated by spaces, each prefixed with a version tag:
//   "v1,base64sig1 v1,base64sig2"
// (Multiple sigs happen during secret rotation.) We accept the webhook
// if ANY of them match.
//
// The secret as stored in the dashboard is prefixed with "whsec_" followed
// by base64-encoded random bytes — we strip the prefix and decode before
// using as the HMAC key.
async function verifyStandardWebhookSignature(
  secret:    string,
  id:        string,
  timestamp: string,
  body:      string,
  signatureHeader: string,
): Promise<boolean> {
  if (!secret || !id || !timestamp || !signatureHeader) return false;

  // Replay protection — reject events older than 5 min.
  const tsSec = parseInt(timestamp, 10);
  if (Number.isNaN(tsSec)) return false;
  const tsMs = tsSec * 1000;
  if (Math.abs(Date.now() - tsMs) > TIMESTAMP_TOLERANCE_MS) {
    console.warn(`[yoco-webhook] timestamp outside tolerance: ${timestamp}`);
    return false;
  }

  const signedContent = `${id}.${timestamp}.${body}`;
  const expected = await hmacSha256Base64(secret, signedContent);

  // Header may contain multiple "<version>,<sig>" entries separated by spaces.
  const sigs = signatureHeader
    .split(" ")
    .map(s => {
      const idx = s.indexOf(",");
      return idx === -1 ? s : s.slice(idx + 1);
    });
  return sigs.includes(expected);
}

async function hmacSha256Base64(secret: string, data: string): Promise<string> {
  // Yoco / Standard Webhooks: secret is "whsec_" + base64 random bytes.
  // The HMAC key is the base64-DECODED random bytes, not the literal string.
  let keyBytes: Uint8Array;
  if (secret.startsWith("whsec_")) {
    keyBytes = base64ToBytes(secret.slice("whsec_".length));
  } else {
    // Fallback: treat the secret as the raw key (some test setups).
    keyBytes = new TextEncoder().encode(secret);
  }
  const key = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(data));
  return bytesToBase64(new Uint8Array(sig));
}

function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
function bytesToBase64(bytes: Uint8Array): string {
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}
