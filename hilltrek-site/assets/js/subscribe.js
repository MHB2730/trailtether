// ============================================================================
// Hilltrek footer subscribe form — wires the form to subscriber_signup RPC.
// Anon Supabase REST call; the RPC is SECURITY DEFINER with rate-limit + email
// validation server-side.
// ============================================================================
(function () {
  'use strict';

  var SUPABASE_URL  = 'https://xuqmdujupbmxahyhkdwl.supabase.co';
  // Public anon key — safe to ship; RLS + RPC permission gate everything.
  var SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh1cW1kdWp1cGJteGFoeWhrZHdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyMzYyODYsImV4cCI6MjA5MjgxMjI4Nn0.aUfLfzgW25Ozsl9EMkDfmelBzxlCOWjGcatQQ-eh2Jo';

  var form = document.getElementById('hk-subscribe-form');
  var input = document.getElementById('hk-subscribe-email');
  var btn = document.getElementById('hk-subscribe-btn');
  var msg = document.getElementById('hk-subscribe-msg');
  if (!form || !input || !btn || !msg) return;

  var originalBtnHTML = btn.innerHTML;

  function setMsg(text, isError) {
    msg.textContent = text;
    msg.style.color = isError ? '#ff6b6b' : '';
  }

  form.addEventListener('submit', async function (e) {
    e.preventDefault();
    var email = (input.value || '').trim();
    if (!email) { setMsg('Pop an email address in there first.', true); return; }

    btn.disabled = true;
    btn.innerHTML = '<span class="btn-stack"><span class="sub">…</span><span class="main">Sending</span></span>';

    try {
      var res = await fetch(SUPABASE_URL + '/rest/v1/rpc/subscriber_signup', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': SUPABASE_ANON,
          'Authorization': 'Bearer ' + SUPABASE_ANON,
        },
        body: JSON.stringify({ p_email: email, p_source: 'site' }),
      });

      var data = await res.json();
      if (!res.ok || !data || data.ok === false) {
        var err = (data && data.error) || 'something_broke';
        if (err === 'email_required' || err === 'email_invalid') {
          setMsg("That doesn't look like a valid email. Try again.", true);
        } else {
          setMsg("Couldn't sign you up right now. Try again in a sec.", true);
        }
        btn.disabled = false;
        btn.innerHTML = originalBtnHTML;
        return;
      }

      // Track conversion in analytics (if loaded)
      if (window.hkTrack) window.hkTrack('subscribe_signup', { status: data.status });

      // Fire confirmation email (fire-and-forget — user sees success
      // regardless; we don't want SMTP slowness to hold the UI).
      // Skip if already confirmed (no point re-sending).
      if (data.token && data.status !== 'already_subscribed') {
        fetch(SUPABASE_URL + '/functions/v1/subscriber-send-confirmation', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': SUPABASE_ANON,
            'Authorization': 'Bearer ' + SUPABASE_ANON,
          },
          body: JSON.stringify({ email: email, token: data.token }),
        }).catch(function () { /* swallow */ });
      }

      var status = data.status;
      if (status === 'already_subscribed') {
        setMsg("You're already on the list — thanks for the keenness.");
      } else if (status === 'pending') {
        setMsg("Already pending — we've re-sent your confirmation email.");
      } else if (status === 'resubscribed') {
        setMsg("Welcome back. Check your inbox to confirm.");
      } else {
        setMsg("On the list. Check your inbox to confirm.");
      }
      form.reset();
      btn.disabled = true;
      btn.innerHTML = '<span class="btn-stack"><span class="sub">Done</span><span class="main">Subscribed</span></span>';
    } catch (err) {
      console.warn('subscribe error:', err);
      setMsg("Couldn't reach the server. Check your connection and try again.", true);
      btn.disabled = false;
      btn.innerHTML = originalBtnHTML;
    }
  });
})();
