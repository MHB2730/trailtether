// ============================================================================
// zapper-checkout — Hilltrek Edge Function (with diagnostics v2)
// ============================================================================

// deno-lint-ignore-file no-explicit-any
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const ZAPPER_API_KEY        = (Deno.env.get("ZAPPER_API_KEY")        ?? "").trim();
const ZAPPER_MERCHANT_ID    = (Deno.env.get("ZAPPER_MERCHANT_ID")    ?? "").trim();
const ZAPPER_SITE_ID        = (Deno.env.get("ZAPPER_SITE_ID")        ?? "").trim();
const ZAPPER_SITE_REFERENCE = (Deno.env.get("ZAPPER_SITE_REFERENCE") ?? "").trim();
const ZAPPER_API_BASE       = (Deno.env.get("ZAPPER_API_BASE_URL")   ?? "https://api.zapper.com").trim();

const SITE_PUBLIC = "https://hilltrek.co.za";

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
  };
}

Deno.serve(async (req) => {
  const cors = corsHeaders(req.headers.get("origin"));

  function j(status: number, body: any): Response {
    return new Response(JSON.stringify(body), {
      status,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST")    return j(405, { error: "POST only" });

  if (!ZAPPER_API_KEY || !ZAPPER_MERCHANT_ID || !ZAPPER_SITE_ID || !ZAPPER_SITE_REFERENCE) {
    return j(503, {
      error: "zapper_not_configured",
      detail: "Set ZAPPER_API_KEY, ZAPPER_MERCHANT_ID, ZAPPER_SITE_ID and ZAPPER_SITE_REFERENCE in Supabase Edge Function Secrets.",
    });
  }

  let body: any;
  try { body = await req.json(); }
  catch { return j(400, { error: "Invalid JSON body" }); }

  const orderId = String(body?.order_id ?? "").trim();
  if (!orderId) return j(400, { error: "order_id required" });

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

  const invoicePayload = {
    externalReference: String(order.id),
    siteReference:     ZAPPER_SITE_REFERENCE,
    currencyISOCode:   "ZAR",
    amount:            Number(order.total_cents),
    origin:            "hilltrek-site",
    originReference:   String(order.order_number),
    lineItems: [
      {
        name:      `Hilltrek order ${order.order_number}`,
        unitPrice: Number(order.total_cents),
        quantity:  1,
      },
    ],
  };

  const invoiceUrl =
    `${ZAPPER_API_BASE}/business/api/v1/merchants/${encodeURIComponent(ZAPPER_MERCHANT_ID)}` +
    `/sites/${encodeURIComponent(ZAPPER_SITE_ID)}/invoices`;

  console.log(`[zapper-checkout] POST ${invoiceUrl} amount=${invoicePayload.amount} mid_len=${ZAPPER_MERCHANT_ID.length} sid_len=${ZAPPER_SITE_ID.length} key_len=${ZAPPER_API_KEY.length}`);
  const fetchStart = Date.now();
  let zapperResp: Response;
  const ctrl = new AbortController();
  const abortTimer = setTimeout(() => ctrl.abort(), 10_000);
  try {
    zapperResp = await fetch(invoiceUrl, {
      method:  "POST",
      headers: {
        "Authorization": `Bearer ${ZAPPER_API_KEY}`,
        "Content-Type":  "application/json",
        "Accept":        "application/json",
      },
      body:   JSON.stringify(invoicePayload),
      signal: ctrl.signal,
    });
  } catch (e: any) {
    const elapsed = Date.now() - fetchStart;
    console.error(`[zapper-checkout] fetch failed after ${elapsed}ms: name=${e?.name} msg=${e?.message}`);
    return j(502, {
      error:      "zapper_unreachable",
      detail:     String(e?.message ?? e),
      name:       String(e?.name ?? ""),
      elapsed_ms: elapsed,
      url:        invoiceUrl,
    });
  } finally {
    clearTimeout(abortTimer);
  }

  const respText = await zapperResp.text();
  let zapperData: any = null;
  try { zapperData = JSON.parse(respText); } catch { /* keep as text */ }
  const elapsedMs = Date.now() - fetchStart;
  console.log(`[zapper-checkout] response status=${zapperResp.status} elapsed=${elapsedMs}ms bodyPreview=${respText.slice(0, 300)}`);

  if (!zapperResp.ok) {
    return j(502, {
      error:      "zapper_api_error",
      status:     zapperResp.status,
      detail:     zapperData ?? respText,
      elapsed_ms: elapsedMs,
    });
  }

  const invoiceReference = zapperData?.reference ?? null;
  if (!invoiceReference) {
    return j(502, {
      error:  "zapper_no_reference",
      detail: "Zapper response did not include an invoice reference",
      raw:    zapperData,
    });
  }

  await admin
    .from("site_orders")
    .update({
      payment_provider:     "zapper",
      payment_provider_ref: invoiceReference,
    })
    .eq("id", order.id);

  const deeplink = `https://zapper.com/payWithZapper?invoice=${encodeURIComponent(invoiceReference)}`;

  return j(200, {
    provider:        "zapper",
    order_number:    order.order_number,
    amount:          (Number(order.total_cents) / 100).toFixed(2),
    pending_url:     `${SITE_PUBLIC}/payment-pending/?id=${order.id}&token=${encodeURIComponent(String(order.confirmation_token ?? ""))}`,
    deeplink,
    invoice_reference: invoiceReference,
  });
});
