// ============================================================================
// publish-site — Hilltrek Edge Function
// ----------------------------------------------------------------------------
// One-click publish from the admin. Pulls latest content from Supabase,
// renders the static HTML, and pushes each file to cPanel via the cPanel
// UAPI (HTTPS, no SFTP needed).
//
// Required env vars (set in Supabase Dashboard → Edge Functions → Secrets):
//   CPANEL_HOST       e.g. "fennec.aserv.co.za"  (no protocol, no port)
//   CPANEL_USER       e.g. "hilltro7a4x5"
//   CPANEL_API_TOKEN  cPanel-generated API token (NOT your password)
//   CPANEL_HOME       e.g. "/home/hilltro7a4x5/public_html"
// ============================================================================

// deno-lint-ignore-file no-explicit-any
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL  = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY   = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY      = Deno.env.get("SUPABASE_ANON_KEY")!;

const CPANEL_HOST   = Deno.env.get("CPANEL_HOST") ?? "";
const CPANEL_USER   = Deno.env.get("CPANEL_USER") ?? "";
const CPANEL_TOKEN  = Deno.env.get("CPANEL_API_TOKEN") ?? "";
const CPANEL_HOME   = Deno.env.get("CPANEL_HOME") ?? "";

const SITE_PUBLIC   = "https://hilltrek.co.za";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ----------------------------------------------------------------------------
// HTTP entry
// ----------------------------------------------------------------------------
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST")    return j(405, { error: "POST only" });

  // 1. Verify the caller is an authenticated admin.
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ")) return j(401, { error: "Missing bearer token" });

  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user }, error: ue } = await userClient.auth.getUser();
  if (ue || !user) return j(401, { error: "Invalid session", detail: ue?.message });
  const { data: isAdmin, error: ae } = await userClient.rpc("is_admin");
  if (ae)           return j(500, { error: "is_admin check failed", detail: ae.message });
  if (!isAdmin)     return j(403, { error: "Not on Hilltrek admin allowlist" });

  // 2. Read content from DB using the service role (bypasses RLS for an
  //    accurate full read of unpublished rows too).
  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  const { data: hikes,    error: he } = await admin
    .from("site_hikes")
    .select("*")
    .eq("is_published", true)
    .order("display_order", { ascending: true })
    .order("hike_date",     { ascending: false, nullsFirst: false });
  if (he) return j(500, { error: "Failed to fetch hikes", detail: he.message });

  const { data: products, error: pe } = await admin
    .from("site_products")
    .select("*")
    .eq("is_active", true)
    .order("display_order", { ascending: true });
  if (pe) return j(500, { error: "Failed to fetch products", detail: pe.message });

  // 3. Render every file.
  const files: Array<{ path: string; content: string }> = [];
  for (const h of hikes ?? []) {
    files.push({ path: `/hikes/${h.slug}/index.html`, content: renderHikeDetail(h, hikes ?? []) });
  }
  files.push({ path: "/hikes/index.html", content: renderHikesIndex(hikes ?? []) });
  files.push({ path: "/merch/index.html", content: renderMerchIndex(products ?? []) });

  // 4. Validate cPanel config before attempting uploads.
  if (!CPANEL_HOST || !CPANEL_USER || !CPANEL_TOKEN || !CPANEL_HOME) {
    return j(500, {
      error: "cPanel secrets not configured",
      detail: "Set CPANEL_HOST, CPANEL_USER, CPANEL_API_TOKEN, CPANEL_HOME in Edge Functions → Secrets",
    });
  }

  // 5. Upload every rendered file.
  const results: Array<{ path: string; ok: boolean; status?: number; error?: string }> = [];
  for (const f of files) {
    try {
      const r = await uploadFile(f.path, f.content);
      results.push({ path: f.path, ok: r.ok, status: r.status });
    } catch (e) {
      results.push({ path: f.path, ok: false, error: String(e?.message ?? e) });
    }
  }

  const allOk = results.every(r => r.ok);
  return j(allOk ? 200 : 207, {
    ok: allOk,
    hikes_count:    hikes?.length    ?? 0,
    products_count: products?.length ?? 0,
    files_published: results.length,
    results,
  });
});

function j(status: number, body: any) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// ----------------------------------------------------------------------------
// cPanel UAPI uploader
// Docs: https://api.docs.cpanel.net/openapi/cpanel/operation/upload_files/
// ----------------------------------------------------------------------------
async function uploadFile(sitePath: string, content: string): Promise<Response> {
  const dir       = CPANEL_HOME + sitePath.substring(0, sitePath.lastIndexOf("/"));
  const filename  = sitePath.substring(sitePath.lastIndexOf("/") + 1);

  const url = `https://${CPANEL_HOST}:2083/execute/Fileman/upload_files`;
  const form = new FormData();
  form.append("dir", dir);
  form.append("overwrite", "1");
  form.append("file-1", new Blob([content], { type: "text/html" }), filename);

  return await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `cpanel ${CPANEL_USER}:${CPANEL_TOKEN}`,
    },
    body: form,
  });
}

