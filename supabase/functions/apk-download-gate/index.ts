// ============================================================================
// apk-download-gate
// Gated APK download for the public hilltrek.co.za/trailtether/ page.
//
// Flow:
//   1. Site button opens a modal: email + T&Cs + (optional) newsletter
//      + Cloudflare Turnstile widget.
//   2. Modal POSTs here. We verify Turnstile server-side, validate email,
//      record the gate row in apk_downloads, optionally enroll the user
//      in the newsletter (mirrors the footer form's RPC path), and return
//      the latest app_releases.download_url so the site triggers the
//      actual download.
//
// We deliberately do NOT make the storage bucket private — the in-app
// updater also fetches from app-releases via that same download_url, and
// breaking installed apps is not worth the marginal security gain. The
// bucket's LIST permission is dropped in the matching migration, so
// scrapers can't enumerate APKs anymore even though direct object reads
// still work.
// ============================================================================
import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL          = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const SUPABASE_ANON         = Deno.env.get('SUPABASE_ANON_KEY')!;
const TURNSTILE_SECRET      = Deno.env.get('TURNSTILE_SECRET') || '';

const ALLOWED_ORIGINS = [
  'https://hilltrek.co.za',
  'https://www.hilltrek.co.za',
  'https://admin.hilltrek.co.za',
];

// Same per-IP rate-limit pattern as subscriber-send-confirmation. The
// gate is higher-friction than the newsletter form (Turnstile + checkbox
// + email retype), so 10/min/IP comfortably covers honest retries on a
// typo while still throttling bots that solve one captcha and hammer.
const rateLimits = new Map<string, { count: number; reset: number }>();
const RATE_LIMIT_PER_MIN = 10;
const RATE_WINDOW_MS = 60_000;

const EMAIL_RE = /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$/;

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

function checkRateLimit(ip: string): { ok: boolean } {
  const now = Date.now();
  const rl = rateLimits.get(ip);
  if (rl && rl.reset > now) {
    if (rl.count >= RATE_LIMIT_PER_MIN) return { ok: false };
    rl.count++;
    return { ok: true };
  }
  rateLimits.set(ip, { count: 1, reset: now + RATE_WINDOW_MS });
  if (rateLimits.size > 5000) {
    for (const [k, v] of rateLimits) {
      if (v.reset < now) rateLimits.delete(k);
    }
  }
  return { ok: true };
}

async function verifyTurnstile(token: string, ip: string): Promise<{ ok: boolean; error?: string }> {
  // If no secret is configured, fail closed — refusing the request is
  // safer than silently letting every download through.
  if (!TURNSTILE_SECRET) return { ok: false, error: 'turnstile_not_configured' };
  try {
    const body = new URLSearchParams({
      secret: TURNSTILE_SECRET,
      response: token,
      remoteip: ip,
    });
    const res = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
      method: 'POST',
      body,
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    });
    const data: any = await res.json();
    if (!data.success) {
      const codes = Array.isArray(data['error-codes']) ? data['error-codes'].join(',') : 'unknown';
      return { ok: false, error: codes };
    }
    return { ok: true };
  } catch (e: any) {
    console.error('Turnstile verify error:', e);
    return { ok: false, error: 'turnstile_unreachable' };
  }
}

