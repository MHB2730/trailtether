// ============================================================================
// newsletter-track-click — logs a click then 302-redirects to the real URL.
// Hit when a recipient clicks a link in a sent newsletter (links rewritten
// by newsletter-send before SMTP delivery).
//
// Security: redirects ONLY to an allowlist of trusted hosts. Anything else
// falls back to the homepage. Without this, the function is an open redirect
// — attackers can craft phishing URLs of the shape
//   https://xuqmdujupbmxahyhkdwl.supabase.co/functions/v1/newsletter-track-click?url=https://attacker.example/fake-login
// and trade on the hilltrek.co.za-adjacent domain in the URL bar for
// credibility. Open redirects are a classic phishing primitive.
// ============================================================================
import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FALLBACK = 'https://hilltrek.co.za';

// Hosts we'll redirect to. Anything else → FALLBACK.
//   hilltrek.co.za + any subdomain (admin, www, blog, etc) — covers all
//     our own content
//   xuqmdujupbmxahyhkdwl.supabase.co — APK downloads + storage-served assets
//     referenced in newsletters (release notes images, etc)
const ALLOW_SUFFIXES = ['.hilltrek.co.za'];
const ALLOW_EXACT    = ['hilltrek.co.za', 'xuqmdujupbmxahyhkdwl.supabase.co'];

function isAllowedDest(raw: string): boolean {
  let u: URL;
  try { u = new URL(raw); } catch { return false; }
  if (u.protocol !== 'https:' && u.protocol !== 'http:') return false;
  const host = u.hostname.toLowerCase();
  if (ALLOW_EXACT.includes(host)) return true;
  for (const suffix of ALLOW_SUFFIXES) {
    if (host.endsWith(suffix)) return true;
  }
  return false;
}

Deno.serve(async (req: Request) => {
  let target = FALLBACK;
  try {
    const url = new URL(req.url);
    const nid = url.searchParams.get('nid');
    const sid = url.searchParams.get('sid');
    const dest = url.searchParams.get('url');

    if (dest) {
      if (isAllowedDest(dest)) {
        target = dest;
      } else {
        // Visible-but-non-fatal: don't 4xx (would break the user's click for
        // no reason if we ever block a legit URL). Log so we can audit.
        console.warn('[newsletter-track-click] blocked redirect to off-allowlist host:', dest);
      }
    }

    if (nid && sid) {
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);
      await supabase.from('site_newsletter_sends')
        .update({ clicked_at: new Date().toISOString() })
        .eq('id', parseInt(sid))
        .is('clicked_at', null)
        .then(() => {}, () => {});
    }
  } catch (_) { /* swallow */ }

  return new Response(null, {
    status: 302,
    headers: { 'Location': target, 'Cache-Control': 'no-store' },
  });
});
