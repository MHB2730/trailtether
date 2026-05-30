// ============================================================================
// Hilltrek admin — vanilla JS SPA.
//
// Architecture:
//   - Supabase JS v2 SDK from esm.sh (no build step)
//   - Hash-router with views injected into #route-outlet
//   - Two top-level views: #view-login (shown when no session) and #view-app
//   - Authenticated full access to public.site_hikes per RLS policy
// ============================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
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
async function bootstrap() {
  const { data: { session } } = await supabase.auth.getSession();
  await renderAuth(session);
  supabase.auth.onAuthStateChange(async (_event, sess) => { await renderAuth(sess); });

  $('#login-form').addEventListener('submit', onLoginSubmit);
  // Null-safe: if an element is missing (e.g. a partial/cached deploy where
  // index.html and app.js are out of sync) the optional-chain skips the bind
  // instead of throwing and taking down the whole app at bootstrap.
  $('#forgot-link')?.addEventListener('click', onForgotPassword);
  $('#mfa-form')?.addEventListener('submit', onMfaSubmit);
  $('#mfa-cancel')?.addEventListener('click', onMfaCancel);
  $('#btn-logout')?.addEventListener('click', onLogout);
  window.addEventListener('hashchange', route);
}

// Forgot-password: email a reset link. The Reset Password email template
// hard-codes the hosted web reset page (hilltrek.co.za/account/reset) via
// {{ .TokenHash }}, so no redirectTo is needed here — the link works in any
// browser, no app required.
async function onForgotPassword(e) {
  e.preventDefault();
  const email = $('#login-email').value.trim();
  if (!email || !email.includes('@')) {
    toast('Enter your email', 'error',
      'Type your admin email in the field above, then click Forgot password.');
    return;
  }
  const link = $('#forgot-link');
  link.style.pointerEvents = 'none';
  link.textContent = 'Sending…';
  try {
    const { error } = await supabase.auth.resetPasswordForEmail(email);
    if (error) throw error;
    toast('Reset link sent', 'success',
      `Check ${email} (and spam). The link opens a page where you set a new password.`);
  } catch (err) {
    toast('Could not send reset', 'error', explainError(err));
  } finally {
    link.style.pointerEvents = '';
    link.textContent = 'Forgot your password?';
  }
}

