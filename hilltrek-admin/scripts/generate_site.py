#!/usr/bin/env python3
"""
Hilltrek site generator
=======================

Reads published hikes from Supabase and regenerates the static HTML files
under hilltrek-site/hikes/.

Why this exists:
  Public site is static (fast, SEO clean, cheap hosting). Content lives in
  Supabase so non-technical editors can manage it via the admin UI. This
  script bridges the two by re-rendering HTML whenever the editor publishes.

Usage:
  python scripts/generate_site.py
  python scripts/generate_site.py --site-dir "C:\\path\\to\\hilltrek-site"
  python scripts/generate_site.py --dry-run    # show what would change

No third-party dependencies — uses only stdlib (urllib for the Supabase
REST call, a tiny inline markdown renderer for the body text).
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import sys
import urllib.request
from pathlib import Path
from typing import Any

# ------------------------------------------------------------------
# Config — change these only if the Supabase project moves.
# ------------------------------------------------------------------
SUPABASE_URL = "https://xuqmdujupbmxahyhkdwl.supabase.co"
SUPABASE_ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh1c"
    "W1kdWp1cGJteGFoeWhrZHdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyMzYyODYsImV4cC"
    "I6MjA5MjgxMjI4Nn0.aUfLfzgW25Ozsl9EMkDfmelBzxlCOWjGcatQQ-eh2Jo"
)

REPO_ROOT = Path(__file__).resolve().parent.parent.parent  # Trailtetherv2.0/
ADMIN_DIR = REPO_ROOT / "hilltrek-admin"
DEFAULT_SITE_DIR = Path("C:/Users/bremn/Documents/hilltrek-site")  # legacy path


# ------------------------------------------------------------------
# Supabase REST
# ------------------------------------------------------------------
def _supabase_get(endpoint: str) -> list[dict[str, Any]]:
    """GET helper for Supabase REST API."""
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/{endpoint}",
        headers={
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_published_hikes() -> list[dict[str, Any]]:
    """Returns published hikes ordered for display."""
    return _supabase_get(
        "site_hikes?select=*"
        "&is_published=eq.true"
        "&order=display_order.asc,hike_date.desc.nullslast"
    )


def fetch_active_products() -> list[dict[str, Any]]:
    """Returns active products ordered for display."""
    return _supabase_get(
        "site_products?select=*"
        "&is_active=eq.true"
        "&order=display_order.asc"
    )


# ------------------------------------------------------------------
# Tiny markdown renderer
#   Supports: ## h2, ### h3, paragraphs, - bullet lists, **bold**, _italic_,
#             [text](url). Anything fancier (tables, code blocks, images)
#             is not used in hike bodies and would just bloat this script.
# ------------------------------------------------------------------
_BOLD = re.compile(r"\*\*([^*]+)\*\*")
_ITAL_ASTERISK = re.compile(r"(?<!\w)\*([^*]+)\*(?!\w)")
_ITAL_UNDER = re.compile(r"(?<!\w)_([^_]+)_(?!\w)")
_LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")


def _inline(s: str) -> str:
    s = html.escape(s)
    s = _LINK.sub(r'<a href="\2">\1</a>', s)
    s = _BOLD.sub(r"<strong>\1</strong>", s)
    s = _ITAL_ASTERISK.sub(r"<em>\1</em>", s)
    s = _ITAL_UNDER.sub(r"<em>\1</em>", s)
    return s


def md_to_html(md: str) -> str:
    if not md or not md.strip():
        return ""
    out: list[str] = []
    in_list = False
    para: list[str] = []

    def flush_para():
        nonlocal para
        if para:
            out.append("<p>" + _inline(" ".join(para)).strip() + "</p>")
            para = []

    def flush_list():
        nonlocal in_list
        if in_list:
            out.append("</ul>")
            in_list = False

    for raw in md.splitlines():
        line = raw.rstrip()
        if not line:
            flush_para()
            flush_list()
            continue
        if line.startswith("## "):
            flush_para(); flush_list()
            out.append(f"<h2>{_inline(line[3:])}</h2>")
        elif line.startswith("### "):
            flush_para(); flush_list()
            out.append(f"<h3>{_inline(line[4:])}</h3>")
        elif line.startswith("- "):
            flush_para()
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{_inline(line[2:])}</li>")
        else:
            flush_list()
            para.append(line)
    flush_para()
    flush_list()
    return "\n".join(out)


# ------------------------------------------------------------------
# Templates
# ------------------------------------------------------------------
def _load_template(name: str) -> str:
    path = ADMIN_DIR / "templates" / name
    return path.read_text(encoding="utf-8")


def _resolve_url(u: str | None) -> str:
    if not u:
        return ""
    return u


def _format_date(d: str | None) -> str:
    if not d:
        return ""
    try:
        from datetime import date
        dt = date.fromisoformat(d)
        return dt.strftime("%d %b %Y").upper()
    except Exception:
        return d


# Pills + tag rendering
def _hike_pills(hike: dict[str, Any]) -> str:
    bits = []
    if hike.get("region"):
        bits.append(hike["region"].upper())
    if hike.get("hike_date"):
        bits.append(_format_date(hike["hike_date"]))
    if hike.get("hike_type"):
        bits.append(hike["hike_type"].upper())
    if hike.get("difficulty"):
        bits.append(hike["difficulty"].upper())
    out = []
    for i, b in enumerate(bits):
        if i:
            out.append('<span class="dot"></span>')
        out.append(f'<span><span class="pill"></span> {html.escape(b)}</span>')
    return "".join(out)


def _stats_row(stats: dict[str, Any]) -> str:
    """Renders 4 stat cells from the stats JSONB. Fills with sane defaults."""
    cells = []
    items = list(stats.items())[:4] if stats else []
    while len(items) < 4:
        items.append(("", ""))
    for label, val in items:
        label_disp = (str(label).replace("_", " ").title() if label else "&nbsp;")
        val_disp = html.escape(str(val)) if val else "&mdash;"
        cells.append(
            f'<div class="stat-cell"><div class="label">{label_disp}</div>'
            f'<div class="val">{val_disp}</div></div>'
        )
    return "\n".join(cells)


def _gallery_tiles(urls: list[str]) -> str:
    if not urls:
        return ""
    tile_classes = ["g1", "g2", "g3", "g4", "g5", "g6"]
    out = []
    for i, u in enumerate(urls[:6]):
        cls = tile_classes[i % len(tile_classes)]
        out.append(
            f'<div class="gallery-tile {cls}">'
            f'<img src="{html.escape(_resolve_url(u))}" alt="" loading="lazy" />'
            f"</div>"
        )
    return "\n".join(out)


def _next_hikes(current_slug: str, all_hikes: list[dict[str, Any]]) -> str:
    """The two cards at the bottom of a hike page linking to other hikes."""
    others = [h for h in all_hikes if h["slug"] != current_slug][:2]
    if not others:
        return ""
    cards = []
    for o in others:
        thumb = html.escape(_resolve_url(o.get("hero_image_url") or ""))
        thumb_html = ('<img src="' + thumb + '" alt="" />') if thumb else ""
        cards.append(
            '<a class="next-card" href="/hikes/' + html.escape(o["slug"]) + '/">'
            '<div class="thumb">' + thumb_html + '</div>'
            '<div class="body"><div class="dir">→ Other hike</div>'
            '<h4>' + html.escape(o["title"]) + '</h4></div>'
            "</a>"
        )
    return "\n".join(cards)


def render_hike_detail(hike: dict[str, Any], all_hikes: list[dict[str, Any]]) -> str:
    template = _load_template("hike-detail.html")
    return template.format(
        title=html.escape(hike.get("title") or ""),
        subtitle=html.escape(hike.get("subtitle") or ""),
        intro=html.escape(hike.get("intro") or ""),
        meta_description=html.escape((hike.get("intro") or hike.get("subtitle") or "")[:155]),
        slug=html.escape(hike["slug"]),
        hero_image_url=html.escape(_resolve_url(hike.get("hero_image_url") or "")),
        pills_html=_hike_pills(hike),
        stats_html=_stats_row(hike.get("stats") or {}),
        body_html=md_to_html(hike.get("body_md") or ""),
        gallery_html=_gallery_tiles(hike.get("gallery_image_urls") or []),
        next_hikes_html=_next_hikes(hike["slug"], all_hikes),
    )


def _format_price_html(price_cents: int, compare_cents: int | None = None) -> str:
    rand = f"{price_cents / 100:.0f}" if price_cents % 100 == 0 else f"{price_cents / 100:.2f}"
    out = f'<span class="cur">R</span>{rand}'
    if compare_cents and compare_cents > price_cents:
        compare_rand = f"{compare_cents / 100:.0f}" if compare_cents % 100 == 0 else f"{compare_cents / 100:.2f}"
        out += f' <span class="compare">R{compare_rand}</span>'
    return out


def _variant_options_summary(variants: list[dict[str, Any]]) -> str:
    """Renders the option groups summary line shown under the product blurb."""
    if not variants:
        return "One size · One option"
    parts = []
    for v in variants:
        name = v.get("name") or "Option"
        values = v.get("values") or []
        if not values:
            continue
        parts.append(f"{html.escape(name)}: {html.escape(' / '.join(values))}")
    return " · ".join(parts) if parts else "—"


def _product_mailto(product: dict[str, Any]) -> str:
    """Builds the pre-filled mailto: order URL for a product. Switches to a real
    cart/checkout when PayFast is wired up in Phase B/C."""
    from urllib.parse import quote
    name = product.get("name", "")
    price_rand = f"R{product['price_cents'] / 100:.0f}" if product["price_cents"] % 100 == 0 else f"R{product['price_cents'] / 100:.2f}"

    body_lines = [
        "Hi Hilltrek,",
        "",
        "I'd like to order:",
        "",
        f"Product: {name} — {price_rand}",
    ]
    for v in product.get("variants") or []:
        opts = " / ".join(v.get("values") or [])
        body_lines.append(f"{v.get('name', 'Option')}: [{opts}]")
    body_lines += [
        "Quantity: 1",
        "",
        "Name: ",
        "Delivery address: ",
        "",
        "Thanks!",
    ]
    subject = f"Order: {name} ({price_rand})"
    body = "\n".join(body_lines)
    return f"mailto:info@hilltrek.co.za?subject={quote(subject)}&body={quote(body)}"


def render_products_grid(products: list[dict[str, Any]]) -> str:
    card_tpl = _load_template("_product-card.html")
    cards = []
    for p in products:
        # Tag chooser: ribbon_text wins; else featured; else first tag
        if p.get("ribbon_text"):
            tag_text = p["ribbon_text"]
            tag_classes = "featured" if p.get("is_featured") else ""
        elif p.get("is_featured"):
            tag_text = "Featured"
            tag_classes = "featured"
        elif p.get("category"):
            tag_text = p["category"]
            tag_classes = ""
        else:
            tag_text = "Hilltrek"
            tag_classes = ""

        tag_html = (
            f'<span class="product-tag {tag_classes}">'
            f'<span class="pill"></span> {html.escape(tag_text)}'
            f'</span>'
        )

        # Stock check
        track = p.get("track_inventory", True)
        qty = p.get("stock_quantity")
        out_of_stock = track and qty is not None and qty <= 0

        # Blurb: take description first paragraph or subtitle
        blurb_src = p.get("description_md") or p.get("subtitle") or ""
        first_para = blurb_src.split("\n\n")[0].lstrip("# ").strip()
        if len(first_para) > 220:
            first_para = first_para[:217] + "…"

        # Build the buy button — out-of-stock products show a different state
        if out_of_stock:
            buy_html = '<span class="product-stock-out">Out of stock</span>'
        else:
            buy_html = (
                '<span class="product-buy">'
                '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" '
                'stroke-linecap="round" stroke-linejoin="round">'
                '<circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/>'
                '<path d="M1 1h4l2.7 13.4a2 2 0 0 0 2 1.6h9.7a2 2 0 0 0 2-1.6L23 6H6"/>'
                '</svg> Order'
                '</span>'
            )

        cards.append(card_tpl.format(
            order_mailto=_product_mailto(p),
            tag_html=tag_html,
            image=html.escape(_resolve_url(p.get("main_image_url") or "")),
            name=html.escape(p["name"]),
            category_label=html.escape((p.get("subtitle") or p.get("category") or "").upper()),
            blurb=html.escape(first_para),
            options_summary=_variant_options_summary(p.get("variants") or []),
            price_html=_format_price_html(p["price_cents"], p.get("compare_at_price_cents")),
            buy_html=buy_html,
        ))
    return "\n".join(cards)


def render_merch_index(products: list[dict[str, Any]]) -> str:
    template = _load_template("merch-index.html")
    return template.format(cards_html=render_products_grid(products))


def render_hikes_index(hikes: list[dict[str, Any]]) -> str:
    template = _load_template("hikes-index.html")
    card_tpl = _load_template("_hike-card.html")
    cards = []
    for h in hikes:
        cards.append(card_tpl.format(
            slug=html.escape(h["slug"]),
            title=html.escape(h["title"]),
            intro=html.escape(h.get("intro") or h.get("subtitle") or ""),
            hero=html.escape(_resolve_url(h.get("hero_image_url") or "")),
            meta=_hike_pills(h),
            featured_pill='<span class="hike-tag featured"><span class="pill"></span> Featured</span>'
                if h.get("is_featured") else
                '<span class="hike-tag"><span class="pill"></span> Route log</span>',
        ))
    return template.format(cards_html="\n".join(cards))


# ------------------------------------------------------------------
# Writer
# ------------------------------------------------------------------
def write_if_changed(path: Path, content: str, dry_run: bool) -> tuple[str, int]:
    """Returns ('created'|'updated'|'unchanged', bytes_written)."""
    new_bytes = content.encode("utf-8")
    if path.exists():
        existing = path.read_bytes()
        if existing == new_bytes:
            return ("unchanged", 0)
        status = "updated"
    else:
        status = "created"
    if dry_run:
        return (status + " (dry-run)", len(new_bytes))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(new_bytes)
    return (status, len(new_bytes))


# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--site-dir", type=Path, default=DEFAULT_SITE_DIR,
        help=f"Path to the static site root (default: {DEFAULT_SITE_DIR})"
    )
    ap.add_argument("--dry-run", action="store_true", help="Report changes without writing.")
    args = ap.parse_args()

    site_dir: Path = args.site_dir
    if not site_dir.exists():
        print(f"ERROR: site dir not found: {site_dir}", file=sys.stderr)
        return 2

    print(f"Fetching published hikes from Supabase...")
    try:
        hikes = fetch_published_hikes()
    except Exception as e:
        print(f"ERROR: Supabase fetch failed: {e}", file=sys.stderr)
        return 3
    print(f"  {len(hikes)} published hike(s)")

    if not hikes:
        print("Nothing to publish. Add hikes via the admin first.")
        return 0

    hikes_dir = site_dir / "hikes"
    summary: list[tuple[str, str, int]] = []

    # Detail pages
    for h in hikes:
        target = hikes_dir / h["slug"] / "index.html"
        html_out = render_hike_detail(h, hikes)
        status, n = write_if_changed(target, html_out, args.dry_run)
        summary.append((status, str(target.relative_to(site_dir)), n))

    # Hikes listing page
    target = hikes_dir / "index.html"
    html_out = render_hikes_index(hikes)
    status, n = write_if_changed(target, html_out, args.dry_run)
    summary.append((status, str(target.relative_to(site_dir)), n))

    # Merch listing page (built from site_products)
    try:
        products = fetch_active_products()
        print(f"  {len(products)} active product(s)")
        merch_target = site_dir / "merch" / "index.html"
        html_out = render_merch_index(products)
        status, n = write_if_changed(merch_target, html_out, args.dry_run)
        summary.append((status, str(merch_target.relative_to(site_dir)), n))
    except Exception as e:
        print(f"  WARN: merch generation failed (non-fatal): {e}", file=sys.stderr)

    # Report
    print()
    for status, path, n in summary:
        size = f"{n} bytes" if n else "no change"
        print(f"  [{status:>20}]  {path}  ({size})")

    changes = sum(1 for s, _, _ in summary if not s.startswith("unchanged"))
    print()
    print(f"Done. {changes} of {len(summary)} files {'would be ' if args.dry_run else ''}changed.")
    if changes and not args.dry_run:
        print()
        print("Next step: upload these files to cPanel public_html/ via File Manager.")
        print(f"  Affected paths under: {hikes_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
