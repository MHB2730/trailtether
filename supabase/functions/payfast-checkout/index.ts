// ============================================================================
// payfast-checkout — Hilltrek Edge Function
// ----------------------------------------------------------------------------
// Generates the PayFast redirect URL for a pending order.
//
// Flow:
//   1. The browser POSTs { order_id } here after place_order() succeeds.
//   2. We load the order from the DB (service role).
//   3. We build the PayFast field list in the canonical order, compute the
//      md5 signature using PayFast's PHP-urlencode rules + an optional
//      passphrase, and append signature as the final field.
//   4. We return { redirect_url } — a fully-baked GET URL the browser
//      navigates to. PayFast handles the rest.
//
// PayFast docs:
//   https://developers.payfast.co.za/docs#custom_integration
//
// Required env vars (Supabase Dashboard → Edge Functions → Secrets):
//   PAYFAST_MERCHANT_ID    — from the PayFast merchant dashboard
//   PAYFAST_MERCHANT_KEY   — from the PayFast merchant dashboard
//   PAYFAST_PASSPHRASE     — set in PayFast dashboard; empty string if you
//                            haven't enabled passphrases yet (development)
//   PAYFAST_MODE           — 'sandbox' (default) or 'production'
// ============================================================================

// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY    = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const PF_MERCHANT_ID  = Deno.env.get("PAYFAST_MERCHANT_ID")  ?? "";
const PF_MERCHANT_KEY = Deno.env.get("PAYFAST_MERCHANT_KEY") ?? "";
const PF_PASSPHRASE   = Deno.env.get("PAYFAST_PASSPHRASE")   ?? "";
const PF_MODE         = (Deno.env.get("PAYFAST_MODE") ?? "sandbox").toLowerCase();

const SITE_PUBLIC = "https://hilltrek.co.za";
const PF_URL = PF_MODE === "production"
  ? "https://www.payfast.co.za/eng/process"
  : "https://sandbox.payfast.co.za/eng/process";

const cors = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST")    return j(405, { error: "POST only" });

  // 1. PayFast config sanity check. We return a structured error so the
  //    public site's checkout can fall back to the Phase B EFT flow.
  if (!PF_MERCHANT_ID || !PF_MERCHANT_KEY) {
    return j(503, {
      error: "payfast_not_configured",
      detail: "Set PAYFAST_MERCHANT_ID + PAYFAST_MERCHANT_KEY (and optionally PAYFAST_PASSPHRASE, PAYFAST_MODE) in Supabase Edge Function Secrets.",
    });
  }

  let body: any;
  try { body = await req.json(); }
  catch { return j(400, { error: "Invalid JSON body" }); }

  const orderId = String(body?.order_id ?? "").trim();
  if (!orderId) return j(400, { error: "order_id required" });

  // 2. Load the order with the service role (RLS would block anon reads).
  const admin = createClient(SUPABASE_URL, SERVICE_KEY);
  const { data: order, error } = await admin
    .from("site_orders")
    .select("*")
    .eq("id", orderId)
    .maybeSingle();

  if (error)  return j(500, { error: "DB error", detail: error.message });
  if (!order) return j(404, { error: "Order not found" });
  if (order.status !== "pending") {
    return j(409, { error: "Order is not pending", detail: `status=${order.status}` });
  }

  // 3. Split the customer's full name. PayFast accepts a blank-ish
  //    last name but we substitute a single dash so the field is non-empty
  //    (some PayFast UI screens trip on empty last names).
  const fullName = String(order.customer_name ?? "").trim();
  const spaceIdx = fullName.indexOf(" ");
  const firstName = spaceIdx === -1 ? fullName : fullName.slice(0, spaceIdx);
  const lastName  = spaceIdx === -1 ? "-"      : fullName.slice(spaceIdx + 1).trim() || "-";

  // PayFast expects the amount as a decimal with 2 places.
  const amount = (Number(order.total_cents) / 100).toFixed(2);

  // 4. Field list in the canonical order PayFast documents. Empty values
  //    are skipped in the signature step (per their spec).
  //    custom_str1 carries our order UUID so the ITN can match the order
  //    even if m_payment_id (the human-readable number) is somehow lost.
  const fields: Array<[string, string]> = [
    ["merchant_id",   PF_MERCHANT_ID],
    ["merchant_key",  PF_MERCHANT_KEY],
    ["return_url",    `${SITE_PUBLIC}/order-confirmation/?id=${order.id}`],
    ["cancel_url",    `${SITE_PUBLIC}/payment-cancelled/?id=${order.id}`],
    ["notify_url",    `${SUPABASE_URL}/functions/v1/payfast-itn`],
    ["name_first",    firstName || "Customer"],
    ["name_last",     lastName],
    ["email_address", String(order.customer_email ?? "")],
    ["cell_number",   String(order.customer_phone ?? "")],
    ["m_payment_id",  String(order.order_number)],
    ["amount",        amount],
    ["item_name",     `Hilltrek order ${order.order_number}`],
    ["custom_str1",   String(order.id)],
  ];

  // 5. Compute the signature.
  const signature = await computeSignature(fields, PF_PASSPHRASE);
  fields.push(["signature", signature]);

  // 6. Build the GET redirect URL. (We could POST via auto-submitting HTML
  //    instead, but GET works fine for redirects this size and keeps the
  //    flow simpler.)
  const query = fields
    .filter(([_, v]) => v !== "")
    .map(([k, v]) => `${pfEncode(k)}=${pfEncode(v)}`)
    .join("&");
  const redirectUrl = `${PF_URL}?${query}`;

  return j(200, {
    redirect_url: redirectUrl,
    order_number: order.order_number,
    amount:       amount,
    mode:         PF_MODE,
  });
});

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------

function j(status: number, body: any): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// PayFast signs using PHP's urlencode rules, which differ from JS's
// encodeURIComponent in a few ways: spaces are '+', and a handful of
// extra characters get percent-encoded. This matches the encoding most
// community Node SDKs settled on; PayFast's PHP examples produce the
// same output for everyday strings.
function pfEncode(s: string): string {
  return encodeURIComponent(String(s))
    .replace(/!/g,  "%21")
    .replace(/\*/g, "%2A")
    .replace(/'/g,  "%27")
    .replace(/\(/g, "%28")
    .replace(/\)/g, "%29")
    .replace(/%20/g, "+");
}

// MD5 isn't in the standard Web Crypto API but Deno's std crypto extends
// it with the algorithms PayFast (and the rest of legacy enterprise) still
// uses. We use that here.
async function md5Hex(s: string): Promise<string> {
  const { crypto: dcrypto } = await import("https://deno.land/std@0.224.0/crypto/mod.ts");
  const buf  = new TextEncoder().encode(s);
  const hash = await dcrypto.subtle.digest("MD5", buf);
  return Array.from(new Uint8Array(hash as ArrayBuffer))
    .map(b => b.toString(16).padStart(2, "0"))
    .join("");
}

// PayFast spec: concatenate field=value pairs in the order they appear on
// the page, skip blanks, append `passphrase=<urlenc>` if a passphrase is
// configured, md5 the result.
async function computeSignature(
  fields: Array<[string, string]>,
  passphrase: string,
): Promise<string> {
  const parts = fields
    .filter(([_, v]) => v !== "" && v !== null && v !== undefined)
    .map(([k, v]) => `${pfEncode(k)}=${pfEncode(v)}`);
  let str = parts.join("&");
  if (passphrase) str += `&passphrase=${pfEncode(passphrase)}`;
  return await md5Hex(str);
}