// ----------------------------------------------------------------------------
// Template engine — mimics Python's str.format() with {name} placeholders
// and {{ / }} escaping so the inline CSS in our templates survives intact.
// ----------------------------------------------------------------------------
function fmt(tpl: string, vars: Record<string, string>): string {
  return tpl
    .replace(/\{\{/g, "\x00OPEN\x00")
    .replace(/\}\}/g, "\x00CLOSE\x00")
    .replace(/\{(\w+)\}/g, (_, k) => vars[k] ?? "")
    .replace(/\x00OPEN\x00/g, "{")
    .replace(/\x00CLOSE\x00/g, "}");
}

function esc(s: any): string {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// Minimal markdown → HTML for hike body_md (h2/h3/p/ul/links/strong/em).
function mdToHtml(md: string): string {
  if (!md?.trim()) return "";
  const lines = md.replace(/\r\n/g, "\n").split("\n");
  const out: string[] = [];
  let inList = false;
  let para: string[] = [];
  const inline = (s: string) =>
    esc(s)
      .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>')
      .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
      .replace(/(?<!\w)\*([^*]+)\*(?!\w)/g, "<em>$1</em>")
      .replace(/(?<!\w)_([^_]+)_(?!\w)/g, "<em>$1</em>");
  const flushPara = () => { if (para.length) { out.push(`<p>${inline(para.join(" ")).trim()}</p>`); para = []; } };
  const flushList = () => { if (inList) { out.push("</ul>"); inList = false; } };
  for (const raw of lines) {
    const line = raw.replace(/\s+$/, "");
    if (!line) { flushPara(); flushList(); continue; }
    if (line.startsWith("## "))      { flushPara(); flushList(); out.push(`<h2>${inline(line.slice(3))}</h2>`); }
    else if (line.startsWith("### ")){ flushPara(); flushList(); out.push(`<h3>${inline(line.slice(4))}</h3>`); }
    else if (line.startsWith("- "))  { flushPara(); if (!inList) { out.push("<ul>"); inList = true; } out.push(`<li>${inline(line.slice(2))}</li>`); }
    else                             { flushList(); para.push(line); }
  }
  flushPara(); flushList();
  return out.join("\n");
}

function formatDate(s: string | null | undefined): string {
  if (!s) return "";
  try {
    const d = new Date(s);
    return d.toLocaleDateString("en-ZA", { year: "numeric", month: "short", day: "numeric" }).toUpperCase();
  } catch { return s; }
}

function priceHtml(cents: number, compareCents: number | null = null): string {
  const fmt = (c: number) => (c % 100 === 0) ? (c / 100).toFixed(0) : (c / 100).toFixed(2);
  let out = `<span class="cur">R</span>${fmt(cents)}`;
  if (compareCents && compareCents > cents) out += ` <span class="compare">R${fmt(compareCents)}</span>`;
  return out;
}

// Build interactive variant <select> markup. The shopper picks size/colour
// before adding to cart; cart.js reads each select's data-variant-group +
// value when wiring the button.
function variantSelectsHtml(variants: any[]): string {
  if (!variants?.length) return "";
  const rows: string[] = [];
  for (const v of variants) {
    const name = String(v.name ?? "").trim();
    const vals = (v.values ?? []).map((x: any) => String(x).trim()).filter(Boolean);
    if (!name || !vals.length) continue;
    const opts = vals.map((val: string) => `<option value="${esc(val)}">${esc(val)}</option>`).join("");
    rows.push(
      `<label class="variant-row">` +
        `<span class="variant-label">${esc(name)}</span>` +
        `<select data-variant-group="${esc(name)}">${opts}</select>` +
      `</label>`
    );
  }
  return rows.length ? `<div class="product-variants">${rows.join("")}</div>` : "";
}

function hikePills(h: any): string {
  const bits: string[] = [];
  if (h.region)     bits.push(String(h.region).toUpperCase());
  if (h.hike_date)  bits.push(formatDate(h.hike_date));
  if (h.hike_type)  bits.push(String(h.hike_type).toUpperCase());
  if (h.difficulty) bits.push(String(h.difficulty).toUpperCase());
  const parts: string[] = [];
  bits.forEach((b, i) => {
    if (i) parts.push('<span class="dot"></span>');
    parts.push(`<span><span class="pill"></span> ${esc(b)}</span>`);
  });
  return parts.join("");
}

function statsRow(stats: Record<string, any>): string {
  const entries = Object.entries(stats ?? {}).slice(0, 4);
  while (entries.length < 4) entries.push(["", ""]);
  return entries.map(([label, val]) => {
    const labelDisp = label ? String(label).replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase()) : "&nbsp;";
    const valDisp   = val ? esc(val) : "&mdash;";
    return `<div class="stat-cell"><div class="label">${labelDisp}</div><div class="val">${valDisp}</div></div>`;
  }).join("\n");
}

