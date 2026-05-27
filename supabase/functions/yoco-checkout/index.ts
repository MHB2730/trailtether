// ============================================================================
// yoco-checkout — Hilltrek Edge Function
// ----------------------------------------------------------------------------
// Creates a Yoco Online Checkout for a pending order and returns the
// shopper-redirect URL.
//
// Yoco's Online Checkout API is much simpler than PayFast's redirect-with-
// query-string-signature pattern: we POST a JSON body to their API with
// our secret key, they return a hosted-checkout URL, we redirect to it.
// Webhooks are signed using the Standard Webhooks spec (see yoco-webhook).
//
// Docs: https://developer.yoco.com/online/online-payments/checkout-api
//
// Required env vars (Supabase Dashboard → Edge Functions → Secrets):
//   YOCO_SECRET_KEY      — sk_test_xxx (test) or sk_live_xxx (production).
//                          The prefix tells Yoco which environment.
//
// Optional:
//   YOCO_WEBHOOK_SECRET  — used by yoco-webhook, not this function. Set both.
// ============================================================================

// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const YOCO_SECRET_KEY = Deno.env.get("YOCO_SECRET_KEY") ?? "";

const YOCO_API_URL = "https://payments.yoco.com/api";
const SITE_PUBLIC  = "https://hilltrek.co.za";

// Restrict CORS to the Hilltrek origins instead of '*' — the public site
// and admin SPA are the only browser callers; any other origin trying to
// initiate a checkout is suspicious.
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
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST")    return j(cors, 405, { error: "POST only" });

  if (!YOCO_SECRET_KEY) {
    return j(cors, 503, {
      error: "yoco_not_configured",
      detail: "Set YOCO_SECRET_KEY in Supabase Edge Function Secrets.",
    });
  }

  let body: any;
  try { body = await req.json(); }
  catch { return j(cors, 400, { error: "Invalid JSON body" }); }

  const orderId = String(body?.order_id ?? "").trim();
  if (!orderId) return j(cors, 400, { error: "order_id required" });

  // 1. Load the order with the service role (RLS would block anon reads).
  const admin = createClient(SUPABASE_URL, SERVICE_KEY);
  const { data: order, error } = await admin
    .from("site_orders")
    .select("*")
    .eq("id", orderId)
    .maybeSingle();

  if (error)  return j(cors, 500, { error: "DB error", detail: error.message });
  if (!order) return j(cors, 404, { error: "Order not found" });
  if (order.status !== "pending") {
    return j(cors, 409, { error: "Order is not pending", detail: `status=${order.status}` });
  }

  // 2. Build the Yoco checkout payload. Amount is in cents (matches our
  //    DB). Metadata travels through the webhook so we can map back to
  //    our order on the other side. The confirmation_token gates PII on
  //    the /order-confirmation/ page — Yoco's success redirect carries
  //    it so the shopper sees the full receipt, not the stripped one.
  const confirmToken = String(order.confirmation_token ?? "");
  const tokenQS = confirmToken ? `&token=${confirmToken}` : "";

  const payload = {
    amount:   Number(order.total_cents),
    currency: "ZAR",
    metadata: {
      order_id:     String(order.id),
      order_number: String(order.order_number),
    },
    successUrl: `${SITE_PUBLIC}/order-confirmation/?id=${order.id}${tokenQS}`,
    cancelUrl:  `${SITE_PUBLIC}/payment-cancelled/?id=${order.id}`,
    failureUrl: `${SITE_PUBLIC}/payment-cancelled/?id=${order.id}&failed=1`,
  };

  // 3. Call Yoco. Idempotency-Key dedupes accidental double-clicks.
  let yocoResp: Response;
  try {
    yocoResp = await fetch(`${YOCO_API_URL}/checkouts`, {
      method: "POST",
      headers: {
        "Authorization":   `Bearer ${YOCO_SECRET_KEY}`,
        "Content-Type":    "application/json",
        "Idempotency-Key": String(order.id),
      },
      body: JSON.stringify(payload),
    });
  } catch (e: any) {
    return j(cors, 502, { error: "yoco_unreachable", detail: String(e?.message ?? e) });
  }

  const respText = await yocoResp.text();
  let yocoData: any = null;
  try { yocoData = JSON.parse(respText); } catch { /* keep as text */ }

  if (!yocoResp.ok) {
    return j(cors, 502, {
      error:  "yoco_api_error",
      status: yocoResp.status,
      detail: yocoData ?? respText,
    });
  }

  if (!yocoData?.redirectUrl) {
    return j(cors, 502, {
      error:  "yoco_no_redirect",
      detail: "Yoco response missing redirectUrl",
      raw:    yocoData,
    });
  }

  // 4. Stamp the provider on the order now so the admin can see "yoco"
  //    even before the webhook fires. payment_provider_ref will be set
  //    to the Yoco checkout id; updated to the final payment id by the
  //    webhook.
  await admin
    .from("site_orders")
    .update({
      payment_provider:     "yoco",
      payment_provider_ref: yocoData.id ?? null,
    })
    .eq("id", order.id);

  return j(cors, 200, {
    redirect_url:      yocoData.redirectUrl,
    order_number:      order.order_number,
    amount:            (Number(order.total_cents) / 100).toFixed(2),
    provider:          "yoco",
    yoco_checkout_id:  yocoData.id ?? null,
  });
});

function j(cors: Record<string, string>, status: number, body: any): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
