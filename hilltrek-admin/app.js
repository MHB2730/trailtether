// ============================================================================
// Hilltrek admin — vanilla JS SPA.
//
// Architecture:
//   - Supabase JS v2 SDK from esm.sh (no build step)
//   - Hash-router with views injected into #route-outlet
//   - Two top-level views: #view-login (shown when no session) and #view-app
//   - Authenticated full access to public.site_hikes per RLS policy
// ============================================================================

// jsdelivr's pre-built +esm bundle is materially faster than esm.sh's
// compile-on-fly pipeline (esm.sh occasionally takes 2-5s on cold cache;
// jsdelivr edges sit behind Cloudflare + jsDelivr's own CDN).
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.0/+esm';
import { marked } from 'https://cdn.jsdelivr.net/npm/marked@12.0.0/+esm';
import {
  SUPABASE_URL, SUPABASE_ANON_KEY, SITE_PUBLIC_URL,
  STORAGE_BUCKET, HIKE_PHOTOS_PREFIX,
} from '/config.js';

// ----------------------------------------------------------------------------
// Supabase client + boot
// ----------------------------------------------------------------------------
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: true, autoRefreshToken: true },
});

// Visible client version. Bump whenever app.js changes meaningfully. Shows
// in the topbar so we can verify which build is actually running in a given
// browser session (cache-busted by ?v=N on the script tag).
const ADMIN_VERSION = 'v13';

// ----------------------------------------------------------------------------
// Hang protection
// ----------------------------------------------------------------------------
// Symptom we're guarding against: every renderer starts with "Loading…",
// awaits a supabase query, then swaps in real content. If a query *hangs*
// (no response ever — usually because the SDK's token refresh stalls and
// every subsequent request queues forever behind it), the loading text
// stays up indefinitely. The user has to force-refresh to clear it.
//
// Fix: wrap every list query in `query()`, which:
//   1. Times out after QUERY_TIMEOUT_MS (10s — generous; normal calls are
//      sub-second).
//   2. On timeout, forces a session refresh (heals the stuck SDK state).
//   3. Retries the query once. If it still fails, the renderer's existing
//      catch block surfaces a real error to the user (vs forever-loading).
// ----------------------------------------------------------------------------
const QUERY_TIMEOUT_MS = 10000;
const REFRESH_TIMEOUT_MS = 5000;

function withTimeout(p, ms, label) {
  return Promise.race([
    p,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms)
    ),
  ]);
}

// Deduplicates parallel refresh attempts — if two queries stall in
// parallel, we only fire one refresh call. Both then await the same
// recovery instead of stampeding the auth endpoint.
let _activeRefresh = null;
function refreshSessionOnce() {
  if (_activeRefresh) return _activeRefresh;
  _activeRefresh = withTimeout(supabase.auth.refreshSession(), REFRESH_TIMEOUT_MS, 'Session refresh')
    .catch(err => { console.warn('[admin] Session refresh stalled:', err); })
    .finally(() => { _activeRefresh = null; });
  return _activeRefresh;
}

// Wrap a supabase call. `factory` is a thunk that returns a fresh promise
// each time it's called — needed so we can retry on stall. Don't pass an
// already-created promise; it can only resolve once.
async function query(factory, label = 'Query') {
  try {
    return await withTimeout(factory(), QUERY_TIMEOUT_MS, label);
  } catch (err) {
    if (String(err?.message || '').includes('timed out')) {
      console.warn(`[admin] ${label} stalled — healing session and retrying once…`);
      await refreshSessionOnce();
      return await withTimeout(factory(), QUERY_TIMEOUT_MS, label + ' (retry)');
    }
    throw err;
  }
}

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

const viewLogin = $('#view-login');
const viewApp   = $('#view-app');
const outlet    = $('#route-outlet');

function show(el) { el.classList.remove('hide'); }
function hide(el) { el.classList.add('hide'); }

// ----------------------------------------------------------------------------
// Toast
// ----------------------------------------------------------------------------
let toastTimer = null;
function toast(msg, kind = 'info', meta = '') {
  const t = $('#toast');
  $('#toast-msg').textContent = msg;
  $('#toast-meta').textContent = meta;
  t.classList.remove('hide', 'ok', 'error');
  if (kind === 'ok') t.classList.add('ok');
  if (kind === 'error') t.classList.add('error');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.add('hide'), kind === 'error' ? 6000 : 3500);
}
function explainError(e) {
  if (!e) return 'Unknown error';
  if (typeof e === 'string') return e;
  return e.message || e.error_description || JSON.stringify(e);
}

// ----------------------------------------------------------------------------
// Auth lifecycle
// ----------------------------------------------------------------------------

// Once admin + MFA are verified in this tab session, cache for 5 minutes so
// subsequent renders (token refresh, route changes, the duplicate INITIAL_SESSION
// event, etc.) don't re-hit the network. Was the biggest source of admin lag —
// every re-render did two sequential RPCs.
let _verifiedAt = 0;
const VERIFY_TTL_MS = 5 * 60 * 1000;

// onAuthStateChange fires INITIAL_SESSION right after registration with the
// same session we just resolved via getSession(). We track the first fire
// and skip it so renderAuth runs once, not twice, on bootstrap.
let _initialAuthSeen = false;