function filenameFromUrl(url: string): string | null {
  try {
    const u = new URL(url);
    const parts = u.pathname.split('/').filter(Boolean);
    const last = parts[parts.length - 1];
    if (!last) return null;
    return decodeURIComponent(last.replace(/\?.*$/, ''));
  } catch {
    return null;
  }
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

  // Rate limit FIRST so probes never reach Turnstile/DB.
  const ip = clientIp(req);
  if (!checkRateLimit(ip).ok) {
    return new Response(
      JSON.stringify({ ok: false, error: 'rate_limited', detail: 'Too many download attempts. Try again in a minute.' }),
      { status: 429, headers: { ...cors, 'Retry-After': '60' } },
    );
  }

  try {
    const body = await req.json();
    const email           = String(body.email || '').trim().toLowerCase();
    const termsAccepted   = body.terms_accepted === true;
    const newsletterOptIn = body.newsletter_opt_in === true;
    const turnstileToken  = String(body.turnstile_token || '').trim();

    if (!email || !EMAIL_RE.test(email)) {
      return new Response(JSON.stringify({ ok: false, error: 'email_invalid' }), { status: 400, headers: cors });
    }
    if (!termsAccepted) {
      return new Response(JSON.stringify({ ok: false, error: 'terms_required' }), { status: 400, headers: cors });
    }
    if (!turnstileToken) {
      return new Response(JSON.stringify({ ok: false, error: 'captcha_required' }), { status: 400, headers: cors });
    }

    const captcha = await verifyTurnstile(turnstileToken, ip);
    if (!captcha.ok) {
      return new Response(
        JSON.stringify({ ok: false, error: 'captcha_failed', detail: captcha.error }),
        { status: 403, headers: cors },
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

    // Resolve the latest android release. The in-app updater uses the
    // same row — this keeps the website button and the auto-updater
    // pointing at the same artifact.
    const { data: release, error: releaseErr } = await supabase
      .from('app_releases')
      .select('id, version_name, version_code, download_url, sha256')
      .eq('platform', 'android')
      .order('released_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (releaseErr || !release) {
      console.error('apk-download-gate: no release found', releaseErr);
      return new Response(JSON.stringify({ ok: false, error: 'release_not_found' }), { status: 500, headers: cors });
    }

    const filename  = filenameFromUrl(release.download_url);
    const userAgent = req.headers.get('user-agent')?.slice(0, 500) || null;
    const ipCountry = req.headers.get('cf-ipcountry') || null;

    // Optional newsletter signup. Reuses subscriber_signup so the
    // confirm/unsubscribe flow + dedupe behavior is identical to the
    // footer form.
    let subscriberId:     string | null = null;
    let subscriberToken:  string | null = null;
    let subscriberStatus: string | null = null;
    if (newsletterOptIn) {
      const { data: subResult, error: subErr } = await supabase.rpc('subscriber_signup', {
        p_email: email,
        p_source: 'apk_gate',
        p_country: ipCountry,
        p_ua: userAgent,
      });
      if (subErr) {
        console.warn('apk-download-gate: subscriber_signup failed:', subErr);
      } else if (subResult && typeof subResult === 'object') {
        const r = subResult as any;
        subscriberId    = r.id     || null;
        subscriberToken = r.token  || null;
        subscriberStatus = r.status || null;
      }
    }

    // Audit row — legal evidence of T&Cs acceptance. Soft-fail if the
    // insert errors: the user already passed Turnstile + agreed to T&Cs,
    // and edge logs still capture the attempt.
    const { error: insertErr } = await supabase.from('apk_downloads').insert({
      email,
      terms_accepted_at: new Date().toISOString(),
      newsletter_opt_in: newsletterOptIn,
      subscriber_id:     subscriberId,
      apk_release_id:    release.id,
      apk_filename:      filename,
      apk_version_name:  release.version_name,
      apk_version_code:  release.version_code,
      ip,
      ip_country:        ipCountry,
      user_agent:        userAgent,
    });
    if (insertErr) {
      console.error('apk-download-gate: apk_downloads insert failed:', insertErr);
    }

    // Fire-and-forget confirmation email when a fresh token was issued.
    // Skip on 'already_subscribed' — they've already confirmed, no point
    // re-mailing. Errors are swallowed; the user already has their URL.
    if (subscriberToken && subscriberStatus && subscriberStatus !== 'already_subscribed') {
      fetch(`${SUPABASE_URL}/functions/v1/subscriber-send-confirmation`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': SUPABASE_ANON,
          'Authorization': `Bearer ${SUPABASE_ANON}`,
        },
        body: JSON.stringify({ email, token: subscriberToken }),
      }).catch((e) => console.warn('apk-download-gate: send-confirmation failed:', e));
    }

    return new Response(JSON.stringify({
      ok: true,
      download_url:      release.download_url,
      filename,
      version_name:      release.version_name,
      version_code:      release.version_code,
      sha256:            release.sha256,
      subscriber_status: subscriberStatus,
    }), { status: 200, headers: cors });
  } catch (e: any) {
    console.error('apk-download-gate error:', e);
    return new Response(
      JSON.stringify({ ok: false, error: String(e?.message || 'unknown').slice(0, 300) }),
      { status: 500, headers: cors },
    );
  }
});
