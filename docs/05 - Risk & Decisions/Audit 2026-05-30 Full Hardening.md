---
tags: [type/audit, status/current, domain/security, domain/safety]
aliases: [Full Hardening Audit 2026-05-30]
---

# Audit — 2026-05-30 Full Platform Hardening

Autonomous 11-phase audit across all 5 components (Flutter app, Garmin watch,
storefront, admin SPA, Supabase). Method: 6 parallel read-only audit agents, then
**every CRITICAL/HIGH claim verified against ground truth before acting** — ~5 of 8
agent-flagged CRITICAL/HIGH items were FALSE ALARMS. Full detail in repo
`AUDIT_LOG.md`. Builds on the morning's [[Audit Findings|RLS/grant/verify_jwt pass]]
(migration `20260530_security_audit_critical_high_fixes` + 9 edge-function redeploys).

## Verdict
**No CRITICAL findings.** No service-role-key leak, no committed secrets, no RLS
bypass, no payment-forgery path. Safety-critical logic fails safe throughout and
was **not modified** (so no safety-behaviour change tests were required).

## Findings
- **HIGH H1** — Auth leaked-password protection still disabled. Dashboard →
  Authentication → Password (HaveIBeenPwned). 1 toggle. *(carried from [[Known Issues]])*
- **MED M1** — `incident-photos` storage bucket is `public:true`; the app uploads
  safety-incident photos and serves via `getPublicUrl`. Empty today → no live leak.
  Fix = signed URLs + flip private (coordinated change; flagged, not done).
- **MED M2** — `watch_devices` had no owner DELETE policy (can't self-revoke a lost
  watch). Additive policy staged in the gated migration (see below).
- **MED M3** — `zapper-webhook` multi-format signature fallback (4 headers × hex|base64,
  marked UNCONFIRMED). Confirm canonical scheme against a real delivery, then narrow.
  Don't change blind (live-payment risk).
- **LOW** — empty unused public buckets `gpx-files`/`gpx_files` (delete, gated);
  `pc_shell.dart` dead code (FIXED); watch `properties.xml` default token (clear
  before CIQ publish — see [[Watch App Module]]); `tether_pairings` hiker self-revoke
  (product decision).

## Payment webhooks (code audit — secrets unreadable)
PayFast / Yoco / Zapper all verify signature BEFORE mutation, validate amount vs
stored order, are idempotent, fail closed, and run `verify_jwt:false`. **PASS** (Zapper
caveat M3). None executed end-to-end (signing secrets are server-side env vars).

## Safety logic (audited deep — fails safe, unchanged)
Off-trail (`40m + 1.5×accuracy` cap 120m, 5-min debounce), live tracking (position
age graded live/recent/stale — the headline "stale-shown-as-live" bug is handled),
SOS (5s hold + 15s timeout + loud failure, refuses null GPS), weather (45-min lead
gate), GPS pipeline (accuracy/jump/stale gates, UTC, metres), watch off-route (−1
sentinel guards null/`(0,0)` route). See `AUDIT_LOG.md` for per-path detail.

## Applied this pass
- `main` commit `0afba0d`: deep-link auth-payload guard + dead-code cleanup.
  `flutter analyze` → 0 issues.

## Awaiting decision
- **Gated production migration** (additive, safe):
  ```sql
  CREATE POLICY watch_devices_owner_delete ON public.watch_devices
    FOR DELETE TO authenticated USING (auth.uid() = user_id);
  ```
- H1 toggle, M1 bucket change, M3 Zapper confirmation, L1 bucket deletion — user.

## GO / NO-GO
**GO for shipping to test.** No blocker found. Remaining items are hardening (H1/M1),
a non-leak capability gap (M2), and confirm-then-narrow (M3) — none block a test ship.

Related: [[Known Issues]], [[Fragile Areas]], [[Audit Findings]], [[Watch App Module]].