async function bootstrap() {
  console.log(`[admin] starting ${ADMIN_VERSION}`);

  // Global error surfacing — turn silent JS errors into visible toasts so
  // we never have a "page just doesn't load and there's no error" mystery.
  window.addEventListener('error', (e) => {
    console.error('[admin] uncaught error:', e.error || e.message);
    toast('Unexpected error', 'error', e.message || String(e.error));
  });
  window.addEventListener('unhandledrejection', (e) => {
    console.error('[admin] unhandled promise rejection:', e.reason);
    toast('Unexpected error', 'error', e.reason?.message || String(e.reason));
  });

  // Wire up all synchronous listeners FIRST so they're guaranteed attached
  // even if the async auth round-trip below stalls or errors. This was the
  // root cause of an old routing bug: when renderAuth threw, nav clicks
  // stopped updating the view because `hashchange` was never bound.
  $('#login-form').addEventListener('submit', onLoginSubmit);
  $('#mfa-form').addEventListener('submit', onMfaSubmit);
  $('#mfa-cancel').addEventListener('click', onMfaCancel);
  $('#btn-logout').addEventListener('click', onLogout);
  window.addEventListener('hashchange', route);

  // Smart same-hash handler. Browsers (and iOS Safari especially) do NOT
  // fire `hashchange` when the user clicks a link to the hash they're
  // already on — so re-tapping the current tab leaves the view stale.
  // We detect that exact case and call route() manually. Different-hash
  // clicks fall through to hashchange (no double render).
  document.querySelectorAll('.topbar-nav [data-nav]').forEach(a => {
    a.addEventListener('click', () => {
      const target  = (a.getAttribute('href') || '').replace(/^#/, '') || '/';
      const current = location.hash.replace(/^#/, '') || '/';
      if (target === current) route();
    });
  });

  // Initial session resolve + first render. Wrapped + timed out so the
  // boot screen never hangs forever if getSession itself stalls/throws
  // (observed on very flaky links and Safari private mode).
  try {
    const { data: { session } } = await withTimeout(
      supabase.auth.getSession(), QUERY_TIMEOUT_MS, 'Initial getSession'
    );
    await renderAuth(session);
  } catch (err) {
    console.error('[admin] Bootstrap failed:', err);
    hide(viewApp);
    show(viewLogin);
    showLoginForm();
    toast('Could not initialise', 'error', explainError(err));
  } finally {
    hideBoot();
  }

  // Listen for subsequent auth state changes. We deliberately handle ONLY
  // SIGNED_OUT here — every other transition has an explicit path that
  // updates the UI synchronously:
  //   - Sign-in: onLoginSubmit calls renderAuth itself
  //   - MFA verify: onMfaSubmit swaps views directly
  //   - Sign-out from this tab: onLogout calls supabase.auth.signOut()
  //
  // If we also call renderAuth from here, it races with those explicit
  // paths. Specifically: when mfa.verify fires the MFA_CHALLENGE_VERIFIED
  // event, the SDK notifies subscribers BEFORE the verify() promise
  // resolves — so the listener's renderAuth runs while onMfaSubmit is
  // still awaiting. The listener reads _verifiedAt=0 (our continuation
  // hasn't run yet), bypasses the cache, fires is_admin, and that request
  // gets queued behind the SDK's internal token rotation and stalls
  // indefinitely. This is what caused "is_admin timed out after 10000ms"
  // in production.
  //
  // SIGNED_OUT is the only state we still need to react to here: catches
  // cross-tab logouts and server-forced signouts (e.g. refresh failure).
  supabase.auth.onAuthStateChange((event, sess) => {
    console.log('[admin] auth event:', event);
    if (event === 'SIGNED_OUT') {
      _verifiedAt = 0;
      hide(viewApp);
      show(viewLogin);
      showLoginForm();
    }
  });
}

function hideBoot() {
  document.getElementById('view-boot')?.classList.add('hide');
}

// Show login if no session. Otherwise enforce two checks (run in parallel):
//   1) Admin allowlist — Trailtether app users share this Supabase project,
//      so we must explicitly verify the current user is in public.admin_users
//      before showing any CMS UI.
//   2) MFA assurance level — if a TOTP factor is enrolled, prompt for the
//      6-digit code before unlocking the app.
// Result is cached for VERIFY_TTL_MS; later re-renders skip the round-trips.
// On transient network errors we retry once and, if still failing, show the
// login screen WITHOUT signing out — the session stays valid so a refresh
// works. Used to sign out on any blip → "I have to refresh to load".
async function renderAuth(session) {
  if (!session) {
    _verifiedAt = 0;
    hide(viewApp);
    show(viewLogin);
    showLoginForm();
    return;
  }

  // Trust the cache — makes tab clicks + token refresh effectively free.
  if (Date.now() - _verifiedAt < VERIFY_TTL_MS) {
    hide(viewLogin);
    show(viewApp);
    route();
    return;
  }

  // Parallel admin + MFA checks, each wrapped in a 10s timeout. Without
  // these timeouts, a stalled SDK call (common right after mfa.verify())
  // would leave the user stuck on the loading/MFA screen forever — the
  // exact "stuck at 2FA, have to refresh to get in" symptom.
  const runChecks = () => Promise.all([
    withTimeout(supabase.rpc('is_admin'), QUERY_TIMEOUT_MS, 'is_admin'),
    withTimeout(supabase.auth.mfa.getAuthenticatorAssuranceLevel(), QUERY_TIMEOUT_MS, 'AAL check'),
  ]);

  let adminRes, aalRes;
  try {
    [adminRes, aalRes] = await runChecks();
  } catch (err) {
    // Either the SDK stalled (timeout) or a real network/DNS error.
    // Heal by forcing a session refresh (clears any stuck refresh queue
    // inside supabase-js), then retry once. Do NOT sign the user out —
    // the session is still valid; we just couldn't verify access right
    // now. Used to sign out on any blip → "have to refresh to load".
    console.warn('[admin] Auth checks stalled/errored, healing session and retrying:', err);
    await refreshSessionOnce();
    try {
      [adminRes, aalRes] = await runChecks();
    } catch (err2) {
      console.warn('[admin] Auth checks failed twice — preserving session:', err2);
      hide(viewApp);
      show(viewLogin);
      showLoginForm();
      toast('Network issue', 'error',
        'Could not verify access. Your session is preserved — try again in a moment.');
      return;
    }
  }

  // Admin allowlist outcome.
  if (adminRes.error) {
    console.warn('is_admin RPC error:', adminRes.error);
    hide(viewApp); show(viewLogin); showLoginForm();
    toast('Could not verify admin status', 'error', explainError(adminRes.error));
    return;
  }
  if (!adminRes.data) {
    // Confirmed non-admin (Trailtether app user, etc) — sign out cleanly.
    await supabase.auth.signOut();
    hide(viewApp); show(viewLogin); showLoginForm();
    toast('Not authorised', 'error',
      'This account is not on the Hilltrek admin allowlist.');
    return;
  }

  // MFA outcome.
  if (aalRes.error) {
    console.warn('AAL RPC error:', aalRes.error);
    hide(viewApp); show(viewLogin); showLoginForm();
    toast('Could not verify MFA status', 'error', explainError(aalRes.error));
    return;
  }
  if (aalRes.data.currentLevel !== aalRes.data.nextLevel) {
    // TOTP factor enrolled but this session hasn't satisfied AAL2 yet.
    show(viewLogin); hide(viewApp);
    await showMfaPrompt();
    return;
  }

  // All checks passed — cache + show app.
  _verifiedAt = Date.now();
  hide(viewLogin);
  show(viewApp);
  route();
}

function showLoginForm() {
  $('#login-form').classList.remove('hide');
  $('#mfa-form').classList.add('hide');
}

async function showMfaPrompt() {
  $('#login-form').classList.add('hide');
  $('#mfa-form').classList.remove('hide');
  setTimeout(() => $('#mfa-code').focus(), 50);
}

async function onLoginSubmit(e) {
  e.preventDefault();
  const email = $('#login-email').value.trim();
  const password = $('#login-password').value;
  const btn = $('#login-submit');
  btn.disabled = true;
  btn.innerHTML = '<span class="spinner"></span> Signing in…';
  try {
    const { data, error } = await withTimeout(
      supabase.auth.signInWithPassword({ email, password }),
      QUERY_TIMEOUT_MS, 'Sign in'
    );
    if (error) throw error;
    // Render explicitly. Don't rely solely on onAuthStateChange firing
    // SIGNED_IN — our filter now skips noise events and SDK versions vary
    // in exactly what they fire. Belt + suspenders.
    _verifiedAt = 0;
    await renderAuth(data.session);
  } catch (err) {
    toast('Sign-in failed', 'error', explainError(err));
  } finally {
    btn.disabled = false;
    btn.textContent = 'Sign in';
  }
}

async function onMfaSubmit(e) {
  e.preventDefault();
  const code = $('#mfa-code').value.trim();
  const btn = $('#mfa-submit');
  btn.disabled = true;
  btn.innerHTML = '<span class="spinner"></span> Verifying…';
  try {
    // Every MFA call is timeout-wrapped so we can't hang the user on a
    // stalled SDK request after they submit their 6-digit code. Retrying
    // mfa.verify() is NOT safe (single-use code), so on stall we surface
    // an error rather than auto-retry.
    const { data: factors, error: lf } = await withTimeout(
      supabase.auth.mfa.listFactors(), QUERY_TIMEOUT_MS, 'List MFA factors'
    );
    if (lf) throw lf;
    const totp = (factors.totp || []).find(f => f.status === 'verified');
    if (!totp) {
      throw new Error('No verified TOTP factor on this account. Enrol one from the Security page.');
    }
    const { data: challenge, error: ce } = await withTimeout(
      supabase.auth.mfa.challenge({ factorId: totp.id }), QUERY_TIMEOUT_MS, 'MFA challenge'
    );
    if (ce) throw ce;
    const { error: ve } = await withTimeout(
      supabase.auth.mfa.verify({ factorId: totp.id, challengeId: challenge.id, code }),
      QUERY_TIMEOUT_MS, 'MFA verify'
    );
    if (ve) throw ve;
    toast('Signed in', 'ok');
    $('#mfa-code').value = '';

    // ----------------------------------------------------------------------
    // CRITICAL: swap directly to the app shell here. Do NOT call renderAuth
    // again at this point — it would re-run getAuthenticatorAssuranceLevel,
    // which (in supabase-js v2.x) sometimes still reads `aal1` from a stale
    // cached access_token for a few ms after mfa.verify resolves, before
    // the SDK has rotated to the new aal2 token. That race shows the MFA
    // prompt a second time, looking identical to "stuck at 2FA". A hard
    // refresh works because the page reloads with the rotated aal2 token
    // already persisted in local storage.
    //
    // We can safely trust both facts at this point:
    //   - Admin status: verified before the MFA prompt was shown (couldn't
    //     have gotten here otherwise).
    //   - MFA: just verified server-side this instant.
    // So we cache the verification ourselves and switch views directly.
    // The 5-min TTL means the next renderAuth call after that re-checks
    // naturally, with no race because the token has long since rotated.
    // ----------------------------------------------------------------------
    _verifiedAt = Date.now();
    hide(viewLogin);
    show(viewApp);
    route();
  } catch (err) {
    toast('Code did not verify', 'error', explainError(err));
  } finally {
    btn.disabled = false;
    btn.textContent = 'Verify code';
  }
}

async function onMfaCancel() {
  await supabase.auth.signOut();
  $('#mfa-code').value = '';
  showLoginForm();
}

async function onLogout() {
  await supabase.auth.signOut();
  location.hash = '';
  toast('Signed out', 'ok');
}

// ----------------------------------------------------------------------------
// Router
// ----------------------------------------------------------------------------
function route() {
  const path = location.hash.replace(/^#/, '') || '/';
  setActiveNav(path);

  if (path === '/' || path === '')             return renderDashboard();
  if (path === '/hikes')                       return renderHikesList();
  if (path === '/hikes/new')                   return renderHikeEdit(null);
  if (path === '/products')                    return renderProductsList();
  if (path === '/products/new')                return renderProductEdit(null);
  if (path === '/orders')                      return renderOrdersList();
  if (path === '/subscribers')                 return renderSubscribers();
  if (path === '/newsletters')                 return renderNewslettersList();
  if (path === '/newsletters/new')             return renderNewsletterEdit(null);
  if (path === '/analytics')                   return renderAnalytics();
  if (path === '/health')                      return renderHealth();
  if (path === '/audit')                       return renderAuditLog();
  if (path === '/settings')                    return renderSettings();
  if (path === '/security')                    return renderSecurity();
  const m = path.match(/^\/hikes\/(.+)$/);
  if (m) return renderHikeEdit(m[1]);
  const p = path.match(/^\/products\/(.+)$/);
  if (p) return renderProductEdit(p[1]);
  const o = path.match(/^\/orders\/(.+)$/);
  if (o) return renderOrderDetail(o[1]);
  const n = path.match(/^\/newsletters\/([0-9a-f-]+)$/);
  if (n) return renderNewsletterDetail(n[1]);
  const ne = path.match(/^\/newsletters\/([0-9a-f-]+)\/edit$/);
  if (ne) return renderNewsletterEdit(ne[1]);

  outlet.innerHTML = `<div class="card"><h2 style="font-size:20px;">Not found</h2><p class="muted">The URL <code>${path}</code> isn't a known admin view. <a href="#/" class="subtle-link">Back to dashboard</a></p></div>`;
}
function setActiveNav(path) {
  $$('[data-nav]').forEach(a => a.classList.remove('active'));
  if (path === '/' || path === '')              $('[data-nav="dashboard"]')?.classList.add('active');
  else if (path.startsWith('/hikes'))           $('[data-nav="hikes"]')?.classList.add('active');
  else if (path.startsWith('/products'))        $('[data-nav="products"]')?.classList.add('active');
  else if (path.startsWith('/orders'))          $('[data-nav="orders"]')?.classList.add('active');
  else if (path === '/subscribers')             $('[data-nav="subscribers"]')?.classList.add('active');
  else if (path.startsWith('/newsletters'))     $('[data-nav="newsletters"]')?.classList.add('active');
  else if (path === '/analytics')               $('[data-nav="analytics"]')?.classList.add('active');
  else if (path === '/health')                  $('[data-nav="health"]')?.classList.add('active');
  else if (path === '/audit')                   $('[data-nav="audit"]')?.classList.add('active');
  else if (path === '/settings')                $('[data-nav="settings"]')?.classList.add('active');
  else if (path === '/security')                $('[data-nav="security"]')?.classList.add('active');
}

// ----------------------------------------------------------------------------
// View: Dashboard
// ----------------------------------------------------------------------------
async function renderDashboard() {
  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>Mission Control</h1>
        <div class="sub">Welcome to Hilltrek Admin. Add new hikes, manage published content, and trigger republishes.</div>
      </div>
      <div class="page-actions">
        <button id="btn-publish" class="btn btn-primary">↑ Publish to live site</button>
        <a href="#/hikes/new" class="btn btn-ghost">+ New hike</a>
      </div>
    </div>

    <div id="publish-panel" class="card hide" style="margin-bottom: 20px;">
      <div style="display: flex; align-items: center; justify-content: space-between; gap: 12px;">
        <div>
          <h3 style="font-size: 15px; font-weight: 600; letter-spacing: -0.01em; margin-bottom: 4px;">Publishing to hilltrek.co.za…</h3>
          <div id="publish-status" class="muted" style="font-size: 13px;">Preparing…</div>
        </div>
        <span class="spinner" id="publish-spinner"></span>
      </div>
      <div id="publish-results" class="hide" style="margin-top: 14px; padding-top: 14px; border-top: 1px solid var(--border);"></div>
    </div>

    <div id="dash-stats" class="stat-row">
      <div class="stat"><div class="label">Loading…</div><div class="num">—</div></div>
    </div>

    <div class="card">
      <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px;">
        <h2 style="font-size: 18px; font-weight: 600; letter-spacing: -0.01em;">Latest hikes</h2>
        <a href="#/hikes" class="subtle-link">See all →</a>
      </div>
      <div id="dash-latest" class="muted" style="padding: 18px 4px;">Loading…</div>
    </div>
  `;

  // Wire the Publish button
  $('#btn-publish').addEventListener('click', onPublish);

  // Fetch counts + 3 most recent hikes (each query has its own 10s timeout
  // + auto-heal on stall, so dashboard never gets stuck on "Loading…").
  try {
    const [counts, latest] = await Promise.all([
      query(
        () => supabase.from('site_hikes').select('id, is_published, is_featured', { count: 'exact' }),
        'Dashboard counts'
      ),
      query(
        () => supabase.from('site_hikes')
          .select('slug, title, is_published, is_featured, hike_date, updated_at, hero_image_url')
          .order('updated_at', { ascending: false })
          .limit(3),
        'Dashboard latest'
      ),
    ]);
    if (counts.error) throw counts.error;
    if (latest.error) throw latest.error;

    const total     = counts.data.length;
    const published = counts.data.filter(h => h.is_published).length;
    const featured  = counts.data.filter(h => h.is_featured).length;
    const drafts    = total - published;

    $('#dash-stats').innerHTML = `
      <div class="stat"><div class="label">Total hikes</div><div class="num">${total}</div><div class="delta">${published} published · ${drafts} draft</div></div>
      <div class="stat"><div class="label">Published</div><div class="num">${published}</div><div class="delta">Live at hilltrek.co.za</div></div>
      <div class="stat"><div class="label">Featured</div><div class="num">${featured}</div><div class="delta">Shown on Home</div></div>
      <div class="stat"><div class="label">Drafts</div><div class="num">${drafts}</div><div class="delta">Not yet visible</div></div>
    `;

    if (!latest.data.length) {
      $('#dash-latest').innerHTML = `
        <div style="padding: 24px 0; text-align: center;">
          <p class="muted">No hikes yet.</p>
          <p style="margin-top: 12px;"><a href="#/hikes/new" class="btn btn-primary btn-sm">+ Add first hike</a></p>
        </div>`;
    } else {
      $('#dash-latest').innerHTML = latest.data.map(h => `
        <a href="#/hikes/${encodeURIComponent(h.slug)}" class="list-row" style="text-decoration:none;color:inherit;">
          <div class="list-thumb">${h.hero_image_url ? `<img src="${resolveUrl(h.hero_image_url)}" alt="" />` : ''}</div>
          <div class="list-title">${escapeHtml(h.title)}<span class="slug">${h.slug}</span></div>
          <div>${h.hike_date ? formatDate(h.hike_date) : '<span class="dim">—</span>'}</div>
          <div>${h.is_published ? '<span class="pill pub">Published</span>' : '<span class="pill draft">Draft</span>'}</div>
          <div>${h.is_featured ? '<span class="pill feat">Featured</span>' : ''}</div>
          <div></div>
        </a>
      `).join('');
    }
  } catch (err) {
    // Update BOTH panels — otherwise "#dash-latest" stays "Loading…" forever
    // on an error, which is the exact symptom the user reported.
    $('#dash-stats').innerHTML = `<div class="stat"><div class="label">Error</div><div class="num bad">!</div><div class="delta">${explainError(err)}</div></div>`;
    $('#dash-latest').innerHTML = `<div class="bad" style="padding: 20px 4px;">Could not load latest hikes: ${explainError(err)}</div>`;
  }
}

// ----------------------------------------------------------------------------
// Publish action — invokes the publish-site Edge Function which renders the
// static HTML and pushes it to cPanel.
//
// Confirms before running (it's a write to the live site), shows progress in
// the #publish-panel card, and surfaces per-file results if anything fails.
// ----------------------------------------------------------------------------
async function onPublish() {
  const btn   = $('#btn-publish');
  const panel = $('#publish-panel');
  const status = $('#publish-status');
  const results = $('#publish-results');
  const spinner = $('#publish-spinner');

  if (!confirm(
    'Publish all changes to hilltrek.co.za?\n\n' +
    'This regenerates every hike page + /merch/ + /hikes/ from the current ' +
    'database content and pushes them to the live site via cPanel.\n\n' +
    'Only published / active items go live.'
  )) return;

  btn.disabled = true;
  btn.textContent = 'Publishing…';
  panel.classList.remove('hide');
  spinner.classList.remove('hide');
  results.classList.add('hide');
  results.innerHTML = '';
  status.textContent = 'Rendering pages and uploading to cPanel — this can take 10–30s…';

  try {
    const { data, error } = await supabase.functions.invoke('publish-site', { body: {} });

    if (error) {
      // Try to dig out the function's structured error response from FunctionsHttpError
      let detail = error.message;
      if (error.context && typeof error.context.text === 'function') {
        try {
          const t = await error.context.text();
          try { const j = JSON.parse(t); detail = j.detail || j.error || t; }
          catch { detail = t; }
        } catch { /* keep error.message */ }
      }
      throw new Error(detail);
    }

    if (data?.ok) {
      status.innerHTML =
        `<span class="ok">✓ Published</span> · ` +
        `${data.files_published} files · ` +
        `${data.hikes_count} hike${data.hikes_count === 1 ? '' : 's'} · ` +
        `${data.products_count} product${data.products_count === 1 ? '' : 's'} · ` +
        `<a href="${SITE_PUBLIC_URL}" target="_blank" rel="noopener" class="subtle-link">View live ↗</a>`;
      toast('Published to hilltrek.co.za', 'ok',
        `${data.files_published} files pushed`);
    } else {
      // Partial success (207)
      const failed = (data?.results || []).filter(r => !r.ok);
      status.innerHTML =
        `<span class="bad">${failed.length} of ${data?.files_published ?? '?'} files failed</span>`;
      results.classList.remove('hide');
      results.innerHTML = `
        <div style="font-family: var(--font-mono); font-size: 12.5px; max-height: 240px; overflow: auto;">
          ${failed.map(r => `
            <div style="display: flex; gap: 10px; padding: 4px 0;">
              <span class="bad">✗</span>
              <span class="mono dim">${escapeHtml(r.path)}</span>
              <span class="bad">${escapeHtml(r.error || ('HTTP ' + r.status))}</span>
            </div>
          `).join('')}
        </div>
      `;
      toast('Publish completed with errors', 'error',
        `${failed.length} file(s) failed — see panel`);
    }
  } catch (err) {
    status.innerHTML = `<span class="bad">Publish failed</span>`;
    results.classList.remove('hide');
    results.innerHTML = `
      <div style="font-family: var(--font-mono); font-size: 12.5px; padding: 6px 10px; background: rgba(220,38,38,0.08); border: 1px solid rgba(220,38,38,0.25); border-radius: var(--r-sm); color: #fca5a5;">
        ${escapeHtml(explainError(err))}
      </div>
      <p class="dim" style="font-size: 12px; margin-top: 10px;">
        Common causes: cPanel secrets missing in Supabase → Edge Functions → Secrets
        (CPANEL_HOST, CPANEL_USER, CPANEL_API_TOKEN, CPANEL_HOME), or the cPanel
        API token has been revoked.
      </p>
    `;
    toast('Publish failed', 'error', explainError(err));
  } finally {
    spinner.classList.add('hide');
    btn.disabled = false;
    btn.textContent = '↑ Publish to live site';
  }
}

// ----------------------------------------------------------------------------
// View: Hikes list
// ----------------------------------------------------------------------------
async function renderHikesList() {
  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>Hikes</h1>
        <div class="sub">Every Drakensberg route log — published, draft and featured.</div>
      </div>
      <div class="page-actions">
        <a href="#/hikes/new" class="btn btn-primary">+ New hike</a>
      </div>
    </div>

    <div id="hikes-list" class="list">
      <div class="list-empty">Loading…</div>
    </div>
  `;

  try {
    const { data, error } = await query(
      () => supabase
        .from('site_hikes')
        .select('id, slug, title, hike_date, region, is_published, is_featured, hero_image_url, updated_at')
        .order('display_order', { ascending: true })
        .order('hike_date', { ascending: false, nullsFirst: false }),
      'Hikes list'
    );
    if (error) throw error;

    if (!data.length) {
      $('#hikes-list').innerHTML = `
        <div class="list-empty">
          <h3>No hikes yet</h3>
          <p>Nothing has been added to the CMS. Add your first hike to get started.</p>
          <p style="margin-top: 18px;"><a href="#/hikes/new" class="btn btn-primary">+ New hike</a></p>
        </div>`;
      return;
    }

    const head = `
      <div class="list-row is-head">
        <div>Photo</div>
        <div>Title</div>
        <div>Date</div>
        <div>Status</div>
        <div>Featured</div>
        <div style="text-align:right;">Actions</div>
      </div>
    `;
    const rows = data.map(h => `
      <div class="list-row" data-slug="${h.slug}">
        <div class="list-thumb">${h.hero_image_url ? `<img src="${resolveUrl(h.hero_image_url)}" alt="" />` : ''}</div>
        <div class="list-title">${escapeHtml(h.title)}<span class="slug">/${h.slug}</span></div>
        <div>${h.hike_date ? formatDate(h.hike_date) : '<span class="dim">—</span>'}</div>
        <div>${h.is_published ? '<span class="pill pub">Published</span>' : '<span class="pill draft">Draft</span>'}</div>
        <div>${h.is_featured ? '<span class="pill feat">Featured</span>' : ''}</div>
        <div class="row-actions">
          <a href="#/hikes/${encodeURIComponent(h.slug)}" class="btn btn-ghost btn-sm">Edit</a>
          <button class="btn btn-danger btn-sm" data-delete="${h.slug}">Delete</button>
        </div>
      </div>
    `).join('');

    $('#hikes-list').innerHTML = head + rows;

    $$('[data-delete]', $('#hikes-list')).forEach(btn => {
      btn.addEventListener('click', () => onDeleteHike(btn.getAttribute('data-delete')));
    });
  } catch (err) {
    $('#hikes-list').innerHTML = `<div class="list-empty"><h3 class="bad">Error</h3><p>${explainError(err)}</p></div>`;
  }
}

async function onDeleteHike(slug) {
  if (!confirm(`Delete "${slug}" permanently?\n\nThis removes the hike from the database. Photos in Supabase Storage are kept (delete those manually if you want).`)) return;
  try {
    const { error } = await supabase.from('site_hikes').delete().eq('slug', slug);
    if (error) throw error;
    toast(`Deleted "${slug}"`, 'ok');
    renderHikesList();
  } catch (err) {
    toast('Delete failed', 'error', explainError(err));
  }
}

// ----------------------------------------------------------------------------
// View: Hike edit / create
// ----------------------------------------------------------------------------
async function renderHikeEdit(slug) {
  const isNew = !slug;
  outlet.innerHTML = `<div class="card"><p class="muted">Loading editor…</p></div>`;

  let hike = null;
  if (!isNew) {
    let res;
    try {
      res = await query(
        () => supabase.from('site_hikes').select('*').eq('slug', slug).maybeSingle(),
        'Load hike'
      );
    } catch (err) {
      outlet.innerHTML = `<div class="card bad">Failed to load hike: ${explainError(err)}</div>`;
      return;
    }
    if (res.error) { outlet.innerHTML = `<div class="card bad">${explainError(res.error)}</div>`; return; }
    if (!res.data)  { outlet.innerHTML = `<div class="card">Hike not found. <a href="#/hikes" class="subtle-link">Back to list</a></div>`; return; }
    hike = res.data;
  } else {
    hike = {
      slug: '', title: '', subtitle: '', hike_date: '',
      region: '', hike_type: 'Day hike', difficulty: '',
      tags: [], intro: '', body_md: '',
      hero_image_url: '', gallery_image_urls: [],
      stats: {}, is_featured: false, is_published: false, display_order: 0,
    };
  }

  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>${isNew ? 'New hike' : 'Edit hike'}</h1>
        <div class="sub">${isNew ? 'Add a new route log. Save as draft first; publish when it\'s ready.' : `Editing <code>${hike.slug}</code>`}</div>
      </div>
      <div class="page-actions">
        <a href="#/hikes" class="btn btn-ghost">← Back to list</a>
        ${!isNew ? `<a href="${SITE_PUBLIC_URL}/hikes/${hike.slug}/" target="_blank" rel="noopener" class="btn btn-ghost">View live ↗</a>` : ''}
      </div>
    </div>

    <form id="hike-form" class="edit-grid">
      <div class="edit-main">
        <div class="card">
          <div class="field-row">
            <div class="field">
              <label for="f-title">Title</label>
              <input id="f-title" type="text" required value="${escapeHtml(hike.title)}" placeholder='e.g. "MJ Cave"' />
            </div>
            <div class="field">
              <label for="f-slug">Slug</label>
              <input id="f-slug" type="text" required pattern="[a-z0-9\-]+" value="${escapeHtml(hike.slug)}" placeholder="mj-cave" />
              <div class="field-help">URL: hilltrek.co.za/hikes/<span id="slug-preview">${hike.slug || '...'}</span>/</div>
            </div>
          </div>
          <div class="field" style="margin-top: 16px;">
            <label for="f-subtitle">Subtitle / tagline</label>
            <input id="f-subtitle" type="text" value="${escapeHtml(hike.subtitle || '')}" placeholder="A laid-back day to one of the central Berg's most accessible cave shelters." />
          </div>
          <div class="field" style="margin-top: 16px;">
            <label for="f-intro">Intro (1–2 sentences shown in hero)</label>
            <textarea id="f-intro" style="min-height: 80px;">${escapeHtml(hike.intro || '')}</textarea>
          </div>
          <div class="field" style="margin-top: 16px;">
            <label for="f-body">Body (Markdown)</label>
            <textarea id="f-body" placeholder="## The route&#10;&#10;Describe the day, the lessons learned…">${escapeHtml(hike.body_md || '')}</textarea>
            <div class="field-help">Use # / ## for headings, **bold**, _italic_, - bullet lists, [link](url).</div>
          </div>
        </div>

        <div class="card">
          <h3 style="font-size: 14px; font-weight: 600; letter-spacing: -0.01em; margin-bottom: 12px;">Hero photo</h3>
          <div class="media-block">
            <div class="media-current" id="hero-preview">
              ${hike.hero_image_url
                ? `<img src="${resolveUrl(hike.hero_image_url)}" alt="" />`
                : `<div class="empty">No hero photo yet</div>`}
            </div>
            <div class="media-upload-row">
              <label class="btn btn-ghost btn-sm">
                <input type="file" id="hero-upload" accept="image/*" />
                Upload new hero
              </label>
              <button type="button" class="btn btn-danger btn-sm" id="hero-clear" ${hike.hero_image_url ? '' : 'disabled'}>Clear</button>
            </div>
            <div class="field-help" id="hero-status"></div>
          </div>
        </div>

        <div class="card">
          <h3 style="font-size: 14px; font-weight: 600; letter-spacing: -0.01em; margin-bottom: 12px;">Gallery</h3>
          <div class="media-block">
            <div class="gallery" id="gallery-preview">
              ${(hike.gallery_image_urls || []).map((u, i) => `
                <div class="gallery-tile">
                  <img src="${resolveUrl(u)}" alt="" />
                  <button type="button" data-remove-gallery="${i}" aria-label="Remove">×</button>
                </div>
              `).join('')}
            </div>
            <div class="media-upload-row">
              <label class="btn btn-ghost btn-sm">
                <input type="file" id="gallery-upload" accept="image/*" multiple />
                + Add gallery photos
              </label>
            </div>
            <div class="field-help" id="gallery-status"></div>
          </div>
        </div>
      </div>

      <aside class="edit-aside">
        <div class="card card-tight">
          <h3 style="font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--ember); margin-bottom: 14px;">Publish</h3>
          <div class="field" style="margin-bottom: 12px;">
            <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-family: inherit; font-size: 14px; letter-spacing: 0; text-transform: none; color: var(--text);">
              <input type="checkbox" id="f-published" ${hike.is_published ? 'checked' : ''} style="accent-color: var(--ember); width: 16px; height: 16px;" />
              Published (visible on site)
            </label>
          </div>
          <div class="field" style="margin-bottom: 16px;">
            <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-family: inherit; font-size: 14px; letter-spacing: 0; text-transform: none; color: var(--text);">
              <input type="checkbox" id="f-featured" ${hike.is_featured ? 'checked' : ''} style="accent-color: var(--ember); width: 16px; height: 16px;" />
              Featured (shown on Home)
            </label>
          </div>
          <div class="field-row">
            <div class="field">
              <label for="f-order">Order</label>
              <input id="f-order" type="number" value="${hike.display_order || 0}" />
            </div>
            <div class="field">
              <label for="f-date">Hike date</label>
              <input id="f-date" type="date" value="${hike.hike_date || ''}" />
            </div>
          </div>
          <button type="submit" class="btn btn-primary" id="btn-save" style="margin-top: 18px; width: 100%; justify-content: center;">Save changes</button>
          ${!isNew ? `<button type="button" class="btn btn-danger btn-sm" id="btn-delete" style="margin-top: 10px; width: 100%; justify-content: center;">Delete hike</button>` : ''}
        </div>

        <div class="card card-tight">
          <h3 style="font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--ember); margin-bottom: 14px;">Metadata</h3>
          <div class="field" style="margin-bottom: 12px;">
            <label for="f-region">Region</label>
            <input id="f-region" type="text" value="${escapeHtml(hike.region || '')}" placeholder="Central Drakensberg" />
          </div>
          <div class="field-row">
            <div class="field">
              <label for="f-type">Type</label>
              <select id="f-type">
                ${['Day hike','Multi-day','Overnight','Cave-to-cave','Summit'].map(t =>
                  `<option value="${t}" ${hike.hike_type === t ? 'selected' : ''}>${t}</option>`
                ).join('')}
              </select>
            </div>
            <div class="field">
              <label for="f-difficulty">Difficulty</label>
              <select id="f-difficulty">
                ${['','Chilled','Easy','Moderate','Strenuous','Technical'].map(d =>
                  `<option value="${d}" ${(hike.difficulty || '') === d ? 'selected' : ''}>${d || '— select —'}</option>`
                ).join('')}
              </select>
            </div>
          </div>
          <div class="field" style="margin-top: 12px;">
            <label for="f-tags">Tags (comma-separated)</label>
            <input id="f-tags" type="text" value="${(hike.tags || []).join(', ')}" placeholder="cave-route, overnight, featured" />
          </div>
        </div>
      </aside>
    </form>
  `;

  // Auto-generate slug from title for new hikes
  const titleInput = $('#f-title');
  const slugInput  = $('#f-slug');
  const slugPreview = $('#slug-preview');
  let slugManuallyEdited = !isNew;
  slugInput.addEventListener('input', () => { slugManuallyEdited = true; slugPreview.textContent = slugInput.value || '...'; });
  titleInput.addEventListener('input', () => {
    if (!slugManuallyEdited) {
      slugInput.value = slugify(titleInput.value);
      slugPreview.textContent = slugInput.value || '...';
    }
  });

  // Hero upload + clear
  $('#hero-upload').addEventListener('change', async (e) => {
    const file = e.target.files[0]; if (!file) return;
    const status = $('#hero-status');
    status.innerHTML = '<span class="spinner"></span> Uploading hero…';
    try {
      const url = await uploadPhoto(file, slugInput.value || 'unsorted');
      hike.hero_image_url = url;
      $('#hero-preview').innerHTML = `<img src="${url}" alt="" />`;
      $('#hero-clear').disabled = false;
      status.textContent = '';
      toast('Hero photo uploaded', 'ok');
    } catch (err) {
      status.innerHTML = `<span class="bad">${explainError(err)}</span>`;
    }
    e.target.value = '';
  });
  $('#hero-clear').addEventListener('click', () => {
    hike.hero_image_url = '';
    $('#hero-preview').innerHTML = `<div class="empty">No hero photo yet</div>`;
    $('#hero-clear').disabled = true;
  });

  // Gallery upload + remove
  $('#gallery-upload').addEventListener('change', async (e) => {
    const files = Array.from(e.target.files); if (!files.length) return;
    const status = $('#gallery-status');
    status.innerHTML = `<span class="spinner"></span> Uploading ${files.length} photo${files.length > 1 ? 's' : ''}…`;
    let uploaded = 0;
    for (const file of files) {
      try {
        const url = await uploadPhoto(file, slugInput.value || 'unsorted');
        hike.gallery_image_urls = [...(hike.gallery_image_urls || []), url];
        uploaded++;
        renderGallery(hike.gallery_image_urls);
      } catch (err) {
        toast(`Failed: ${file.name}`, 'error', explainError(err));
      }
    }
    status.textContent = uploaded === files.length
      ? ''
      : `Uploaded ${uploaded}/${files.length}.`;
    if (uploaded > 0) toast(`Added ${uploaded} photo${uploaded > 1 ? 's' : ''}`, 'ok');
    e.target.value = '';
  });

  function renderGallery(urls) {
    $('#gallery-preview').innerHTML = urls.map((u, i) => `
      <div class="gallery-tile">
        <img src="${resolveUrl(u)}" alt="" />
        <button type="button" data-remove-gallery="${i}" aria-label="Remove">×</button>
      </div>
    `).join('');
    $$('[data-remove-gallery]', $('#gallery-preview')).forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = parseInt(btn.getAttribute('data-remove-gallery'), 10);
        hike.gallery_image_urls.splice(idx, 1);
        renderGallery(hike.gallery_image_urls);
      });
    });
  }
  renderGallery(hike.gallery_image_urls || []);

  // Save
  $('#hike-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = $('#btn-save');
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Saving…';
    try {
      const payload = {
        slug: slugInput.value.trim(),
        title: titleInput.value.trim(),
        subtitle: $('#f-subtitle').value.trim() || null,
        hike_date: $('#f-date').value || null,
        region: $('#f-region').value.trim() || null,
        hike_type: $('#f-type').value || null,
        difficulty: $('#f-difficulty').value || null,
        tags: ($('#f-tags').value || '').split(',').map(s => s.trim()).filter(Boolean),
        intro: $('#f-intro').value.trim() || null,
        body_md: $('#f-body').value,
        hero_image_url: hike.hero_image_url || null,
        gallery_image_urls: hike.gallery_image_urls || [],
        is_featured: $('#f-featured').checked,
        is_published: $('#f-published').checked,
        display_order: parseInt($('#f-order').value, 10) || 0,
      };
      // Stamp published_at when transitioning to published
      if (payload.is_published && !hike.published_at) payload.published_at = new Date().toISOString();

      let res;
      if (isNew) {
        res = await supabase.from('site_hikes').insert(payload).select().single();
      } else {
        res = await supabase.from('site_hikes').update(payload).eq('slug', slug).select().single();
      }
      if (res.error) throw res.error;
      toast(isNew ? 'Hike created' : 'Saved', 'ok', `slug: ${res.data.slug}`);
      // If slug changed (or new), update the hash so reloads land on the correct record
      if (res.data.slug !== slug) location.hash = `#/hikes/${encodeURIComponent(res.data.slug)}`;
      else renderHikeEdit(res.data.slug);
    } catch (err) {
      toast('Save failed', 'error', explainError(err));
      btn.disabled = false;
      btn.textContent = 'Save changes';
    }
  });

  if (!isNew) {
    $('#btn-delete')?.addEventListener('click', async () => {
      if (!confirm(`Delete "${hike.title}" permanently?`)) return;
      const { error } = await supabase.from('site_hikes').delete().eq('slug', slug);
      if (error) return toast('Delete failed', 'error', explainError(error));
      toast('Deleted', 'ok');
      location.hash = '#/hikes';
    });
  }
}

