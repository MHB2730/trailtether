// ============================================================================
// payfast-itn — Hilltrek Edge Function
// ----------------------------------------------------------------------------
// Receives Instant Transaction Notifications (ITNs) from PayFast.
//
// This is the AUTHORITATIVE source of payment status. The shopper-facing
// return_url cannot be trusted (anyone can hit it). PayFast posts directly
// to this endpoint server-to-server, and we verify three ways before
// touching the order:
//
//   1. md5 signature matches what we re-compute with the passphrase.
//   2. PayFast's /eng/query/validate endpoint confirms the payload.
//   3. The gross amount matches what we have stored for the order.
//
// We log EVERY ITN we receive (valid or not) to site_payment_events for
// audit. The order itself is only updated when all three checks pass.
//
// Required env vars (Supabase Dashboard → Edge Functions → Secrets):
//   PAYFAST_PASSPHRASE   — set in PayFast dashboard (or "")
//   PAYFAST_MODE         — 'sandbox' or 'production'
//
// IMPORTANT: this function MUST have verify_jwt: false. PayFast doesn't
// send a Supabase JWT — it's calling from their servers, not a logged-in
// browser. The signature check IS our auth.
// ============================================================================

// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const PF_PASSPHRASE = Deno.env.get("PAYFAST_PASSPHRASE") ?? "";
const PF_MODE       = (Deno.env.get("PAYFAST_MODE") ?? "sandbox").toLowerCase();

const PF_VALIDATE_URL = PF_MODE === "production"
  ? "https://www.payfast.co.za/eng/query/validate"
  : "https://sandbox.payfast.co.za/eng/query/validate";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });

  // 1. Parse the form-encoded payload exactly as PayFast sent it. The
  //    insertion order from formData() matters — we sign in that order.
  const payload: Record<string, string> = {};
  const fieldOrder: string[] = [];
  try {
    const fd = await req.formData();
    for (const [k, v] of fd.entries()) {
      payload[k] = String(v);
      fieldOrder.push(k);
    }
  } catch (err) {
    console.error("[payfast-itn] failed to parse form data:", err);
    return new Response("bad request", { status: 400 });
  }

  const orderRef    = payload.m_payment_id   ?? "";
  const orderUuid   = payload.custom_str1    ?? "";  // we stashed order.id here
  const status      = payload.payment_status ?? "";
  const pfPaymentId = payload.pf_payment_id  ?? "";
  const amountGross = parseFloat(payload.amount_gross ?? "0");
  const sourceIp    = req.headers.get("x-forwarded-for") ??
                      req.headers.get("cf-connecting-ip") ?? "";

  console.log(`[payfast-itn] ${orderRef} status=${status} pf=${pfPaymentId} amount=${amountGross}`);

  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  // 2. Signature check.
  const givenSignature = payload.signature ?? "";
  const expectedSignature = await computeSignatureFromPayload(
    fieldOrder, payload, PF_PASSPHRASE
  );
  const signatureValid = givenSignature.length > 0 && givenSignature === expectedSignature;

  // 3. Server-to-server validate with PayFast (defence in depth).
  let validateOk = false;
  try {
    const body = Object.entries(payload)
      .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
      .join("&");
    const res = await fetch(PF_VALIDATE_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    });
    const text = (await res.text()).trim();
    validateOk = text.toUpperCase().startsWith("VALID");
  } catch (err) {
    console.error("[payfast-itn] /query/validate call failed:", err);
  }

  // 4. Log the event (always — including invalid ones).
  await admin.from("site_payment_events").insert({
    order_id:        orderUuid || null,
    provider:        "payfast",
    payload:         payload,
    signature_valid: signatureValid,
    validate_ok:     validateOk,
    ip_address:      sourceIp || null,
  });

  if (!signatureValid) {
    console.warn(`[payfast-itn] REJECT — bad signature for ${orderRef}`);
    return new Response("invalid signature", { status: 400 });
  }
  if (!validateOk) {
    console.warn(`[payfast-itn] REJECT — PayFast validate failed for ${orderRef}`);
    return new Response("validate failed", { status: 400 });
  }

  // 5. Look up the order and verify the amount matches.
  if (!orderUuid) {
    console.warn(`[payfast-itn] REJECT — missing custom_str1 for ${orderRef}`);
    return new Response("missing order id", { status: 400 });
  }
  const { data: order, error: oErr } = await admin
    .from("site_orders")
    .select("*")
    .eq("id", orderUuid)
    .maybeSingle();
  if (oErr) {
    console.error(`[payfast-itn] DB lookup failed:`, oErr);
    return new Response("db error", { status: 500 });
  }
  if (!order) {
    console.warn(`[payfast-itn] REJECT — order ${orderUuid} not found`);
    return new Response("order not found", { status: 404 });
  }

  const expectedAmount = Number(order.total_cents) / 100;
  if (Math.abs(amountGross - expectedAmount) > 0.01) {
    console.warn(`[payfast-itn] REJECT — amount mismatch for ${orderRef}: expected R${expectedAmount}, got R${amountGross}`);
    return new Response("amount mismatch", { status: 400 });
  }

  // 6. Idempotency — if we've already finalised this order, ack the ITN
  //    but skip the update.
  if (order.status === "paid" && order.payment_provider_ref === pfPaymentId) {
    console.log(`[payfast-itn] already paid (idempotent) — ${orderRef}`);
    return new Response("ok (already finalised)", { status: 200 });
  }

  // 7. Map PayFast status → our status.
  let newStatus = order.status;
  let setCompleted = false;
  switch (status.toUpperCase()) {
    case "COMPLETE":
      newStatus = "paid";
      setCompleted = true;
      break;
    case "FAILED":
    case "CANCELLED":
      // Only flip to cancelled if we haven't already paid; sometimes
      // sandbox sends a CANCELLED after a COMPLETE during testing.
      if (order.status === "pending") newStatus = "cancelled";
      break;
    default:
      console.warn(`[payfast-itn] unknown payment_status: ${status}`);
  }

  const updates: any = {
    status:               newStatus,
    payment_provider:     "payfast",
    payment_provider_ref: pfPaymentId || order.payment_provider_ref,
  };
  if (setCompleted) {
    updates.payment_completed_at = new Date().toISOString();
  }

  const { error: uErr } = await admin
    .from("site_orders")
    .update(updates)
    .eq("id", orderUuid);
  if (uErr) {
    console.error("[payfast-itn] order update failed:", uErr);
    return new Response("db update error", { status: 500 });
  }

  console.log(`[payfast-itn] OK — ${orderRef} → ${newStatus} (pf=${pfPaymentId})`);
  return new Response("ok", { status: 200 });
});

