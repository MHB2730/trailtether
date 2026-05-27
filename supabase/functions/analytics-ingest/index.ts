// ============================================================================
// analytics-ingest — receives pageview / event beacons from the public site.
// POPIA-safe: no PII stored. IP hashed, no cookies, country from CF header only.
// ============================================================================
import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const ALLOWED_ORIGINS = [
  'https://hilltrek.co.za',
  'https://www.hilltrek.co.za',
  'https://admin.hilltrek.co.za',
];

const rateLimits = new Map<string, { count: number; reset: number }>();
const RATE_LIMIT_PER_MIN = 120;
const RATE_WINDOW_MS = 60_000;

function corsHeaders(origin: string | null) {
  const allow = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, x-client-info',
    // sendBeacon always includes credentials; without this header browsers
    // reject the preflight with "credentials mode is 'include'".
    'Access-Control-Allow-Credentials': 'true',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
  };
}

function parseUA(ua: string) {
  const u = ua.toLowerCase();
  let device = 'desktop';
  if (/tablet|ipad/.test(u)) device = 'tablet';
  else if (/mobi|android|iphone|ipod/.test(u)) device = 'mobile';

  let browser = 'other';
  if (/edg\//.test(u)) browser = 'edge';
  else if (/chrome|crios/.test(u)) browser = 'chrome';
  else if (/firefox|fxios/.test(u)) browser = 'firefox';
  else if (/safari/.test(u)) browser = 'safari';
  else if (/opera|opr\//.test(u)) browser = 'opera';

  let os = 'other';
  if (/windows/.test(u)) os = 'windows';
  else if (/mac os|macintosh/.test(u)) os = 'macos';
  else if (/android/.test(u)) os = 'android';
  else if (/iphone|ipad|ipod|ios/.test(u)) os = 'ios';
  else if (/linux/.test(u)) os = 'linux';

  return { device, browser, os };
}

async function hashUA(ua: string, ip: string): Promise<string> {
  const data = new TextEncoder().encode(`${ua}|${ip}|hilltrek-salt`);
  const buf = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(buf))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
    .slice(0, 16);
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get('origin');
  const cors = corsHeaders(origin);

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors });
  }
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: cors });
  }

  try {
    const body = await req.json();
    if (!body.session_id || !body.path) {
      return new Response('Bad request', { status: 400, headers: cors });
    }

    const country = req.headers.get('cf-ipcountry') || null;
    const realIp = req.headers.get('cf-connecting-ip')
      || req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
      || 'unknown';
    const ua = String(body.ua || req.headers.get('user-agent') || '').slice(0, 500);

    const now = Date.now();
    const rl = rateLimits.get(realIp);
    if (rl && rl.reset > now) {
      if (rl.count >= RATE_LIMIT_PER_MIN) {
        return new Response('Rate limited', { status: 429, headers: cors });
      }
      rl.count++;
    } else {
      rateLimits.set(realIp, { count: 1, reset: now + RATE_WINDOW_MS });
    }
    if (rateLimits.size > 5000) {
      for (const [k, v] of rateLimits) {
        if (v.reset < now) rateLimits.delete(k);
      }
    }

    const { device, browser, os } = parseUA(ua);
    const uaHash = await hashUA(ua, realIp);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);
    const { error } = await supabase.from('site_analytics_events').insert({
      session_id: body.session_id,
      path: String(body.path).slice(0, 500),
      referrer: body.referrer ? String(body.referrer).slice(0, 500) : null,
      country,
      device_type: device,
      browser,
      os,
      ua_hash: uaHash,
      event_type: String(body.event_type || 'pageview').slice(0, 40),
      event_data: body.event_data || null,
    });

    if (error) {
      console.error('insert error:', error);
      return new Response('Insert failed', { status: 500, headers: cors });
    }
    return new Response(null, { status: 204, headers: cors });
  } catch (e) {
    console.error('analytics-ingest error:', e);
    return new Response('Error', { status: 500, headers: cors });
  }
});
