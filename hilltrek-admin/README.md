# Hilltrek admin (`admin.hilltrek.co.za`)

A single-user SPA for managing hilltrek.co.za content. Branded admin UI on
top of the same Supabase project the Trailtether mobile app uses.

## Layout

```
hilltrek-admin/
├── index.html          SPA shell (login + app views)
├── app.js              All app logic — auth, MFA, hikes CRUD, products CRUD
├── styles.css          Dark/ember design tokens, matches the public site
├── config.js           Supabase URL + anon key + bucket name
├── .htaccess           Hardening + HTTPS + CSP for the production subdomain
├── assets/             Logo + favicon
├── templates/          HTML templates used by the static-site generator
└── scripts/
    └── generate_site.py   Reads Supabase → regenerates hilltrek-site/ HTML
```

## Two-factor authentication

The admin uses TOTP-based 2FA via Supabase Auth. After signing in with email
+ password, if a verified TOTP factor exists on the account the user is
prompted for a 6-digit code from their authenticator app.

To enable 2FA:

1. Sign in (without 2FA) for the first time.
2. Navigate to **Security**.
3. Click **+ Enable 2FA**.
4. Scan the QR code with Google Authenticator / Authy / 1Password.
5. Enter the 6-digit code to confirm. Done.

To recover if the device is lost:

1. Open the Supabase Dashboard → Authentication → Users → your account.
2. Click the menu next to the account → **Remove MFA factor**.
3. Sign in with password, re-enrol 2FA on the Security page.

## Supabase project hardening — do these once

The Supabase project is **shared with the Trailtether mobile app**.
The Trailtether app needs public sign-ups enabled so hikers can register —
don't disable them. Hilltrek admin access is gated separately via the
`public.admin_users` allowlist (see below).

Apply these in the Supabase Dashboard before giving the admin URL to anyone.

### 1. Admin allowlist (the important one)

The migration that creates this table is already applied. You need to add
your user account to it so the admin app lets you in.

After you create your auth user (Dashboard → Authentication → Users → Add
User → your email + a strong password → Auto Confirm User), open the SQL
Editor and run:

```sql
insert into public.admin_users (user_id, email, notes)
select id, email, 'Hilltrek admin'
from auth.users
where email = 'bremnermail@gmail.com'
on conflict (user_id) do nothing
returning *;
```

(Replace the email with whatever you used.)

From this point: anyone can sign up to the project via the Trailtether app,
but **only users in `admin_users` can write to `site_hikes` /
`site_products` / website-assets storage**. The admin SPA also calls
`is_admin()` on every page load and signs out anyone who isn't on the list.

To revoke admin later:

```sql
delete from public.admin_users where email = 'someone@example.com';
```

### 2. Restrict allowed origins

Dashboard → **Authentication** → **URL Configuration**:
- **Site URL**: `https://admin.hilltrek.co.za`
- **Redirect URLs**: include both
  - `https://admin.hilltrek.co.za/*`
  - `https://hilltrek.co.za/*` (the public site uses Supabase for the dynamic
    Trailtether APK lookup)
  - `trailtether://*` (if the mobile app uses deep links — already in place)

Add `http://localhost:5174/*` while developing locally; remove before
production handover.

### 3. Password protection

Dashboard → **Authentication** → **Policies** → **Password protection**:
- **Minimum password length**: 12 (works on Free plan)
- **Prevent use of leaked passwords**: requires Supabase Pro plan ($25/mo).
  Skip on Free; revisit if upgrading.

### 4. Email confirmations stay ON for both apps

Dashboard → **Authentication** → **Providers** → **Email**:
- **Enable Email provider**: ON
- **Enable Confirmations**: ON (so a sign-up email-bombing attack can't just
  fill the auth table with un-confirmed accounts)
- **Secure email change**: ON
- **Allow new users to sign up**: **leave ON** — the Trailtether app needs
  this. Admin access is gated via `admin_users`, not via this flag.

### 5. Tighten session length (optional)

Dashboard → **Authentication** → **Sessions**: defaults (1h JWT,
rotating refresh tokens) are fine; tighten only if you want shorter
sessions.

### 6. Rate limiting

Supabase Auth applies built-in rate limiting (30 sign-ins/hour/IP). No
config needed; just know it exists if you get locked out testing.

## Deploy the admin

Upload everything in this folder **except `scripts/`** to the cPanel
subdomain at `admin.hilltrek.co.za/`. The `scripts/` folder is meant to run
locally on the maintainer's machine.

```
admin.hilltrek.co.za/
├── index.html
├── app.js
├── styles.css
├── config.js
├── .htaccess
├── assets/logo.png
└── templates/                  (optional — generator reads them locally,
                                 not needed at runtime in the browser)
```

## The publish loop

1. Edit hikes / products in the admin UI; save with **Published** ticked.
2. Click **↑ Publish to live site** on the Mission Control dashboard.

That's it. The Edge Function renders all hike pages, `/hikes/`, and
`/merch/` and pushes them to cPanel `public_html/` over HTTPS.

(The Python generator in `scripts/generate_site.py` is kept around as a
local fallback / preview tool — never required for production.)

### One-time setup for the Publish button

The Publish button calls a Supabase Edge Function (`publish-site`) which
authenticates to cPanel using an **API token**, not your password.

**1. Generate a cPanel API token.**

- cPanel → **Security** → **Manage API Tokens** → **Create**
- Name: `hilltrek-publish`
- Expiry: leave blank (no expiry) or set 1 year out
- Privileges: leave at defaults (full account) — the function only needs
  Fileman, but cPanel doesn't expose a granular per-feature toggle
- Copy the token immediately — cPanel only shows it once

**2. Add the four secrets to the Edge Function.**

- Supabase Dashboard → **Edge Functions** → **publish-site** → **Secrets**
- Add:

  | Name              | Value                                              |
  | ----------------- | -------------------------------------------------- |
  | `CPANEL_HOST`     | Your cPanel server hostname (e.g. `fennec.aserv.co.za`) — no `https://`, no port |
  | `CPANEL_USER`     | Your cPanel username (e.g. `hilltro7a4x5`)         |
  | `CPANEL_API_TOKEN`| The token from step 1                              |
  | `CPANEL_HOME`     | Absolute path to your public_html, e.g. `/home/hilltro7a4x5/public_html` |

  `CPANEL_HOST` and `CPANEL_USER` are visible at the top-left of cPanel
  ("Logged in as … to fennec.aserv.co.za"). `CPANEL_HOME` is shown on the
  cPanel dashboard under "General Information" → "Home Directory" — append
  `/public_html` to that path.

**3. Test the button.**

Open the admin → Mission Control → click **↑ Publish to live site**. You
should see a green ✓ within 10-30s and the live site at hilltrek.co.za
reflecting the latest content.

If anything fails, the dashboard panel shows the exact file path and
HTTP error per file. Most failures are either:

- The four secrets aren't set (or have typos) → fix in Supabase Dashboard
- The API token has been revoked → regenerate and update `CPANEL_API_TOKEN`
- `CPANEL_HOME` path is wrong → verify against cPanel "Home Directory"