// ----------------------------------------------------------------------------
// View: Products list
// ----------------------------------------------------------------------------
async function renderProductsList() {
  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>Products</h1>
        <div class="sub">The Hilltrek store catalog — what shows up on /merch/.</div>
      </div>
      <div class="page-actions">
        <a href="#/products/new" class="btn btn-primary">+ New product</a>
      </div>
    </div>

    <div id="products-list" class="list"><div class="list-empty">Loading…</div></div>
  `;

  try {
    const { data, error } = await query(
      () => supabase
        .from('site_products')
        .select('id, slug, name, category, price_cents, stock_quantity, track_inventory, is_active, is_featured, main_image_url, display_order')
        .order('display_order', { ascending: true }),
      'Products list'
    );
    if (error) throw error;

    if (!data.length) {
      $('#products-list').innerHTML = `
        <div class="list-empty">
          <h3>No products yet</h3>
          <p>Add your first product to get started.</p>
          <p style="margin-top: 18px;"><a href="#/products/new" class="btn btn-primary">+ New product</a></p>
        </div>`;
      return;
    }

    const head = `
      <div class="list-row is-head">
        <div>Photo</div>
        <div>Name</div>
        <div>Price</div>
        <div>Stock</div>
        <div>Status</div>
        <div style="text-align:right;">Actions</div>
      </div>
    `;
    const rows = data.map(p => `
      <div class="list-row">
        <div class="list-thumb">${p.main_image_url ? `<img src="${resolveUrl(p.main_image_url)}" alt="" />` : ''}</div>
        <div class="list-title">${escapeHtml(p.name)}<span class="slug">/${p.slug}${p.category ? ' · ' + escapeHtml(p.category) : ''}</span></div>
        <div class="mono">${formatPrice(p.price_cents)}</div>
        <div class="mono">${p.track_inventory ? (p.stock_quantity ?? 0) : '∞'}</div>
        <div>${p.is_active ? '<span class="pill pub">Active</span>' : '<span class="pill draft">Hidden</span>'} ${p.is_featured ? '<span class="pill feat">Featured</span>' : ''}</div>
        <div class="row-actions">
          <a href="#/products/${encodeURIComponent(p.slug)}" class="btn btn-ghost btn-sm">Edit</a>
          <button class="btn btn-danger btn-sm" data-delete-prod="${p.slug}">Delete</button>
        </div>
      </div>
    `).join('');

    $('#products-list').innerHTML = head + rows;
    $$('[data-delete-prod]', $('#products-list')).forEach(btn => {
      btn.addEventListener('click', () => onDeleteProduct(btn.getAttribute('data-delete-prod')));
    });
  } catch (err) {
    $('#products-list').innerHTML = `<div class="list-empty"><h3 class="bad">Error</h3><p>${explainError(err)}</p></div>`;
  }
}

async function onDeleteProduct(slug) {
  if (!confirm(`Delete product "${slug}" permanently?`)) return;
  try {
    const { error } = await supabase.from('site_products').delete().eq('slug', slug);
    if (error) throw error;
    toast(`Deleted "${slug}"`, 'ok');
    renderProductsList();
  } catch (err) {
    toast('Delete failed', 'error', explainError(err));
  }
}

// ----------------------------------------------------------------------------
// View: Product edit / create
// ----------------------------------------------------------------------------
async function renderProductEdit(slug) {
  const isNew = !slug;
  outlet.innerHTML = `<div class="card"><p class="muted">Loading editor…</p></div>`;

  let product = null;
  if (!isNew) {
    let res;
    try {
      res = await query(
        () => supabase.from('site_products').select('*').eq('slug', slug).maybeSingle(),
        'Load product'
      );
    } catch (err) {
      outlet.innerHTML = `<div class="card bad">Failed to load product: ${explainError(err)}</div>`;
      return;
    }
    if (res.error) { outlet.innerHTML = `<div class="card bad">${explainError(res.error)}</div>`; return; }
    if (!res.data)  { outlet.innerHTML = `<div class="card">Product not found. <a href="#/products" class="subtle-link">Back to list</a></div>`; return; }
    product = res.data;
  } else {
    product = {
      slug: '', name: '', subtitle: '', category: 'apparel',
      description_md: '', price_cents: 0, compare_at_price_cents: null,
      currency: 'ZAR', stock_quantity: 5, track_inventory: true,
      variants: [], main_image_url: '', gallery_image_urls: [],
      weight_g: null, tags: [], ribbon_text: null,
      is_active: true, is_featured: false, display_order: 0,
    };
  }

  // Convert price cents to rand for display
  const priceRand = (product.price_cents / 100).toFixed(2);
  const compareRand = product.compare_at_price_cents ? (product.compare_at_price_cents / 100).toFixed(2) : '';

  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>${isNew ? 'New product' : 'Edit product'}</h1>
        <div class="sub">${isNew ? 'Add a new merch item.' : `Editing <code>${product.slug}</code>`}</div>
      </div>
      <div class="page-actions">
        <a href="#/products" class="btn btn-ghost">← Back to list</a>
        ${!isNew ? `<a href="${SITE_PUBLIC_URL}/merch/" target="_blank" rel="noopener" class="btn btn-ghost">View live ↗</a>` : ''}
      </div>
    </div>

    <form id="product-form" class="edit-grid">
      <div class="edit-main">
        <div class="card">
          <div class="field-row">
            <div class="field">
              <label for="pf-name">Name</label>
              <input id="pf-name" type="text" required value="${escapeHtml(product.name)}" placeholder="Hiking Buff" />
            </div>
            <div class="field">
              <label for="pf-slug">Slug</label>
              <input id="pf-slug" type="text" required pattern="[a-z0-9\-]+" value="${escapeHtml(product.slug)}" placeholder="hiking-buff" />
            </div>
          </div>
          <div class="field-row" style="margin-top: 16px;">
            <div class="field">
              <label for="pf-category">Category</label>
              <select id="pf-category">
                ${['apparel','headwear','accessory','footwear','other'].map(c =>
                  `<option value="${c}" ${product.category === c ? 'selected' : ''}>${c}</option>`).join('')}
              </select>
            </div>
            <div class="field">
              <label for="pf-subtitle">Subtitle / tag line</label>
              <input id="pf-subtitle" type="text" value="${escapeHtml(product.subtitle || '')}" placeholder="Tech layer" />
            </div>
          </div>
          <div class="field" style="margin-top: 16px;">
            <label for="pf-desc">Description (Markdown)</label>
            <textarea id="pf-desc" placeholder="Describe the product…">${escapeHtml(product.description_md || '')}</textarea>
          </div>
        </div>

        <div class="card">
          <h3 style="font-size: 14px; font-weight: 600; letter-spacing: -0.01em; margin-bottom: 12px;">Variants (size / colour options)</h3>
          <p class="dim" style="font-size: 12.5px; margin-bottom: 14px;">Each row is an option group. Values are comma-separated.</p>
          <div id="variants-list"></div>
          <button type="button" id="add-variant" class="btn btn-ghost btn-sm" style="margin-top: 10px;">+ Add option group</button>
        </div>

        <div class="card">
          <h3 style="font-size: 14px; font-weight: 600; letter-spacing: -0.01em; margin-bottom: 12px;">Main image</h3>
          <div class="media-block">
            <div class="media-current" id="pmain-preview">
              ${product.main_image_url
                ? `<img src="${resolveUrl(product.main_image_url)}" alt="" />`
                : `<div class="empty">No main image yet</div>`}
            </div>
            <div class="media-upload-row">
              <label class="btn btn-ghost btn-sm">
                <input type="file" id="pmain-upload" accept="image/*" />
                Upload main image
              </label>
              <button type="button" class="btn btn-danger btn-sm" id="pmain-clear" ${product.main_image_url ? '' : 'disabled'}>Clear</button>
            </div>
            <div class="field-help" id="pmain-status"></div>
          </div>
        </div>

        <div class="card">
          <h3 style="font-size: 14px; font-weight: 600; letter-spacing: -0.01em; margin-bottom: 12px;">Gallery</h3>
          <div class="media-block">
            <div class="gallery" id="pgallery-preview"></div>
            <div class="media-upload-row">
              <label class="btn btn-ghost btn-sm">
                <input type="file" id="pgallery-upload" accept="image/*" multiple />
                + Add gallery photos
              </label>
            </div>
            <div class="field-help" id="pgallery-status"></div>
          </div>
        </div>
      </div>

      <aside class="edit-aside">
        <div class="card card-tight">
          <h3 style="font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--ember); margin-bottom: 14px;">Status</h3>
          <div class="field" style="margin-bottom: 12px;">
            <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-family: inherit; font-size: 14px; letter-spacing: 0; text-transform: none; color: var(--text);">
              <input type="checkbox" id="pf-active" ${product.is_active ? 'checked' : ''} style="accent-color: var(--ember); width: 16px; height: 16px;" />
              Active (visible on /merch/)
            </label>
          </div>
          <div class="field" style="margin-bottom: 16px;">
            <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-family: inherit; font-size: 14px; letter-spacing: 0; text-transform: none; color: var(--text);">
              <input type="checkbox" id="pf-featured" ${product.is_featured ? 'checked' : ''} style="accent-color: var(--ember); width: 16px; height: 16px;" />
              Featured (highlighted)
            </label>
          </div>
          <div class="field">
            <label for="pf-order">Display order</label>
            <input id="pf-order" type="number" value="${product.display_order || 0}" />
          </div>
          <button type="submit" class="btn btn-primary" id="pbtn-save" style="margin-top: 18px; width: 100%; justify-content: center;">Save</button>
          ${!isNew ? `<button type="button" class="btn btn-danger btn-sm" id="pbtn-delete" style="margin-top: 10px; width: 100%; justify-content: center;">Delete product</button>` : ''}
        </div>

        <div class="card card-tight">
          <h3 style="font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--ember); margin-bottom: 14px;">Pricing</h3>
          <div class="field" style="margin-bottom: 12px;">
            <label for="pf-price">Price (ZAR)</label>
            <input id="pf-price" type="number" min="0" step="0.01" required value="${priceRand}" />
          </div>
          <div class="field" style="margin-bottom: 12px;">
            <label for="pf-compare">Compare-at price (for sales)</label>
            <input id="pf-compare" type="number" min="0" step="0.01" value="${compareRand}" placeholder="leave blank if no sale" />
          </div>
          <div class="field">
            <label for="pf-ribbon">Ribbon text (optional)</label>
            <input id="pf-ribbon" type="text" value="${escapeHtml(product.ribbon_text || '')}" placeholder="SALE / Featured #1" />
          </div>
        </div>

        <div class="card card-tight">
          <h3 style="font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--ember); margin-bottom: 14px;">Inventory</h3>
          <div class="field" style="margin-bottom: 12px;">
            <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-family: inherit; font-size: 14px; letter-spacing: 0; text-transform: none; color: var(--text);">
              <input type="checkbox" id="pf-track" ${product.track_inventory ? 'checked' : ''} style="accent-color: var(--ember); width: 16px; height: 16px;" />
              Track stock
            </label>
          </div>
          <div class="field">
            <label for="pf-stock">Quantity on hand</label>
            <input id="pf-stock" type="number" min="0" value="${product.stock_quantity ?? ''}" placeholder="—" />
          </div>
          <div class="field" style="margin-top: 12px;">
            <label for="pf-weight">Weight (grams)</label>
            <input id="pf-weight" type="number" min="0" value="${product.weight_g ?? ''}" placeholder="for shipping calc" />
          </div>
        </div>

        <div class="card card-tight">
          <h3 style="font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--ember); margin-bottom: 14px;">Tags</h3>
          <div class="field">
            <label for="pf-tags">Tags (comma-separated)</label>
            <input id="pf-tags" type="text" value="${(product.tags || []).join(', ')}" placeholder="featured, tech-layer" />
          </div>
        </div>
      </aside>
    </form>
  `;

  // ===== Variants UI =====
  let variants = JSON.parse(JSON.stringify(product.variants || [])); // deep clone
  function renderVariants() {
    const el = $('#variants-list');
    el.innerHTML = variants.length === 0
      ? `<p class="dim" style="font-size: 13px; padding: 8px 0;">No options — single-variant product.</p>`
      : variants.map((v, i) => `
        <div class="field-row" style="margin-bottom: 10px; align-items: end;">
          <div class="field">
            <label>Group name (#${i + 1})</label>
            <input type="text" data-var-name="${i}" value="${escapeHtml(v.name || '')}" placeholder="Size / Colour" />
          </div>
          <div class="field" style="grid-column: span 2;">
            <label>Values (comma-separated)</label>
            <input type="text" data-var-values="${i}" value="${escapeHtml((v.values || []).join(', '))}" placeholder="S, M, L, XL" />
          </div>
          <button type="button" class="btn btn-danger btn-sm" data-var-remove="${i}" style="height: 38px;">×</button>
        </div>
      `).join('');
    // wire change handlers
    $$('[data-var-name]', el).forEach(inp => {
      inp.addEventListener('input', () => variants[parseInt(inp.dataset.varName)].name = inp.value.trim());
    });
    $$('[data-var-values]', el).forEach(inp => {
      inp.addEventListener('input', () => {
        variants[parseInt(inp.dataset.varValues)].values = inp.value.split(',').map(s => s.trim()).filter(Boolean);
      });
    });
    $$('[data-var-remove]', el).forEach(btn => {
      btn.addEventListener('click', () => {
        variants.splice(parseInt(btn.dataset.varRemove), 1);
        renderVariants();
      });
    });
  }
  renderVariants();
  $('#add-variant').addEventListener('click', () => {
    variants.push({ name: '', values: [] });
    renderVariants();
  });

  // ===== Auto-slug from name =====
  const nameInput = $('#pf-name');
  const slugInput = $('#pf-slug');
  let slugManuallyEdited = !isNew;
  slugInput.addEventListener('input', () => { slugManuallyEdited = true; });
  nameInput.addEventListener('input', () => {
    if (!slugManuallyEdited) slugInput.value = slugify(nameInput.value);
  });

  // ===== Main image upload =====
  $('#pmain-upload').addEventListener('change', async (e) => {
    const file = e.target.files[0]; if (!file) return;
    const status = $('#pmain-status');
    status.innerHTML = '<span class="spinner"></span> Uploading…';
    try {
      const url = await uploadProductPhoto(file, slugInput.value || 'unsorted');
      product.main_image_url = url;
      $('#pmain-preview').innerHTML = `<img src="${url}" alt="" />`;
      $('#pmain-clear').disabled = false;
      status.textContent = '';
      toast('Main image uploaded', 'ok');
    } catch (err) {
      status.innerHTML = `<span class="bad">${explainError(err)}</span>`;
    }
    e.target.value = '';
  });
  $('#pmain-clear').addEventListener('click', () => {
    product.main_image_url = '';
    $('#pmain-preview').innerHTML = `<div class="empty">No main image yet</div>`;
    $('#pmain-clear').disabled = true;
  });

  // ===== Gallery =====
  function renderGallery() {
    $('#pgallery-preview').innerHTML = (product.gallery_image_urls || []).map((u, i) => `
      <div class="gallery-tile">
        <img src="${resolveUrl(u)}" alt="" />
        <button type="button" data-pgallery-remove="${i}" aria-label="Remove">×</button>
      </div>
    `).join('');
    $$('[data-pgallery-remove]').forEach(btn => {
      btn.addEventListener('click', () => {
        product.gallery_image_urls.splice(parseInt(btn.dataset.pgalleryRemove), 1);
        renderGallery();
      });
    });
  }
  renderGallery();
  $('#pgallery-upload').addEventListener('change', async (e) => {
    const files = Array.from(e.target.files); if (!files.length) return;
    const status = $('#pgallery-status');
    status.innerHTML = `<span class="spinner"></span> Uploading ${files.length}…`;
    let uploaded = 0;
    for (const file of files) {
      try {
        const url = await uploadProductPhoto(file, slugInput.value || 'unsorted');
        product.gallery_image_urls = [...(product.gallery_image_urls || []), url];
        uploaded++;
        renderGallery();
      } catch (err) {
        toast(`Failed: ${file.name}`, 'error', explainError(err));
      }
    }
    status.textContent = uploaded === files.length ? '' : `Uploaded ${uploaded}/${files.length}.`;
    if (uploaded > 0) toast(`Added ${uploaded} photo${uploaded > 1 ? 's' : ''}`, 'ok');
    e.target.value = '';
  });

  // ===== Save =====
  $('#product-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = $('#pbtn-save');
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Saving…';
    try {
      const payload = {
        slug: slugInput.value.trim(),
        name: nameInput.value.trim(),
        subtitle: $('#pf-subtitle').value.trim() || null,
        category: $('#pf-category').value || null,
        description_md: $('#pf-desc').value,
        price_cents: Math.round(parseFloat($('#pf-price').value || '0') * 100),
        compare_at_price_cents: $('#pf-compare').value ? Math.round(parseFloat($('#pf-compare').value) * 100) : null,
        currency: 'ZAR',
        stock_quantity: $('#pf-stock').value ? parseInt($('#pf-stock').value, 10) : null,
        track_inventory: $('#pf-track').checked,
        variants: variants.filter(v => v.name && v.values.length > 0),
        main_image_url: product.main_image_url || null,
        gallery_image_urls: product.gallery_image_urls || [],
        weight_g: $('#pf-weight').value ? parseInt($('#pf-weight').value, 10) : null,
        tags: $('#pf-tags').value.split(',').map(s => s.trim()).filter(Boolean),
        ribbon_text: $('#pf-ribbon').value.trim() || null,
        is_active: $('#pf-active').checked,
        is_featured: $('#pf-featured').checked,
        display_order: parseInt($('#pf-order').value, 10) || 0,
      };

      let res;
      if (isNew) {
        res = await supabase.from('site_products').insert(payload).select().single();
      } else {
        res = await supabase.from('site_products').update(payload).eq('slug', slug).select().single();
      }
      if (res.error) throw res.error;
      toast(isNew ? 'Product created' : 'Saved', 'ok', `slug: ${res.data.slug}`);
      if (res.data.slug !== slug) location.hash = `#/products/${encodeURIComponent(res.data.slug)}`;
      else renderProductEdit(res.data.slug);
    } catch (err) {
      toast('Save failed', 'error', explainError(err));
      btn.disabled = false;
      btn.textContent = 'Save';
    }
  });

  if (!isNew) {
    $('#pbtn-delete')?.addEventListener('click', async () => {
      if (!confirm(`Delete "${product.name}" permanently?`)) return;
      const { error } = await supabase.from('site_products').delete().eq('slug', slug);
      if (error) return toast('Delete failed', 'error', explainError(error));
      toast('Deleted', 'ok');
      location.hash = '#/products';
    });
  }
}

