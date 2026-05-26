// ============================================================================
// Hilltrek — Maintenance gate
//
// Runs on every public page. Hits site_settings.maintenance_mode and, when
// the admin has toggled the site off, replaces the page with a maintenance
// screen so no other JS or content is visible.
//
// Admin preview bypass: visiting ANY page with ?preview=1 stores a flag in
// sessionStorage; subsequent navigations in the same tab also skip the gate.
// Clearing the tab clears the bypass.
// ============================================================================
(function () {
  'use strict';

  var SUPABASE_URL = 'https://xuqmdujupbmxahyhkdwl.supabase.co';
  var SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh1cW1kdWp1cGJteGFoeWhrZHdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyMzYyODYsImV4cCI6MjA5MjgxMjI4Nn0.aUfLfzgW25Ozsl9EMkDfmelBzxlCOWjGcatQQ-eh2Jo';
  var BYPASS_KEY = 'hk_maint_bypass';
  var REVEAL_TIMEOUT_MS = 1200; // fail-open after this if Supabase doesn't answer

  // Admin preview flow: ?preview=1 in the URL sets a sticky session flag,
  // so the admin can browse the live site even while maintenance mode is on.
  try {
    if (location.search.indexOf('preview=1') !== -1) {
      sessionStorage.setItem(BYPASS_KEY, '1');
    }
    if (sessionStorage.getItem(BYPASS_KEY) === '1') return;
  } catch (_) { /* sessionStorage blocked — fall through, gate normally */ }

  // Sync hide the page while we ask Supabase about maintenance state. Without
  // this the visitor briefly sees the real homepage before it's replaced —
  // the whole point of maintenance mode is to NOT show the site. Failsafe
  // timeout makes sure we never strand the page invisible on a network blip.
  var html = document.documentElement;
  html.style.visibility = 'hidden';
  var revealTimer = setTimeout(reveal, REVEAL_TIMEOUT_MS);
  function reveal() {
    clearTimeout(revealTimer);
    html.style.visibility = '';
  }

  fetch(
    SUPABASE_URL + '/rest/v1/site_settings?key=eq.maintenance_mode&select=value',
    {
      method: 'GET',
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': 'Bearer ' + SUPABASE_ANON_KEY,
        'Accept': 'application/json'
      }
    }
  )
  .then(function (res) { return res.ok ? res.json() : []; })
  .then(function (rows) {
    var row = (rows && rows[0]) || null;
    var v = row && row.value;
    if (!v || !v.enabled) { reveal(); return; }
    paintMaintenance(v.message || '', v.eta || '');
  })
  .catch(function () { reveal(); /* fail open — never gate visitors on a network blip */ });

  function paintMaintenance(message, eta) {
    var safeMsg = String(message || 'We’re making improvements. Back shortly.').replace(/[<>&]/g, function (c) {
      return c === '<' ? '&lt;' : c === '>' ? '&gt;' : '&amp;';
    });
    var safeEta = String(eta || '').replace(/[<>&]/g, function (c) {
      return c === '<' ? '&lt;' : c === '>' ? '&gt;' : '&amp;';
    });

    // Replacing innerHTML detaches every running script — the body becomes
    // exactly the maintenance screen, nothing else.
    reveal();
    document.documentElement.innerHTML =
      '<head>' +
      '<meta charset="utf-8" />' +
      '<meta name="viewport" content="width=device-width, initial-scale=1" />' +
      '<title>Hilltrek — Back shortly</title>' +
      '<meta name="robots" content="noindex" />' +
      '<link rel="icon" href="/assets/img/logo.png" type="image/png" />' +
      '<style>' +
      '  :root { --ember:#ff7a1a; --bg:#0a0908; --text:#f4f1ed; --muted:#a39d96; --dim:#6b665f; --border:#2a2521; }' +
      '  *,*::before,*::after { box-sizing:border-box; }' +
      '  html,body { margin:0; padding:0; background:var(--bg); color:var(--text); font-family:"Sora",system-ui,-apple-system,sans-serif; -webkit-font-smoothing:antialiased; min-height:100vh; }' +
      '  body { display:grid; place-items:center; padding:32px; line-height:1.55; }' +
      '  body::before { content:""; position:fixed; inset:0; z-index:0; pointer-events:none; background: radial-gradient(ellipse at 20% 10%, rgba(255,122,26,0.10), transparent 55%), radial-gradient(ellipse at 80% 95%, rgba(255,122,26,0.07), transparent 55%); }' +
      '  .wrap { position:relative; z-index:1; max-width:560px; text-align:center; }' +
      // Ember-glow logo: two stacked radial-gradient pseudo-layers behind
      // the badge, each running a slightly different keyframe so the light
      // breathes + flickers like coals. The badge itself gets layered
      // drop-shadows for hot/warm depth.
      '  .mark { position:relative; width:84px; height:84px; margin:0 auto 32px; display:grid; place-items:center; isolation:isolate; }' +
      '  .mark::before { content:""; position:absolute; inset:-72px; z-index:-2; border-radius:50%; background: radial-gradient(circle at 50% 50%, rgba(255,150,60,0.55) 0%, rgba(255,90,10,0.38) 22%, rgba(220,40,0,0.20) 44%, rgba(120,20,0,0.08) 65%, transparent 78%); filter: blur(6px); animation: ember-breathe 3.6s ease-in-out infinite; transform-origin:center; }' +
      '  .mark::after  { content:""; position:absolute; inset:-36px; z-index:-1; border-radius:50%; background: radial-gradient(circle at 50% 55%, rgba(255,200,110,0.85), rgba(255,120,30,0.50) 35%, transparent 70%); filter: blur(3px); mix-blend-mode:screen; animation: ember-flicker 2.3s ease-in-out infinite; }' +
      '  .mark img { width:100%; height:100%; object-fit:contain; position:relative; z-index:1; filter: drop-shadow(0 0 14px rgba(255,160,60,0.85)) drop-shadow(0 0 28px rgba(255,90,10,0.55)) drop-shadow(0 4px 18px rgba(180,40,0,0.45)); }' +
      '  @keyframes ember-breathe { 0%,100% { opacity:0.65; transform:scale(0.96); } 50% { opacity:1; transform:scale(1.10); } }' +
      '  @keyframes ember-flicker { 0%,100% { opacity:0.70; } 18% { opacity:1; } 41% { opacity:0.55; } 63% { opacity:0.95; } 82% { opacity:0.62; } }' +
      '  @media (prefers-reduced-motion: reduce) { .mark::before, .mark::after { animation:none; } }' +
      '  .eyebrow { display:inline-block; font-family:"JetBrains Mono",ui-monospace,monospace; font-size:11px; letter-spacing:0.22em; text-transform:uppercase; color:var(--ember); margin-bottom:18px; }' +
      '  h1 { font-size:clamp(32px, 5vw, 44px); font-weight:700; letter-spacing:-0.025em; line-height:1.05; margin:0 0 18px; }' +
      '  p  { color:var(--muted); font-size:17px; margin:0 0 28px; text-wrap:pretty; }' +
      '  .eta { display:inline-flex; align-items:center; gap:10px; padding:8px 16px; border-radius:999px; background:rgba(255,255,255,0.04); border:1px solid var(--border); font-family:"JetBrains Mono",ui-monospace,monospace; font-size:12.5px; letter-spacing:0.08em; text-transform:uppercase; color:var(--muted); }' +
      '  .eta .dot { width:8px; height:8px; border-radius:50%; background:var(--ember); box-shadow:0 0 12px var(--ember); animation:pulse 2s infinite; }' +
      '  .foot { margin-top:48px; font-family:"JetBrains Mono",ui-monospace,monospace; font-size:11px; letter-spacing:0.18em; text-transform:uppercase; color:var(--dim); }' +
      '  .foot a { color:var(--muted); text-decoration:underline; text-decoration-color:var(--border); }' +
      '  .foot a:hover { color:var(--ember); }' +
      '  @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.35} }' +
      '</style>' +
      '</head>' +
      '<body>' +
      '<div class="wrap">' +
      '  <div class="mark"><img src="/assets/img/logo.png" alt="Hilltrek" /></div>' +
      '  <span class="eyebrow">// Maintenance window</span>' +
      '  <h1>We’ll be right back.</h1>' +
      '  <p>' + safeMsg + '</p>' +
      (safeEta ? '  <div class="eta"><span class="dot"></span>Back ' + safeEta + '</div>' : '') +
      '  <div class="foot">Hilltrek (Pty) Ltd &middot; <a href="mailto:info@hilltrek.co.za">info@hilltrek.co.za</a></div>' +
      '</div>' +
      '</body>';

    // Kill any in-flight scripts. They may already have started loading the
    // site bundles before we got the maintenance verdict — stop their work
    // from racing into the maintenance view we just painted.
    try { window.stop(); } catch (_) { /* not supported */ }
  }
})();
