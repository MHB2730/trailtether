// ============================================================================
// subscriber-send-confirmation
// Sends the confirmation email to a freshly-signed-up subscriber.
// Called by subscribe.js right after subscriber_signup() succeeds.
// Verifies the token matches the email in DB (anti-abuse — random tokens
// can't be used to spam arbitrary emails).
//
// Rate-limit: per-IP cap so even with a valid (email, token) pair an
// attacker can't drive thousands of emails through SMTP. 5 per minute is
// well above what a real signup flow needs (1 send per signup) and
// throttles spam-bots that find a leaked token pair.
// ============================================================================
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { SMTPClient } from 'https://deno.land/x/denomailer@1.6.0/mod.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const SMTP_HOST = Deno.env.get('SMTP_HOST')!;
const SMTP_PORT = parseInt(Deno.env.get('SMTP_PORT') || '465');
const SMTP_USER = Deno.env.get('SMTP_USER')!;
const SMTP_PASS = Deno.env.get('SMTP_PASS')!;
const FROM_NAME = 'Hilltrek';
const FROM_EMAIL = SMTP_USER;
const SITE_URL = 'https://hilltrek.co.za';

const ALLOWED_ORIGINS = [
  'https://hilltrek.co.za',
  'https://www.hilltrek.co.za',
  'https://admin.hilltrek.co.za',
];

// Per-IP rate limit. Map persists across invocations as long as the
// edge runtime keeps the isolate warm; cold starts reset it (acceptable
// — attacks would have to wait for the isolate to warm).
const rateLimits = new Map<string, { count: number; reset: number }>();
const RATE_LIMIT_PER_MIN = 5;
const RATE_WINDOW_MS = 60_000;

function corsHeaders(origin: string | null) {
  const allow = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, x-client-info',
    'Access-Control-Allow-Credentials': 'true',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
    'Content-Type': 'application/json',
  };
}

function clientIp(req: Request): string {
  return req.headers.get('cf-connecting-ip')
    || req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
    || 'unknown';
}

function checkRateLimit(ip: string): { ok: boolean; remaining: number } {
  const now = Date.now();
  const rl = rateLimits.get(ip);
  if (rl && rl.reset > now) {
    if (rl.count >= RATE_LIMIT_PER_MIN) return { ok: false, remaining: 0 };
    rl.count++;
    return { ok: true, remaining: RATE_LIMIT_PER_MIN - rl.count };
  }
  rateLimits.set(ip, { count: 1, reset: now + RATE_WINDOW_MS });
  // GC opportunistically to stop the map growing unbounded.
  if (rateLimits.size > 5000) {
    for (const [k, v] of rateLimits) {
      if (v.reset < now) rateLimits.delete(k);
    }
  }
  return { ok: true, remaining: RATE_LIMIT_PER_MIN - 1 };
}

