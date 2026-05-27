// ============================================================================
// newsletter-track-open — returns a 1x1 transparent GIF and logs the open.
// Hit by <img src="...?nid=X&sid=Y"> embedded in sent newsletters.
// Always returns the GIF regardless of DB outcome (analytics never blocks).
// ============================================================================
import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// 43-byte transparent 1x1 GIF
const PIXEL = new Uint8Array([
  0x47,0x49,0x46,0x38,0x39,0x61,0x01,0x00,0x01,0x00,0x80,0x00,0x00,0x00,0x00,0x00,
  0xff,0xff,0xff,0x21,0xf9,0x04,0x01,0x00,0x00,0x00,0x00,0x2c,0x00,0x00,0x00,0x00,
  0x01,0x00,0x01,0x00,0x00,0x02,0x02,0x44,0x01,0x00,0x3b,
]);

function pixelResponse() {
  return new Response(PIXEL, {
    status: 200,
    headers: {
      'Content-Type': 'image/gif',
      'Content-Length': String(PIXEL.length),
      'Cache-Control': 'no-store, no-cache, must-revalidate, private',
      'Pragma': 'no-cache',
      'Access-Control-Allow-Origin': '*',
    },
  });
}

Deno.serve(async (req: Request) => {
  try {
    const url = new URL(req.url);
    const nid = url.searchParams.get('nid');
    const sid = url.searchParams.get('sid');
    if (nid && sid) {
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);
      // Atomic: increment open_count, set opened_at if null
      await supabase.rpc('newsletter_record_open', { p_send_id: parseInt(sid) }).then(() => {}, () => {});
      // Fallback in case RPC doesn't exist yet: do direct update
      await supabase.from('site_newsletter_sends')
        .update({ opened_at: new Date().toISOString() })
        .eq('id', parseInt(sid))
        .is('opened_at', null)
        .then(() => {}, () => {});
    }
  } catch (_) { /* never throw — always return pixel */ }
  return pixelResponse();
});
