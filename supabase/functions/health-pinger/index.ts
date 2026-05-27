// ============================================================================
// health-pinger — invoked by pg_cron every minute. Pings public + admin sites,
// logs status + latency to site_health_checks.
// Supabase health is implicit: if this function ran, Supabase is up.
// Protected by CRON_SECRET (set in Function secrets AND site_settings.cron_secret).
// ============================================================================
import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const CRON_SECRET = Deno.env.get('CRON_SECRET') || '';

const ENDPOINTS = [
  { name: 'public', url: 'https://hilltrek.co.za' },
  { name: 'admin', url: 'https://admin.hilltrek.co.za' },
];

const TIMEOUT_MS = 15_000;

async function ping(url: string) {
  const start = Date.now();
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
    const r = await fetch(url, {
      method: 'HEAD',
      signal: ctrl.signal,
      redirect: 'follow',
      headers: { 'User-Agent': 'Hilltrek-HealthPinger/1.0' },
    });
    clearTimeout(timer);
    return {
      ok: r.ok,
      status_code: r.status,
      latency_ms: Date.now() - start,
      error: null as string | null,
    };
  } catch (e: any) {
    return {
      ok: false,
      status_code: null,
      latency_ms: Date.now() - start,
      error: String(e?.message || 'unknown').slice(0, 200),
    };
  }
}

Deno.serve(async (req: Request) => {
  if (CRON_SECRET) {
    const provided = req.headers.get('x-cron-secret') || '';
    if (provided !== CRON_SECRET) {
      return new Response('Forbidden', { status: 403 });
    }
  }

  const results = await Promise.all(
    ENDPOINTS.map(async (ep) => {
      const r = await ping(ep.url);
      return { endpoint: ep.name, ...r };
    })
  );

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);
  const { error } = await supabase.from('site_health_checks').insert(results);
  if (error) {
    console.error('insert error:', error);
    return new Response(JSON.stringify({ ok: false, error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  return new Response(JSON.stringify({ ok: true, results }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