function galleryTiles(urls: string[]): string {
  if (!urls?.length) return "";
  const cls = ["g1","g2","g3","g4","g5","g6"];
  return urls.slice(0,6).map((u, i) =>
    `<div class="gallery-tile ${cls[i % cls.length]}"><img src="${esc(u)}" alt="" loading="lazy" /></div>`
  ).join("\n");
}

function nextHikesHtml(currentSlug: string, all: any[]): string {
  const others = all.filter(h => h.slug !== currentSlug).slice(0, 2);
  return others.map(o => {
    const thumb = esc(o.hero_image_url ?? "");
    const thumbHtml = thumb ? `<img src="${thumb}" alt="" />` : "";
    return `<a class="next-card" href="/hikes/${esc(o.slug)}/">` +
           `<div class="thumb">${thumbHtml}</div>` +
           `<div class="body"><div class="dir">→ Other hike</div>` +
           `<h4>${esc(o.title)}</h4></div>` +
           `</a>`;
  }).join("\n");
}

// ============================================================================
// Templates — inline so the function bundle is self-contained.
// Mirrors hilltrek-admin/templates/*.html. Keep them in sync when changing.
// ============================================================================
const TPL_HIKE_DETAIL = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <script src="/assets/js/maintenance-gate.js"></script>
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <title>{title} — Hilltrek hike log</title>
  <meta name="description" content="{meta_description}" />
  <meta name="theme-color" content="#0a0908" />
  <link rel="icon" href="/assets/img/logo.png" type="image/png" />
  <link rel="stylesheet" href="/assets/css/site.css" />
  <style>
    .hike-hero {{ position: relative; isolation: isolate; overflow: hidden; padding: 100px 0 80px; min-height: 600px; display: flex; align-items: flex-end; }}
    .hike-hero-bg {{ position: absolute; inset: 0; z-index: -2; background: linear-gradient(180deg, rgba(10,9,8,0.35) 0%, rgba(10,9,8,0.5) 40%, rgba(10,9,8,0.95) 90%, var(--bg) 100%), url('{hero_image_url}') center / cover no-repeat; }}
    .hike-hero h1 {{ font-size: clamp(40px, 6.4vw, 76px); font-weight: 700; letter-spacing: -0.04em; line-height: 1.02; margin: 22px 0 14px; max-width: 16ch; text-wrap: balance; }}
    .hike-hero .meta-row {{ display: flex; flex-wrap: wrap; gap: 16px; font-family: var(--font-mono); font-size: 12.5px; letter-spacing: 0.16em; text-transform: uppercase; color: var(--muted); margin-top: 6px; }}
    .hike-hero .meta-row span {{ display: inline-flex; align-items: center; gap: 8px; }}
    .hike-hero .meta-row .pill {{ width: 5px; height: 5px; border-radius: 50%; background: var(--ember); box-shadow: 0 0 6px var(--ember); }}
    .hike-hero .meta-row .dot {{ width: 3px; height: 3px; border-radius: 50%; background: var(--dim); }}
    .breadcrumb {{ font-family: var(--font-mono); font-size: 12px; letter-spacing: 0.16em; text-transform: uppercase; color: var(--ember); }}
    .breadcrumb a {{ color: var(--muted); }}
    .breadcrumb a:hover {{ color: var(--ember); }}
    .stats-panel {{ padding: 50px 0; border-bottom: 1px solid var(--border); }}
    .stats-row {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 0; }}
    .stat-cell {{ padding: 10px 24px; border-left: 1px solid var(--border); }}
    .stat-cell:first-child {{ border-left: 0; padding-left: 0; }}
    .stat-cell .label {{ font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--muted); margin-bottom: 6px; }}
    .stat-cell .val {{ font-size: 22px; font-weight: 700; letter-spacing: -0.02em; }}
    @media (max-width: 760px) {{ .stats-row {{ grid-template-columns: 1fr 1fr; gap: 24px; }} .stat-cell {{ border-left: 0; padding: 0; }} }}
    .log-body {{ padding: 70px 0 60px; }}
    .log-text {{ max-width: 65ch; margin: 0 auto; }}
    .log-text h2 {{ font-size: clamp(24px, 2.6vw, 30px); font-weight: 700; letter-spacing: -0.02em; margin: 36px 0 14px; line-height: 1.2; }}
    .log-text h2:first-child {{ margin-top: 0; }}
    .log-text h3 {{ font-size: 19px; font-weight: 600; margin: 28px 0 10px; }}
    .log-text p {{ color: rgba(244,241,237,0.88); font-size: 16.5px; line-height: 1.75; margin-bottom: 14px; }}
    .log-text ul {{ display: grid; gap: 8px; margin: 14px 0 18px 0; }}
    .log-text ul li {{ position: relative; padding-left: 20px; color: var(--muted); font-size: 15.5px; list-style: none; }}
    .log-text ul li::before {{ content: ""; position: absolute; left: 0; top: 11px; width: 8px; height: 1px; background: var(--ember); }}
    .log-text a {{ color: var(--ember); text-decoration: underline; }}
    .log-text strong {{ color: var(--text); }}
    .gallery {{ padding: 80px 0; border-top: 1px solid var(--border); }}
    .gallery-grid {{ display: grid; grid-template-columns: repeat(4, 1fr); grid-auto-rows: 200px; gap: 12px; margin-top: 32px; }}
    .gallery-tile {{ position: relative; overflow: hidden; border-radius: var(--r-md); background: var(--surface); border: 1px solid var(--border); }}
    .gallery-tile img {{ width: 100%; height: 100%; object-fit: cover; transition: transform 0.5s ease; }}
    .gallery-tile:hover img {{ transform: scale(1.04); }}
    .gallery-tile.g1 {{ grid-column: span 2; grid-row: span 2; }}
    .gallery-tile.g2 {{ grid-column: span 2; grid-row: span 1; }}
    .gallery-tile.g3 {{ grid-column: span 1; grid-row: span 1; }}
    .gallery-tile.g4 {{ grid-column: span 1; grid-row: span 1; }}
    .gallery-tile.g5 {{ grid-column: span 2; grid-row: span 1; }}
    .gallery-tile.g6 {{ grid-column: span 2; grid-row: span 1; }}
    @media (max-width: 760px) {{ .gallery-grid {{ grid-template-columns: repeat(2, 1fr); grid-auto-rows: 160px; }} .gallery-tile.g1 {{ grid-column: span 2; grid-row: span 2; }} .gallery-tile.g2, .gallery-tile.g3, .gallery-tile.g4, .gallery-tile.g5, .gallery-tile.g6 {{ grid-column: span 1; grid-row: span 1; }} }}
    .next-hikes {{ padding: 60px 0 100px; border-top: 1px solid var(--border); }}
    .next-hikes h2 {{ font-size: 24px; font-weight: 700; letter-spacing: -0.02em; margin-bottom: 24px; }}
    .next-hikes-grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 18px; }}
    .next-card {{ display: flex; gap: 16px; align-items: center; padding: 18px 22px; border-radius: var(--r-md); background: var(--surface); border: 1px solid var(--border); color: inherit; transition: border-color 0.2s ease, transform 0.15s ease; }}
    .next-card:hover {{ border-color: var(--ember); transform: translateY(-2px); }}
    .next-card .thumb {{ width: 72px; height: 72px; flex-shrink: 0; border-radius: var(--r-sm); overflow: hidden; }}
    .next-card .thumb img {{ width: 100%; height: 100%; object-fit: cover; }}
    .next-card .body .dir {{ font-family: var(--font-mono); font-size: 10.5px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--ember); margin-bottom: 4px; }}
    .next-card .body h4 {{ font-size: 16px; font-weight: 600; letter-spacing: -0.01em; }}
    @media (max-width: 760px) {{ .next-hikes-grid {{ grid-template-columns: 1fr; }} }}
  </style>
