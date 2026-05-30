---
tags: [type/runbook, layer/ops, status/current, domain/auth, domain/email]
aliases: [Trailtether auth email setup]
source_paths: [docs/email-templates/confirm-signup.html, docs/email-templates/reset-password.html, trailtether_app/lib/services/auth_service.dart]
---

# Trailtether auth email setup

End-to-end runbook for the welcome (confirm-signup) + password-reset emails. Outbound via cPanel SMTP on `no-reply@trailtether.co.za`, branded HTML templates, deep-link back into the Flutter app.

The Flutter side is already wired in `4.0.2+65+` — this doc covers the parts I can't do for you: cPanel mailbox creation, Supabase Dashboard config, DNS records.

## 1. Create the sender mailbox in cPanel

In cPanel → Email Accounts → **Create**:

| Field | Value |
|---|---|
| Username | `no-reply` |
| Domain | `trailtether.co.za` |
| Password | (generate a strong one — store in your password manager) |
| Storage Space | 100 MB (we never read this inbox; replies go to `info@`) |

Once created, click **Connect Devices** on the mailbox row. Copy these — you'll paste them into Supabase:

| Setting | Typical cPanel value |
|---|---|
| Outgoing Server | `mail.trailtether.co.za` |
| SMTP Port | `465` (SSL) — preferred. Fallback `587` (STARTTLS). |
| Username | `no-reply@trailtether.co.za` (full address, NOT just `no-reply`) |
| Password | the one you just set |

## 2. Set the Reply-To routing in cPanel

So replies to `no-reply@` land in `info@` (rather than a black hole):

cPanel → Forwarders → **Add Forwarder**:
- Address to forward: `no-reply@trailtether.co.za`
- Destination: `info@trailtether.co.za`

(Optional but recommended — auto-replies that explain not to reply are spammy. Forwarding is cleaner.)

## 3. DNS — make Gmail/Outlook trust the sender

Without these, large mailbox providers drop your mail or send it straight to spam.

In cPanel → Email Deliverability for `trailtether.co.za`:

- **SPF**: ensure the record exists and includes your cPanel server. Typical:
  `v=spf1 +a +mx +ip4:<your-cpanel-IP> ~all`
- **DKIM**: cPanel's Email Deliverability page generates the public key — click **Manage** and ensure it's published in your DNS. (If you use Cloudflare for DNS, copy the TXT record there.)
- **DMARC**: add a TXT record on `_dmarc.trailtether.co.za`:
  `v=DMARC1; p=none; rua=mailto:info@trailtether.co.za`

Allow up to an hour for DNS propagation before sending the first test.

## 4. Supabase — point Auth at the new SMTP

Supabase Dashboard → **Authentication → SMTP Settings**:

| Field | Value |
|---|---|
| Enable Custom SMTP | ✅ |
| Sender email | `no-reply@trailtether.co.za` |
| Sender name | `Trailtether` |
| Host | `mail.trailtether.co.za` |
| Port | `465` |
| Username | `no-reply@trailtether.co.za` |
| Password | from step 1 |
| Minimum interval between emails per address | `60` (seconds — keeps automated abuse manageable) |

Save and click **Send Test Email** to your own address. If it lands in your inbox (not spam) → SMTP is good.

## 5. Supabase — register the deep-link redirect URLs

Supabase Dashboard → **Authentication → URL Configuration → Redirect URLs**.

Add both, plus the existing OAuth one:

```
trailtether://login-callback
trailtether://reset-password
trailtether://confirm
```

Save. Without this, Supabase strips redirect URLs it doesn't recognise and the user lands on Supabase's default page instead of the app.

## 6. Supabase — paste the branded templates

Supabase Dashboard → **Authentication → Email Templates**.

For each template, switch to the HTML editor and paste the matching file:

| Template tab | File |
|---|---|
| Confirm signup | [`confirm-signup.html`](docs/email-templates/confirm-signup.html) |
| Reset Password | [`reset-password.html`](docs/email-templates/reset-password.html) |

The only template variable used is `{{ .ConfirmationURL }}` which Supabase replaces with the actual deep-link. Don't add extra interpolations — Supabase's template engine is strict.

Also set the **subject lines**:

| Template | Subject |
|---|---|
| Confirm signup | `Welcome to Trailtether — confirm your email` |
| Reset Password | `Reset your Trailtether password` |

## 7. Smoke test

On a phone with the app installed:

1. **Signup confirm**: register a new email (use a Gmail / personal address you can read). Email should arrive from `Trailtether <no-reply@trailtether.co.za>` within seconds. Tap **Confirm email & get started** → the Trailtether app opens to the home shell.
2. **Password reset**: from the login screen, type that email → tap **Forgot password** → confirm. Email arrives. Tap **Set a new password** → app opens to the *Set a new password* screen → set a password → routed to the home shell. Sign out and sign back in with the new password to verify.

If either email never arrives, check:
- Supabase Dashboard → **Logs → Auth** — look for the most recent `recovery` or `signup` event and any error.
- Spam folder. If spammed, revisit step 3 (DNS) and/or warm up the sender slowly.
- cPanel mail logs (cPanel → Email → Track Delivery).

## 8. Notes for later

- **DMARC enforcement**: once the email is reliably delivered for a few weeks, tighten `p=none` to `p=quarantine` so spoofs get junked.
- **List-unsubscribe**: Gmail's bulk-sender rules require a one-click unsubscribe header for senders >5k/day. Trailtether isn't there yet; add the header when adding any marketing emails.
- **Welcome email v2**: if you want a separate post-confirmation onboarding email (link to download, watch app, tips), add a Postgres trigger on `auth.users.email_confirmed_at` change → calls an edge function → sends via SMTP. Keep the current confirm+welcome as the only signup email until that's needed.

## Related

- [[Watch App Module]] — the watch app gets a mention in the welcome email
- [[apk-download-gate]] — alternate "get the app" entry point
- [[Workflow - Auth]] — broader auth-flow reference