// ----------------------------------------------------------------------------
// Product photo upload helper
// Uploads into website-assets/products/<slug>/...
// ----------------------------------------------------------------------------
async function uploadProductPhoto(file, slug) {
  const cleanName = file.name.toLowerCase().replace(/[^a-z0-9._-]+/g, '-');
  const path = `products/${slug || 'unsorted'}/${Date.now()}-${cleanName}`;
  const { error } = await supabase.storage
    .from(STORAGE_BUCKET)
    .upload(path, file, { upsert: false, cacheControl: '3600' });
  if (error) throw error;
  const { data } = supabase.storage.from(STORAGE_BUCKET).getPublicUrl(path);
  return data.publicUrl;
}

function formatPrice(cents) {
  if (cents == null) return '—';
  return 'R' + (cents / 100).toFixed(2);
}

// ----------------------------------------------------------------------------
// View: Security (2FA enrolment, account info)
// ----------------------------------------------------------------------------
async function renderSecurity() {
  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>Security</h1>
        <div class="sub">Two-factor authentication, session info, account.</div>
      </div>
    </div>
    <div id="security-body" class="muted">Loading…</div>
  `;
  await reloadSecurity();
}

async function reloadSecurity() {
  const body = $('#security-body');
  body.innerHTML = '<div class="card"><span class="spinner"></span> Loading…</div>';
  try {
    const { data: { user }, error: ue } = await supabase.auth.getUser();
    if (ue) throw ue;
    const { data: factors, error: fe } = await supabase.auth.mfa.listFactors();
    if (fe) throw fe;
    const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();

    const verified = (factors.totp || []).filter(f => f.status === 'verified');
    const pending  = (factors.totp || []).filter(f => f.status !== 'verified');

    body.innerHTML = `
      <div class="card">
        <h3 style="font-size: 16px; font-weight: 600; letter-spacing: -0.01em; margin-bottom: 14px;">Two-factor authentication (TOTP)</h3>
        <p class="muted" style="font-size: 14px; margin-bottom: 16px;">
          Adds a 6-digit code from your authenticator app (Google Authenticator, Authy, 1Password) on top of your password.
          ${verified.length ? '<strong class="ok">2FA is enabled.</strong>' : '<strong class="bad">2FA is not enabled.</strong>'}
        </p>

        ${verified.length ? `
          <div style="display: flex; gap: 12px; flex-wrap: wrap;">
            ${verified.map(f => `
              <div class="card-tight" style="flex: 1; min-width: 240px;">
                <div style="display: flex; align-items: center; justify-content: space-between; gap: 12px;">
                  <div>
                    <div style="font-weight: 600;">${escapeHtml(f.friendly_name || 'TOTP factor')}</div>
                    <div class="dim mono" style="font-size: 11.5px; margin-top: 2px;">Enrolled ${formatDate(f.created_at)}</div>
                  </div>
                  <button class="btn btn-danger btn-sm" data-unenroll="${f.id}">Remove</button>
                </div>
              </div>
            `).join('')}
          </div>
        ` : `
          <button id="btn-enroll-mfa" class="btn btn-primary">+ Enable 2FA</button>
        `}

        ${pending.length ? `<p class="dim" style="font-size: 12px; margin-top: 14px;">${pending.length} pending (unverified) factor(s) will be auto-cleaned next enrolment.</p>` : ''}
      </div>

      <div class="card" style="margin-top: 16px;">
        <h3 style="font-size: 16px; font-weight: 600; letter-spacing: -0.01em; margin-bottom: 14px;">Session</h3>
        <p class="muted" style="font-size: 14px;">
          Signed in as <strong>${escapeHtml(user.email)}</strong>
          ${aal ? `· Assurance level: <span class="mono">${aal.currentLevel}</span>` : ''}
        </p>
        <p class="dim" style="font-size: 12px; margin-top: 8px;">
          Sessions stay active for 1 hour and auto-refresh while you're using the admin. Sign out to invalidate the current session immediately.
        </p>
      </div>

      <div class="card" style="margin-top: 16px;">
        <h3 style="font-size: 16px; font-weight: 600; letter-spacing: -0.01em; margin-bottom: 12px;">Recovery</h3>
        <p class="muted" style="font-size: 14px; margin-bottom: 10px;">
          If you lose access to your authenticator app, you'll need to reset 2FA via the Supabase dashboard
          (Authentication → Users → your account → Remove MFA factor). Then re-enrol from this page.
        </p>
        <p class="dim" style="font-size: 12px;">
          For extra safety: when enrolling, save the secret key in a password manager so you can re-add the factor to a new device.
        </p>
      </div>
    `;

    // Wire interactions
    $('#btn-enroll-mfa')?.addEventListener('click', startEnrollment);
    $$('[data-unenroll]', body).forEach(btn => {
      btn.addEventListener('click', () => onUnenroll(btn.getAttribute('data-unenroll')));
    });
  } catch (err) {
    body.innerHTML = `<div class="card bad">Failed to load security info: ${explainError(err)}</div>`;
  }
}

async function startEnrollment() {
  // Clean up any pending unverified factors first
  try {
    const { data: factors } = await supabase.auth.mfa.listFactors();
    for (const f of (factors.totp || [])) {
      if (f.status !== 'verified') {
        await supabase.auth.mfa.unenroll({ factorId: f.id });
      }
    }
  } catch (_) {/* non-fatal */}

  let enrolled;
  try {
    const { data, error } = await supabase.auth.mfa.enroll({
      factorType: 'totp',
      friendlyName: 'Hilltrek Admin · ' + new Date().toISOString().slice(0, 10),
    });
    if (error) throw error;
    enrolled = data;
  } catch (err) {
    toast('Enrolment failed', 'error', explainError(err));
    return;
  }

  // Render the QR + secret + verification prompt as a modal overlay
  showEnrolmentDialog(enrolled);
}

function showEnrolmentDialog(enrolled) {
  // Lightweight modal — re-uses the toast-style positioning
  let modal = document.getElementById('mfa-modal');
  if (modal) modal.remove();
  modal = document.createElement('div');
  modal.id = 'mfa-modal';
  modal.style.cssText = 'position: fixed; inset: 0; z-index: 200; background: rgba(0,0,0,0.7); display: grid; place-items: center; padding: 24px;';
  modal.innerHTML = `
    <div class="card" style="max-width: 460px; width: 100%; padding: 28px;">
      <h3 style="font-size: 18px; font-weight: 700; letter-spacing: -0.01em; margin-bottom: 6px;">Set up 2FA</h3>
      <p class="muted" style="font-size: 14px; margin-bottom: 18px;">
        Scan this QR code with your authenticator app, then enter the 6-digit code it shows.
      </p>
      <div id="qr-wrap" style="background: #fff; padding: 14px; border-radius: var(--r-md); display: grid; place-items: center; margin-bottom: 14px;"></div>
      <details style="margin-bottom: 18px;">
        <summary style="cursor: pointer; font-size: 13px; color: var(--muted);">Can't scan? Enter the secret manually</summary>
        <div class="mono" style="margin-top: 10px; padding: 10px 12px; background: var(--surface-2); border-radius: var(--r-sm); font-size: 12.5px; word-break: break-all; letter-spacing: 0.06em;">${enrolled.totp.secret}</div>
      </details>
      <form id="mfa-enroll-form">
        <div class="field">
          <label for="enroll-code">Verification code</label>
          <input id="enroll-code" type="text" inputmode="numeric" pattern="[0-9]{6}" maxlength="6"
                 required autocomplete="one-time-code" placeholder="123456"
                 style="font-family: var(--font-mono); font-size: 22px; letter-spacing: 0.4em; text-align: center;" />
        </div>
        <div style="display: flex; gap: 10px; margin-top: 16px;">
          <button type="button" id="enroll-cancel" class="btn btn-ghost" style="flex: 1; justify-content: center;">Cancel</button>
          <button type="submit" class="btn btn-primary" id="enroll-submit" style="flex: 1; justify-content: center;">Enable 2FA</button>
        </div>
      </form>
    </div>
  `;
  document.body.appendChild(modal);

  // Set the QR src via DOM rather than HTML template so SVG quotes don't
  // break the surrounding attributes.
  const qrImg = document.createElement('img');
  qrImg.alt = '2FA QR code';
  qrImg.style.cssText = 'width: 200px; height: 200px; display: block;';
  qrImg.src = enrolled.totp.qr_code;
  $('#qr-wrap').appendChild(qrImg);

  setTimeout(() => $('#enroll-code')?.focus(), 60);

  $('#enroll-cancel').addEventListener('click', async () => {
    // Clean up the unverified factor
    await supabase.auth.mfa.unenroll({ factorId: enrolled.id }).catch(() => {});
    modal.remove();
  });

  $('#mfa-enroll-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const code = $('#enroll-code').value.trim();
    const btn = $('#enroll-submit');
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Verifying…';
    try {
      const { data: challenge, error: ce } = await supabase.auth.mfa.challenge({ factorId: enrolled.id });
      if (ce) throw ce;
      const { error: ve } = await supabase.auth.mfa.verify({
        factorId: enrolled.id,
        challengeId: challenge.id,
        code,
      });
      if (ve) throw ve;
      modal.remove();
      toast('2FA enabled', 'ok');
      reloadSecurity();
    } catch (err) {
      btn.disabled = false;
      btn.textContent = 'Enable 2FA';
      toast('Verification failed', 'error', explainError(err));
    }
  });
}

async function onUnenroll(factorId) {
  if (!confirm('Remove 2FA from this account?\n\nYou\'ll only need your password to sign in after this. You can re-enable 2FA at any time.')) return;
  try {
    const { error } = await supabase.auth.mfa.unenroll({ factorId });
    if (error) throw error;
    toast('2FA disabled', 'ok');
    reloadSecurity();
  } catch (err) {
    toast('Could not disable 2FA', 'error', explainError(err));
  }
}

// ----------------------------------------------------------------------------
// View: Orders list
// ----------------------------------------------------------------------------
async function renderOrdersList() {
  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>Orders</h1>
        <div class="sub">Every order placed via the merch checkout. Phase B is pending-pay only; PayFast is Phase C.</div>
      </div>
    </div>

    <div id="orders-list" class="list">
      <div class="list-empty">Loading…</div>
    </div>
  `;

  try {
    const { data, error } = await query(
      () => supabase
        .from('site_orders')
        .select('id, order_number, status, customer_name, customer_email, total_cents, created_at')
        .order('created_at', { ascending: false }),
      'Orders list'
    );
    if (error) throw error;

    if (!data.length) {
      $('#orders-list').innerHTML = `
        <div class="list-empty">
          <h3>No orders yet</h3>
          <p>Once someone checks out from <code>/merch/</code>, the order shows up here.</p>
        </div>`;
      return;
    }

    const head = `
      <div class="list-row is-head">
        <div>Order #</div>
        <div>Customer</div>
        <div>Total</div>
        <div>Status</div>
        <div>Date</div>
        <div style="text-align:right;">Actions</div>
      </div>
    `;
    const rows = data.map(o => `
      <div class="list-row" data-id="${o.id}">
        <div class="mono" style="font-weight: 600;">${escapeHtml(o.order_number)}</div>
        <div class="list-title">${escapeHtml(o.customer_name)}<span class="slug">${escapeHtml(o.customer_email)}</span></div>
        <div class="mono">${formatPrice(o.total_cents)}</div>
        <div>${statusPill(o.status)}</div>
        <div>${formatDate(o.created_at)}</div>
        <div class="row-actions">
          <a href="#/orders/${encodeURIComponent(o.id)}" class="btn btn-ghost btn-sm">View</a>
        </div>
      </div>
    `).join('');

    $('#orders-list').innerHTML = head + rows;
  } catch (err) {
    $('#orders-list').innerHTML = `<div class="list-empty"><h3 class="bad">Error</h3><p>${explainError(err)}</p></div>`;
  }
}