function buildEmail(confirmUrl: string, unsubUrl: string) {
  const text = `Welcome to Hilltrek!

Confirm your email to start receiving hike notes, gear reviews, and Trailtether release updates:

${confirmUrl}

If you didn't sign up, just ignore this email — we won't email you again.

Unsubscribe anytime:
${unsubUrl}

—
Hilltrek (Pty) Ltd · Drakensberg, South Africa
hilltrek.co.za`;

  const html = `<!doctype html>
<html><head><meta charset="utf-8"><title>Confirm your Hilltrek subscription</title></head>
<body style="margin:0;padding:0;background:#f5f4f1;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#222;line-height:1.55;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f5f4f1;">
    <tr><td align="center" style="padding:40px 16px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;background:#ffffff;border-radius:10px;overflow:hidden;">
        <tr><td style="background:#0a0908;padding:24px;text-align:center;">
          <span style="color:#ff7a1a;font-size:13px;letter-spacing:0.35em;font-weight:700;">// HILLTREK</span>
        </td></tr>
        <tr><td style="padding:32px 32px 8px;">
          <h1 style="font-size:24px;letter-spacing:-0.02em;margin:0 0 14px;color:#0a0908;">Welcome aboard.</h1>
          <p style="margin:0 0 18px;font-size:15px;color:#444;">Confirm your email to start receiving hike notes, gear reviews, and Trailtether release updates.</p>
        </td></tr>
        <tr><td align="center" style="padding:8px 32px 32px;">
          <a href="${confirmUrl}" style="display:inline-block;padding:14px 32px;background:#ff7a1a;color:#0a0908;text-decoration:none;font-weight:700;border-radius:8px;font-size:15px;letter-spacing:0.02em;">Confirm email →</a>
        </td></tr>
        <tr><td style="padding:0 32px 24px;">
          <p style="margin:0;font-size:12px;color:#999;">Or paste this link into your browser:</p>
          <p style="margin:6px 0 0;font-size:12px;"><a href="${confirmUrl}" style="color:#888;word-break:break-all;">${confirmUrl}</a></p>
        </td></tr>
        <tr><td style="padding:0 32px 28px;">
          <hr style="border:none;border-top:1px solid #eee;margin:0 0 18px;">
          <p style="margin:0;font-size:12px;color:#999;">Didn't sign up? Ignore this email — we won't email you again. Or <a href="${unsubUrl}" style="color:#999;text-decoration:underline;">unsubscribe immediately</a>.</p>
        </td></tr>
        <tr><td style="padding:18px;text-align:center;background:#fafaf8;">
          <p style="margin:0;font-size:11px;color:#aaa;">Hilltrek (Pty) Ltd · Drakensberg, South Africa<br><a href="https://hilltrek.co.za" style="color:#aaa;">hilltrek.co.za</a></p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`;

  return { text, html };
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get('origin');
  const cors = corsHeaders(origin);

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors });
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ ok: false, error: 'method_not_allowed' }), { status: 405, headers: cors });
  }

  // Rate limit BEFORE the DB lookup, so probes don't even cost a query.
  const ip = clientIp(req);
  const rl = checkRateLimit(ip);
  if (!rl.ok) {
    return new Response(
      JSON.stringify({ ok: false, error: 'rate_limited', detail: 'Too many requests' }),
      { status: 429, headers: { ...cors, 'Retry-After': '60' } },
    );
  }

  try {
    const body = await req.json();
    const email = String(body.email || '').trim().toLowerCase();
    const token = String(body.token || '').trim();
    if (!email || !token) {
      return new Response(JSON.stringify({ ok: false, error: 'email_and_token_required' }), { status: 400, headers: cors });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);
    const { data: sub, error: lookupErr } = await supabase
      .from('site_subscribers')
      .select('id, email, confirmation_token, unsubscribe_token, confirmed_at')
      .eq('email', email)
      .maybeSingle();

    if (lookupErr) {
      console.error('lookup error:', lookupErr);
      return new Response(JSON.stringify({ ok: false, error: 'lookup_failed' }), { status: 500, headers: cors });
    }
    if (!sub) {
      return new Response(JSON.stringify({ ok: false, error: 'subscriber_not_found' }), { status: 404, headers: cors });
    }
    if (sub.confirmation_token !== token) {
      return new Response(JSON.stringify({ ok: false, error: 'token_mismatch' }), { status: 403, headers: cors });
    }
    if (sub.confirmed_at) {
      return new Response(JSON.stringify({ ok: true, status: 'already_confirmed' }), { status: 200, headers: cors });
    }

    const confirmUrl = `${SITE_URL}/subscribe/confirm/?token=${sub.confirmation_token}`;
    const unsubUrl = `${SITE_URL}/subscribe/unsubscribe/?token=${sub.unsubscribe_token}`;
    const { text, html } = buildEmail(confirmUrl, unsubUrl);

    const client = new SMTPClient({
      connection: {
        hostname: SMTP_HOST,
        port: SMTP_PORT,
        tls: true,
        auth: { username: SMTP_USER, password: SMTP_PASS },
      },
    });

    await client.send({
      from: `${FROM_NAME} <${FROM_EMAIL}>`,
      to: email,
      subject: 'Confirm your Hilltrek subscription',
      content: text,
      html: html,
    });

    await client.close();

    return new Response(JSON.stringify({ ok: true, status: 'sent' }), { status: 200, headers: cors });
  } catch (e: any) {
    console.error('subscriber-send-confirmation error:', e);
    return new Response(JSON.stringify({ ok: false, error: String(e?.message || 'unknown').slice(0, 300) }), { status: 500, headers: cors });
  }
});