</head>
<body>
  <header class="nav">
    <div class="container nav-inner">
      <a href="/" class="brand" aria-label="Hilltrek home"><span class="brand-mark"><img src="/assets/img/logo.png" alt="Hilltrek" width="46" height="46" /></span></a>
      <nav class="nav-links" aria-label="Primary">
        <a href="/">Mission Control</a>
        <a href="/hikes/" class="active">Hikes</a>
        <a href="/reviews/">Reviews</a>
        <a href="/trailtether/">TrailTether</a>
        <a href="/merch/">Merch</a>
        <a href="/reach-out/">Reach Out</a>
        <a href="/trailtether/#download" class="nav-cta" data-apk-link>Get the App</a>
      </nav>
      <button class="nav-toggle" aria-label="Open menu" aria-expanded="false">☰</button>
    </div>
  </header>
  <section class="hike-hero">
    <div class="hike-hero-bg" aria-hidden="true"></div>
    <div class="container">
      <span class="breadcrumb"><a href="/hikes/">← All hikes</a> // {title}</span>
      <h1>{title}</h1>
      <p style="color: rgba(244,241,237,0.82); font-size: clamp(17px,1.5vw,19px); max-width: 60ch; text-wrap: pretty;">{intro}</p>
      <div class="meta-row">{pills_html}</div>
    </div>
  </section>
  <section class="stats-panel"><div class="container"><div class="stats-row">{stats_html}</div></div></section>
  <section class="log-body"><div class="container"><div class="log-text">{body_html}</div></div></section>
  <section class="gallery"><div class="container">
    <span class="eyebrow">// Gallery</span>
    <h2 style="font-size: clamp(24px, 2.8vw, 32px); font-weight: 700; letter-spacing: -0.02em; margin-top: 6px;">From the route.</h2>
    <div class="gallery-grid">{gallery_html}</div>
  </div></section>
  <section class="next-hikes"><div class="container">
    <h2>Other Hilltrek hikes</h2>
    <div class="next-hikes-grid">{next_hikes_html}</div>
  </div></section>
  {footer}
  <script>document.getElementById('year').textContent = new Date().getFullYear();</script>
  <script src="/assets/js/site.js" defer></script>