// Show login if no session. Otherwise enforce two checks:
//   1) Admin allowlist — Trailtether app users share this Supabase project,
//      so we must explicitly verify the current user is in public.admin_users
//      before showing any CMS UI.
//   2) MFA assurance level — if a TOTP factor is enrolled, prompt for the
//      6-digit code before unlocking the app.
async function renderAuth(session) {
  if (!session) {
    hide(viewApp);
    show(viewLogin);
    showLoginForm();
    return;
  }

  // 1. Admin allowlist check
  try {
    const { data: isAdmin, error: adminErr } = await supabase.rpc('is_admin');
    if (adminErr) throw adminErr;
    if (!isAdmin) {
      // Logged-in user is NOT on the admin allowlist (likely a Trailtether
      // app user signed in via the same project). Refuse access cleanly.
      await supabase.auth.signOut();
      show(viewLogin); hide(viewApp);
      showLoginForm();
      toast('Not authorised', 'error',
        'This account is not on the Hilltrek admin allowlist.');
      return;
    }
  } catch (err) {
    console.warn('is_admin check failed:', err);
    await supabase.auth.signOut();
    show(viewLogin); hide(viewApp);
    showLoginForm();
    toast('Could not verify access', 'error', explainError(err));
    return;
  }

  // 2. MFA assurance check
  try {
    const { data, error } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (error) throw error;
    if (data.currentLevel === data.nextLevel) {
      hide(viewLogin);
      show(viewApp);
      route();
      return;
    }
    show(viewLogin);
    hide(viewApp);
    await showMfaPrompt();
  } catch (err) {
    console.warn('AAL check failed:', err);
    await supabase.auth.signOut();
    show(viewLogin);
    hide(viewApp);
    showLoginForm();
  }
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
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    // renderAuth is triggered by onAuthStateChange and will decide whether to
    // show the MFA prompt or the app shell.
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
    const { data: factors, error: lf } = await supabase.auth.mfa.listFactors();
    if (lf) throw lf;
    const totp = (factors.totp || []).find(f => f.status === 'verified');
    if (!totp) {
      throw new Error('No verified TOTP factor on this account. Enrol one from the Security page.');
    }
    const { data: challenge, error: ce } = await supabase.auth.mfa.challenge({ factorId: totp.id });
    if (ce) throw ce;
    const { error: ve } = await supabase.auth.mfa.verify({
      factorId: totp.id,
      challengeId: challenge.id,
      code,
    });
    if (ve) throw ve;
    toast('Signed in', 'ok');
    $('#mfa-code').value = '';
    // onAuthStateChange will fire and renderAuth will swap to the app shell.
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
  if (path === '/security')                    return renderSecurity();
  const m = path.match(/^\/hikes\/(.+)$/);
  if (m) return renderHikeEdit(m[1]);
  const p = path.match(/^\/products\/(.+)$/);
  if (p) return renderProductEdit(p[1]);

  outlet.innerHTML = `<div class="card"><h2 style="font-size:20px;">Not found</h2><p class="muted">The URL <code>${path}</code> isn't a known admin view. <a href="#/" class="subtle-link">Back to dashboard</a></p></div>`;
}
function setActiveNav(path) {
  $$('[data-nav]').forEach(a => a.classList.remove('active'));
  if (path === '/' || path === '')              $('[data-nav="dashboard"]')?.classList.add('active');
  else if (path.startsWith('/hikes'))           $('[data-nav="hikes"]')?.classList.add('active');
  else if (path.startsWith('/products'))        $('[data-nav="products"]')?.classList.add('active');
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
        <a href="#/hikes/new" class="btn btn-primary">+ New hike</a>
        <a href="#/hikes" class="btn btn-ghost">All hikes →</a>
      </div>
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

  // Fetch counts + 3 most recent hikes
  try {
    const [counts, latest] = await Promise.all([
      supabase.from('site_hikes').select('id, is_published, is_featured', { count: 'exact' }),
      supabase.from('site_hikes')
        .select('slug, title, is_published, is_featured, hike_date, updated_at, hero_image_url')
        .order('updated_at', { ascending: false })
        .limit(3),
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
    $('#dash-stats').innerHTML = `<div class="stat"><div class="label">Error</div><div class="num bad">!</div><div class="delta">${explainError(err)}</div></div>`;
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
    const { data, error } = await supabase
      .from('site_hikes')
      .select('id, slug, title, hike_date, region, is_published, is_featured, hero_image_url, updated_at')
      .order('display_order', { ascending: true })
      .order('hike_date', { ascending: false, nullsFirst: false });
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
    const { data, error } = await supabase.from('site_hikes').select('*').eq('slug', slug).maybeSingle();
    if (error) { outlet.innerHTML = `<div class="card bad">${explainError(error)}</div>`; return; }
    if (!data)  { outlet.innerHTML = `<div class="card">Hike not found. <a href="#/hikes" class="subtle-link">Back to list</a></div>`; return; }
    hike = data;
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
    const { data, error } = await supabase
      .from('site_products')
      .select('id, slug, name, category, price_cents, stock_quantity, track_inventory, is_active, is_featured, main_image_url, display_order')
      .order('display_order', { ascending: true });
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
    const { data, error } = await supabase.from('site_products').select('*').eq('slug', slug).maybeSingle();
    if (error) { outlet.innerHTML = `<div class="card bad">${explainError(error)}</div>`; return; }
    if (!data)  { outlet.innerHTML = `<div class="card">Product not found. <a href="#/products" class="subtle-link">Back to list</a></div>`; return; }
    product = data;
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

bootstrap();