// ----------------------------------------------------------------------------
// Signature helpers (mirror payfast-checkout exactly so the two can agree)
// ----------------------------------------------------------------------------

function pfEncode(s: string): string {
  return encodeURIComponent(String(s))
    .replace(/!/g,  "%21")
    .replace(/\*/g, "%2A")
    .replace(/'/g,  "%27")
    .replace(/\(/g, "%28")
    .replace(/\)/g, "%29")
    .replace(/%20/g, "+");
}

async function md5Hex(s: string): Promise<string> {
  const { crypto: dcrypto } = await import("https://deno.land/std@0.224.0/crypto/mod.ts");
  const buf  = new TextEncoder().encode(s);
  const hash = await dcrypto.subtle.digest("MD5", buf);
  return Array.from(new Uint8Array(hash as ArrayBuffer))
    .map(b => b.toString(16).padStart(2, "0"))
    .join("");
}

// For an ITN, PayFast computes the signature in the order the fields
// appear in the POST body, skipping empty values and excluding the
// signature itself. We preserve insertion order via the fieldOrder array
// captured at parse time.
async function computeSignatureFromPayload(
  fieldOrder: string[],
  payload: Record<string, string>,
  passphrase: string,
): Promise<string> {
  const parts: string[] = [];
  for (const k of fieldOrder) {
    if (k === "signature") continue;
    const v = payload[k];
    if (v !== undefined && v !== null && v !== "") {
      parts.push(`${pfEncode(k)}=${pfEncode(v)}`);
    }
  }
  let str = parts.join("&");
  if (passphrase) str += `&passphrase=${pfEncode(passphrase)}`;
  return await md5Hex(str);
}