</body>
</html>`;

const TPL_FOOTER = `<footer class="footer"><div class="container">
  <div class="foot-grid">
    <div class="foot-col">
      <a href="/" class="brand brand-sm" style="margin-bottom: 14px;"><span class="brand-mark"><img src="/assets/img/logo.png" alt="Hilltrek" width="36" height="36" /></span><span class="brand-name">(PTY) LTD</span></a>
      <p>Drakensberg-rooted outdoor community. Makers of Trailtether. Built for the people who keep going when the trail goes quiet.</p>
      <div class="foot-social">
        <a href="https://www.facebook.com/profile.php?id=61584133487681" target="_blank" rel="noopener" aria-label="Facebook"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M22 12a10 10 0 1 0-11.6 9.9v-7H8v-2.9h2.4V9.4c0-2.4 1.4-3.7 3.6-3.7 1 0 2.1.2 2.1.2v2.3h-1.2c-1.2 0-1.5.7-1.5 1.5v1.8h2.6l-.4 2.9h-2.2v7A10 10 0 0 0 22 12z"/></svg></a>
        <a href="https://www.instagram.com/hilltrek.co.za/" target="_blank" rel="noopener" aria-label="Instagram"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.5" cy="6.5" r="1" fill="currentColor" stroke="none"/></svg></a>
      </div>
    </div>
    <div class="foot-col"><h5>Explore</h5><ul><li><a href="/">Mission Control</a></li><li><a href="/hikes/">Hikes</a></li><li><a href="/reviews/">Reviews</a></li><li><a href="/merch/">Merch</a></li></ul></div>
    <div class="foot-col"><h5>Product</h5><ul><li><a href="/trailtether/">Trailtether app</a></li><li><a href="/trailtether/#download">Download APK</a></li><li><a href="/trailtether/#faq">FAQ</a></li></ul></div>
    <div class="foot-col"><h5>Company</h5><ul><li><a href="/reach-out/">Reach Out</a></li><li><a href="/legal-notice/">Legal Notice</a></li><li><a href="/privacy/">Privacy Policy</a></li></ul></div>
  </div>
  <div class="foot-bottom"><span>© <span id="year"></span> Hilltrek (Pty) Ltd · All rights reserved.</span><span class="dim">Made in the Drakensberg.</span></div>