function statusPill(status) {
  const cls = {
    pending:   'draft',
    paid:      'pub',
    shipped:   'feat',
    cancelled: 'draft',
    refunded:  'draft',
  }[status] || 'draft';
  return `<span class="pill ${cls}">${escapeHtml(status || 'pending')}</span>`;
}

// ----------------------------------------------------------------------------
// View: Order detail
// ----------------------------------------------------------------------------
async function renderOrderDetail(id) {
  outlet.innerHTML = `<div class="card"><p class="muted">Loading order…</p></div>`;

  let order;
  let items;
  try {
    const [orderRes, itemsRes] = await Promise.all([
      query(() => supabase.from('site_orders').select('*').eq('id', id).maybeSingle(), 'Load order'),
      query(() => supabase.from('site_order_items').select('*').eq('order_id', id).order('created_at'), 'Load order items'),
    ]);
    if (orderRes.error)  throw orderRes.error;
    if (itemsRes.error)  throw itemsRes.error;
    if (!orderRes.data)  { outlet.innerHTML = `<div class="card">Order not found. <a href="#/orders" class="subtle-link">Back to list</a></div>`; return; }
    order = orderRes.data;
    items = itemsRes.data || [];
  } catch (err) {
    outlet.innerHTML = `<div class="card bad">Failed to load order: ${explainError(err)}</div>`;
    return;
  }

  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>${escapeHtml(order.order_number)}</h1>
        <div class="sub">Placed ${formatDate(order.created_at)} · ${escapeHtml(order.customer_name)} · ${escapeHtml(order.customer_email)}</div>
      </div>
      <div class="page-actions">
        <a href="#/orders" class="btn btn-ghost">← Back to orders</a>
      </div>
    </div>

    <div class="edit-grid">
      <div class="edit-main">
        <div class="card">
          <h3 style="font-size: 14px; font-weight: 600; margin-bottom: 14px;">Line items</h3>
          <div class="list" style="border: 1px solid var(--border); border-radius: var(--r-md); overflow: hidden;">
            ${items.map(it => `
              <div class="list-row" style="grid-template-columns: 64px 1fr auto auto;">
                <div class="list-thumb">${it.product_image ? `<img src="${resolveUrl(it.product_image)}" alt="" />` : ''}</div>
                <div class="list-title">${escapeHtml(it.product_name)}<span class="slug">${escapeHtml(variantSummary(it.variants))}</span></div>
                <div class="mono dim" style="text-align:right;">${formatPrice(it.unit_price_cents)} × ${it.quantity}</div>
                <div class="mono" style="font-weight: 600; text-align: right; min-width: 90px;">${formatPrice(it.line_total_cents)}</div>
              </div>
            `).join('')}
          </div>
        </div>

        <div class="card">
          <h3 style="font-size: 14px; font-weight: 600; margin-bottom: 14px;">Shipping address</h3>
          <div style="font-family: var(--font-mono); font-size: 13px; line-height: 1.7; color: var(--text);">
            ${escapeHtml(order.customer_name)}<br />
            ${escapeHtml(order.shipping_address_line1)}<br />
            ${order.shipping_address_line2 ? escapeHtml(order.shipping_address_line2) + '<br />' : ''}
            ${escapeHtml(order.shipping_city)}, ${escapeHtml(order.shipping_province)} ${escapeHtml(order.shipping_postal_code)}<br />
            <span class="dim">Phone:</span> ${escapeHtml(order.customer_phone)}
          </div>
          ${order.notes ? `<div style="margin-top: 16px; padding-top: 16px; border-top: 1px solid var(--border);"><div style="font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--muted); margin-bottom: 6px;">Notes</div><div style="color: var(--muted); font-size: 14px; line-height: 1.55;">${escapeHtml(order.notes)}</div></div>` : ''}
        </div>
      </div>

      <aside class="edit-aside">
        <div class="card card-tight">
          <h3 style="font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--ember); margin-bottom: 14px;">Status</h3>
          <div class="field" style="margin-bottom: 14px;">
            <select id="order-status" style="width: 100%; padding: 10px 14px; border-radius: var(--r-md); border: 1px solid var(--border-2); background: rgba(255,255,255,0.04); color: var(--text); font-family: inherit; font-size: 14px;">
              ${['pending','paid','shipped','cancelled','refunded'].map(s =>
                `<option value="${s}" ${order.status === s ? 'selected' : ''}>${s}</option>`).join('')}
            </select>
          </div>
          <button id="btn-save-status" class="btn btn-primary" style="width: 100%; justify-content: center;">Update status</button>
          <p class="dim" style="font-size: 11.5px; margin-top: 12px; line-height: 1.5;">
            <strong style="color: var(--text);">Current:</strong> ${statusPill(order.status)}
          </p>
        </div>

        <div class="card card-tight">
          <h3 style="font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--ember); margin-bottom: 14px;">Totals</h3>
          <div style="display: flex; justify-content: space-between; padding: 6px 0; font-size: 14px; color: var(--muted);"><span>Subtotal</span><span class="mono" style="color: var(--text);">${formatPrice(order.subtotal_cents)}</span></div>
          <div style="display: flex; justify-content: space-between; padding: 6px 0; font-size: 14px; color: var(--muted);"><span>Shipping</span><span class="mono" style="color: var(--text);">${formatPrice(order.shipping_cents)}</span></div>
          <div style="display: flex; justify-content: space-between; padding: 12px 0 0; margin-top: 8px; border-top: 1px solid var(--border); font-size: 17px; font-weight: 700;"><span>Total</span><span>${formatPrice(order.total_cents)}</span></div>
        </div>

        <div class="card card-tight">
          <h3 style="font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--ember); margin-bottom: 14px;">Customer</h3>
          <div style="font-size: 14px; line-height: 1.6;">
            <strong>${escapeHtml(order.customer_name)}</strong><br />
            <a href="mailto:${escapeHtml(order.customer_email)}" class="subtle-link" style="font-size: 13px;">${escapeHtml(order.customer_email)}</a><br />
            <a href="tel:${escapeHtml(order.customer_phone)}" class="subtle-link" style="font-size: 13px;">${escapeHtml(order.customer_phone)}</a>
          </div>
        </div>

        <div class="card card-tight">
          <h3 style="font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--ember); margin-bottom: 14px;">Payment</h3>
          ${order.payment_provider ? `
            <div style="font-size: 13px; line-height: 1.65;">
              <div><span class="dim">Provider:</span> <strong style="text-transform: capitalize;">${escapeHtml(order.payment_provider)}</strong></div>
              ${order.payment_provider_ref ? `<div><span class="dim">Reference:</span> <span class="mono" style="font-size: 12px; color: var(--text); word-break: break-all;">${escapeHtml(order.payment_provider_ref)}</span></div>` : ''}
              ${order.payment_completed_at ? `<div><span class="dim">Completed:</span> ${formatDate(order.payment_completed_at)}</div>` : ''}
            </div>
          ` : `
            <p class="dim" style="font-size: 12.5px; line-height: 1.5; margin: 0;">No payment yet. This order is awaiting PayFast confirmation, or shipping payment is being handled by email (Phase B fallback).</p>
          `}
        </div>

        <button id="btn-delete-order" class="btn btn-danger btn-sm" style="width: 100%; justify-content: center;">Delete order</button>
      </aside>
    </div>
  `;

  $('#btn-save-status').addEventListener('click', async () => {
    const newStatus = $('#order-status').value;
    if (newStatus === order.status) return toast('No change', 'info');
    const btn = $('#btn-save-status');
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Saving…';
    try {
      const { error } = await query(
        () => supabase.from('site_orders').update({ status: newStatus }).eq('id', id),
        'Update order status'
      );
      if (error) throw error;
      toast('Status updated', 'ok', `${order.status} → ${newStatus}`);
      renderOrderDetail(id);
    } catch (err) {
      toast('Save failed', 'error', explainError(err));
      btn.disabled = false;
      btn.textContent = 'Update status';
    }
  });

  $('#btn-delete-order').addEventListener('click', async () => {
    if (!confirm(`Delete ${order.order_number} permanently?\n\nThis removes the order and all line items. Cannot be undone.`)) return;
    try {
      const { error } = await supabase.from('site_orders').delete().eq('id', id);
      if (error) throw error;
      toast('Order deleted', 'ok');
      location.hash = '#/orders';
    } catch (err) {
      toast('Delete failed', 'error', explainError(err));
    }
  });
}

// Compact variant summary for display in order line items.
function variantSummary(variants) {
  if (!variants || typeof variants !== 'object') return '';
  const entries = Object.entries(variants);
  if (!entries.length) return '';
  return entries.map(([k, v]) => `${k}: ${v}`).join(' · ');
}

// ----------------------------------------------------------------------------
// View: Settings (flat shipping rate, etc.)
// ----------------------------------------------------------------------------
async function renderSettings() {
  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>Settings</h1>
        <div class="sub">Site-wide settings used by checkout and the public store.</div>
      </div>
    </div>
    <div id="settings-body"><div class="card"><p class="muted"><span class="spinner"></span> Loading settings…</p></div></div>
  `;

  let rows;
  try {
    const { data, error } = await query(
      () => supabase.from('site_settings').select('*'),
      'Load settings'
    );
    if (error) throw error;
    rows = data || [];
  } catch (err) {
    $('#settings-body').innerHTML = `<div class="card bad">${explainError(err)}</div>`;
    return;
  }

  // Pull current values with sensible defaults.
  const byKey = Object.fromEntries(rows.map(r => [r.key, r.value]));
  const shippingCents = parseInt(byKey.shipping_flat_rate_cents, 10) || 15000;
  const orderEmail = (typeof byKey.order_email_recipient === 'string')
    ? byKey.order_email_recipient
    : 'info@hilltrek.co.za';
  const maint = (byKey.maintenance_mode && typeof byKey.maintenance_mode === 'object')
    ? byKey.maintenance_mode
    : { enabled: false, message: '', eta: '' };

  $('#settings-body').innerHTML = `
    <div class="card maint-card ${maint.enabled ? 'is-on' : ''}" style="max-width: 640px; margin-bottom: 18px;">
      <div style="display:flex; align-items:flex-start; justify-content:space-between; gap:18px; margin-bottom: 14px;">
        <div>
          <h3 style="font-size: 15px; font-weight: 600; letter-spacing: -0.01em; margin-bottom: 6px;">Site availability</h3>
          <p class="muted" style="font-size: 13.5px; margin: 0;">
            Toggle this on to take <strong>hilltrek.co.za</strong> offline for everyone.
            Visitors see a maintenance screen on every page; admins keep access via <a class="subtle-link" href="${SITE_PUBLIC_URL}/?preview=1" target="_blank" rel="noopener">?preview=1</a>.
          </p>
        </div>
        <label class="switch" title="Maintenance mode">
          <input type="checkbox" id="set-maint-enabled" ${maint.enabled ? 'checked' : ''} />
          <span class="switch-track"><span class="switch-thumb"></span></span>
        </label>
      </div>
      <div id="maint-status" class="maint-status ${maint.enabled ? 'on' : 'off'}">
        ${maint.enabled
          ? '<span class="dot"></span> Maintenance mode is <strong>ON</strong> — site is offline for visitors.'
          : '<span class="dot"></span> Site is <strong>LIVE</strong> — visitors see the normal site.'}
      </div>
      <div class="field" style="margin-top: 16px;">
        <label for="set-maint-message">Visitor message</label>
        <textarea id="set-maint-message" rows="2" style="min-height: 64px; font-family: var(--font-sans); font-size: 14px;" placeholder="We’re making improvements. Back shortly.">${escapeHtml(maint.message || '')}</textarea>
        <div class="field-help">Shown on the maintenance screen. Plain text only.</div>
      </div>
      <div class="field" style="margin-top: 12px;">
        <label for="set-maint-eta">ETA (optional)</label>
        <input id="set-maint-eta" type="text" maxlength="60" placeholder="e.g. by 18:00 SAST" value="${escapeHtml(maint.eta || '')}" />
        <div class="field-help">A short phrase like "by 18:00 SAST". Leave blank to hide the ETA pill.</div>
      </div>
      <div style="display:flex; gap:10px; flex-wrap:wrap; margin-top: 18px; align-items:center;">
        <button type="button" class="btn btn-primary" id="btn-save-maint">Save site availability</button>
        <a class="btn btn-ghost" href="${SITE_PUBLIC_URL}/?preview=1" target="_blank" rel="noopener">Preview live site ↗</a>
      </div>
    </div>

    <div class="card" style="max-width: 640px;">
      <h3 style="font-size: 15px; font-weight: 600; letter-spacing: -0.01em; margin-bottom: 6px;">Shipping</h3>
      <p class="muted" style="font-size: 13.5px; margin-bottom: 18px;">
        Flat-rate shipping is added to every order at checkout. South Africa-wide.
      </p>
      <form id="settings-form">
        <div class="field-row">
          <div class="field">
            <label for="set-shipping-rand">Shipping rate (ZAR)</label>
            <input id="set-shipping-rand" type="number" min="0" step="0.01" required value="${(shippingCents / 100).toFixed(2)}" />
            <div class="field-help">Stored as ${shippingCents} cents. Enter rands (e.g. 150 = R150).</div>
          </div>
          <div class="field">
            <label for="set-email">Order notification email</label>
            <input id="set-email" type="email" value="${escapeHtml(orderEmail)}" />
            <div class="field-help">Where new-order alerts will land (Phase C wiring).</div>
          </div>
        </div>
        <button type="submit" class="btn btn-primary" id="btn-save-settings" style="margin-top: 18px;">Save settings</button>
      </form>
    </div>

    <div class="card" style="max-width: 640px; margin-top: 18px;">
      <h3 style="font-size: 15px; font-weight: 600; letter-spacing: -0.01em; margin-bottom: 6px;">Payment gateways</h3>
      <p class="muted" style="font-size: 13.5px; margin-bottom: 6px;">
        Credentials live in <strong>Supabase Edge Function Secrets</strong> — not in this database — so they never travel to the public site.
        Set them in <a href="https://supabase.com/dashboard/project/xuqmdujupbmxahyhkdwl/settings/functions" target="_blank" rel="noopener" class="subtle-link">Dashboard → Edge Functions → Secrets</a>.
      </p>
      <p class="dim" style="font-size: 12.5px; margin-bottom: 18px; line-height: 1.55;">
        The checkout tries gateways in priority order: <strong>Yoco</strong> first, then <strong>PayFast</strong>.
        Whichever has credentials configured handles the payment. If neither, checkout falls back to a "pending, we'll email you" flow.
      </p>

      <h4 style="font-size: 12.5px; font-family: var(--font-mono); letter-spacing: 0.18em; text-transform: uppercase; color: var(--ember); margin-bottom: 10px;">Yoco — recommended</h4>
      <p class="muted" style="font-size: 12.5px; margin-bottom: 10px; line-height: 1.55;">
        SA-built, fast onboarding (usually within a day). Sign up at <a href="https://www.yoco.com/za/" target="_blank" rel="noopener" class="subtle-link">yoco.com</a>, then create a webhook in their dashboard pointing to <code style="font-size: 11px;">${SUPABASE_URL}/functions/v1/yoco-webhook</code>.
      </p>
      <div style="font-family: var(--font-mono); font-size: 12.5px; line-height: 1.85; background: var(--surface-2); padding: 12px 16px; border-radius: var(--r-md); border: 1px solid var(--border); margin-bottom: 22px;">
        <div><span class="ember">YOCO_SECRET_KEY</span>     <span class="dim">— sk_test_… or sk_live_… (prefix selects env)</span></div>
        <div><span class="ember">YOCO_WEBHOOK_SECRET</span> <span class="dim">— whsec_… returned when you create the webhook</span></div>
      </div>

      <h4 style="font-size: 12.5px; font-family: var(--font-mono); letter-spacing: 0.18em; text-transform: uppercase; color: var(--ember); margin-bottom: 10px;">PayFast</h4>
      <p class="muted" style="font-size: 12.5px; margin-bottom: 10px; line-height: 1.55;">
        Industry-standard SA gateway. Verification can take a week. Sign up at <a href="https://www.payfast.co.za/" target="_blank" rel="noopener" class="subtle-link">payfast.co.za</a>.
      </p>
      <div style="font-family: var(--font-mono); font-size: 12.5px; line-height: 1.85; background: var(--surface-2); padding: 12px 16px; border-radius: var(--r-md); border: 1px solid var(--border);">
        <div><span class="ember">PAYFAST_MERCHANT_ID</span>  <span class="dim">— PayFast → Settings → Integration</span></div>
        <div><span class="ember">PAYFAST_MERCHANT_KEY</span> <span class="dim">— PayFast → Settings → Integration</span></div>
        <div><span class="ember">PAYFAST_PASSPHRASE</span>   <span class="dim">— set in PayFast dashboard (recommended)</span></div>
        <div><span class="ember">PAYFAST_MODE</span>         <span class="dim">— "sandbox" or "production"</span></div>
      </div>
    </div>
  `;

  $('#settings-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = $('#btn-save-settings');
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Saving…';
    try {
      const newShippingCents = Math.round(parseFloat($('#set-shipping-rand').value || '0') * 100);
      const newEmail = $('#set-email').value.trim();

      // Upsert both keys in parallel.
      const [r1, r2] = await Promise.all([
        supabase.from('site_settings').upsert({
          key: 'shipping_flat_rate_cents',
          value: newShippingCents,
        }, { onConflict: 'key' }),
        supabase.from('site_settings').upsert({
          key: 'order_email_recipient',
          value: newEmail,
        }, { onConflict: 'key' }),
      ]);
      if (r1.error) throw r1.error;
      if (r2.error) throw r2.error;
      toast('Settings saved', 'ok');
      renderSettings();
    } catch (err) {
      toast('Save failed', 'error', explainError(err));
      btn.disabled = false;
      btn.textContent = 'Save settings';
    }
  });

  // ---------- Site availability (maintenance mode) ----------
  // Live preview of the status pill while the toggle moves, before save.
  $('#set-maint-enabled').addEventListener('change', () => {
    const on = $('#set-maint-enabled').checked;
    const card = $('.maint-card');
    const status = $('#maint-status');
    card.classList.toggle('is-on', on);
    status.className = 'maint-status ' + (on ? 'on' : 'off');
    status.innerHTML = on
      ? '<span class="dot"></span> Maintenance mode is <strong>ON</strong> — site is offline for visitors. <em style="color:var(--dim);">(not saved yet)</em>'
      : '<span class="dot"></span> Site is <strong>LIVE</strong> — visitors see the normal site. <em style="color:var(--dim);">(not saved yet)</em>';
  });

  $('#btn-save-maint').addEventListener('click', async () => {
    const btn = $('#btn-save-maint');
    const enabled = $('#set-maint-enabled').checked;
    const message = $('#set-maint-message').value.trim();
    const eta = $('#set-maint-eta').value.trim();

    if (enabled && !confirm(
      'Take hilltrek.co.za OFFLINE for all visitors?\n\n' +
      'Everyone (except admins using ?preview=1) will see a maintenance screen ' +
      'on every page until you turn this off.'
    )) {
      $('#set-maint-enabled').checked = false;
      $('#set-maint-enabled').dispatchEvent(new Event('change'));
      return;
    }

    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Saving…';
    try {
      const { error } = await supabase.from('site_settings').upsert({
        key: 'maintenance_mode',
        value: { enabled, message, eta },
      }, { onConflict: 'key' });
      if (error) throw error;
      toast(enabled ? 'Site is now OFFLINE' : 'Site is back LIVE', 'ok',
        enabled ? 'Visitors will see the maintenance screen' : 'Maintenance screen cleared');
      renderSettings();
    } catch (err) {
      toast('Could not save', 'error', explainError(err));
      btn.disabled = false;
      btn.textContent = 'Save site availability';
    }
  });
}

