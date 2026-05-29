// ============================================================================
// Hilltrek analytics beacon — self-hosted pageview tracking.
// POPIA-safe: no cookies, IP hashed server-side, country from CF header only.
// Runs in parallel with Cloudflare Web Analytics — we keep CF's data for
// sanity-checking ours.
// ============================================================================
(function () {
  'use strict';

  var ENDPOINT = 'https://xuqmdujupbmxahyhkdwl.supabase.co/functions/v1/analytics-ingest';
  var SESSION_KEY = 'hk_sid';

  // Session id persists per browser tab (sessionStorage) so a quick page
  // navigation looks like one session, not two visitors.
  function getSessionId() {
    try {
      var sid = sessionStorage.getItem(SESSION_KEY);
      if (sid) return sid;
      sid = (crypto && crypto.randomUUID) ? crypto.randomUUID() : (
        'sid-' + Date.now() + '-' + Math.random().toString(36).slice(2, 10)
      );
      sessionStorage.setItem(SESSION_KEY, sid);
      return sid;
    } catch (_) {
      // Private mode / disabled storage — generate a one-shot id.
      return 'no-storage-' + Date.now();
    }
  }

  function send(eventType, extra) {
    try {
      var body = JSON.stringify({
        session_id: getSessionId(),
        path: location.pathname + location.search,
        referrer: document.referrer || null,
        ua: navigator.userAgent || '',
        event_type: eventType || 'pageview',
        event_data: extra || null
      });
      // Prefer sendBeacon for unloads — fire-and-forget, doesn't delay nav.
      if (navigator.sendBeacon) {
        var blob = new Blob([body], { type: 'application/json' });
        navigator.sendBeacon(ENDPOINT, blob);
      } else {
        fetch(ENDPOINT, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: body,
          keepalive: true
        }).catch(function () { /* swallow */ });
      }
    } catch (_) { /* swallow — analytics must never break the page */ }
  }

  // Initial pageview
  send('pageview');

  // Expose for manual events (form submits, clicks, etc.)
  window.hkTrack = function (eventType, data) { send(eventType, data); };
})();