</div></footer>`;

const TPL_HIKES_INDEX = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <script src="/assets/js/maintenance-gate.js"></script>
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <title>Hikes — Hilltrek route logs from the Drakensberg</title>
  <meta name="description" content="Past hikes documented with photos, route notes and trail intel. Real days in the Berg." />
  <meta name="theme-color" content="#0a0908" />
  <link rel="icon" href="/assets/img/logo.png" type="image/png" />
  <link rel="stylesheet" href="/assets/css/site.css" />
  <style>
    .page-hero {{ padding: 80px 0 30px; border-bottom: 1px solid var(--border); }}
    .page-hero h1 {{ font-size: clamp(36px, 5vw, 60px); font-weight: 700; letter-spacing: -0.035em; line-height: 1.02; margin-bottom: 16px; max-width: 18ch; text-wrap: balance; }}
    .page-hero p {{ color: var(--muted); max-width: 60ch; font-size: 17px; }}
    .hike-grid {{ display: grid; grid-template-columns: repeat(2, 1fr); gap: 28px; margin-top: 56px; }}
    .hike-card {{ display: flex; flex-direction: column; border-radius: var(--r-lg); background: var(--surface); border: 1px solid var(--border); overflow: hidden; color: inherit; transition: transform 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease; }}
    .hike-card:hover {{ transform: translateY(-4px); border-color: var(--border-2); box-shadow: 0 16px 40px -16px rgba(0,0,0,0.6); }}
    .hike-media {{ aspect-ratio: 16 / 10; overflow: hidden; position: relative; background: var(--surface-2); }}
    .hike-media img {{ width: 100%; height: 100%; object-fit: cover; transition: transform 0.4s ease; }}
    .hike-card:hover .hike-media img {{ transform: scale(1.04); }}
    .hike-tag {{ position: absolute; top: 16px; left: 16px; display: inline-flex; align-items: center; gap: 8px; padding: 6px 12px; border-radius: var(--r-pill); background: rgba(10,9,8,0.85); backdrop-filter: blur(10px); border: 1px solid rgba(255,255,255,0.08); font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.16em; text-transform: uppercase; color: var(--text); }}
    .hike-tag .pill {{ width: 5px; height: 5px; border-radius: 50%; background: var(--ember); box-shadow: 0 0 6px var(--ember); }}
    .hike-tag.featured {{ background: var(--ember); color: #110a04; border-color: rgba(255,255,255,0.15); }}
    .hike-tag.featured .pill {{ background: #110a04; box-shadow: none; }}
    .hike-body {{ padding: 26px 28px 28px; }}
    .hike-meta {{ font-family: var(--font-mono); font-size: 11.5px; letter-spacing: 0.16em; text-transform: uppercase; color: var(--ember); margin-bottom: 14px; display: flex; gap: 16px; align-items: center; flex-wrap: wrap; }}
    .hike-meta .pill {{ width: 5px; height: 5px; border-radius: 50%; background: var(--ember); box-shadow: 0 0 6px var(--ember); }}
    .hike-meta .dot {{ width: 4px; height: 4px; border-radius: 50%; background: var(--dim); }}
    .hike-body h3 {{ font-size: 24px; font-weight: 700; letter-spacing: -0.02em; margin-bottom: 10px; line-height: 1.15; }}
    .hike-body p {{ color: var(--muted); font-size: 15px; line-height: 1.55; }}
    .hike-link {{ display: inline-flex; align-items: center; gap: 8px; margin-top: 16px; font-family: var(--font-mono); font-size: 12px; letter-spacing: 0.16em; text-transform: uppercase; color: var(--ember); }}
    @media (max-width: 760px) {{ .hike-grid {{ grid-template-columns: 1fr; }} }}
  </style>
</head>
<body>
  <header class="nav">
    <div class="container nav-inner">
      <a href="/" class="brand"><span class="brand-mark"><img src="/assets/img/logo.png" alt="Hilltrek" width="46" height="46" /></span></a>
      <nav class="nav-links">
        <a href="/">Mission Control</a><a href="/hikes/" class="active">Hikes</a><a href="/reviews/">Reviews</a>
        <a href="/trailtether/">TrailTether</a><a href="/merch/">Merch</a><a href="/reach-out/">Reach Out</a>
        <a href="/trailtether/#download" class="nav-cta" data-apk-link>Get the App</a>
      </nav>
      <button class="nav-toggle">☰</button>
    </div>
  </header>
  <section class="page-hero"><div class="container">
    <span class="eyebrow">// Past hikes</span>
    <h1>Route logs from real days in the Berg.</h1>
    <p>Each hike below is one we've actually walked. Photos, route notes and what we learned — the stuff that doesn't fit on a topo map.</p>
  </div></section>
  <section class="section-tight"><div class="container">
    <div class="hike-grid">{cards_html}</div>
  </div></section>
  {footer}
  <script>document.getElementById('year').textContent = new Date().getFullYear();</script>
  <script src="/assets/js/site.js" defer></script>
</body>
</html>`;

const TPL_HIKE_CARD = `<a class="hike-card" href="/hikes/{slug}/">
  <div class="hike-media">{featured_pill}<img src="{hero}" alt="{title}" loading="lazy" /></div>
  <div class="hike-body">
    <div class="hike-meta">{meta}</div>
    <h3>{title}</h3>
    <p>{intro}</p>
    <span class="hike-link">Read the route log →</span>
  </div>
</a>`;

