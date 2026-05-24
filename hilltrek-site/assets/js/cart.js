// =============================================================================
// Hilltrek shopping cart — vanilla JS, localStorage-backed.
//
// Loaded by every page that needs to read/write the cart: /merch/, /cart/,
// /checkout/, /order-confirmation/. Other pages can include it harmlessly —
// it only injects UI if the page has a recognisable nav.
//
// Cart data shape (one localStorage key, JSON array):
//   [
//     { slug, name, image, priceCents, qty, variants: { Size: 'M', ... } },
//     ...
//   ]
//
// Lines are deduplicated by slug + JSON.stringify(variants). Same product
// with different size = two lines. Same product, same size, second click =
// quantity bumps.
//
// Public API (window.HilltrekCart):
//   .read()             -> Array of items
//   .add(item)          -> add { slug, name, image, priceCents, qty, variants }
//   .updateQty(slug, variants, qty)
//   .remove(slug, variants)
//   .clear()
//   .count()            -> total item count across all lines
//   .subtotalCents()    -> sum of priceCents * qty
//   .priceString(cents) -> "R149" / "R149.50"
//   .lineKey(slug, variants) -> stable string id for a line
// =============================================================================

(function () {
  'use strict';

  const CART_KEY = 'hilltrek_cart_v1';
  const CART_CHANGED_EVENT = 'hilltrek:cart-changed';

  // -------------------------------------------------------------------
  // Storage helpers
  // -------------------------------------------------------------------
  function readCart() {
    try {
      const raw = localStorage.getItem(CART_KEY);
      if (!raw) return [];
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }

  function writeCart(items) {
    try {
      localStorage.setItem(CART_KEY, JSON.stringify(items));
    } catch (err) {
      console.warn('[hilltrek-cart] failed to persist cart:', err);
    }
    window.dispatchEvent(new CustomEvent(CART_CHANGED_EVENT, { detail: items }));
  }

  function lineKey(slug, variants) {
    return slug + '|' + JSON.stringify(variants || {});
  }

  // -------------------------------------------------------------------
  // Mutators
  // -------------------------------------------------------------------
  function addItem(item) {
    const slug       = item.slug;
    const name       = item.name;
    const image      = item.image || '';
    const priceCents = parseInt(item.priceCents, 10);
    const qty        = Math.max(1, parseInt(item.qty || 1, 10));
    const variants   = item.variants || {};
    if (!slug || !name || !Number.isFinite(priceCents)) {
      console.warn('[hilltrek-cart] add() rejected — missing fields', item);
      return readCart();
    }
    const items = readCart();
    const key   = lineKey(slug, variants);
    const found = items.find(it => lineKey(it.slug, it.variants) === key);
    if (found) {
      found.qty += qty;
    } else {
      items.push({ slug, name, image, priceCents, qty, variants });
    }
    writeCart(items);
    return items;
  }

  function updateQty(slug, variants, qty) {
    const items = readCart();
    const key = lineKey(slug, variants);
    const idx = items.findIndex(it => lineKey(it.slug, it.variants) === key);
    if (idx === -1) return items;
    const n = parseInt(qty, 10);
    if (!Number.isFinite(n) || n <= 0) {
      items.splice(idx, 1);
    } else {
      items[idx].qty = n;
    }
    writeCart(items);
    return items;
  }

  function removeItem(slug, variants) {
    return updateQty(slug, variants, 0);
  }

  function clearCart() {
    writeCart([]);
  }

  // -------------------------------------------------------------------
  // Read helpers
  // -------------------------------------------------------------------
  function getCount() {
    return readCart().reduce((sum, it) => sum + (parseInt(it.qty, 10) || 0), 0);
  }

  function getSubtotalCents() {
    return readCart().reduce(
      (sum, it) => sum + (parseInt(it.priceCents, 10) || 0) * (parseInt(it.qty, 10) || 0),
      0
    );
  }

  function priceString(cents) {
    const n = parseInt(cents, 10) || 0;
    if (n % 100 === 0) return 'R' + (n / 100).toFixed(0);
    return 'R' + (n / 100).toFixed(2);
  }

  // -------------------------------------------------------------------
  // Cart badge — injected into the page's primary nav. Hidden when 0.
  // -------------------------------------------------------------------
  function ensureCartBadge() {
    const navLinks = document.querySelector('.nav-links');
    if (!navLinks) return;
    let badge = document.getElementById('cart-badge');
    if (!badge) {
      badge = document.createElement('a');
      badge.id = 'cart-badge';
      badge.href = '/cart/';
      badge.className = 'cart-badge';
      badge.setAttribute('aria-label', 'View cart');
      badge.innerHTML =
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
        'stroke-width="2" stroke-linecap="round" stroke-linejoin="round" ' +
        'width="16" height="16">' +
        '<circle cx="9" cy="21" r="1"/>' +
        '<circle cx="20" cy="21" r="1"/>' +
        '<path d="M1 1h4l2.7 13.4a2 2 0 0 0 2 1.6h9.7a2 2 0 0 0 2-1.6L23 6H6"/>' +
        '</svg>' +
        '<span class="cart-count"></span>';
      const cta = navLinks.querySelector('.nav-cta');
      if (cta) navLinks.insertBefore(badge, cta);
      else     navLinks.appendChild(badge);
    }
    renderCartBadge();
  }

  function renderCartBadge() {
    const badge = document.getElementById('cart-badge');
    if (!badge) return;
    const count = getCount();
    const countEl = badge.querySelector('.cart-count');
    if (countEl) countEl.textContent = count > 0 ? count : '';
    badge.classList.toggle('has-items', count > 0);
  }

  // -------------------------------------------------------------------
  // Add-to-cart button wiring
  //
  // Looks for any element with [data-add-to-cart]. Required data-* attrs:
  //   data-slug, data-name, data-price-cents
  // Optional:
  //   data-image
  // Variants are read from <select data-variant-group="..."> inside the
  // nearest .product-card ancestor.
  // -------------------------------------------------------------------
  function wireAddToCartButtons(root) {
    (root || document).querySelectorAll('[data-add-to-cart]').forEach(btn => {
      if (btn._cartWired) return;
      btn._cartWired = true;
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        const slug       = btn.getAttribute('data-slug');
        const name       = btn.getAttribute('data-name');
        const image      = btn.getAttribute('data-image') || '';
        const priceCents = parseInt(btn.getAttribute('data-price-cents'), 10);
        if (!slug || !name || !Number.isFinite(priceCents)) return;

        const card = btn.closest('.product-card') || btn.parentElement;
        const variants = {};
        if (card) {
          card.querySelectorAll('select[data-variant-group]').forEach(sel => {
            if (sel.value) variants[sel.getAttribute('data-variant-group')] = sel.value;
          });
        }

        addItem({ slug, name, image, priceCents, qty: 1, variants });
        showAddedToast(name);
      });
    });
  }

  // -------------------------------------------------------------------
  // "Added to cart" toast
  // -------------------------------------------------------------------
  let toastTimer = null;
  function showAddedToast(name) {
    let toast = document.getElementById('cart-toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'cart-toast';
      toast.className = 'cart-toast';
      document.body.appendChild(toast);
    }
    toast.innerHTML =
      '<div class="cart-toast-row">' +
        '<span class="cart-toast-mark">✓</span>' +
        '<div class="cart-toast-body">' +
          '<div class="cart-toast-title">Added to cart</div>' +
          '<div class="cart-toast-sub">' + escapeHtml(name) + '</div>' +
        '</div>' +
        '<a class="cart-toast-link" href="/cart/">View cart →</a>' +
      '</div>';
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('show'), 3000);
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, c => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[c]));
  }

  // -------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------
  window.HilltrekCart = {
    read:          readCart,
    add:           addItem,
    updateQty:     updateQty,
    remove:        removeItem,
    clear:         clearCart,
    count:         getCount,
    subtotalCents: getSubtotalCents,
    priceString:   priceString,
    lineKey:       lineKey,
    // For pages that inject dynamic add-to-cart buttons after load.
    wireButtons:   wireAddToCartButtons,
  };

  // -------------------------------------------------------------------
  // Bootstrap
  // -------------------------------------------------------------------
  function init() {
    ensureCartBadge();
    wireAddToCartButtons();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
  window.addEventListener(CART_CHANGED_EVENT, renderCartBadge);
  // Cross-tab sync: another tab modified the cart → re-render our badge.
  window.addEventListener('storage', (e) => {
    if (e.key === CART_KEY) renderCartBadge();
  });
})();