// ----------------------------------------------------------------------------
// Photo upload helper
// Uploads into website-assets/hikes/<slug>/<timestamp>-<name>
// Returns the public URL.
// ----------------------------------------------------------------------------
async function uploadPhoto(file, slug) {
  // Keep filenames safe + unique
  const cleanName = file.name.toLowerCase().replace(/[^a-z0-9._-]+/g, '-');
  const path = `${HIKE_PHOTOS_PREFIX}/${slug || 'unsorted'}/${Date.now()}-${cleanName}`;
  const { error } = await supabase.storage
    .from(STORAGE_BUCKET)
    .upload(path, file, { upsert: false, cacheControl: '3600' });
  if (error) throw error;
  const { data } = supabase.storage.from(STORAGE_BUCKET).getPublicUrl(path);
  return data.publicUrl;
}

// ----------------------------------------------------------------------------
// URL helper — supports both Supabase public URLs and legacy /assets paths
// (the seeded hikes use site-local paths so old photos still render in admin).
// ----------------------------------------------------------------------------
function resolveUrl(u) {
  if (!u) return '';
  if (u.startsWith('http://') || u.startsWith('https://')) return u;
  if (u.startsWith('/')) return SITE_PUBLIC_URL + u;
  return u;
}

// ----------------------------------------------------------------------------
// Small utilities
// ----------------------------------------------------------------------------
function slugify(s) {
  return s.toLowerCase()
    .replace(/[''""]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}
function escapeHtml(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}
function formatDate(d) {
  if (!d) return '';
  try {
    return new Date(d).toLocaleDateString('en-ZA', { year: 'numeric', month: 'short', day: 'numeric' }).toUpperCase();
  } catch { return d; }
}

// ============================================================================
// Phase D views: Subscribers, Analytics, Health, Audit Log
// ============================================================================

// ----------------------------------------------------------------------------
// View: Subscribers (D1c)
// ----------------------------------------------------------------------------
async function renderSubscribers() {
  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>Subscribers</h1>
        <div class="sub">Mailing list opt-ins from the public site.</div>
      </div>
      <div class="page-actions">
        <button id="subs-export" class="btn btn-ghost">↓ Export CSV</button>
      </div>
    </div>
    <div id="subs-stats" class="stat-row">
      <div class="stat"><div class="label">Loading…</div><div class="num">—</div></div>
    </div>
    <div class="card">
      <div style="display:flex;gap:10px;align-items:center;margin-bottom:14px;flex-wrap:wrap;">
        <input id="subs-search" type="search" placeholder="Search email or tag…" style="flex:1;min-width:240px;padding:8px 12px;border-radius:6px;border:1px solid var(--border);background:var(--bg-2);color:var(--text);" />
        <select id="subs-filter" style="padding:8px 12px;border-radius:6px;border:1px solid var(--border);background:var(--bg-2);color:var(--text);">
          <option value="all">All</option>
          <option value="confirmed">Confirmed only</option>
          <option value="pending">Pending confirmation</option>
          <option value="unsubscribed">Unsubscribed</option>
        </select>
      </div>
      <div id="subs-list">Loading…</div>
    </div>
  `;

  let rows = [];
  try {
    const { data, error } = await query(
      () => supabase.from('site_subscribers').select('*').order('created_at', { ascending: false }).limit(2000),
      'Load subscribers'
    );
    if (error) throw error;
    rows = data || [];
  } catch (err) {
    $('#subs-list').innerHTML = `<p class="muted">Could not load: ${escapeHtml(explainError(err))}</p>`;
    return;
  }

  const total = rows.length;
  const confirmed = rows.filter(r => r.confirmed_at && !r.unsubscribed_at).length;
  const pending = rows.filter(r => !r.confirmed_at && !r.unsubscribed_at).length;
  const unsub = rows.filter(r => r.unsubscribed_at).length;
  const since7 = new Date(Date.now() - 7 * 86400000).toISOString();
  const last7 = rows.filter(r => r.created_at > since7).length;
  $('#subs-stats').innerHTML = `
    <div class="stat"><div class="label">Total</div><div class="num">${total}</div></div>
    <div class="stat"><div class="label">Confirmed</div><div class="num">${confirmed}</div></div>
    <div class="stat"><div class="label">Pending</div><div class="num">${pending}</div></div>
    <div class="stat"><div class="label">Unsubscribed</div><div class="num">${unsub}</div></div>
    <div class="stat"><div class="label">Last 7 days</div><div class="num">${last7}</div></div>
  `;

  const renderList = () => {
    const q = $('#subs-search').value.toLowerCase().trim();
    const f = $('#subs-filter').value;
    const filtered = rows.filter(r => {
      if (f === 'confirmed' && !(r.confirmed_at && !r.unsubscribed_at)) return false;
      if (f === 'pending' && !(!r.confirmed_at && !r.unsubscribed_at)) return false;
      if (f === 'unsubscribed' && !r.unsubscribed_at) return false;
      if (q) {
        const hit = r.email.toLowerCase().includes(q) || (r.tags || []).some(t => t.toLowerCase().includes(q));
        if (!hit) return false;
      }
      return true;
    });
    if (filtered.length === 0) {
      $('#subs-list').innerHTML = `<p class="muted">No subscribers match.</p>`;
      return;
    }
    $('#subs-list').innerHTML = `
      <table style="width:100%;border-collapse:collapse;">
        <thead><tr style="text-align:left;border-bottom:1px solid var(--border);font-size:11px;color:var(--muted);text-transform:uppercase;letter-spacing:0.05em;">
          <th style="padding:8px 6px;">Email</th>
          <th style="padding:8px 6px;">Source</th>
          <th style="padding:8px 6px;">Country</th>
          <th style="padding:8px 6px;">Status</th>
          <th style="padding:8px 6px;">Signed up</th>
          <th style="padding:8px 6px;text-align:right;">Actions</th>
        </tr></thead>
        <tbody>
        ${filtered.map(r => {
          const status = r.unsubscribed_at ? '<span style="color:#888;">unsubscribed</span>' :
            (r.confirmed_at ? '<span style="color:#5ac26d;">confirmed</span>' : '<span style="color:#e0a847;">pending</span>');
          return `<tr style="border-bottom:1px solid var(--border);">
            <td style="padding:10px 6px;">${escapeHtml(r.email)}</td>
            <td style="padding:10px 6px;font-size:12px;color:var(--muted);">${escapeHtml(r.source)}</td>
            <td style="padding:10px 6px;font-size:12px;">${escapeHtml(r.ip_country || '—')}</td>
            <td style="padding:10px 6px;font-size:12px;">${status}</td>
            <td style="padding:10px 6px;font-size:12px;color:var(--muted);">${formatDate(r.created_at)}</td>
            <td style="padding:10px 6px;text-align:right;">
              <button data-del="${r.id}" class="btn btn-ghost btn-sm">Delete</button>
            </td>
          </tr>`;
        }).join('')}
        </tbody>
      </table>
    `;
    $$('[data-del]', $('#subs-list')).forEach(btn => {
      btn.addEventListener('click', async () => {
        const id = btn.dataset.del;
        if (!confirm('Delete this subscriber permanently?')) return;
        try {
          const { error } = await query(
            () => supabase.from('site_subscribers').delete().eq('id', id),
            'Delete subscriber'
          );
          if (error) throw error;
          rows = rows.filter(r => r.id !== id);
          renderList();
          toast('Deleted', 'ok');
        } catch (err) {
          toast('Could not delete', 'error', explainError(err));
        }
      });
    });
  };

  $('#subs-search').addEventListener('input', renderList);
  $('#subs-filter').addEventListener('change', renderList);
  $('#subs-export').addEventListener('click', () => {
    const header = 'email,source,country,tags,confirmed_at,unsubscribed_at,created_at\n';
    const lines = rows.map(r => [
      r.email, r.source, r.ip_country || '',
      (r.tags || []).join('|'),
      r.confirmed_at || '', r.unsubscribed_at || '', r.created_at,
    ].map(v => '"' + String(v).replace(/"/g, '""') + '"').join(','));
    const csv = header + lines.join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `subscribers-${new Date().toISOString().slice(0,10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  });

  renderList();
}

// ----------------------------------------------------------------------------
// View: Analytics (D5b)
// ----------------------------------------------------------------------------
async function renderAnalytics() {
  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>Analytics</h1>
        <div class="sub">Self-hosted pageview tracking. Last 30 days.</div>
      </div>
    </div>
    <div id="ana-stats" class="stat-row"><div class="stat"><div class="label">Loading…</div><div class="num">—</div></div></div>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:14px;margin-top:18px;">
      <div class="card"><h3 style="font-size:14px;margin-bottom:14px;letter-spacing:-0.01em;">Top pages</h3><div id="ana-pages">Loading…</div></div>
      <div class="card"><h3 style="font-size:14px;margin-bottom:14px;letter-spacing:-0.01em;">Top countries</h3><div id="ana-countries">Loading…</div></div>
      <div class="card"><h3 style="font-size:14px;margin-bottom:14px;letter-spacing:-0.01em;">Top referrers</h3><div id="ana-refs">Loading…</div></div>
      <div class="card"><h3 style="font-size:14px;margin-bottom:14px;letter-spacing:-0.01em;">Devices</h3><div id="ana-devices">Loading…</div></div>
    </div>
  `;

  let events = [];
  try {
    const since = new Date(Date.now() - 30 * 86400000).toISOString();
    const { data, error } = await query(
      () => supabase.from('site_analytics_events').select('*').gte('ts', since).order('ts', { ascending: false }).limit(10000),
      'Load analytics'
    );
    if (error) throw error;
    events = data || [];
  } catch (err) {
    $('#ana-stats').innerHTML = `<div class="stat"><div class="label">Error</div><div class="num" style="font-size:13px;color:#ff6b6b;">${escapeHtml(explainError(err))}</div></div>`;
    return;
  }

  if (events.length === 0) {
    $('#ana-stats').innerHTML = `<div class="stat"><div class="label">Total events</div><div class="num">0</div></div>`;
    $('#ana-pages').innerHTML = '<p class="muted">No data yet. Visit hilltrek.co.za to generate the first event.</p>';
    $('#ana-countries').innerHTML = '<p class="muted">—</p>';
    $('#ana-refs').innerHTML = '<p class="muted">—</p>';
    $('#ana-devices').innerHTML = '<p class="muted">—</p>';
    return;
  }

  const now = Date.now();
  const today = events.filter(e => now - new Date(e.ts).getTime() < 86400000).length;
  const last7 = events.filter(e => now - new Date(e.ts).getTime() < 7 * 86400000).length;
  const uniqueSessions = new Set(events.map(e => e.session_id)).size;
  const uniqueVisitors = new Set(events.map(e => e.ua_hash)).size;

  $('#ana-stats').innerHTML = `
    <div class="stat"><div class="label">Events (30d)</div><div class="num">${events.length}</div></div>
    <div class="stat"><div class="label">Last 7 days</div><div class="num">${last7}</div></div>
    <div class="stat"><div class="label">Today</div><div class="num">${today}</div></div>
    <div class="stat"><div class="label">Unique sessions</div><div class="num">${uniqueSessions}</div></div>
    <div class="stat"><div class="label">Unique visitors</div><div class="num">${uniqueVisitors}</div></div>
  `;

  const tally = (key) => {
    const m = new Map();
    events.forEach(e => {
      const v = e[key] || '—';
      m.set(v, (m.get(v) || 0) + 1);
    });
    return [...m.entries()].sort((a,b) => b[1] - a[1]).slice(0, 10);
  };
  const renderTally = (rows) => {
    if (rows.length === 0) return '<p class="muted">—</p>';
    const max = rows[0][1];
    return `<table style="width:100%;font-size:13px;table-layout:fixed;">${rows.map(([k,v]) => `<tr>
      <td style="padding:4px 6px 4px 0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${escapeHtml(String(k))}</td>
      <td style="padding:4px 0;text-align:right;color:var(--muted);width:50px;">${v}</td>
      <td style="padding:4px 0 4px 8px;width:55%;"><div style="background:var(--accent,#ff7a1a);height:6px;border-radius:3px;width:${Math.round(v/max*100)}%;"></div></td>
    </tr>`).join('')}</table>`;
  };

  $('#ana-pages').innerHTML = renderTally(tally('path'));
  $('#ana-countries').innerHTML = renderTally(tally('country'));
  $('#ana-refs').innerHTML = renderTally(tally('referrer'));
  $('#ana-devices').innerHTML = renderTally(tally('device_type'));
}

// ----------------------------------------------------------------------------
// View: Health (D4)
// ----------------------------------------------------------------------------
async function renderHealth() {
  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>Site Health</h1>
        <div class="sub">Uptime + latency probes. Last 7 days.</div>
      </div>
    </div>
    <div id="hl-stats" class="stat-row"><div class="stat"><div class="label">Loading…</div><div class="num">—</div></div></div>
    <div class="card" style="margin-top:18px;">
      <h3 style="font-size:14px;margin-bottom:14px;letter-spacing:-0.01em;">Recent incidents (last 50 failures)</h3>
      <div id="hl-incidents">Loading…</div>
    </div>
  `;

  let checks = [];
  try {
    const since = new Date(Date.now() - 7 * 86400000).toISOString();
    const { data, error } = await query(
      () => supabase.from('site_health_checks').select('*').gte('ts', since).order('ts', { ascending: false }).limit(50000),
      'Load health checks'
    );
    if (error) throw error;
    checks = data || [];
  } catch (err) {
    $('#hl-stats').innerHTML = `<div class="stat"><div class="label">Error</div><div class="num" style="font-size:13px;color:#ff6b6b;">${escapeHtml(explainError(err))}</div></div>`;
    return;
  }

  if (checks.length === 0) {
    $('#hl-stats').innerHTML = `<div class="stat"><div class="label">No checks yet</div><div class="num">—</div></div>`;
    $('#hl-incidents').innerHTML = '<p class="muted">Health pinger has not run yet. Schedule the pg_cron job (see CRON_SECRET setup in Supabase secrets).</p>';
    return;
  }

  const endpoints = [...new Set(checks.map(c => c.endpoint))];
  const stats = endpoints.map(ep => {
    const epChecks = checks.filter(c => c.endpoint === ep);
    const ok = epChecks.filter(c => c.ok).length;
    const uptimePct = (ok / epChecks.length * 100).toFixed(2);
    const latencies = epChecks.filter(c => c.ok).map(c => c.latency_ms);
    const avgLatency = latencies.length ? Math.round(latencies.reduce((a,b)=>a+b,0) / latencies.length) : 0;
    return { ep, total: epChecks.length, ok, uptimePct, avgLatency };
  });
  $('#hl-stats').innerHTML = stats.map(s => `
    <div class="stat">
      <div class="label">${escapeHtml(s.ep)} uptime (7d)</div>
      <div class="num" style="color:${s.uptimePct >= 99.5 ? '#5ac26d' : (s.uptimePct >= 95 ? '#e0a847' : '#ff6b6b')};">${s.uptimePct}%</div>
      <div class="muted" style="font-size:11px;margin-top:4px;">${s.ok}/${s.total} checks · avg ${s.avgLatency}ms</div>
    </div>
  `).join('');

  const incidents = checks.filter(c => !c.ok).slice(0, 50);
  if (incidents.length === 0) {
    $('#hl-incidents').innerHTML = '<p class="muted">No failures in the last 7 days. 🎉</p>';
    return;
  }
  $('#hl-incidents').innerHTML = `
    <table style="width:100%;font-size:13px;border-collapse:collapse;">
      <thead><tr style="text-align:left;border-bottom:1px solid var(--border);font-size:11px;color:var(--muted);text-transform:uppercase;letter-spacing:0.05em;">
        <th style="padding:8px 6px;">When</th>
        <th style="padding:8px 6px;">Endpoint</th>
        <th style="padding:8px 6px;">Status</th>
        <th style="padding:8px 6px;">Latency</th>
        <th style="padding:8px 6px;">Error</th>
      </tr></thead>
      <tbody>
      ${incidents.map(c => `<tr style="border-bottom:1px solid var(--border);">
        <td style="padding:8px 6px;color:var(--muted);white-space:nowrap;">${new Date(c.ts).toLocaleString('en-ZA')}</td>
        <td style="padding:8px 6px;">${escapeHtml(c.endpoint)}</td>
        <td style="padding:8px 6px;">${c.status_code ?? '—'}</td>
        <td style="padding:8px 6px;">${c.latency_ms}ms</td>
        <td style="padding:8px 6px;color:#ff6b6b;">${escapeHtml(c.error || '')}</td>
      </tr>`).join('')}
      </tbody>
    </table>
  `;
}

// ----------------------------------------------------------------------------
// View: Audit Log (D2)
// ----------------------------------------------------------------------------
async function renderAuditLog() {
  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>Audit Log</h1>
        <div class="sub">Every admin action on hikes, products, orders, settings, admin users, and subscribers.</div>
      </div>
    </div>
    <div class="card">
      <div style="display:flex;gap:10px;margin-bottom:14px;flex-wrap:wrap;">
        <select id="audit-resource" style="padding:8px 12px;border-radius:6px;border:1px solid var(--border);background:var(--bg-2);color:var(--text);">
          <option value="all">All tables</option>
          <option value="site_hikes">Hikes</option>
          <option value="site_products">Products</option>
          <option value="site_orders">Orders</option>
          <option value="site_subscribers">Subscribers</option>
          <option value="site_settings">Settings</option>
          <option value="admin_users">Admin users</option>
        </select>
        <select id="audit-action" style="padding:8px 12px;border-radius:6px;border:1px solid var(--border);background:var(--bg-2);color:var(--text);">
          <option value="all">All actions</option>
          <option value="insert">Insert</option>
          <option value="update">Update</option>
          <option value="delete">Delete</option>
        </select>
      </div>
      <div id="audit-list">Loading…</div>
    </div>
    <div id="audit-modal" class="hide" style="position:fixed;inset:0;background:rgba(0,0,0,0.6);z-index:200;display:flex;align-items:center;justify-content:center;padding:20px;">
      <div style="background:var(--bg);border:1px solid var(--border);border-radius:8px;max-width:900px;max-height:80vh;width:100%;overflow:auto;padding:20px;">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;">
          <h3 id="audit-modal-title" style="font-size:16px;letter-spacing:-0.01em;">Change detail</h3>
          <button id="audit-modal-close" class="btn btn-ghost btn-sm">Close</button>
        </div>
        <div id="audit-modal-body" style="font-family:var(--font-mono);font-size:12px;"></div>
      </div>
    </div>
  `;

  let rows = [];
  try {
    const { data, error } = await query(
      () => supabase.from('admin_audit_log').select('*').order('created_at', { ascending: false }).limit(500),
      'Load audit log'
    );
    if (error) throw error;
    rows = data || [];
  } catch (err) {
    $('#audit-list').innerHTML = `<p class="muted">Could not load: ${escapeHtml(explainError(err))}</p>`;
    return;
  }

  const renderList = () => {
    const r = $('#audit-resource').value;
    const a = $('#audit-action').value;
    const filtered = rows.filter(row => {
      if (r !== 'all' && row.resource_type !== r) return false;
      if (a !== 'all' && row.action !== a) return false;
      return true;
    });
    if (filtered.length === 0) {
      $('#audit-list').innerHTML = '<p class="muted">No entries match.</p>';
      return;
    }
    $('#audit-list').innerHTML = `
      <table style="width:100%;font-size:13px;border-collapse:collapse;">
        <thead><tr style="text-align:left;border-bottom:1px solid var(--border);font-size:11px;color:var(--muted);text-transform:uppercase;letter-spacing:0.05em;">
          <th style="padding:8px 6px;">When</th>
          <th style="padding:8px 6px;">Actor</th>
          <th style="padding:8px 6px;">Action</th>
          <th style="padding:8px 6px;">Resource</th>
          <th style="padding:8px 6px;">ID</th>
          <th style="padding:8px 6px;"></th>
        </tr></thead>
        <tbody>
        ${filtered.map(row => `<tr style="border-bottom:1px solid var(--border);">
          <td style="padding:8px 6px;color:var(--muted);white-space:nowrap;">${new Date(row.created_at).toLocaleString('en-ZA')}</td>
          <td style="padding:8px 6px;font-size:12px;">${escapeHtml(row.actor_email || row.actor_id || 'system')}</td>
          <td style="padding:8px 6px;"><span style="font-size:11px;padding:2px 8px;border-radius:4px;background:${row.action==='insert'?'rgba(90,194,109,0.15)':row.action==='delete'?'rgba(255,107,107,0.15)':'rgba(224,168,71,0.15)'};">${escapeHtml(row.action)}</span></td>
          <td style="padding:8px 6px;font-family:var(--font-mono);font-size:12px;">${escapeHtml(row.resource_type)}</td>
          <td style="padding:8px 6px;font-family:var(--font-mono);font-size:11px;color:var(--muted);">${escapeHtml((row.resource_id || '').slice(0,8))}</td>
          <td style="padding:8px 6px;text-align:right;"><button data-view="${row.id}" class="btn btn-ghost btn-sm">View →</button></td>
        </tr>`).join('')}
        </tbody>
      </table>
    `;
    $$('[data-view]', $('#audit-list')).forEach(b => {
      b.addEventListener('click', () => {
        const row = rows.find(r => r.id === Number(b.dataset.view));
        if (!row) return;
        $('#audit-modal-title').textContent = `${row.action} on ${row.resource_type} (${(row.resource_id||'').slice(0,8)})`;
        $('#audit-modal-body').innerHTML = `
          <div style="margin-bottom:14px;color:var(--muted);font-family:var(--font-sans);font-size:12px;">${new Date(row.created_at).toLocaleString('en-ZA')} · ${escapeHtml(row.actor_email || row.actor_id || 'system')}</div>
          ${row.payload_before ? `<div style="margin-bottom:10px;"><strong style="font-family:var(--font-sans);font-size:12px;color:#ff6b6b;">BEFORE</strong></div><pre style="background:var(--bg-2);padding:12px;border-radius:6px;overflow-x:auto;white-space:pre-wrap;word-break:break-all;">${escapeHtml(JSON.stringify(row.payload_before, null, 2))}</pre>` : ''}
          ${row.payload_after ? `<div style="margin:14px 0 10px;"><strong style="font-family:var(--font-sans);font-size:12px;color:#5ac26d;">AFTER</strong></div><pre style="background:var(--bg-2);padding:12px;border-radius:6px;overflow-x:auto;white-space:pre-wrap;word-break:break-all;">${escapeHtml(JSON.stringify(row.payload_after, null, 2))}</pre>` : ''}
        `;
        $('#audit-modal').classList.remove('hide');
      });
    });
  };

  $('#audit-resource').addEventListener('change', renderList);
  $('#audit-action').addEventListener('change', renderList);
  $('#audit-modal-close').addEventListener('click', () => $('#audit-modal').classList.add('hide'));
  $('#audit-modal').addEventListener('click', e => { if (e.target.id === 'audit-modal') $('#audit-modal').classList.add('hide'); });
  renderList();
}

// ============================================================================
// Phase D3 views: Newsletters (list, compose, detail)
// ============================================================================

function newsletterStatusBadge(status) {
  var colors = {
    draft:     'rgba(180,180,180,0.18)',
    queued:    'rgba(224,168,71,0.18)',
    sending:   'rgba(90,176,224,0.22)',
    sent:      'rgba(90,194,109,0.18)',
    failed:    'rgba(255,107,107,0.20)',
    cancelled: 'rgba(180,180,180,0.18)',
  };
  return '<span style="font-size:11px;padding:2px 10px;border-radius:4px;background:' + (colors[status] || colors.draft) + ';">' + escapeHtml(status) + '</span>';
}

// ----------------------------------------------------------------------------
// View: Newsletters list (D3b)
// ----------------------------------------------------------------------------
async function renderNewslettersList() {
  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>Newsletters</h1>
        <div class="sub">Mailing list broadcasts. Sends go via Aserv SMTP at ~10/sec.</div>
      </div>
      <div class="page-actions">
        <a href="#/newsletters/new" class="btn btn-primary">+ New newsletter</a>
      </div>
    </div>
    <div id="nl-stats" class="stat-row"><div class="stat"><div class="label">Loading…</div><div class="num">—</div></div></div>
    <div class="card">
      <div id="nl-list">Loading…</div>
    </div>
  `;

  let rows = [];
  try {
    const { data, error } = await query(
      () => supabase.from('site_newsletters').select('*').order('created_at', { ascending: false }).limit(200),
      'Load newsletters'
    );
    if (error) throw error;
    rows = data || [];
  } catch (err) {
    $('#nl-list').innerHTML = `<p class="muted">Could not load: ${escapeHtml(explainError(err))}</p>`;
    return;
  }

  const sentRows = rows.filter(r => r.status === 'sent');
  const totalSent = sentRows.reduce((a, r) => a + (r.sent_count || 0), 0);
  const totalFailed = sentRows.reduce((a, r) => a + (r.failed_count || 0), 0);

  $('#nl-stats').innerHTML = `
    <div class="stat"><div class="label">Total newsletters</div><div class="num">${rows.length}</div></div>
    <div class="stat"><div class="label">Sent</div><div class="num">${sentRows.length}</div></div>
    <div class="stat"><div class="label">Drafts</div><div class="num">${rows.filter(r => r.status === 'draft').length}</div></div>
    <div class="stat"><div class="label">Total emails sent</div><div class="num">${totalSent}</div></div>
    <div class="stat"><div class="label">Failures</div><div class="num" style="color:${totalFailed ? '#ff6b6b' : 'inherit'};">${totalFailed}</div></div>
  `;

  if (rows.length === 0) {
    $('#nl-list').innerHTML = '<p class="muted">No newsletters yet. Click "New newsletter" to compose your first.</p>';
    return;
  }

  $('#nl-list').innerHTML = `
    <table style="width:100%;font-size:13px;border-collapse:collapse;">
      <thead><tr style="text-align:left;border-bottom:1px solid var(--border);font-size:11px;color:var(--muted);text-transform:uppercase;letter-spacing:0.05em;">
        <th style="padding:8px 6px;">Subject</th>
        <th style="padding:8px 6px;">Status</th>
        <th style="padding:8px 6px;">Recipients</th>
        <th style="padding:8px 6px;">Sent</th>
        <th style="padding:8px 6px;">Failed</th>
        <th style="padding:8px 6px;">Sent at</th>
        <th style="padding:8px 6px;text-align:right;"></th>
      </tr></thead>
      <tbody>
      ${rows.map(r => `<tr style="border-bottom:1px solid var(--border);">
        <td style="padding:10px 6px;"><a href="#/newsletters/${r.id}" class="subtle-link">${escapeHtml(r.subject || '(no subject)')}</a></td>
        <td style="padding:10px 6px;">${newsletterStatusBadge(r.status)}</td>
        <td style="padding:10px 6px;color:var(--muted);">${r.recipient_count ?? '—'}</td>
        <td style="padding:10px 6px;color:#5ac26d;">${r.sent_count || 0}</td>
        <td style="padding:10px 6px;color:${r.failed_count ? '#ff6b6b' : 'var(--muted)'};">${r.failed_count || 0}</td>
        <td style="padding:10px 6px;color:var(--muted);font-size:12px;">${r.sent_at ? formatDate(r.sent_at) : '—'}</td>
        <td style="padding:10px 6px;text-align:right;">
          ${r.status === 'draft' ? `<a href="#/newsletters/${r.id}/edit" class="btn btn-ghost btn-sm">Edit</a>` : `<a href="#/newsletters/${r.id}" class="btn btn-ghost btn-sm">View →</a>`}
        </td>
      </tr>`).join('')}
      </tbody>
    </table>
  `;
}

// ----------------------------------------------------------------------------
// Newsletter helpers: cursor-insert, preview chrome, image upload
// ----------------------------------------------------------------------------

// Insert text at the current cursor position of a textarea, then re-trigger
// 'input' so the live preview updates.
function insertAtCursor(el, text) {
  const start = el.selectionStart || 0;
  const end = el.selectionEnd || 0;
  el.value = el.value.substring(0, start) + text + el.value.substring(end);
  const newPos = start + text.length;
  el.selectionStart = el.selectionEnd = newPos;
  el.focus();
  el.dispatchEvent(new Event('input', { bubbles: true }));
}

// Wrap body HTML in the same chrome the real email uses, so the admin preview
// is true WYSIWYG (logo, header, footer, unsubscribe placeholder).
function wrapEmailPreview(bodyHtml) {
  return `<div style="background:#f5f4f1;padding:18px;border-radius:6px;">
    <div style="max-width:600px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;font-family:-apple-system,BlinkMacSystemFont,sans-serif;color:#222;line-height:1.7;box-shadow:0 1px 3px rgba(0,0,0,0.04);">
      <div style="background:#0a0908;padding:32px 24px;text-align:center;">
        <img src="https://hilltrek.co.za/assets/img/logo.png" width="64" height="64" alt="Hilltrek" style="display:block;margin:0 auto 14px;border:0;">
        <span style="color:#ff7a1a;font-size:11px;letter-spacing:0.45em;font-weight:700;display:block;">// HILLTREK</span>
        <span style="color:#7a7670;font-size:11px;letter-spacing:0.15em;display:block;margin-top:4px;">Drakensberg-rooted hikers</span>
      </div>
      <div style="padding:36px 36px 28px;font-size:15.5px;line-height:1.7;color:#222;">${bodyHtml}</div>
      <div style="padding:0 36px 28px;">
        <hr style="border:none;border-top:1px solid #eee;margin:0 0 20px;">
        <p style="margin:0;font-size:12px;color:#999;">You're getting this because you subscribed at hilltrek.co.za. <a style="color:#888;text-decoration:underline;">Unsubscribe</a> anytime.</p>
      </div>
      <div style="padding:18px;text-align:center;background:#fafaf8;">
        <p style="margin:0;font-size:11px;color:#aaa;">Hilltrek (Pty) Ltd · Drakensberg, South Africa</p>
      </div>
    </div>
  </div>`;
}

// Upload an image file to website-assets/newsletters/ and return the public URL.
async function uploadNewsletterImage(file) {
  const ext = (file.name.split('.').pop() || 'jpg').toLowerCase().replace(/[^a-z0-9]/g, '') || 'jpg';
  const slug = (slugify(file.name.replace(/\.[^.]+$/, '')) || 'image').slice(0, 60);
  const path = `newsletters/${Date.now()}-${slug}.${ext}`;
  const { error: upErr } = await supabase.storage.from(STORAGE_BUCKET).upload(path, file, {
    contentType: file.type || 'image/jpeg',
    cacheControl: '604800',
    upsert: false,
  });
  if (upErr) throw upErr;
  const { data } = supabase.storage.from(STORAGE_BUCKET).getPublicUrl(path);
  return data.publicUrl;
}

// Email-safe HTML snippets the toolbar can insert
const NL_SNIPPETS = {
  button: '\n\n<p style="text-align:center;margin:28px 0;"><a href="https://hilltrek.co.za" style="display:inline-block;padding:14px 32px;background:#ff7a1a;color:#0a0908;text-decoration:none;font-weight:700;border-radius:8px;font-size:15px;">Click here →</a></p>\n\n',
  divider: '\n\n<hr style="border:none;border-top:1px solid #eee;margin:28px 0;">\n\n',
  twoCol: '\n\n<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:18px 0;"><tr><td valign="top" width="50%" style="padding:0 10px 0 0;">**Left column** — write here.</td><td valign="top" width="50%" style="padding:0 0 0 10px;">**Right column** — write here.</td></tr></table>\n\n',
  quote: '\n\n<blockquote style="border-left:4px solid #ff7a1a;padding:8px 16px;margin:22px 0;background:#fafaf8;color:#555;font-style:italic;">"Your quote here."</blockquote>\n\n',
  signature: '\n\n— Matt @ Hilltrek\n[hilltrek.co.za](https://hilltrek.co.za)\n',
};

// ----------------------------------------------------------------------------
// View: Newsletter compose / edit (D3b)
// ----------------------------------------------------------------------------
async function renderNewsletterEdit(id) {
  let nl = {
    id: null,
    subject: '',
    body_md: '# Hello fellow hikers,\n\nWelcome to the first Hilltrek newsletter…\n',
    body_html: '',
    segment_filter: { confirmed_only: true, source: null, tags: [] },
    status: 'draft',
  };

  if (id) {
    try {
      const { data, error } = await query(
        () => supabase.from('site_newsletters').select('*').eq('id', id).single(),
        'Load newsletter'
      );
      if (error) throw error;
      if (data.status !== 'draft') {
        toast('Newsletter is locked', 'error', 'Status is ' + data.status + ' — cannot edit.');
        location.hash = '#/newsletters/' + id;
        return;
      }
      nl = data;
      nl.segment_filter = nl.segment_filter || { confirmed_only: true, source: null, tags: [] };
    } catch (err) {
      outlet.innerHTML = '<div class="card"><p>Could not load: ' + escapeHtml(explainError(err)) + '</p></div>';
      return;
    }
  }

  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1>${id ? 'Edit newsletter' : 'New newsletter'}</h1>
        <div class="sub">Markdown body with inline HTML support. Live preview shows what subscribers will see.</div>
      </div>
      <div class="page-actions">
        <a href="#/newsletters" class="btn btn-ghost">← All newsletters</a>
      </div>
    </div>

    <div class="card" style="margin-bottom:14px;">
      <div class="field">
        <label for="nl-subject">Subject</label>
        <input id="nl-subject" type="text" placeholder="What's this newsletter about?" value="${escapeHtml(nl.subject)}" />
      </div>
    </div>

    <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:14px;">
      <div class="card">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;gap:10px;flex-wrap:wrap;">
          <h3 style="font-size:13px;letter-spacing:-0.01em;margin:0;">Body (markdown + HTML)</h3>
          <div id="nl-toolbar" style="display:flex;gap:4px;flex-wrap:wrap;">
            <button type="button" data-snip="image" class="btn btn-ghost btn-sm" title="Upload image">📷 Image</button>
            <button type="button" data-snip="button" class="btn btn-ghost btn-sm" title="CTA button">🔘 Button</button>
            <button type="button" data-snip="twoCol" class="btn btn-ghost btn-sm" title="Two columns">📐 2-col</button>
            <button type="button" data-snip="divider" class="btn btn-ghost btn-sm" title="Horizontal divider">➖ Divider</button>
            <button type="button" data-snip="quote" class="btn btn-ghost btn-sm" title="Blockquote">💬 Quote</button>
            <button type="button" data-snip="signature" class="btn btn-ghost btn-sm" title="Sign-off">✍️ Sig</button>
          </div>
        </div>
        <input type="file" id="nl-file" accept="image/*" style="display:none;" />
        <textarea id="nl-body" style="width:100%;min-height:480px;font-family:var(--font-mono);font-size:13px;padding:12px;border-radius:6px;border:1px solid var(--border);background:var(--bg-2);color:var(--text);resize:vertical;">${escapeHtml(nl.body_md)}</textarea>
        <p class="muted" style="margin-top:8px;font-size:11px;">Markdown: **bold**, *italic*, # heading, [link](url), ![alt](image-url), &gt; quote, lists. Inline HTML works too — use it for buttons, tables, embeds.</p>
      </div>
      <div class="card">
        <h3 style="font-size:13px;margin-bottom:10px;letter-spacing:-0.01em;">Preview <span class="muted" style="font-weight:normal;font-size:11px;">(WYSIWYG — what recipients see)</span></h3>
        <div id="nl-preview" style="max-height:560px;overflow:auto;"></div>
      </div>
    </div>

    <div class="card" style="margin-bottom:14px;">
      <h3 style="font-size:13px;margin-bottom:10px;letter-spacing:-0.01em;">Recipients</h3>
      <div style="display:flex;gap:18px;flex-wrap:wrap;align-items:center;">
        <label style="display:flex;align-items:center;gap:8px;font-size:13px;cursor:pointer;">
          <input id="nl-confirmed-only" type="checkbox" ${nl.segment_filter.confirmed_only !== false ? 'checked' : ''} />
          Confirmed subscribers only
        </label>
        <label style="display:flex;align-items:center;gap:8px;font-size:13px;">
          Source filter:
          <select id="nl-source" style="padding:6px 10px;border-radius:6px;border:1px solid var(--border);background:var(--bg-2);color:var(--text);">
            <option value="">All</option>
            <option value="site" ${nl.segment_filter.source === 'site' ? 'selected' : ''}>Site footer</option>
            <option value="checkout" ${nl.segment_filter.source === 'checkout' ? 'selected' : ''}>Checkout</option>
            <option value="admin" ${nl.segment_filter.source === 'admin' ? 'selected' : ''}>Admin (manually added)</option>
            <option value="import" ${nl.segment_filter.source === 'import' ? 'selected' : ''}>Import</option>
          </select>
        </label>
        <div id="nl-seg-count" style="margin-left:auto;font-size:13px;color:var(--muted);">Calculating recipients…</div>
      </div>
    </div>

    <div class="card">
      <div style="display:flex;gap:10px;justify-content:flex-end;flex-wrap:wrap;">
        <button id="nl-save" class="btn btn-ghost">Save draft</button>
        <button id="nl-send-test" class="btn btn-ghost">Send test to me</button>
        <button id="nl-send-live" class="btn btn-primary">Send to all recipients →</button>
      </div>
      <div id="nl-progress" class="hide" style="margin-top:14px;padding:12px;background:var(--bg-2);border-radius:6px;font-size:13px;"></div>
    </div>
  `;

  function getFilter() {
    return {
      confirmed_only: $('#nl-confirmed-only').checked,
      source: $('#nl-source').value || null,
      tags: [],
    };
  }

  function renderPreview() {
    try {
      const bodyHtml = marked.parse($('#nl-body').value || '');
      $('#nl-preview').innerHTML = wrapEmailPreview(bodyHtml);
    } catch (e) {
      $('#nl-preview').innerHTML = '<p style="color:#ff6b6b;">Markdown parse error.</p>';
    }
  }

  // Wire toolbar buttons
  $$('[data-snip]', $('#nl-toolbar')).forEach(btn => {
    btn.addEventListener('click', async () => {
      const kind = btn.dataset.snip;
      const textarea = $('#nl-body');
      if (kind === 'image') {
        $('#nl-file').click();
        return;
      }
      if (NL_SNIPPETS[kind]) {
        insertAtCursor(textarea, NL_SNIPPETS[kind]);
      }
    });
  });

  // Image upload handler
  $('#nl-file').addEventListener('change', async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      toast('Not an image file', 'error');
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      toast('Image too large', 'error', 'Max 5 MB. Resize first.');
      return;
    }
    const textarea = $('#nl-body');
    const placeholder = `\n\n![uploading ${file.name}…]()\n\n`;
    insertAtCursor(textarea, placeholder);
    try {
      const url = await uploadNewsletterImage(file);
      // Replace the placeholder with the real markdown image
      textarea.value = textarea.value.replace(placeholder, `\n\n![${file.name.replace(/\.[^.]+$/, '')}](${url})\n\n`);
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
      toast('Image uploaded', 'ok');
    } catch (err) {
      textarea.value = textarea.value.replace(placeholder, '');
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
      toast('Upload failed', 'error', explainError(err));
    }
    e.target.value = '';
  });

  async function refreshSegmentCount() {
    $('#nl-seg-count').textContent = 'Counting…';
    try {
      const { data, error } = await query(
        () => supabase.rpc('newsletter_segment_count', { p_filter: getFilter() }),
        'Count segment'
      );
      if (error) throw error;
      $('#nl-seg-count').innerHTML = '<strong>' + data + '</strong> recipient' + (data === 1 ? '' : 's') + ' match';
    } catch (err) {
      $('#nl-seg-count').innerHTML = '<span style="color:#ff6b6b;">' + escapeHtml(explainError(err)) + '</span>';
    }
  }

  async function saveDraft() {
    const subject = $('#nl-subject').value.trim();
    const body_md = $('#nl-body').value;
    if (!subject) { toast('Subject required', 'error'); return null; }
    if (!body_md.trim()) { toast('Body required', 'error'); return null; }

    const body_html = marked.parse(body_md);
    // Plain-text fallback: strip basic tags
    const body_text = body_html.replace(/<[^>]+>/g, '').replace(/\n{3,}/g, '\n\n').trim();

    const payload = {
      subject,
      body_md,
      body_html,
      body_text,
      segment_filter: getFilter(),
    };

    try {
      if (nl.id) {
        const { data, error } = await query(
          () => supabase.from('site_newsletters').update(payload).eq('id', nl.id).select().single(),
          'Save newsletter'
        );
        if (error) throw error;
        nl = data;
      } else {
        const { data, error } = await query(
          () => supabase.from('site_newsletters').insert(payload).select().single(),
          'Create newsletter'
        );
        if (error) throw error;
        nl = data;
        // Update URL to reflect new id
        history.replaceState(null, '', '#/newsletters/' + nl.id + '/edit');
      }
      toast('Draft saved', 'ok');
      return nl;
    } catch (err) {
      toast('Save failed', 'error', explainError(err));
      return null;
    }
  }

  async function sendBlast(mode) {
    const saved = await saveDraft();
    if (!saved) return;
    if (mode === 'live') {
      const segData = await query(() => supabase.rpc('newsletter_segment_count', { p_filter: saved.segment_filter }), 'Count');
      const n = segData.data || 0;
      if (!confirm('Send to ' + n + ' recipient' + (n === 1 ? '' : 's') + '? This cannot be undone.')) return;
    }
    const progress = $('#nl-progress');
    progress.classList.remove('hide');
    progress.innerHTML = '<span class="spinner"></span> ' + (mode === 'test' ? 'Sending test…' : 'Sending to all recipients…');
    try {
      const { data, error } = await supabase.functions.invoke('newsletter-send', {
        body: { newsletter_id: saved.id, mode: mode },
      });
      if (error) throw error;
      if (!data || data.ok === false) throw new Error((data && data.error) || 'send_failed');
      progress.innerHTML = '✅ Done. Sent: <strong>' + data.sent + '</strong>, failed: <strong>' + data.failed + '</strong>'
        + (data.errors && data.errors.length ? '<br><br>Errors:<br>' + data.errors.map(e => '· ' + escapeHtml(e)).join('<br>') : '');
      toast(mode === 'test' ? 'Test sent' : 'Newsletter sent', 'ok');
      if (mode === 'live') {
        setTimeout(() => { location.hash = '#/newsletters/' + saved.id; }, 1500);
      }
    } catch (err) {
      progress.innerHTML = '<span style="color:#ff6b6b;">Failed: ' + escapeHtml(explainError(err)) + '</span>';
      toast('Send failed', 'error', explainError(err));
    }
  }

  $('#nl-body').addEventListener('input', renderPreview);
  $('#nl-confirmed-only').addEventListener('change', refreshSegmentCount);
  $('#nl-source').addEventListener('change', refreshSegmentCount);
  $('#nl-save').addEventListener('click', saveDraft);
  $('#nl-send-test').addEventListener('click', () => sendBlast('test'));
  $('#nl-send-live').addEventListener('click', () => sendBlast('live'));

  renderPreview();
  refreshSegmentCount();
}

// ----------------------------------------------------------------------------
// View: Newsletter detail / send stats (D3b)
// ----------------------------------------------------------------------------
async function renderNewsletterDetail(id) {
  outlet.innerHTML = '<div class="card">Loading…</div>';

  let nl, sends = [];
  try {
    const [nlRes, sendsRes] = await Promise.all([
      query(() => supabase.from('site_newsletters').select('*').eq('id', id).single(), 'Load newsletter'),
      query(() => supabase.from('site_newsletter_sends').select('*').eq('newsletter_id', id).order('id', { ascending: true }), 'Load sends'),
    ]);
    if (nlRes.error) throw nlRes.error;
    nl = nlRes.data;
    sends = sendsRes.data || [];
  } catch (err) {
    outlet.innerHTML = '<div class="card"><p>Could not load: ' + escapeHtml(explainError(err)) + '</p></div>';
    return;
  }

  const sent = sends.filter(s => s.sent_at).length;
  const opened = sends.filter(s => s.opened_at).length;
  const clicked = sends.filter(s => s.clicked_at).length;
  const failed = sends.filter(s => s.error).length;
  const openRate = sent ? Math.round(opened / sent * 100) : 0;
  const clickRate = sent ? Math.round(clicked / sent * 100) : 0;

  outlet.innerHTML = `
    <div class="page-header">
      <div>
        <h1 style="font-size:22px;">${escapeHtml(nl.subject)}</h1>
        <div class="sub">${newsletterStatusBadge(nl.status)} · ${nl.sent_at ? 'Sent ' + formatDate(nl.sent_at) : 'Not yet sent'}</div>
      </div>
      <div class="page-actions">
        <a href="#/newsletters" class="btn btn-ghost">← All</a>
        ${nl.status === 'draft' ? `<a href="#/newsletters/${nl.id}/edit" class="btn btn-primary">Edit draft</a>` : ''}
      </div>
    </div>

    <div class="stat-row">
      <div class="stat"><div class="label">Recipients</div><div class="num">${nl.recipient_count ?? sends.length}</div></div>
      <div class="stat"><div class="label">Sent</div><div class="num" style="color:#5ac26d;">${sent}</div></div>
      <div class="stat"><div class="label">Failed</div><div class="num" style="color:${failed ? '#ff6b6b' : 'inherit'};">${failed}</div></div>
      <div class="stat"><div class="label">Opens</div><div class="num">${opened} <span style="color:var(--muted);font-size:13px;">(${openRate}%)</span></div></div>
      <div class="stat"><div class="label">Clicks</div><div class="num">${clicked} <span style="color:var(--muted);font-size:13px;">(${clickRate}%)</span></div></div>
    </div>

    <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-top:18px;">
      <div class="card">
        <h3 style="font-size:13px;margin-bottom:10px;letter-spacing:-0.01em;">Email preview <span class="muted" style="font-weight:normal;font-size:11px;">(as sent)</span></h3>
        <div style="max-height:540px;overflow:auto;">${wrapEmailPreview(nl.body_html || '')}</div>
      </div>
      <div class="card">
        <h3 style="font-size:13px;margin-bottom:10px;letter-spacing:-0.01em;">Recipients (${sends.length})</h3>
        ${sends.length === 0 ? '<p class="muted">No sends yet.</p>' : `
          <div style="max-height:500px;overflow:auto;">
            <table style="width:100%;font-size:12px;border-collapse:collapse;">
              <thead><tr style="text-align:left;border-bottom:1px solid var(--border);font-size:10px;color:var(--muted);text-transform:uppercase;letter-spacing:0.05em;position:sticky;top:0;background:var(--bg-2);">
                <th style="padding:6px;">Email</th>
                <th style="padding:6px;">Sent</th>
                <th style="padding:6px;">Opened</th>
                <th style="padding:6px;">Clicked</th>
              </tr></thead>
              <tbody>
              ${sends.map(s => `<tr style="border-bottom:1px solid var(--border);">
                <td style="padding:6px;${s.error ? 'color:#ff6b6b;' : ''}" title="${s.error ? escapeHtml(s.error) : ''}">${escapeHtml(s.email)}</td>
                <td style="padding:6px;color:var(--muted);">${s.sent_at ? '✓' : '—'}</td>
                <td style="padding:6px;color:var(--muted);">${s.opened_at ? '👁' : '—'}</td>
                <td style="padding:6px;color:var(--muted);">${s.clicked_at ? '🔗' : '—'}</td>
              </tr>`).join('')}
              </tbody>
            </table>
          </div>
        `}
      </div>
    </div>
  `;
}

bootstrap();