const TPL_MERCH_INDEX = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <script src="/assets/js/maintenance-gate.js"></script>
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <title>Merch — Hilltrek apparel & trail kit</title>
  <meta name="description" content="Hilltrek branded apparel and trail essentials. Hoodies, hats, beanies, balaclavas and more — built for the Berg." />
  <meta name="theme-color" content="#0a0908" />
  <link rel="icon" href="/assets/img/logo.png" type="image/png" />
  <link rel="stylesheet" href="/assets/css/site.css" />
  <style>
    .page-hero {{ padding: 80px 0 30px; border-bottom: 1px solid var(--border); }}
    .page-hero h1 {{ font-size: clamp(36px, 5vw, 60px); font-weight: 700; letter-spacing: -0.035em; line-height: 1.02; margin-bottom: 16px; max-width: 18ch; text-wrap: balance; }}
    .page-hero p {{ color: var(--muted); max-width: 60ch; font-size: 17px; }}
    .product-grid {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 28px; margin-top: 56px; }}
    @media (max-width: 960px) {{ .product-grid {{ grid-template-columns: repeat(2, 1fr); }} }}
    @media (max-width: 600px) {{ .product-grid {{ grid-template-columns: 1fr; }} }}
    .product-card {{ display: flex; flex-direction: column; border-radius: var(--r-lg); background: var(--surface); border: 1px solid var(--border); overflow: hidden; color: inherit; transition: transform 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease; }}
    .product-card:hover {{ transform: translateY(-4px); border-color: var(--border-2); box-shadow: 0 16px 40px -16px rgba(0,0,0,0.6); }}
    .product-media {{ position: relative; aspect-ratio: 1 / 1; overflow: hidden; background: #f4f1ed; }}
    .product-media img {{ width: 100%; height: 100%; object-fit: contain; padding: 22px; transition: transform 0.4s ease; }}
    .product-tag {{ position: absolute; top: 14px; left: 14px; display: inline-flex; align-items: center; gap: 8px; padding: 5px 11px; border-radius: var(--r-pill); background: rgba(10,9,8,0.85); font-family: var(--font-mono); font-size: 10.5px; letter-spacing: 0.16em; text-transform: uppercase; color: var(--text); }}
    .product-tag.featured {{ background: var(--ember); color: #110a04; }}
    .product-tag .pill {{ width: 5px; height: 5px; border-radius: 50%; background: var(--ember); box-shadow: 0 0 6px var(--ember); }}
    .product-body {{ padding: 22px 24px 24px; display: flex; flex-direction: column; flex: 1; }}
    .product-meta {{ font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.16em; text-transform: uppercase; color: var(--ember); margin-bottom: 8px; }}
    .product-card h3 {{ font-size: 20px; font-weight: 700; letter-spacing: -0.02em; margin: 0 0 6px; line-height: 1.15; }}
    .product-blurb {{ color: var(--muted); font-size: 14px; line-height: 1.5; margin-bottom: 18px; flex: 1; }}
    .product-bottom {{ display: flex; align-items: center; justify-content: space-between; gap: 16px; margin-top: 4px; }}
    .product-price {{ font-size: 22px; font-weight: 700; letter-spacing: -0.02em; }}
    .product-price .cur {{ font-size: 13px; color: var(--muted); font-weight: 500; margin-right: 2px; }}
    .product-price .compare {{ font-size: 13px; color: var(--dim); text-decoration: line-through; margin-left: 8px; }}
    .product-buy {{ display: inline-flex; align-items: center; gap: 8px; padding: 10px 16px; border-radius: var(--r-pill); background: var(--ember); color: #110a04; font-weight: 600; font-size: 13.5px; border: 0; cursor: pointer; font-family: inherit; transition: transform 0.12s ease, box-shadow 0.2s ease; }}
    .product-buy:hover {{ transform: translateY(-1px); box-shadow: 0 10px 22px -8px rgba(255,122,26,0.45); }}
    .product-buy:active {{ transform: translateY(0); }}
    .product-buy svg {{ width: 13px; height: 13px; }}
    .product-variants {{ display: grid; gap: 8px; margin-bottom: 14px; }}
    .variant-row {{ display: flex; align-items: center; gap: 10px; }}
    .variant-label {{ font-family: var(--font-mono); font-size: 10.5px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--muted); min-width: 56px; }}
    .variant-row select {{ flex: 1; padding: 7px 10px; border-radius: var(--r-sm); border: 1px solid var(--border-2); background: rgba(255,255,255,0.04); color: var(--text); font-family: inherit; font-size: 13px; cursor: pointer; }}
    .variant-row select:focus {{ outline: none; border-color: var(--ember); }}
    .product-stock-out {{ background: rgba(220,38,38,0.15); color: #fca5a5; border: 1px solid rgba(220,38,38,0.4); padding: 5px 11px; border-radius: var(--r-pill); font-family: var(--font-mono); font-size: 10.5px; letter-spacing: 0.16em; text-transform: uppercase; }}
  </style>
</head>
<body>
  <header class="nav">
    <div class="container nav-inner">
      <a href="/" class="brand"><span class="brand-mark"><img src="/assets/img/logo.png" alt="Hilltrek" width="46" height="46" /></span></a>
      <nav class="nav-links">
        <a href="/">Mission Control</a><a href="/hikes/">Hikes</a><a href="/reviews/">Reviews</a>
        <a href="/trailtether/">TrailTether</a><a href="/merch/" class="active">Merch</a><a href="/reach-out/">Reach Out</a>
        <a href="/trailtether/#download" class="nav-cta" data-apk-link>Get the App</a>
      </nav>
      <button class="nav-toggle">☰</button>
    </div>
  </header>
  <section class="page-hero"><div class="container">
    <span class="eyebrow">// Hilltrek store · Worn in the Berg</span>
    <h1>Hilltrek apparel & trail kit.</h1>
    <p>Hoodies, hats, beanies, balaclavas and gaiters — every piece carries the Hilltrek mountain emblem, every piece earns its place on the trail.</p>
  </div></section>
  <section class="section-tight"><div class="container">
    <div class="product-grid">{cards_html}</div>
  </div></section>
  {footer}
  <script>document.getElementById('year').textContent = new Date().getFullYear();</script>
  <script src="/assets/js/cart.js" defer></script>
  <script src="/assets/js/site.js" defer></script>
</body>
</html>`;

const TPL_PRODUCT_CARD = `<div class="product-card" data-slug="{slug}">
  <div class="product-media">{tag_html}<img src="{image}" alt="{name}" loading="lazy" /></div>
  <div class="product-body">
    <div class="product-meta">{category_label}</div>
    <h3>{name}</h3>
    <p class="product-blurb">{blurb}</p>
    {variant_selects_html}
    <div class="product-bottom"><div class="product-price">{price_html}</div>{buy_html}</div>
  </div>
</div>`;

// ----------------------------------------------------------------------------
// Renderers
// ----------------------------------------------------------------------------
function renderHikeDetail(hike: any, all: any[]): string {
  const intro = hike.intro ?? "";
  return fmt(TPL_HIKE_DETAIL, {
    title: esc(hike.title ?? ""),
    meta_description: esc(intro.slice(0, 155)),
    hero_image_url: esc(hike.hero_image_url ?? ""),
    intro: esc(intro),
    pills_html: hikePills(hike),
    stats_html: statsRow(hike.stats ?? {}),
    body_html: mdToHtml(hike.body_md ?? ""),
    gallery_html: galleryTiles(hike.gallery_image_urls ?? []),
    next_hikes_html: nextHikesHtml(hike.slug, all),
    footer: TPL_FOOTER,
  });
}

function renderHikesIndex(hikes: any[]): string {
  const cards = hikes.map(h => fmt(TPL_HIKE_CARD, {
    slug: esc(h.slug),
    title: esc(h.title),
    intro: esc(h.intro ?? h.subtitle ?? ""),
    hero: esc(h.hero_image_url ?? ""),
    meta: hikePills(h),
    featured_pill: h.is_featured
      ? '<span class="hike-tag featured"><span class="pill"></span> Featured</span>'
      : '<span class="hike-tag"><span class="pill"></span> Route log</span>',
  })).join("\n");
  return fmt(TPL_HIKES_INDEX, { cards_html: cards, footer: TPL_FOOTER });
}

function renderMerchIndex(products: any[]): string {
  const cards = products.map(p => {
    const track = p.track_inventory ?? true;
    const outOfStock = track && p.stock_quantity != null && p.stock_quantity <= 0;

    let tagText = p.ribbon_text || (p.is_featured ? "Featured" : (p.category || "Hilltrek"));
    const tagClass = (p.ribbon_text || p.is_featured) && p.is_featured ? "featured" : "";
    const tagHtml = `<span class="product-tag ${tagClass}"><span class="pill"></span> ${esc(tagText)}</span>`;

    let blurb = (p.description_md || p.subtitle || "").split("\n\n")[0].replace(/^#+\s*/, "").trim();
    if (blurb.length > 220) blurb = blurb.slice(0, 217) + "…";

    // The Add-to-cart button carries all the data cart.js needs to insert
    // the line item without a server round-trip. Selected variant values
    // are read from the <select>s rendered above the bottom row.
    const cartSvg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/><path d="M1 1h4l2.7 13.4a2 2 0 0 0 2 1.6h9.7a2 2 0 0 0 2-1.6L23 6H6"/></svg>';
    const buyHtml = outOfStock
      ? '<span class="product-stock-out">Out of stock</span>'
      : `<button type="button" class="product-buy" data-add-to-cart ` +
        `data-slug="${esc(p.slug ?? "")}" ` +
        `data-name="${esc(p.name ?? "")}" ` +
        `data-image="${esc(p.main_image_url ?? "")}" ` +
        `data-price-cents="${Number(p.price_cents) || 0}">` +
        cartSvg + ` Add to cart</button>`;

    return fmt(TPL_PRODUCT_CARD, {
      slug: esc(p.slug ?? ""),
      tag_html: tagHtml,
      image: esc(p.main_image_url ?? ""),
      name: esc(p.name ?? ""),
      category_label: esc((p.subtitle || p.category || "").toUpperCase()),
      blurb: esc(blurb),
      variant_selects_html: variantSelectsHtml(p.variants ?? []),
      price_html: priceHtml(p.price_cents, p.compare_at_price_cents),
      buy_html: buyHtml,
    });
  }).join("\n");
  return fmt(TPL_MERCH_INDEX, { cards_html: cards, footer: TPL_FOOTER });
}
